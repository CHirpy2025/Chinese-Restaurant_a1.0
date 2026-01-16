
extends Node
class_name CustomerSystem

var manager: RandmapManager
var customer_holder: Node3D
# 仅存储当前正在显示的排队客人（也就是第一个）
var current_waiting_node: Node3D = null
var current_waiting_customer_id: String = ""

# 压力计时器字典
var customer_pressure_timers: Dictionary = {}
var active_customer_nodes: Dictionary = {}

func setup(randmap_manager: RandmapManager):
	manager = randmap_manager
	if manager.has_node("CustomerHolder"):
		customer_holder = manager.get_node("CustomerHolder")
	else:
		customer_holder = Node3D.new()
		customer_holder.name = "CustomerHolder"
		manager.add_child(customer_holder)
	
	if manager.current_context == RandmapManager.Context.GAME_SCENE:
		# 读档后清理所有桌子的临时预订状态，防止死锁
		_clear_all_table_reservations()
		#load_customer_states()

# ========================================================
# 1. 核心逻辑：生成与状态循环
# ========================================================

# 修改后的生成函数
# spawn_data: 从 main_game_sc 传入的包含类型、人数、预算的字典
func spawn_customer_if_needed(spawn_data: Dictionary = {}):
	if not fc.playerData.is_open: return
	
	var data: Dictionary
	
	# ============================================================
	# 逻辑分支：
	# A. 如果 main_game_sc 已经计算好了数据，直接拿来用（推荐流程）
	# B. 如果没有传入数据（比如直接调用该函数），就在这里随机生成一个
	# ============================================================
	if not spawn_data.is_empty():
		data = spawn_data
	else:
		# 这里是兜底逻辑：如果没人告诉我们要生成什么类型，就自己随机抽一个
		# 1. 计算权重
		var type_weights = fc.calculate_customer_type_weights()
		var types = []
		var weights = []
		for item in type_weights:
			types.append(item["type"])
			weights.append(item["weight"])
		
		# 2. 随机选类型
		var selected_type = "游客" # 默认值
		if types.size() > 0:
			selected_type = fc.weighted_random_choice(types, weights)
		
		# 3. 调用 customer_check 生成数据
		data = fc.customer_check(selected_type)

	# ============================================================
	# 以下为创建客户数据的逻辑（保持不变）
	# ============================================================
	var new_customer = CustomerData.new()
	
	new_customer.group_size = data["人数"]
	new_customer.type = data["类型"]
	new_customer.total_xiaofei = data["预算"]
	new_customer.sex_age_list = data["其他"]
	
	# 初始化压力值
	if new_customer.get("max_pressure") == null or new_customer.max_pressure <= 0:
		new_customer.max_pressure = 100.0
	new_customer.pressure_increase_rate = randf_range(0.5, 3.0)
	
	fc.playerData.waiting_customers.append(new_customer)
	
	# 刷新显示
	_update_waiting_queue_visuals()
	showpaidui()
	# 尝试推进流程
	process_customer_greeting()



func showpaidui():
	var paidui_num=0
	for c in fc.playerData.waiting_customers:
		if c.status == "waiting":
			paidui_num+=1
	
	var main_scene = manager.get_tree().current_scene
	if paidui_num>=1:
		main_scene.bg.get_node("paidui").visible=true
		main_scene.bg.get_node("paidui/num").text=str(paidui_num)
	else:
		main_scene.bg.get_node("paidui").visible=false


func process_customer_greeting():
	# 1. 检查第一个排队的 waiting 客人
	var first_waiting_customer = null
	for customer in fc.playerData.waiting_customers:
		if customer.status == "waiting":
			# 只要找到了排在最前面的 waiting 客人，不管有没有 meta，都锁定他
			first_waiting_customer = customer
			break 

	if not first_waiting_customer:
		return

	# 如果已经派发了任务，且服务员系统确认任务还在运行，就跳过
	if first_waiting_customer.has_meta("greeting_dispatched"):
		if manager.waiter_system and manager.waiter_system.is_greeting_task_active(first_waiting_customer):
			return
		else:
			# 幽灵任务清理
			first_waiting_customer.remove_meta("greeting_dispatched")

	# 2. 判定：进店、劝退、还是等位
	var check_result = _try_reserve_table_or_reject(first_waiting_customer)

	# 3. 只有判定为“准备进店”或“必须劝退”时，才叫服务员
	if check_result == "ready" or check_result == "reject":
		if manager.waiter_system:
			# 派遣任务。如果 dispatch 失败（比如服务员全忙），不要设标记，等下一轮
			manager.waiter_system.dispatch_greeting_task(first_waiting_customer)


# ========================================================
# 2. 【核心修复】桌子预订与分配机制
# ========================================================
func _try_reserve_table_or_reject(customer: CustomerData) -> String:
	# 1. 如果已经定性了，直接返回
	if customer.has_meta("assigned_table"): return "ready"
	if customer.get_meta("greeting_intent", "") == "reject_capacity": return "reject"

	# 2. 【核心】物理容量硬检查
	var max_cap = 0
	var tables = manager.furniture_system.get_all_furniture_by_limit("桌椅")
	for t in tables:
		var item_cfg = fc.get_row_from_csv_data("itemData", "ID", t["ID"])
		var c = int(item_cfg.get("maxnum", 4)) # 取配置的最大人数
		if c > max_cap: max_cap = c
	
	# 如果客人数 > 全店物理上限，直接标记为劝退
	if customer.group_size > max_cap:
		customer.set_meta("greeting_intent", "reject_capacity")
		# print("容量不足：客人 %d 人，饭店上限 %d 人" % [customer.group_size, max_cap])
		return "reject"

	# 3. 尝试寻找当前可用的空桌子
	var table_data = _find_and_reserve_free_table(customer)
	if not table_data.is_empty():
		customer.set_meta("assigned_table", table_data)
		customer.set_meta("greeting_intent", "accept")
		return "ready"
	
	# 4. 店里有这种桌子，但现在全满了，返回 wait_for_table
	return "wait_for_table"
	
# 寻找空闲桌子（包含预订检查）
func _find_and_reserve_free_table(customer: CustomerData) -> Dictionary:
	var tables = manager.furniture_system.get_all_furniture_by_limit("桌椅")
	var best_table = {}
	var min_diff = 999
	
	for t in tables:
		var node = t["node_ref"]
		if not is_instance_valid(node): continue
		
		# 1. 检查物理占用 (有人坐)
		if manager.furniture_system.is_table_occupied(node): continue
		
		# 2. 检查逻辑占用 (还没坐下，但被预订了)
		if node.has_meta("reserved_by_customer_id"):
			var res_id = node.get_meta("reserved_by_customer_id")
			# 如果预订者是自己（防止逻辑死循环），则视为有效
			if res_id != customer.id:
				continue 
		
		# 3. 检查容量
		var item_cfg = fc.get_row_from_csv_data("itemData", "ID", t["ID"])
		var capacity = int(item_cfg.get("maxnum", 4))
		
		if capacity >= customer.group_size:
			var diff = capacity - customer.group_size
			if diff < min_diff:
				min_diff = diff
				best_table = t
	
	# 找到桌子后，立即锁定！
	if not best_table.is_empty():
		var node = best_table["node_ref"]
		node.set_meta("reserved_by_customer_id", customer.id)
		# print("桌子锁定：", best_table["ID"], " 被客人 ", customer.id, " 预订")
		
	return best_table

# 清理所有预订标记（读档或重置时用）
func _clear_all_table_reservations():
	if manager.furniture_system:
		var tables = manager.furniture_system.get_all_furniture_by_limit("桌椅")
		for t in tables:
			var node = t["node_ref"]
			if is_instance_valid(node) and node.has_meta("reserved_by_customer_id"):
				node.remove_meta("reserved_by_customer_id")

# ========================================================
# 3. 【核心修复】可视化逻辑 (所见即所得)
# ========================================================
# CustomerSystem.gd
func _update_waiting_queue_visuals():
	# 1. 基础检查
	if fc.playerData.waiting_customers.is_empty():
		_clear_current_visual()
		return

	# 2. 找到数据列表中，第一个真正处于 waiting 状态（还没进店）的客人
	var first_waiting = null
	for c in fc.playerData.waiting_customers:
		if c.status == "waiting":
			first_waiting = c
			break
	
	# 如果没有等待中的客人在队列里了
	if first_waiting == null:
		_clear_current_visual()
		return

	# 3. 【核心修复】同步 ID。这一步极其重要，服务员靠这个 ID 认人
	current_waiting_customer_id = first_waiting.id

	# 4. 【核心修复】视觉显示逻辑
	# 如果当前已经显示的 3D 节点就是这个人，且节点有效，直接退出
	if is_instance_valid(current_waiting_node) and current_waiting_customer_id == first_waiting.id:
		return

	# 5. 如果当前显示的不是这个人，或者节点失效了，重建 3D 模型
	_clear_current_visual() # 清理旧的
	_create_visual_for_customer(first_waiting) # 创建新的

func _clear_current_visual():
	if is_instance_valid(current_waiting_node):
		current_waiting_node.queue_free()
	current_waiting_node = null
	current_waiting_customer_id = ""

func _create_visual_for_customer(customer: CustomerData):
	var scene_path = "res://sc/keren_show.tscn"
	if not ResourceLoader.exists(scene_path): return
	
	var instance = load(scene_path).instantiate()
	customer_holder.add_child(instance)
	
	# 设置数据
	var num_label = instance.get_node_or_null("num")
	if num_label: num_label.text = str(customer.group_size)
	
	instance.rotation_degrees = Vector3.ZERO
	var pic_node = instance.get_node_or_null("pic")
	if pic_node:
		if pic_node is Sprite3D:
			pic_node.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			pic_node.rotation_degrees = Vector3.ZERO
	
	instance.position = _get_spawn_position()
	
	# 记录引用
	customer.node_ref = instance
	current_waiting_node = instance
	current_waiting_customer_id = customer.id
	
	# 开启压力
	_start_pressure_timer(customer)
	_update_customer_color(customer)

# ========================================================
# 4. 流程回调：接待结束与入座
# ========================================================

func finalize_greeting(customer: CustomerData,waiter_id,):
	var intent = customer.get_meta("greeting_intent", "reject_capacity")
	_stop_pressure_timer(customer)
	customer.remove_meta("greeting_dispatched")
	
	if intent == "reject_capacity":
		_play_gender_specific_exit_sound(customer)
		_customer_leave(customer, "容量不足")
		add_msg("客人因为没有足够大的位置而离开了！")
	else:
		_play_gender_specific_welcome_sound(waiter_id)
		on_customer_seated(customer)
		showpaidui()


func _play_gender_specific_welcome_sound(waiter_id: String):
	var waiter_gender = "unknown"
	for w in fc.playerData.waiters:
		if w.id == waiter_id:
			waiter_gender = w.gender
			break
	
	if waiter_gender == "male":
		fc.play_se_fx("welcome_man")
	elif waiter_gender == "female":
		fc.play_se_fx("welcome_woman")
		

func on_customer_seated(customer: CustomerData):
	var assigned_table = customer.get_meta("assigned_table", {})
	if assigned_table.is_empty():
		_customer_leave(customer, "桌子分配异常")
		return
		
	var table_node = assigned_table.get("node_ref")
	if not is_instance_valid(table_node):
		_customer_leave(customer, "桌子消失了")
		return
	
	# 1. 数据绑定
	customer.set_meta("assigned_table_node", table_node)
	
	# 2. 解锁预订，转为正式占用
	if table_node.has_meta("reserved_by_customer_id"):
		table_node.remove_meta("reserved_by_customer_id")
	
	# 3. 设置占用数据 (覆盖式，防止叠加)
	var occupied = []
	if table_node.has_meta("occupied_customers"):
		# 清理可能存在的旧脏数据
		#var old_list = table_node.get_meta("occupied_customers")
		# 实际上对于拼桌逻辑，这里应该append，但为了解决你的"3人变7人"问题
		# 我们假设一张桌子同一时间只能有一组客人
		# occupied = old_list # 如果支持拼桌
		occupied = [] # 如果不支持拼桌，直接重置
	
	occupied.append({"customer_id": customer.id, "group_size": customer.group_size})
	table_node.set_meta("occupied_customers", occupied)
	
	# 4. 播放动画并销毁排队节点
	_play_sit_animation(customer, table_node)
	
	# 5. 更新桌子图片
	if manager.furniture_system:
		manager.furniture_system.update_table_visual(table_node)
	
	customer.status = "seated"
	showpaidui()
	# 这里建议按人头增加，更真实
	fc.playerData.dirty += customer.group_size
	fc.playerData.record_customer_checkin(customer.type,customer.group_size)
	
	
	# 【核心修改】计算入座时的初始满意度
	# 压力越大，初始好感越低。100压力对应扣除120点满意度
	customer.satisfaction = 200.0 - (customer.pressure * 1.2)
	customer.satisfaction = clamp(customer.satisfaction, 10.0, 200.0)
	
	# 记录开始等待下单的时间
	customer.set_meta("wait_start_time", Time.get_ticks_msec())
	
	# 【核心新增】厕所清洁度扣减
	_consume_toilet_cleanliness(customer.group_size)
	
	# 1. 算出当前全店厕所最差的清洁度
	var min_clean = 100.0
	var toilets = manager.furniture_system.get_all_furniture_by_limit("厕所")
	for t in toilets:
		var c = manager.furniture_system.get_toilet_cleanliness(t["node_ref"])
		if c < min_clean:
			min_clean = c
	
	# 2. 调用 ReviewManager 时把这个分数传进去
	# 假设你的风格数据存在 fc.playerData.style 里
	ReviewManager.calculate_environment_review(customer, fc.playerData.get("style"), min_clean)
	
	
	
	# 7. 开始点餐
	if manager.ordering_system:
		manager.ordering_system.trigger_ordering(customer, table_node)
	

	
	# 8. 刷新队列显示 (让下一个人显示出来)
	_update_waiting_queue_visuals()


func _consume_toilet_cleanliness(group_size: int):
	var toilets = manager.furniture_system.get_all_furniture_by_limit("厕所")
	for t_data in toilets:
		var node = t_data["node_ref"]
		var current = manager.furniture_system.get_toilet_cleanliness(node)
		var new_val = max(0.0, current - group_size)
		manager.furniture_system.update_toilet_cleanliness(node, new_val)
		
		# 极脏预警
		if current >= 20 and new_val < 20:
			add_msg("厕所卫生状况恶劣，已经引起了客人的强烈不满！")

# ========================================================
# 5. 离开与清理
# ========================================================

func _customer_leave(customer: CustomerData, reason: String):
	# 1. 释放桌子预订 (如果还没坐下)
	if customer.has_meta("assigned_table"):
		var t_data = customer.get_meta("assigned_table")
		var t_node = t_data.get("node_ref")
		if is_instance_valid(t_node) and t_node.has_meta("reserved_by_customer_id"):
			if t_node.get_meta("reserved_by_customer_id") == customer.id:
				t_node.remove_meta("reserved_by_customer_id")

	# 2. 释放桌子占用 (如果已经坐下)
	var table_node = null
	if customer.has_meta("assigned_table_node"):
		table_node = customer.get_meta("assigned_table_node")
	
	if is_instance_valid(table_node):
		if customer.status in ["seated", "eating", "waiting_pay", "ordered", "ordering"]:
			# 标记为脏桌子
			table_node.set_meta("needs_cleaning", true)
			# 这里不清空 occupied_customers，等到 clean 任务完成后再清空
			# 更新图片为空桌
			manager.furniture_system.update_table_visual(table_node)
			manager.furniture_system.show_talk_icon(table_node, "res://pic/ui/talk2_qingsao.png")
			if manager.waiter_system:
				manager.waiter_system.dispatch_cleaning_task(table_node)

	# 3. 清理服务员任务
	if customer.has_meta("assigned_waiter_id"):
		if manager.waiter_system:
			manager.waiter_system.cancel_customer_tasks(customer.get_meta("assigned_waiter_id"), customer)
	
	# 4. 结算评价
	var final_score = 0
	if reason == "容量不足":
		# 未进店客人
		final_score = ReviewManager.calculate_no_table_score(customer)
	else:
		# 进店客人
		# 【新增】在计算最终评分前，应用温度影响
		if customer.has_meta("order_result"):
			var order_result = customer.get_meta("order_result")
			ReviewManager.apply_temperature_effects(customer, order_result)
		else:
			ReviewManager.apply_temperature_effects(customer)
		
		# 计算最终评分
		final_score = ReviewManager.calculate_final_score(customer)
	
	
	fc.playerData.update_ratings(customer.type, final_score)
	# ============================================================
	# 【新增】探店博主广告加成逻辑
	# ============================================================
	if customer.type == "探店博主":
		# 只有正常消费离开（非异常原因）才计算加成
		# 这里的 reason 是 String，我们根据是否是正常的“结账离开”或“吃饭离开”来判断
		# 或者直接根据分数，如果分数太低就不加成
		if final_score > 60: # 假设低于60分不算好评
			# 加成公式：每15分加1点广告效果 (例如：150分加10点)
			# 你可以根据游戏平衡调整这个系数
			var boost_amount = floor(final_score / 15.0)
			
			# 至少加1点，上限控制
			boost_amount = max(1, boost_amount)
			
			fc.playerData.ads_effect = min(100.0, fc.playerData.ads_effect + boost_amount)
			
			add_msg("【热点】探店博主发布了%s的探店视频！广告效果提升了 %d 点 (当前: %.1f)！" % 
				["" if final_score > 120 else "还行", boost_amount, fc.playerData.ads_effect])
		else:
			# 评分低，博主发差评，可能不加分或者稍微扣分
			add_msg("【差评】探店博主对本次体验不满意，广告效果未提升。")
	
	
	#增加本日客人
	fc.playerData.total_guest_now_day += customer.group_size
	
	
	
	
	# 5. 销毁节点与数据
	if is_instance_valid(customer.node_ref):
		customer.node_ref.queue_free()
	
	if current_waiting_customer_id == customer.id:
		current_waiting_node = null
		current_waiting_customer_id = ""
		
	_stop_pressure_timer(customer)
	fc.playerData.waiting_customers.erase(customer)
	
	if reason not in ["容量不足", "系统清理", "桌子消失了", "已结账"]:
		add_msg(reason)
	
	# 刷新队列
	_update_waiting_queue_visuals()
	showpaidui()
# ========================================================
# 辅助函数
# ========================================================

func _play_sit_animation(customer, table_node):
	# 如果当前显示的节点就是这个客人，播放个简单动画然后删除
	if is_instance_valid(customer.node_ref):
		var tween = create_tween()
		var pic = customer.node_ref.get_node("pic")
		if pic:
			tween.tween_property(pic, "rotation_degrees:y", 90.0, 0.3)
		tween.tween_callback(func():
			if is_instance_valid(customer.node_ref):
				customer.node_ref.queue_free()
				
			# 确保当前显示引用被置空
			if current_waiting_customer_id == customer.id:
				current_waiting_node = null
				current_waiting_customer_id = ""
		)
	else:
		# 如果节点已经没了（比如已经在 update_visuals 里被切走了），直接确保引用清空
		if current_waiting_customer_id == customer.id:
			current_waiting_node = null
			current_waiting_customer_id = ""

func _start_pressure_timer(customer: CustomerData):
	if customer_pressure_timers.has(customer.id): return
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(func(): _on_pressure_tick(customer))
	add_child(timer)
	timer.start()
	customer_pressure_timers[customer.id] = timer

func _stop_pressure_timer(customer: CustomerData):
	if customer_pressure_timers.has(customer.id):
		var t = customer_pressure_timers[customer.id]
		if is_instance_valid(t): t.queue_free()
		customer_pressure_timers.erase(customer.id)

func _on_pressure_tick(customer: CustomerData):
	customer.pressure += customer.pressure_increase_rate
	_update_customer_color(customer)
	
	if customer.pressure >= customer.max_pressure:
		fc.play_se_fx("error")
		_customer_leave(customer, "客人因为等太久不耐烦所以走了。")

func _update_customer_color(customer: CustomerData):
	if not is_instance_valid(customer.node_ref): return
	var pic = customer.node_ref.get_node_or_null("pic")
	if not pic: return
	
	var ratio = clamp(customer.pressure / customer.max_pressure, 0.0, 1.0)
	var color = Color(1.0, 1.0 - ratio, 1.0 - ratio) # 变红
	if pic is Sprite3D: pic.modulate = color
	elif pic is MeshInstance3D: pic.material_override.albedo_color = color

func _get_spawn_position() -> Vector3:
	var main_scene = manager.get_tree().current_scene
	if main_scene and main_scene.has_method("get_customer_spawn_position"):
		var target = main_scene.get_customer_spawn_position()
		if target != Vector3.ZERO:
			return customer_holder.to_local(target)
	return Vector3(0, 0.2, 0)

func _get_valid_adjacent_pos(grid_pos: Vector3i, size: Array) -> Vector3:
	return manager.grid_map_node.map_to_local(grid_pos + Vector3i(0,0,1))

func _play_gender_specific_exit_sound(customer):
	var waiter_id = customer.get_meta("assigned_waiter_id", "")
	var gender = "unknown"
	for w in fc.playerData.waiters:
		if w.id == waiter_id:
			gender = w.gender
			break
	if gender == "male": fc.play_se_fx("exit_man")
	elif gender == "female": fc.play_se_fx("exit_woman")

func add_msg(msg):
	var main_scene = manager.get_tree().current_scene
	if main_scene and main_scene.has_method("add_msg"):
		main_scene.add_msg(["客人", msg])

## 读档
#func load_customer_states():
	#var valid_customers :Array[CustomerData] = []
	#for c in fc.playerData.waiting_customers:
		#if c.status == "seated":
			#valid_customers.append(c)
		#else:
			## 重置非入座客人的状态
			#_stop_pressure_timer(c)
	#
	#fc.playerData.waiting_customers = valid_customers
	#_update_waiting_queue_visuals()

func _process(_delta):
	# 每帧或定期检查视觉，确保队首永远有人显示
	_update_waiting_queue_visuals()


# 强制清理
func force_cleanup_stuck_customers():
	var cleaned = 0
	# 清理幽灵桌子占用
	if manager.furniture_system:
		var tables = manager.furniture_system.get_all_furniture_by_limit("桌椅")
		for t in tables:
			var node = t["node_ref"]
			if is_instance_valid(node) and node.has_meta("occupied_customers"):
				var occupied = node.get_meta("occupied_customers")
				# 校验数据有效性
				var is_valid = true
				for item in occupied:
					var cid = item.get("customer_id")
					var found = false
					for c in fc.playerData.waiting_customers:
						if c.id == cid: 
							found = true
							break
					if not found: is_valid = false
				
				if not is_valid or occupied.size() > 1: # 严格限制单组客人
					node.set_meta("occupied_customers", [])
					if node.has_meta("reserved_by_customer_id"):
						node.remove_meta("reserved_by_customer_id")
					manager.furniture_system._reset_table_state(node)
					cleaned += 1
	return cleaned

# 获取桌子节点引用
func _get_customer_table_node(customer: CustomerData) -> Node3D:
	if customer.has_meta("assigned_table_node"):
		return customer.get_meta("assigned_table_node")
	return null

# 获取第一个等待的客人（数据）
func _get_first_active_waiting_customer() -> CustomerData:
	for c in fc.playerData.waiting_customers:
		if c.status == "waiting":
			return c
	return null

# --- 兼容性接口 ---
func check_and_assign_table(customer: CustomerData) -> String:
	return _try_reserve_table_or_reject(customer)




# 在 customer_system.gd 中，替换或添加这个函数
func clear_all_customers() -> int:
	var cleared_count = 0
	var tables_to_reset = {} # 使用字典自动去重

	# 倒序遍历，安全删除所有客人
	for i in range(fc.playerData.waiting_customers.size() - 1, -1, -1):
		var customer = fc.playerData.waiting_customers[i]
		
		# 1. 收集所有与该客人相关的桌子（预订的和已入座的）
		if customer.has_meta("assigned_table"):
			var t_data = customer.get_meta("assigned_table")
			var t_node = t_data.get("node_ref")
			if is_instance_valid(t_node):
				tables_to_reset[t_node] = true

		if customer.has_meta("assigned_table_node"):
			var t_node = customer.get_meta("assigned_table_node")
			if is_instance_valid(t_node):
				tables_to_reset[t_node] = true

		# 2. 清理与服务员相关的任务
		if customer.has_meta("assigned_waiter_id"):
			if manager.waiter_system:
				manager.waiter_system.cancel_customer_tasks(customer.get_meta("assigned_waiter_id"), customer)

		# 3. 清理客人的3D节点和计时器
		if is_instance_valid(customer.node_ref):
			customer.node_ref.queue_free()
		_stop_pressure_timer(customer)

		# 4. 从数据列表中移除客人
		fc.playerData.waiting_customers.erase(customer)
		cleared_count += 1

	# 5. 【关键】批量重置所有收集到的桌子
	if manager.furniture_system:
		for table_node in tables_to_reset.keys():
			print("强制重置桌子: ", table_node.name) # 调试信息
			manager.furniture_system._reset_table_state(table_node)
			manager.furniture_system.hide_talk_icon(table_node)

	# 6. 清理当前显示的排队节点
	_clear_current_visual()

	#print("CustomerSystem: 强制清场完成，共清理了 ", cleared_count, " 位客人，并重置了 ", tables_to_reset.size(), " 张桌子。")
	return cleared_count
