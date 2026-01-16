# ordering_system.gd
extends Node
class_name OrderingSystem

var manager: RandmapManager

# 对应设计表1：客人偏好
var customer_preferences: Dictionary = {
	"蓝领": {
		"main": ["下饭", "重口味", "劲嚼", "家常", "热食"],
		"secondary": ["辣", "香口", "多人分享", "肉食为主"],
		"avoid": ["昂贵", "精致", "摆盘风", "商务", "耗时", "软口"],
		"budget": 0.8 # 预算较低
	},
	"白领": {
		"main": ["清淡健康", "精致", "商务", "快捷", "软口"],
		"secondary": ["摆盘风", "搭饮", "单人份", "创新菜"],
		"avoid": ["重口味", "昂贵", "耗时", "油腻"],
		"budget": 1.2
	},
	"退休人士": {
		"main": ["软口", "清淡健康", "滋补", "传统经典", "热食"],
		"secondary": ["汤类", "甜口", "下饭"],
		"avoid": ["辣", "冷食", "昂贵", "创新菜", "劲嚼"],
		"budget": 0.9
	},
	"学生": {
		"main": ["下饭", "重口味", "辣", "多人分享", "实惠"], # "实惠"对应便宜
		"secondary": ["冷食", "下酒", "特色", "地方特色"],
		"avoid": ["昂贵", "高级", "商务", "精致", "摆盘风"],
		"budget": 0.7
	},
	"游客": {
		"main": ["地方特色", "传统经典", "精致", "摆盘风", "创新菜"],
		"secondary": ["高级", "商务", "拍照留念", "昂贵"], # 游客愿意为高级特色买单
		"avoid": ["家常", "廉价"],
		"budget": 1.1
	},
	"自由职业者": {
		"main": ["创新菜", "搭饮", "精致", "健康", "单人份"],
		"secondary": ["地方特色", "咖啡/茶", "甜口"],
		"avoid": ["传统经典", "廉价"],
		"budget": 1.0
	},
	"商务宴请": {
		"main": ["昂贵", "高级", "商务", "国宴", "摆盘风"],
		"secondary": ["滋补", "多人分享", "精致", "酒香", "红酒"],
		"avoid": ["廉价", "家常", "快餐", "冷食"],
		"budget": 1.8 # 商务宴请预算很高
	},
	"旅行团": {
		"main": ["多人分享", "地方特色", "传统经典", "量足"],
		"secondary": ["甜口", "软口", "下饭"],
		"avoid": ["昂贵", "辣(部分敏感)", "创新菜"],
		"budget": 1.3
	},
	"家庭聚餐": {
		"main": ["多人分享", "家常", "下饭", "热食", "健康"],
		"secondary": ["滋补", "传统经典", "甜口", "软口"],
		"avoid": ["昂贵", "商务", "摆盘风", "冷食"],
		"budget": 1.4
	}
}

# ========================================================
# 2. 强制搭配规则表
# 对应设计表4：强制搭配规则
var forced_pairing_rules: Dictionary = {
	"下饭": {"type": "主食", "prob": 0.85, "budget_add": 0.20, "penalty": 25},
	"下酒": {"type": "酒水", "prob": 0.80, "budget_add": 0.15, "penalty": 20},
	"搭饮": {"type": "饮料", "prob": 0.65, "budget_add": 0.10, "penalty": 15},
	"多人分享": {"type": "主菜", "prob": 0.90, "budget_add": 0.30, "penalty": 30}, # 触发额外主菜
	"商务": {"type": "组合", "prob": 0.75, "budget_add": 0.25, "penalty": 35}
}


# ========================================================
# 3. 热销和招牌标签影响配置
# ========================================================
var tag_influences: Dictionary = {
	"hot_selling": {
		"base_bonus": 0.15,
		"crowd_effect": {
			"游客": 0.10,
			"学生": 0.10,
			"蓝领": 0.10
		},
		"quality_trust": {
			"白领": 0.05,
			"商务宴请": 0.05
		}
	},
	"signature": {
		"base_attraction": 0.20,
		"type_multipliers": {
			"商务宴请": 1.5,
			"游客": 1.5,
			"白领": 1.2,
			"自由职业者": 1.2,
			"蓝领": 0.8,
			"学生": 0.8,
			"退休人士": 1.0,
			"家庭聚餐": 1.0,
			"旅行团": 1.0
		}
	}
}

# ========================================================
# 4. 点餐结果数据结构
# ========================================================
class OrderResult:
	var selected_dishes: Array = []  # 选择的菜品ID数组
	var total_cost: float = 0.0
	var satisfaction_score: float = 100.0
	var forced_pairings: Array = []
	var budget_exceeded: bool = false
	var wait_time_minutes: float = 0.0

# ========================================================
# 5. 初始化
# ========================================================
func setup(randmap_manager: RandmapManager):
	manager = randmap_manager
	#print("OrderingSystem: 点餐系统初始化完成")

# ========================================================
# 6. 核心点餐触发函数
# ========================================================
func trigger_ordering(customer: CustomerData, table_node: Node3D):
	customer.status = "ordering"
	
	if fc.playerData.qr_ordering_enabled:
		#await get_tree().create_timer(randf_range(2.0, 4.0)).timeout
		process_qr_ordering(customer, table_node)
	else:
		manager.furniture_system.show_talk_icon(table_node, "res://pic/ui/talk2_xiadan.png")
		manager.waiter_system.dispatch_ordering_task(customer, table_node)


# ========================================================
# 7. 扫码点餐处理
# ========================================================
func process_qr_ordering(customer: CustomerData, table_node: Node3D):
	var order_result = make_order_decision(customer)
	if order_result == null or order_result.selected_dishes.is_empty():
		return
	_finalize_order(customer, table_node, order_result)

# ========================================================
# 8. 人工点餐处理
# ========================================================
#func dispatch_waiter_for_ordering(customer: CustomerData, table_node: Node3D):
	## 【修改】新版本中，服务生会自主寻找点餐任务
	## 不需要手动派遣
	#print("OrderingSystem: 等待服务生自主接收点餐任务")


# 服务员到达桌子后的点餐处理
func on_waiter_arrived_for_ordering(waiter_id: String, customer: CustomerData, table_node: Node3D):
	var order_result = make_order_decision(customer)
	if order_result == null or order_result.selected_dishes.is_empty():
		return # make_order_decision 内部已处理生气离开
	
	_finalize_order(customer, table_node, order_result)
	if manager.waiter_system:
		manager.waiter_system.process_next_task(waiter_id)


# 重写 finalize，将结果传递给厨房并开启计时
func _finalize_order(customer: CustomerData, table_node: Node3D, order_result: OrderResult):
	manager.furniture_system.hide_talk_icon(table_node)
	customer.status = "ordered"
	customer.set_meta("order_result", order_result)
	
	# === 【关键新增】扣除库存并检测售罄 ===
	for dish_id in order_result.selected_dishes:
		var just_sold_out = fc.dish_data_manager.reduce_dish_stock(dish_id, 1)
		
		# 如果这个菜刚刚卖完，通知玩家
		if just_sold_out:
			var dish_name = fc.dish_data_manager.get_dish_full_info(dish_id).get("name", "未知菜品")
			add_msg("【缺货提醒】%s 刚刚售罄了！后续客人将无法点单。" % dish_name)
	
	# === 【新增】记录菜品销量到排行榜 ===
	for dish_id in order_result.selected_dishes:
		if fc.dish_data_manager.get_dish_category(dish_id)=="主菜":
			fc.playerData.record_dish_sale(dish_id)
		
	# === 【新增】计算温度满意度影响 ===
	ReviewManager.apply_temperature_effects(customer, order_result)
	
	# === 【插入】生成 价格 & 菜品类型 评价 ===
	ReviewManager.calculate_order_reviews(customer, order_result)
# === 【插入】生成 服务评价 ===
	# 获取负责该客人的服务员
	var waiter_id = customer.get_meta("assigned_waiter_id", "")
	var waiter_data = null
	# 简单的查找服务员数据逻辑
	for w in fc.playerData.waiters:
		if w.id == waiter_id:
			waiter_data = w
			break
	ReviewManager.calculate_service_review(customer, waiter_data)
	# 打印点餐日志便于调试
	# print("点餐详情: 客人%s, 点了%s, 总价%f, 初始满意度%f" % [customer.type, order_result.selected_dishes, order_result.total_cost, customer.satisfaction])
	#customer.satisfaction += order_result.satisfaction_score
	
	customer.set_meta("order_placed_time", Time.get_ticks_msec())
	if manager.kitchen_system:
		manager.kitchen_system.receive_order(customer, order_result.selected_dishes, table_node)

# ========================================================
# 9. 核心点餐决策函数 (适配 Type 版)
# ========================================================
# ========================================================
# 9. 核心点餐决策函数 (逻辑增强版)
# ========================================================
func make_order_decision(customer: CustomerData) -> OrderResult:
	var result = OrderResult.new()
	
	# 0. 基础数据准备
	var pref = customer_preferences.get(customer.type, customer_preferences["自由职业者"])
	var waiter_id = manager.furniture_system.get_assigned_waiter_id(customer.get_meta("assigned_table_node"))
	var waiter_data = _get_waiter_data_by_id(waiter_id)
	var waiter_charm = waiter_data.charm if waiter_data else 50.0
	var upsell_lv = waiter_data.skills.get("UPSELL", 1.0) if waiter_data else 1.0

	# 1. 获取可用菜品并分类
	var available_ids = get_available_dishes_from_menu()
	if available_ids.is_empty():
		if fc.playerData.MYdisheslist.size() > 0:
			_handle_customer_angry_leave(customer, "菜品售罄")
		else:
			_handle_customer_angry_leave(customer, "菜单为空")
		return null

	# 分类菜单：主菜、主食、饮料、酒水、甜品
	var menu_book = _classify_and_score_dishes(available_ids, customer, pref, waiter_charm, upsell_lv)

	# ==================================================================
	# 阶段一：点主菜 (Base Order)
	# 目标：尽可能让每人一道主菜 (Unique)
	# ==================================================================
	var target_count = customer.group_size
	var solid_food_ids = [] # 记录用来吃饱的菜(主菜/主食/小吃)
	
	# 尝试选取不重复的主菜
	solid_food_ids = _pick_items_unique(menu_book["主菜"], target_count)
	
	# 将选好的主菜加入订单
	result.selected_dishes.append_array(solid_food_ids)

	# ==================================================================
	# 阶段二：分析标签，触发强制搭配 (Mandatory Pairing)
	# 规则：检测到标签 -> 必点对应种类 -> 增加满意度
	# ==================================================================
	var need_staple = false  # 需要主食 (如白米饭)
	var need_alcohol = false # 需要酒水
	var need_drink = false   # 需要饮料
	
	for dish_id in solid_food_ids:
		var info = get_dish_full_info(dish_id)
		var tags = info.get("tags", [])
		
		if "下饭" in tags: need_staple = true
		if "下酒" in tags: need_alcohol = true
		if "搭饮" in tags: need_drink = true

	# ==================================================================
	# 阶段三：随机搭配 (Random Extras)
	# 规则：如果没有触发强制，也有概率点，模拟真实客人需求
	# ==================================================================
	randomize()
	
	# 30% 概率想喝酒 (如果还没点)
	if not need_alcohol and not menu_book["酒水"].is_empty():
		if randf() < 0.3: need_alcohol = true
		
	# 40% 概率想喝饮料 (如果还没点且没喝酒)
	if not need_drink and not need_alcohol and not menu_book["饮料"].is_empty():
		if randf() < 0.4: need_drink = true
		
	# 50% 概率想吃主食 (如果还没点)
	if not need_staple and not menu_book["主食"].is_empty():
		if randf() < 0.5: need_staple = true
	
	# 30% 概率点一份甜品/小吃 (大家一起吃)
	var need_dessert = false
	if not menu_book["甜品"].is_empty() and randf() < 0.3:
		need_dessert = true

	# ==================================================================
	# 阶段四：执行搭配添加
	# ==================================================================
	
	# 1. 添加酒水 (按人头)
	if need_alcohol:
		if _add_category_to_order(result, menu_book["酒水"], target_count):
			result.satisfaction_score += 15 # 喝到了想喝的酒，开心
			
	# 2. 添加饮料 (按人头，如果没喝酒)
	if need_drink and not need_alcohol: # 通常酒和饮料二选一，除非很能喝
		if _add_category_to_order(result, menu_book["饮料"], target_count):
			result.satisfaction_score += 10 # 喝到了饮料，开心
			
	# 3. 添加主食 (按人头)
	# 注意：如果主菜不够吃，后面"兜底"环节也会加主食。这里是"配菜用"的主食。
	if need_staple:
		if _add_category_to_order(result, menu_book["主食"], target_count):
			result.satisfaction_score += 10 # 有米饭配菜，开心
			# 记录主食也属于固体食物
			# (这里不append到solid_food_ids防止影响单一性判断，或者视需求而定)
			
	# 4. 添加甜品 (点1-2份分享)
	if need_dessert:
		var dessert_count = max(1, int(target_count / 3)) # 每3人1份
		if _add_category_to_order(result, menu_book["甜品"], dessert_count):
			result.satisfaction_score += 8

	# ==================================================================
	# 阶段五：兜底填饱肚子 (Fill Hunger)
	# 规则：如果主菜数量 < 人数，说明主菜不够，必须用主食/小吃填满
	# ==================================================================
	var current_solids_count = solid_food_ids.size() # 目前只算了主菜
	
	if current_solids_count < target_count:
		var needed = target_count - current_solids_count
		
		# 优先用主食填 (允许重复，比如5碗饭)
		var added_staples = _add_category_to_order_return_ids(result, menu_book["主食"], needed)
		current_solids_count += added_staples.size()
		
		# 还不够？用甜品/小吃填
		if current_solids_count < target_count:
			needed = target_count - current_solids_count
			var added_snacks = _add_category_to_order_return_ids(result, menu_book["甜品"], needed)
			current_solids_count += added_snacks.size()
			
		# 还不够？(真的没菜了) 重复点主菜
		if current_solids_count < target_count:
			needed = target_count - current_solids_count
			var leftovers = _add_category_to_order_return_ids(result, menu_book["主菜"], needed) # 允许重复
			current_solids_count += leftovers.size()

	# ==================================================================
	# 阶段六：结算与惩罚
	# ==================================================================
	var total_cost = 0.0
	for d_id in result.selected_dishes:
		total_cost += get_dish_price(d_id)
		result.satisfaction_score += 5 # 每点一个菜都有基础分
	
	# [单一菜品惩罚]
	# 检查：如果是多人用餐，且只点了同一种“主菜/主食”
	var unique_check = []
	for d in result.selected_dishes:
		# 排除酒水饮料，只看吃的
		var type = fc.dish_data_manager.get_dish_category(d)
		if type not in ["酒水", "饮料"]:
			if d not in unique_check: unique_check.append(d)
	
	if customer.group_size > 1 and unique_check.size() == 1:
		customer.satisfaction -= 80.0
		result.satisfaction_score = -50.0 
		add_msg("【差评预警】客人 %s 觉得菜品太单一(%s)，非常不满！" % [customer.type, fc.dish_data_manager.get_dish_full_info(unique_check[0]).name])
		customer.review_temp_data["bad_variety"] = true 

	# 严重库存不足惩罚
	if current_solids_count < customer.group_size:
		customer.satisfaction -= 100.0
		result.satisfaction_score -= 100.0
		add_msg("【严重警告】库存严重不足，无法满足 %s 桌的基本用餐量！" % customer.type)

	# 预算检查
	var max_budget = customer.total_xiaofei * pref["budget"]
	if total_cost > max_budget:
		customer.satisfaction -= 30.0
		result.satisfaction_score -= 20
		result.budget_exceeded = true

	result.total_cost = total_cost
	result.satisfaction_score = clamp(result.satisfaction_score, 0, 200)

	fc.play_se_fx("chaocai")
	_record_review_data(customer, result, pref)

	return result
	
# ========================================================
# 辅助函数：选取不重复的物品 ID (返回数组)
# 修改 ordering_system.gd 中的 _pick_items_unique
func _pick_items_unique(candidates: Array, target_count: int) -> Array:
	var picked = []
	var sorted = candidates.duplicate(true) # 复制一份排序
	
	# 只排序前 target_count 个，而不是全部，提高效率
	# 或者：在前 3 个高分菜里随机选，而不是只选第 1 个
	# 这样既保证了喜欢，又防止了千篇一律
	
	# 简单版优化：前3名里随机
	var top_k = min(3, sorted.size()) 
	var pool = sorted.slice(0, top_k)
	
	for i in range(target_count):
		if pool.is_empty(): break
		# 从高分池里随机选一个
		var idx = randi() % pool.size()
		var item = pool[idx]
		picked.append(item.id)
		pool.remove_at(idx) # 防止重复选同ID
		
		# 如果池子空了，且还需要菜，再去排后面的找
		if pool.is_empty() and sorted.size() > picked.size():
			# 简单的回退逻辑：从剩下的里拿
			var next_idx = i + 1 
			if next_idx < sorted.size():
				picked.append(sorted[next_idx].id)
				
	return picked


# ========================================================
# 辅助函数：向订单添加指定类别的物品 (返回是否成功)
# candidates: 排序后的菜品列表 [{"id":1, "score":10}]
# count: 数量
# ========================================================
func _add_category_to_order(result: OrderResult, candidates: Array, count: int) -> bool:
	if candidates.is_empty(): return false
	
	for item in candidates:
		var stock = fc.dish_data_manager.get_dish_stock(item.id)
		# 只有当库存能满足整桌人点这个菜时，才选择它
		if stock >= count:
			for i in count:
				result.selected_dishes.append(item.id)
			return true
	
	# 如果没有一个菜能满足这一桌的人数，退而求其次选库存最多的
	var best_stock_id = candidates[0].id
	# ... 此处可以写更复杂的降级逻辑
	return false

# ========================================================
# 辅助函数：同上，但返回添加的ID列表 (用于计数)
# ========================================================
func _add_category_to_order_return_ids(result: OrderResult, candidates: Array, count: int) -> Array:
	var added = []
	if candidates.is_empty(): return added
	
	# 这里的逻辑是：如果不够，就重复拿最好的
	var best_item_id = candidates[0].id
	
	for i in count:
		result.selected_dishes.append(best_item_id)
		added.append(best_item_id)
	return added
# ========================================================
# 辅助逻辑函数
# ========================================================

# ========================================================
# 菜品分类与评分 (需确保 Type 字符串匹配 CSV)
# ========================================================
func _classify_and_score_dishes(available_ids: Array, customer, pref, charm, upsell) -> Dictionary:
	var book = {
		"主菜": [],
		"甜品": [], # 对应 CSV 中的 type (包含 小吃)
		"主食": [],
		"饮料": [], 
		"酒水": []
	}
	
	for d_id in available_ids:
		# 直接获取类型 (Type)
		var category = fc.dish_data_manager.get_dish_category(d_id)
		
		var score = _calculate_attraction_score(d_id, customer, pref, charm, upsell)
		var item = {"id": d_id, "score": score}
		
		# 根据 Type 归档
		match category:
			"主菜": 
				book["主菜"].append(item)
			"主食": 
				book["主食"].append(item)
			"甜品", "小吃": 
				book["甜品"].append(item)
			"饮料":
				book["饮料"].append(item)
			"酒水":
				book["酒水"].append(item)
			_:
				# 默认归为主菜以防漏单
				book["主菜"].append(item)
	
	# 排序：分数高的在前面
	for key in book:
		book[key].sort_custom(func(a, b): return a.score > b.score)
		
	return book


## 2. 填充订单槽位
## current_list: 当前已选菜品列表
## target: 目标总数
## candidates: 候选菜品列表 [{"id":1, "score":10}, ...]
## unique_only: 是否强迫不重复
#func _fill_order_slots(current_list: Array, target: int, candidates: Array, unique_only: bool) -> Array:
	#if current_list.size() >= target:
		#return current_list
		#
	#var needed = target - current_list.size()
	#
	#for item in candidates:
		#if needed <= 0: break
		#var dish_id = item.id
		#
		## 如果要求唯一，且已经选过这个菜，跳过
		#if unique_only and dish_id in current_list:
			#continue
			#
		## 加入订单
		#current_list.append(dish_id)
		#
		## 如果不是要求唯一（比如主食），可以重复选这个评分最高的，直到填满
		#if not unique_only:
			#needed -= 1
			## 循环里只append了一次，如果是重复模式，我们可以直接把剩下的都填成这个最好的
			#while needed > 0:
				#current_list.append(dish_id)
				#needed -= 1
		#else:
			#needed -= 1 # 唯一模式，选了一个就找下一个
			#
	#return current_list

# 3. 添加饮料搭配
func _add_beverage_pairing(result: OrderResult, count: int, candidates: Array):
	if candidates.is_empty():
		# 没酒/没饮料可点，惩罚满意度
		result.satisfaction_score -= 15
		# print("缺酒水/饮料，无法满足搭配")
		return
		
	# 选分数最高的一款饮料
	var best_drink_id = candidates[0].id
	
	# 添加 人数 份
	for i in count:
		result.selected_dishes.append(best_drink_id)

# 4. 获取服务员数据辅助
func _get_waiter_data_by_id(w_id: String):
	for w in fc.playerData.waiters:
		if w.id == w_id: return w
	return null

# 5. 评价数据记录 (封装原逻辑)
func _record_review_data(customer, result, pref):
	var temp_review = {
		"matched_tags": [],
		"missing_tags": [],
		"ordered_count": result.selected_dishes.size(),
		"bad_variety": customer.review_temp_data.get("bad_variety", false)
	}
	var main_tags = pref.get("main", [])
	var hit_favorite = false
	for dish_id in result.selected_dishes:
		var info = get_dish_full_info(dish_id)
		for tag in info.get("tags", []):
			if tag in main_tags:
				if not tag in temp_review.matched_tags:
					temp_review.matched_tags.append(tag)
				hit_favorite = true
	if not hit_favorite and not main_tags.is_empty():
		temp_review.missing_tags.append(main_tags[0])
	customer.review_temp_data.merge(temp_review, true)


# 3. 修改获取菜品分类
func get_dish_category(dish_id) -> String:
	var str_id = str(dish_id)
	if fc.playerData.Total_dishes_list.has(str_id):
		return fc.playerData.Total_dishes_list[str_id].get("category", "主菜")
	return "主菜"
# ========================================================
# 3. 内部演算逻辑
# ========================================================

# ========================================================
# 计算菜品吸引力分数 (重构版)
# ========================================================
func _calculate_attraction_score(dish_id, customer: CustomerData, pref: Dictionary, charm: float, upsell: float) -> float:
	var info = get_dish_full_info(dish_id)
	var tags = info.get("tags", [])
	var score = 50.0 # 基础分

	# --- 1. 标签匹配逻辑 (覆盖全标签) ---
	var tag_hit_count = 0
	for tag in tags:
		if tag in pref["main"]: 
			score += 40.0 # 主要喜好：大幅加分
			tag_hit_count += 1
		elif tag in pref["secondary"]: 
			score += 20.0 # 次要喜好：中等加分
			tag_hit_count += 1
		elif tag in pref["avoid"]: 
			score -= 50.0 # 厌恶：大幅扣分 (一票否决)
	
	# 特殊处理：如果有“实惠”标签偏好（蓝领/学生），计算价格影响
	# 假设基础价格 < 50 为实惠，> 150 为昂贵
	var price = info["price"]
	if "实惠" in pref["main"] or "廉价" in pref["secondary"]:
		if price < 50: score += 20
		elif price > 150: score -= 30

	# --- 2. 服务员 Upsell 技能影响 (关键) ---
	# 如果菜品是招牌，或者带有“高级”、“昂贵”标签，Upsell 技能起作用
	var is_premium = false
	if info.get("is_signature", false): is_premium = true
	for tag in tags:
		if tag in ["高级", "昂贵", "国宴", "精致", "商务"]: is_premium = true
	
	# Upsell 技能等级通常在 1.0 ~ 10.0 左右，假设
	# 公式：如果是高级菜，分数增加 (Upsell等级 * 5)
	if is_premium:
		score += (upsell * 5.0) 

	# --- 3. 热销影响 ---
	# 热销对蓝领/学生/游客有巨大吸引力，对白领也有一定吸引力
	if info.get("is_hot_selling", false):
		var hot_bonus = 15.0
		if customer.type in ["游客", "学生", "蓝"]: hot_bonus = 25.0
		if customer.type in ["白领"]: hot_bonus = 10.0
		score += hot_bonus

	# --- 4. 服务员魅力 (全局加成) ---
	# 魅力稍微降低对厌恶标签的敏感度，或者增加整体好感
	score += (charm * 0.2)
	
	return max(0.0, score) # 保证分数不为负


# 处理强制搭配与预算
func _process_pairings_and_budget(customer: CustomerData, result: OrderResult, pref: Dictionary, available_ids: Array):
	var total_cost = 0.0
	var final_satisfaction = result.satisfaction_score + 100 # 加上基础100
	
	# 计算当前已选菜品总价
	for d_id in result.selected_dishes:
		total_cost += get_dish_price(d_id)

	# 检查强制搭配触发项
	var current_tags = []
	for d_id in result.selected_dishes:
		current_tags.append_array(get_dish_full_info(d_id).get("tags", []))

	for tag in current_tags:
		if forced_pairing_rules.has(tag):
			var rule = forced_pairing_rules[tag]
			if randf() < rule["prob"]:
				# 寻找符合类型的最便宜菜品
				var pair_id = _find_matching_dish(rule["type"], available_ids)
				if pair_id != 0:
					result.selected_dishes.append(pair_id)
					total_cost += get_dish_price(pair_id)
				else:
					final_satisfaction -= rule["penalty"] # 搭配失败惩罚

	# 预算检查
	var max_budget = customer.total_xiaofei * pref["budget"]
	if total_cost > max_budget:
		final_satisfaction -= 20
		result.budget_exceeded = true

	result.total_cost = total_cost
	result.satisfaction_score = clamp(final_satisfaction, 0, 200)

# 降级逻辑
func _apply_fallback_strategy(dish_scores: Array, pref: Dictionary) -> int:
	# 1. 热销菜品
	for d in dish_scores:
		if get_dish_full_info(d.id).get("is_hot_selling"): return d.id
	# 2. 招牌菜
	for d in dish_scores:
		if get_dish_full_info(d.id).get("is_signature"): return d.id
	# 3. 中性菜品 (无偏好也无避免)
	for d in dish_scores:
		var tags = get_dish_full_info(d.id).get("tags", [])
		var is_neutral = true
		for t in tags:
			if t in pref["main"] or t in pref["avoid"]: 
				is_neutral = false
				break
		if is_neutral: return d.id
	return 0 # 最终失望离开

# 寻找符合分类的菜 (主食/酒水/饮料)
func _find_matching_dish(category_name: String, available_ids: Array) -> int:
	for d_id in available_ids:
		if fc.dish_data_manager.get_dish_category(d_id) == category_name:
			return d_id
	return 0

func _handle_customer_angry_leave(customer: CustomerData, reason: String):
	var table_node = get_customer_table_node(customer)
	if is_instance_valid(table_node):
		# 生气走也得收走盘子（变脏）
		table_node.set_meta("needs_cleaning", true)
		manager.furniture_system.show_talk_icon(table_node, "res://pic/ui/talk2_qingsao.png")
		manager.waiter_system.dispatch_cleaning_task(table_node)
	
	manager.customer_system._customer_leave(customer, reason)



# 【新增】获取客人所在的桌子节点
func get_customer_table_node(customer: CustomerData) -> Node3D:
	# 方法1：从客人数据中获取
	if customer.has_meta("table_node"):
		return customer.get_meta("table_node")
	
	# 方法2：遍历所有桌子，找到占用该客人的桌子
	if manager.furniture_system:
		var tables = manager.furniture_system.get_all_furniture_by_limit("桌椅")
		for table_data in tables:
			var node = table_data["node_ref"]
			if is_instance_valid(node) and node.has_meta("occupied_customers"):
				var occupied = node.get_meta("occupied_customers")
				for customer_info in occupied:
					if customer_info.get("customer_id") == customer.id:
						return node
	
	return null

# ========================================================
# 11. 从菜单获取可用菜品
# ========================================================
# ordering_system.gd

func get_available_dishes_from_menu() -> Array:
	var available_dishes = []
	
	# fc.playerData.MYdisheslist 可能包含 101.0 (float)
	for dish_id in fc.playerData.MYdisheslist:
		# 强制转换为 int，确保 101.0 变成 101

		var dish_info = fc.playerData.Total_dishes_list[dish_id]
		if dish_info.is_empty():
			print("OrderingSystem: 跳过无效菜品ID: ", dish_id) # 如果之前失败，这里会打印
			continue
		
		var stock = fc.dish_data_manager.get_dish_stock(dish_id)
		if stock > 0:
			available_dishes.append(dish_id)
			
	return available_dishes

# ========================================================
# 12. 获取菜品信息
# ========================================================
# ordering_system.gd

# 修改获取信息函数，强制转换类型
func get_dish_full_info(dish_id) -> Dictionary:
	# 确保 dish_id 是字符串以便在 Total_dishes_list 中查找
	var str_id = str(dish_id) 
	if fc.playerData.Total_dishes_list.has(str_id):
		var full_info = fc.playerData.Total_dishes_list[str_id]
				
		return full_info
		
	# 如果查不到，返回空
	return {}

# 获取菜品价格
func get_dish_price(dish_id):
	# 优先读取运行时数据 (Total_dishes_list)
	var str_id = str(dish_id)
	if fc.playerData.Total_dishes_list.has(str_id):
		return float(fc.playerData.Total_dishes_list[str_id].get("price", 0))

# ========================================================
# 14. 选择主菜
# ========================================================
@warning_ignore("unused_parameter")
func select_main_dish(dish_scores: Array, preference: Dictionary) -> int:
	if dish_scores.is_empty():
		return 0
	
	return dish_scores[0].dish_id

# ========================================================
# 15. 降级策略
# ========================================================
func apply_fallback_strategy(dish_scores: Array, preference: Dictionary) -> int:
	# 策略1：选择热销菜品
	for dish_data in dish_scores:
		var dish_info = dish_data.dish_info
		if dish_info.get("is_hot_selling", false):
			print("OrderingSystem: 降级策略1 - 选择热销菜品")
			return dish_data.dish_id
	
	# 策略2：选择招牌菜品
	for dish_data in dish_scores:
		var dish_info = dish_data.dish_info
		if dish_info.get("is_signature", false):
			print("OrderingSystem: 降级策略2 - 选择招牌菜品")
			return dish_data.dish_id
	
	# 策略3：选择中性菜品
	for dish_data in dish_scores:
		var dish_info = dish_data.dish_info
		var dish_tags = dish_info.get("tags", [])
		var is_neutral = true
		
		for tag in preference.get("main_tags", []):
			if tag in dish_tags:
				is_neutral = false
				break
		for tag in preference.get("avoid_tags", []):
			if tag in dish_tags:
				is_neutral = false
				break
		
		if is_neutral:
			#print("OrderingSystem: 降级策略3 - 选择中性菜品")
			return dish_data.dish_id
	
	# 策略4：选择次要偏好菜品
	for dish_data in dish_scores:
		var dish_info = dish_data.dish_info
		var dish_tags = dish_info.get("tags", [])
		for tag in preference.get("secondary_tags", []):
			if tag in dish_tags:
				print("OrderingSystem: 降级策略4 - 选择次要偏好菜品")
				return dish_data.dish_id
	
	# 策略5：选择避免标签菜品
	for dish_data in dish_scores:
		print("OrderingSystem: 降级策略5 - 选择避免标签菜品")
		return dish_data.dish_id
	
	# 策略6：客人失望离开
	print("OrderingSystem: 降级策略6 - 客人失望离开")
	return 0

# ========================================================
# 16. 检查强制搭配
# ========================================================
@warning_ignore("unused_parameter")
func check_forced_pairings(main_dish_id, customer_type: String, available_dishes: Array) -> Array:
	var pairings = []
	var main_dish_info = get_dish_full_info(main_dish_id)
	var main_tags = main_dish_info.get("tags", [])
	
	for tag in main_tags:
		if tag in forced_pairing_rules:
			var rule = forced_pairing_rules[tag]
			
			# 概率判定
			if randf() < rule.probability:
				var pairing_result = {
					"trigger_tag": tag,
					"required_type": rule.required_type,
					"success": false,
					"dish_id": 0,
					"satisfaction_penalty": rule.satisfaction_penalty
				}
				
				# 查找搭配菜品
				var required_dish_id = find_required_dish(rule.required_type, available_dishes)
				if required_dish_id != 0:
					pairing_result.success = true
					pairing_result.dish_id = required_dish_id
				
				pairings.append(pairing_result)
	
	return pairings

# ========================================================
# 17. 查找所需菜品
# ========================================================
# ========================================================
# 17. 查找所需类型的菜品 (修复版)
# ========================================================
func find_required_dish(required_type: String, available_dishes: Array) -> int:
	var candidates = []
	
	for dish_id in available_dishes:
		# 【核心修改】直接获取菜品的分类(Type)，而不是查Tag
		var dish_type = fc.dish_data_manager.get_dish_category(dish_id)
		
		# 直接比对字符串，例如 "主食" == "主食"
		# 如果需要兼容 "甜品" 和 "小吃" 算同一类，可以在这里处理，但根据你的描述，直接比对即可
		if dish_type == required_type:
			candidates.append(dish_id)
	
	if not candidates.is_empty():
		# 按价格从低到高排序（强制搭配通常选便宜的，或者你可以改成按评分）
		candidates.sort_custom(func(a, b): return get_dish_price(a) < get_dish_price(b))
		return candidates[0]
	
	return 0
#


# ========================================================
# 19. 辅助函数
# ========================================================
func _customer_leave(customer: CustomerData, reason: String):
	if manager.customer_system:
		manager.customer_system._customer_leave(customer, reason)

func start_eating(customer: CustomerData, table_node: Node3D):
	var start_time = customer.get_meta("order_placed_time", 0)
	if start_time > 0:
		var wait_ms = Time.get_ticks_msec() - start_time
		var wait_seconds = wait_ms / 1000.0
		# 调用评价
		ReviewManager.calculate_wait_time_review(customer, wait_seconds)
	customer.status = "eating"
	# 显示吃饭图标
	manager.furniture_system.show_talk_icon(table_node, "res://pic/ui/talk2_eat.png")
	
	ReviewManager.calculate_taste_review(customer)
	
	# 【新增】更新桌子为用餐状态图片
	_update_table_to_eating_visual(table_node, customer)
	
	# 计算用餐时间：基础 10秒 + 每道菜 5秒 (你可以根据需求缩短进行测试)
	var order = customer.get_meta("order_result")
	var eat_time = 10.0 + (order.selected_dishes.size() * 5.0)
	
	await get_tree().create_timer(eat_time).timeout
	finish_eating(customer, table_node)
	
	
# 【新增】更新桌子为用餐状态的函数
func _update_table_to_eating_visual(table_node: Node3D, customer: CustomerData):
	if not is_instance_valid(table_node):
		return
	
	# 获取桌子上的所有客人
	var occupied_customers = table_node.get_meta("occupied_customers", [])
	if occupied_customers.is_empty():
		return
	
	# 计算总人数
	var total_customers = 0
	for customer_info in occupied_customers:
		total_customers += customer_info.get("group_size", 1)
	
	# 更新为用餐状态图片
	fc.play_se_fx("panzi")
	var pic_path = "res://pic/keren/sit_%d_eat.png" % total_customers
	var pic_node = table_node.get_child(0).get_node_or_null("pic")
	if pic_node and ResourceLoader.exists(pic_path):
		pic_node.texture = load(pic_path)
	else:
		print("OrderingSystem: 用餐状态图片不存在: ", pic_path)
	
	
# OrderingSystem.gd
# OrderingSystem.gd

func finish_eating(customer: CustomerData, table_node: Node3D):
	manager.furniture_system.hide_talk_icon(table_node)
	_update_table_to_serving_visual(table_node)
	
	if fc.playerData.get("qr_pay_enabled"):
		process_payment(customer, table_node)
	else:
		customer.status = "waiting_pay"
		var cashier_points = manager.furniture_system.get_all_furniture_by_limit("收银台")
		if not cashier_points.is_empty():
			var cashier_node = cashier_points[0]["node_ref"]
			
			var pay_queue = cashier_node.get_meta("pay_queue", [])
			# 检查客人是否已经在排队了，防止重复加入
			var already_in = false
			for item in pay_queue:
				if item.customer == customer:
					already_in = true
					break
			
			if not already_in:
				pay_queue.append({"customer": customer, "table": table_node})
				cashier_node.set_meta("pay_queue", pay_queue)
			
			manager.furniture_system.show_talk_icon(cashier_node, "res://pic/ui/talk2_maidan.png")
			
			# 【关键修复】使用 WaiterSystem.TaskType 访问枚举
			# 并调用检查函数，防止重复派发任务给服务生
			if not manager.waiter_system.has_waiter_handling_task(WaiterSystem.TaskType.PAYMENT, cashier_node):
				manager.waiter_system.dispatch_payment_task(cashier_node)

# 【新增】更新桌子为上菜状态图片的函数
func _update_table_to_serving_visual(table_node: Node3D):
	if not is_instance_valid(table_node):
		return
	
	# 获取桌子上的所有客人
	var occupied_customers = table_node.get_meta("occupied_customers", [])
	if occupied_customers.is_empty():
		return
	
	# 计算总人数
	var total_customers = 0
	for customer_info in occupied_customers:
		total_customers += customer_info.get("group_size", 1)
	
	# 更新为上菜状态图片（有菜但没在吃）
	var pic_path = "res://pic/keren/sit_%d.png" % total_customers
	var pic_node = table_node.get_child(0).get_node_or_null("pic")
	if pic_node and ResourceLoader.exists(pic_path):
		pic_node.texture = load(pic_path)
	else:
		print("OrderingSystem: 上菜状态图片不存在: ", pic_path)



# 最终结算金钱并让客人离开
@warning_ignore("unused_parameter")
func process_payment(customer: CustomerData, table_node: Node3D):
	var order = customer.get_meta("order_result")
	fc.playerData.money += order.total_cost
	fc.playerData.pay_today+=order.total_cost
	
	change_show_info()
	# 触发离店流程
	if manager.customer_system:
		manager.customer_system._customer_leave(customer, "客人结账离开，支付了 %s" %fc.format_money(order.total_cost))

func add_msg(msg):
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("add_msg"):
		main_scene.add_msg(["通知",msg])

func change_show_info():
	var main_scene = get_tree().current_scene
	main_scene.info_ui.show_info()


# 在 OrderingSystem.gd 中添加外卖菜单生成函数
func make_takeaway_menu() -> Array:
	var selected_dishes = []
	var available_ids = get_available_dishes_from_menu()
	
	if available_ids.is_empty():
		return []
	
	# 分类菜单
	var menu_book = _classify_and_score_dishes_simple(available_ids)
	
	# 外卖点餐策略：随机 1-2 道主菜，1 道主食，1 道饮料
	# 1. 选主菜 (1-2道)
	var main_count = randi_range(1, 3) 
	_pick_items_from_list(selected_dishes, menu_book["主菜"], main_count)
	
	# 2. 选主食 (0-1道)
	if randf() < 0.8 and not menu_book["主食"].is_empty():
		_pick_items_from_list(selected_dishes, menu_book["主食"], 1)
		
	# 3. 选饮料 (0-1道)
	if randf() < 0.6 and not menu_book["饮料"].is_empty():
		_pick_items_from_list(selected_dishes, menu_book["饮料"], 1)
		
	# 兜底：如果什么都没选到（库存不足），随机凑一个
	if selected_dishes.is_empty():
		for d_id in available_ids:
			var stock = fc.dish_data_manager.get_dish_stock(d_id)
			if stock > 0:
				selected_dishes.append(d_id)
				break
				
	return selected_dishes

# 辅助函数：简单的分类（不需要计算权重，因为外卖不涉及偏好）
func _classify_and_score_dishes_simple(available_ids: Array) -> Dictionary:
	var book = {
		"主菜": [],
		"甜品": [],
		"主食": [],
		"饮料": [], 
		"酒水": []
	}
	
	for d_id in available_ids:
		var category = fc.dish_data_manager.get_dish_category(d_id)
		var item = {"id": d_id}
		
		match category:
			"主菜": book["主菜"].append(item)
			"主食": book["主食"].append(item)
			"甜品", "小吃": book["甜品"].append(item)
			"饮料": book["饮料"].append(item)
			"酒水": book["酒水"].append(item)
			_: book["主菜"].append(item)
			
	# 随机打乱，增加多样性
	for key in book:
		book[key].shuffle()
		
	return book

# 辅助函数：从列表中取指定数量的菜品ID
func _pick_items_from_list(result_list: Array, source_list: Array, count: int):
	if source_list.is_empty(): return
	
	var picked = 0
	for item in source_list:
		if picked >= count: break
		
		# 检查库存
		var stock = fc.dish_data_manager.get_dish_stock(item.id)
		if stock > 0:
			result_list.append(item.id)
			picked += 1
