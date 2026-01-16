# kitchen_system.gd
extends Node
class_name KitchenSystem

var manager: RandmapManager
var available_chefs: Array[ChefData] = []
var active_orders: Array[Order] = []
var completed_orders: Array[Order] = []
var last_calculated_time: float = 0.0
var chef_manager

# --- 订单数据结构 ---
class Order:
	var customer: CustomerData
	var table_node: Node3D
	var dishes: Array = []
	var status: String = "pending"
	var dish_results: Array = []
	var estimated_completion_time: float = 0.0
	var remaining_time: float = 0.0 # 【新增】修复报错的关键变量
	
	# 【新增】外卖订单专用字段
	var is_takeaway: bool = false
	var takeaway_counter_node: Node3D = null

func _ready():
	chef_manager = preload("res://sc/chef_manager.gd").new()
	add_child(chef_manager)


func setup(randmap_manager: RandmapManager):
	manager = randmap_manager
	refresh_chef_list()

# 刷新厨师列表
func refresh_chef_list():
	available_chefs.clear()
	for chef in fc.playerData.chefs:
		if chef.is_hired: available_chefs.append(chef)

# 接收新订单
# 接收并处理订单
func receive_order(customer: CustomerData, dishes: Array, table_node: Node3D):
	
	if dishes.is_empty(): return
	
	var order = Order.new()
	order.customer = customer
	order.table_node = table_node
	order.dishes = dishes
	
	# 扣除库存
	for dish_id in dishes:
		fc.dish_data_manager.reduce_dish_stock(dish_id, 1)
	
	order.dish_results = calculate_dish_results(dishes)
	order.estimated_completion_time = find_longest_cooking_time(order.dish_results)
	
	# 【核心修改】初始化剩余时间
	order.remaining_time = order.estimated_completion_time
	last_calculated_time = order.estimated_completion_time
	
	active_orders.append(order)
	start_cooking_order(order)
	
	

# 【核心】计算每道菜的结果
# 【修复】计算每道菜的结果
func calculate_dish_results(dishes: Array) -> Array:
	var results = []
	
	#print("KitchenSystem: 开始计算菜品制作时间和质量...")
	#print("  输入菜品: ", dishes)
	
	for dish_id in dishes:
		var dish_info = get_dish_info(dish_id)
		if dish_info.is_empty():
			print("  跳过无效菜品ID: ", dish_id)
			continue
		
		# 找到负责这道菜的厨师
		var chef = find_chef_for_dish(dish_id)
		var chef_id = chef.id if chef else "unknown"
		
		# 计算制作时间（考虑厨师速度技能）
		var base_time = get_dish_base_time(dish_id)
		var cooking_time = calculate_chef_cooking_time(base_time, chef)
		
		# 【修复】确保时间大于0
		if cooking_time <= 0:
			print("  警告 - 菜品 ", dish_id, " 计算时间为0，使用默认时间")
			cooking_time = 30.0
		
		# 计算菜品质量（考虑厨师技能）
		var quality_score = calculate_dish_quality(dish_id, chef)
		
		var result = {
			"dish_id": dish_id,
			"dish_name": dish_info.get("name", "未知菜品"),
			"chef_id": chef_id,
			"chef_name": chef.name if chef else "未知厨师",
			"base_time": base_time,
			"cooking_time": cooking_time,
			"quality_score": quality_score
		}
		
		results.append(result)
		
	
	#print("  有效菜品结果数量: ", results.size())
	return results


func find_longest_cooking_time(dish_results: Array) -> float:
	if dish_results.is_empty():
		print("KitchenSystem: 警告 - 菜品结果为空，返回默认时间")
		return 30.0
	
	var max_time = 0.0
	
	for result in dish_results:
		if result.cooking_time > max_time:
			max_time = result.cooking_time
	
	# 【修复】确保返回的时间大于0
	if max_time <= 0:
		print("KitchenSystem: 警告 - 最长时间为0，使用默认时间")
		max_time = 30.0
	
	#print("KitchenSystem: 最长菜品时间: ", max_time, "秒")
	return max_time

# 找到负责指定菜品的厨师
func find_chef_for_dish(dish_id) -> ChefData:
	if available_chefs.is_empty():
		return null
	
	# 获取菜品的菜系标签
	var dish_info = get_dish_info(dish_id)
	var dish_tags = dish_info.get("tags", [])
	
	# 寻找有对应菜系技能的厨师
	var best_chef = null
	var best_skill_level = -1
	
	for chef in available_chefs:
		for cuisine in chef.cuisines:
			var cuisine_name = get_cuisine_name(cuisine)
			if cuisine_name in dish_tags:
				var skill_level = chef.cuisines[cuisine]
				if skill_level > best_skill_level:
					best_skill_level = skill_level
					best_chef = chef
	
	# 如果没有找到专业厨师，返回速度最快的厨师
	if best_chef == null:
		best_chef = available_chefs[0]
		for chef in available_chefs:
			if chef.speed_skill > best_chef.speed_skill:
				best_chef = chef
	
	return best_chef

# 【核心】计算厨师制作时间（速度技能影响）
func calculate_chef_cooking_time(base_time: float, chef: ChefData) -> float:
	if not chef:
		return base_time
	
	# 速度技能加速公式：加速比例 = 1.5 - (speed_skill / 100) * 0.5
	# speed_skill = 1 → 1.495倍时间（很慢）
	# speed_skill = 50 → 1.25倍时间
	# speed_skill = 100 → 1.0倍时间（基准速度）
	var speed_multiplier = 1.5 - (chef.speed_skill / 100.0) * 0.5
	speed_multiplier = clamp(speed_multiplier, 0.5, 2.0)  # 限制在0.5-2.0倍之间
	
	return base_time * speed_multiplier


func calculate_dish_quality(dish_id, chef: ChefData) -> float:
	# 1. 获取菜品完整信息
	var dish_info = get_dish_info(dish_id)
	if dish_info.is_empty(): return 60.0
	
	var category = dish_info.get("category", "主菜")
	var dish_tags = dish_info.get("tags", [])

	# --- 技能经验增加逻辑 (新增) ---
	# 只要是这个厨师做的菜，不论是不是主菜，只要标签匹配，就有几率加经验
	_update_chef_experience_logic(chef, dish_tags)

	# --- 策略：非主菜只给及格分 ---
	if category != "主菜":
		return 80.0

	# --- 核心：主菜深度算法 (保持你之前的要求) ---
	
	# A. 计算熟度精准度系数
	var current_val = float(dish_info.get("shudu_value", 75.0))
	var base_val = float(dish_info.get("base_shudu_value", 75.0))
	var precision = clamp(1.0 - (abs(current_val - base_val) / 100.0), 0.5, 1.0) 

	# B. 厨师基础实力
	var base_power = chef.cooking_skill * 1.2 

	# C. 菜系契合加成 (同时计算加成)
	var cuisine_bonus = 0.0
	for cuisine_idx in chef.cuisines:
		var cuisine_name = get_cuisine_name(cuisine_idx)
		if cuisine_name in dish_tags:
			var skill_level = chef.cuisines[cuisine_idx]
			cuisine_bonus += (skill_level * 8.0)

	# D. 压力减益
	var stress_multiplier = clamp(1.0 - (chef.yali / 333.0), 0.7, 1.0)

	# E. 最终合成
	var final_quality = (base_power * precision * stress_multiplier) + cuisine_bonus + 30.0
	final_quality += randf_range(-3.0, 3.0)
	
	if stress_multiplier<=0.8&&final_quality<30:#压力太高质量差
		var main_scene = get_tree().current_scene
		main_scene.add_msg(["警告","厨师【%s】的压力太大，做菜发挥失常，是不是该给他加薪了。"%chef.name])
	
	
	##print("主菜评分详情: %s, 精度:%f, 压力系数:%f, 最终分:%f" % [dish_info.name, precision, stress_multiplier, final_quality])
	return clamp(final_quality, 10.0, 200.0)

# --- 新增辅助函数：处理经验值更新 ---
func _update_chef_experience_logic(chef: ChefData, dish_tags: Array):
	if not chef or not chef.has_method("get"): # 基础检查
		return
	
	# 获取厨师拥有的所有菜系键名 (例如 [0, 2, 5] 对应不同的枚举)
	var cuisine_keys = chef.cuisines.keys()
	
	# 按照技能顺序遍历
	for i in range(cuisine_keys.size()):
		var cuisine_type = cuisine_keys[i]
		var cuisine_name = get_cuisine_name(cuisine_type)
		
		# 如果这道菜包含厨师擅长的这个菜系
		if cuisine_name in dish_tags:
			# 二分之一概率增加经验
			if randf() < 0.5:
				_increase_cuisine_exp(chef, i)

# --- 辅助函数：安全增加数组内的经验值 ---
func _increase_cuisine_exp(chef: ChefData, index: int):
	# 确保经验数组已经初始化且长度足够
	if chef.cuisines_experience == null:
		chef.cuisines_experience = []
		
	# 如果数组长度不够，补齐到当前索引
	while chef.cuisines_experience.size() <= index:
		chef.cuisines_experience.append(0)
	
	# 增加经验值
	var current_exp = chef.cuisines_experience[index]
	if current_exp < 100:
		# 每次增加 1 点经验（你可以根据平衡性调整，比如 randi_range(1, 3)）
		var new_exp = min(100, current_exp + 1)
		chef.cuisines_experience[index] = new_exp
		# print("厨师 %s 的技能 %d 经验值增加到: %d" % [chef.name, index, new_exp])



# 获取菜品基础信息
func get_dish_info(dish_id) -> Dictionary:
	return fc.dish_data_manager.get_dish_full_info(dish_id)

# 获取菜品基础制作时间
func get_dish_base_time(dish_id) -> float:
	if fc.dish_data_manager:
		var time = fc.dish_data_manager.get_dish_cooking_time(dish_id)
		# 确保返回的时间大于0
		if time <= 0:
			print("KitchenSystem: 警告 - 菜品 ", dish_id, " 基础时间为0，使用默认值")
			return 30.0
		return time
	
	print("KitchenSystem: 警告 - 无法获取菜品管理器，使用默认时间")
	return 30.0  # 默认30秒

# 获取菜系名称
func get_cuisine_name(cuisine_type) -> String:
	if chef_manager and chef_manager.has_method("get_cuisine_name"):
		return chef_manager.get_cuisine_name(cuisine_type)
	return str(cuisine_type)

# 开始制作订单
func start_cooking_order(order: Order):
	# 【核心修改】这里只修改状态，不要再创建 get_tree().create_timer 了
	# 因为底下的 _process 已经在帮你计时了
	order.status = "cooking"
	#print("KitchenSystem: 订单开始烹饪，预计耗时: ", order.remaining_time)
	

# 获取订单状态
func get_order_status(customer: CustomerData) -> String:
	for order in active_orders:
		if order.customer == customer:
			return order.status
	
	for order in completed_orders:
		if order.customer == customer:
			return "served"
	
	return "not_found"

# 获取订单的菜品质量信息
func get_order_quality_info(customer: CustomerData) -> Array:
	for order in completed_orders:
		if order.customer == customer:
			return order.dish_results
	
	return []

# 获取最后计算的时间
func get_last_calculated_time() -> float:
	return last_calculated_time

# 清理已完成订单
func cleanup_completed_orders():
	completed_orders.clear()

# 【新增】获取厨师效率报告
func get_chef_efficiency_report() -> Dictionary:
	var report = {}
	
	for chef in available_chefs:
		var completed_dishes = 0
		var total_quality = 0.0
		var avg_time = 0.0
		
		for order in completed_orders:
			for result in order.dish_results:
				if result.chef_id == chef.id:
					completed_dishes += 1
					total_quality += result.quality_score
					avg_time += result.cooking_time
		
		if completed_dishes > 0:
			report[chef.id] = {
				"name": chef.name,
				"completed_dishes": completed_dishes,
				"avg_quality": total_quality / completed_dishes,
				"avg_time": avg_time / completed_dishes,
				"speed_skill": chef.speed_skill,
				"cooking_skill": chef.cooking_skill
			}
	
	return report

# 在 kitchen_system.gd 中添加这些函数

# 获取待上菜的订单列表
# 修改 kitchen_system.gd 中的函数
func get_pending_orders():  # 移除 -> Array[Order]
	var pending = []
	for order in completed_orders:
		if order.status == "ready":
			pending.append(order)
	return pending


# 从待上菜列表中移除订单
func remove_pending_order(order: Order):
	completed_orders.erase(order)

# 处理多个并发订单
# --- 每一帧处理倒计时 ---
func _process(delta):
	# 倒序遍历数组，确保在删除元素时不会跳过索引
	for i in range(active_orders.size() - 1, -1, -1):
		var order = active_orders[i]
		
		# --- 保险 1: 存活检查 ---
		# 如果客人对象已失效，或者已经不在全局客人名单里（被赶走了）
		if not is_instance_valid(order.customer) or not fc.playerData.waiting_customers.has(order.customer):
			# print("KitchenSystem: 发现幽灵订单，客人已离开，取消制作")
			active_orders.remove_at(i)
			continue
			
		if order.status == "cooking":
			order.remaining_time -= delta 
			if order.remaining_time <= 0:
				_finish_order(order)

# --- 统一完成订单函数 ---
# KitchenSystem.gd
func _finish_order(order):
	# 1. 存活检查
	if not fc.playerData.waiting_customers.has(order.customer):
		if order in active_orders: active_orders.erase(order)
		return

	# 2. 状态更新
	order.status = "ready"
	if order in active_orders:
		active_orders.erase(order)
	if not order in completed_orders:
		completed_orders.append(order)

# 【核心修改】分流处理：外卖 vs 堂食
	if order.is_takeaway:
		# 外卖流程：直接派发送外卖任务
		if manager.waiter_system:
			manager.waiter_system.dispatch_takeaway_delivery_task(order)
	else:
		# --- 【核心修复：计算平均质量必须在派遣任务之前】 ---
		var total_q = 0.0
		var main_dish_count = 0
		for res in order.dish_results:
			var dish_id = res.dish_id
			var category = fc.dish_data_manager.get_dish_category(dish_id)
			if category == "主菜":
				total_q += res.quality_score
				main_dish_count += 1
		
		if main_dish_count > 0:
			order.customer.review_temp_data["avg_dish_quality"] = total_q / main_dish_count
		else:
			order.customer.review_temp_data["avg_dish_quality"] = 80.0

		# --- 【核心修复：派遣逻辑二选一】 ---
		var pickup_points = manager.furniture_system.get_all_furniture_by_limit("传菜口")
		if not pickup_points.is_empty():
			# 方案 A: 有传菜口，让服务员先去取菜
			var pickup_node = pickup_points[0]["node_ref"]
			var pending = pickup_node.get_meta("pending_pickup", [])
			pending.append(order)
			pickup_node.set_meta("pending_pickup", pending)
			
			manager.furniture_system.show_talk_icon(pickup_node, "res://pic/ui/talk2_nacai.png")
			
			if manager.waiter_system:
				manager.waiter_system.dispatch_pickup_task(order)
		else:
			# 方案 B: 没传菜口，服务员直接把菜送到桌上
			if manager.waiter_system:
				manager.waiter_system.dispatch_serving_task(order)


# 当关店或清场时，由 RandmapManager 或 CustomerSystem 调用
func abort_all_orders():
	# print("KitchenSystem: 强制清理所有厨房任务")
	active_orders.clear()
	completed_orders.clear()
	
	# 如果传菜口有残留的图标，也一并清理
	var pickup_points = manager.furniture_system.get_all_furniture_by_limit("传菜口")
	for p in pickup_points:
		var node = p["node_ref"]
		if is_instance_valid(node):
			node.set_meta("pending_pickup", [])
			manager.furniture_system.hide_talk_icon(node)


# 在 KitchenSystem.gd 中添加接收外卖订单的函数
# dishes: 菜品ID数组
# counter_node: 外卖柜台节点
func receive_takeaway_order(dishes: Array, counter_node: Node3D):
	if dishes.is_empty(): return
	
	var order = Order.new()
	order.is_takeaway = true
	order.takeaway_counter_node = counter_node
	order.dishes = dishes
	
	# 扣除库存
	for dish_id in dishes:
		fc.dish_data_manager.reduce_dish_stock(dish_id, 1)
	
	order.dish_results = calculate_dish_results(dishes)
	order.estimated_completion_time = find_longest_cooking_time(order.dish_results)
	
	# 【关键】初始化剩余时间
	order.remaining_time = order.estimated_completion_time
	
	active_orders.append(order)
	start_cooking_order(order)
	
	# 【新增】显示“接单”图标（表示有外卖在做了）
	manager.furniture_system.show_talk_icon(counter_node, "res://pic/ui/jiedan.png")
