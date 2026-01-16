extends Node
class_name WaiterSystem

var manager: RandmapManager
var grid_map: GridMap
var furniture_holder: Node3D

# --- 核心枚举与结构 ---
enum WaiterState {
	IDLE,
	MOVING,
	GREETING,
	ORDERING,
	SERVING,
	PICKUP,    # 新增：取菜中
	PAYMENT,   # 新增：收银中
	CLEANING
}

enum TaskType {
	PICKUP = 1,
	SERVING = 2,
	GREETING = 3,
	PAYMENT = 4,
	ORDERING = 5,
	TOILET_CLEANING = 6, # 新增
	CLEANING = 7,
	DELIVERY_TAKEAWAY = 8 # 【新增】外卖配送
}

class Task:
	var type: TaskType
	var priority: int
	var customer: CustomerData
	var table_node: Node3D
	var target_pos: Vector3i
	var dishes: Array = []
	var data: Dictionary = {} # 存储额外信息，如Order引用

class WaiterRuntimeData:
	var id: String
	var node_ref: Node3D
	var pos: Vector3i
	var state: WaiterState = WaiterState.IDLE
	var task_queue: Array[Task] = []
	var current_task: Task = null
	var check_timer: Timer = null
	var assigned_furniture: Array[Node3D] = []
	
	# 【新增】用于记录当前活动的动画，防止动画冲突
	var active_tween_xz: Tween = null
	var active_tween_y: Tween = null


# --- 变量存储 ---
var placed_waiters_data: Array = []
var occupied_waiter_cells: Dictionary = {}
var waiter_data_map: Dictionary = {}
var _highlight_mat: StandardMaterial3D

func setup(randmap_manager: RandmapManager):
	manager = randmap_manager
	grid_map = manager.grid_map_node
	furniture_holder = manager.furniture_holder
	_init_materials()
	load_waiters_from_global()

func _init_materials():
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.5)
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

# ========================================================
# 核心功能：放置服务生
# ========================================================
# WaiterSystem.gd

func place_waiter(grid_pos: Vector3i, waiter_info: WaiterData, color: Color = Color.WHITE) -> bool:
	if not check_area_available(grid_pos):
		return false
	
	# 1. 创建 3D 节点
	var waiter_node = _create_waiter_node(grid_pos, waiter_info, color)
	
	# 2. 【核心修复】创建逻辑运行对象 (WaiterRuntimeData)
	var runtime_data = WaiterRuntimeData.new()
	runtime_data.id = waiter_info.id
	runtime_data.node_ref = waiter_node
	runtime_data.pos = grid_pos
	runtime_data.state = WaiterState.IDLE # 初始为空闲
	
	# 3. 【核心修复】为逻辑对象启动检查定时器
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(func(): _check_waiter_state(runtime_data.id))
	add_child(timer)
	timer.start()
	runtime_data.check_timer = timer
	
	# 4. 【关键】存入逻辑字典，否则 _find_nearest_available_waiter 找不到人
	waiter_data_map[runtime_data.id] = runtime_data
	
	# 5. 记录基础数据 (用于保存和 UI)
	var waiter_entry = {
		"waiter_id": waiter_info.id,
		"pos": grid_pos,
		"node_ref": waiter_node,
		"color": color,
		"waiter_data": waiter_info 
	}
	placed_waiters_data.append(waiter_entry)
	
	# 6. 标记格子占用
	var key = str(grid_pos.x) + "," + str(grid_pos.z)
	occupied_waiter_cells[key] = waiter_entry
	
	#print("WaiterSystem: 服务生已就位并加入逻辑字典: ", waiter_info.name)
	return true




# ========================================================
# 核心改变：移除自主寻找任务，改为外部派遣
# ========================================================

# WaiterSystem.gd
# WaiterSystem.gd

# 确认 assign_task_to_waiter 函数的去重逻辑是正确的
func assign_task_to_waiter(waiter_id: String, task: Task) -> bool:
	var waiter = waiter_data_map.get(waiter_id)
	if not waiter: return false
	
	# 去重检查
	for existing_task in waiter.task_queue:
		if existing_task.type == task.type:
			# 如果是点餐任务，且是同一个客人，则视为重复，不添加
			if task.type == TaskType.ORDERING and existing_task.customer == task.customer:
				return true
			if task.type == TaskType.SERVING and existing_task.customer == task.customer:
				return true
			# 其他类型的去重逻辑...
			if task.type == TaskType.PAYMENT and existing_task.table_node == task.table_node:
				return true

	waiter.task_queue.append(task)
	# 排序：数字越小优先级越高 (Pickup=1, Ordering=5)
	waiter.task_queue.sort_custom(func(a, b): return a.priority < b.priority)
	
	if waiter.state == WaiterState.IDLE and waiter.current_task == null:
		_execute_next_task(waiter)
	return true





# --- 核心修复：执行下一个任务 ---
func _execute_next_task(waiter: WaiterRuntimeData):
	# 如果当前已经有任务在处理（正在走或者正在干活），严禁从队列取新任务
	if waiter.current_task != null:
		return

	if waiter.task_queue.is_empty():
		waiter.state = WaiterState.IDLE
		change_cloth(waiter, "待机")
		return
		
	# 取出最高优先级任务
	waiter.current_task = waiter.task_queue.pop_front()
	
	# 转换服装
	_update_waiter_cloth_by_task(waiter, waiter.current_task)

	# 检查目标位置
	if waiter.pos == waiter.current_task.target_pos:
		_execute_current_task(waiter)
	else:
		waiter.state = WaiterState.MOVING
		_start_move_to_position(waiter, waiter.current_task.target_pos)

# 辅助函数：根据任务换装
func _update_waiter_cloth_by_task(waiter, task):
	match task.type:
		TaskType.ORDERING: change_cloth(waiter, "点菜")
		TaskType.CLEANING: change_cloth(waiter, "收拾")
		TaskType.SERVING: change_cloth(waiter, "上菜")
		_: change_cloth(waiter, "待机")




# WaiterSystem.gd

# 修改 _check_waiter_state 函数
func _check_waiter_state(waiter_id: String):
	var waiter = waiter_data_map.get(waiter_id)
	if not waiter: return
	
	# 如果正在移动或正在干活，就不打扰他
	if waiter.state != WaiterState.IDLE: 
		return

	# 1. 优先处理队列里的任务
	if not waiter.task_queue.is_empty():
		_execute_next_task(waiter)
		return
	
	# 2. 【核心新增】如果队列也是空的，闲着也是闲着，主动去寻找任务！
	# 这就是你想要的“每分钟检查一下”，这里是每0.5秒检查一次
	_waiter_scan_for_work(waiter)

# WaiterSystem.gd

# 【新增】服务员主动寻找工作
# WaiterSystem.gd

# WaiterSystem.gd

# 修改 _waiter_scan_for_work 函数
func _waiter_scan_for_work(waiter: WaiterRuntimeData):
	
	# --- 优先级 1: 检查收银台 (最高优先级，拿钱要紧) ---
	var cashiers = manager.furniture_system.get_all_furniture_by_limit("收银台")
	for c_data in cashiers:
		var node = c_data["node_ref"]
		if is_instance_valid(node):
			var queue = node.get_meta("pay_queue", [])
			if not queue.is_empty() and not has_waiter_handling_task(TaskType.PAYMENT, node):
				if _can_waiter_reach_node(waiter, node):
					dispatch_payment_task(node)
					return 
	
	# --- 优先级 2: 检查传菜口 (次高，防止菜凉了) ---
	var pickups = manager.furniture_system.get_all_furniture_by_limit("传菜口")
	for p_data in pickups:
		var node = p_data["node_ref"]
		if is_instance_valid(node):
			var pending = node.get_meta("pending_pickup", [])
			for order in pending:
				if not _is_order_being_delivered(order):
					if _can_waiter_reach_node(waiter, node):
						dispatch_pickup_task(order)
						return

	# --- 优先级 3: 【核心新增】检查门口排队的客人 (迎客) ---
	var showing_id = manager.customer_system.current_waiting_customer_id
	if showing_id != "":
		var customer = null
		for c in fc.playerData.waiting_customers:
			if c.id == showing_id:
				customer = c
				break
		
		# 如果这个客人确实在等接待
		if customer and customer.status == "waiting":
			# 如果还没被指派服务员，尝试指派
			if not customer.has_meta("greeting_dispatched"):
				if dispatch_greeting_task(customer):
					return # 成功领到迎客任务，服务员出发
			
			else:
				# 如果已经有服务员接了这个人的单了，我们也跳过迎客，去干别的。
				pass

	# --- 优先级 4: 检查等待点餐的客人 ---
	for customer in fc.playerData.waiting_customers:
		if customer.status == "ordering":
			var table_node = customer.get_meta("assigned_table_node")
			if is_instance_valid(table_node) and not has_waiter_handling_task(TaskType.ORDERING, table_node):
				if _can_waiter_reach_node(waiter, table_node):
					dispatch_ordering_task(customer, table_node)
					return

	# --- 优先级 5: 检查脏桌子 ---
	var tables = manager.furniture_system.get_all_furniture_by_limit("桌椅")
	for t_data in tables:
		var node = t_data["node_ref"]
		if is_instance_valid(node) and node.get_meta("needs_cleaning", false):
			if not has_waiter_handling_task(TaskType.CLEANING, node):
				if _can_waiter_reach_node(waiter, node):
					dispatch_cleaning_task(node)
					return

# 【新增辅助】检查订单是否正在被配送
func _is_order_being_delivered(order) -> bool:
	for w in waiter_data_map.values():
		# 检查当前任务
		if w.current_task and w.current_task.type == TaskType.PICKUP:
			if w.current_task.data.get("order") == order: return true
		if w.current_task and w.current_task.type == TaskType.SERVING:
			if w.current_task.customer == order.customer: return true
			
		# 检查队列任务
		for t in w.task_queue:
			if t.type == TaskType.PICKUP and t.data.get("order") == order: return true
	return false

# 辅助函数：判断服务员是否能到达某个家具位置
func _can_waiter_reach_node(waiter: WaiterRuntimeData, target_node: Node3D) -> bool:
	if not is_instance_valid(target_node): return false
	
	# 1. 找到家具旁边的空位（交互点）
	# 注意：这里我们只找位置，不占用任务逻辑
	var target_pos = find_empty_spot_near_table(waiter.id, target_node)
	
	# 如果返回 -999，说明家具被围死或者是无效的
	if target_pos == Vector3i(-999, -999, -999):
		return false
		
	# 2. 检查两点之间是否连通
	# 假设 MapSystem 有 is_point_reachable 方法 (基于 A* 或 区域联通性)
	if manager.map_system:
		return manager.map_system.is_point_reachable(waiter.pos, target_pos)
	
	return true # 如果没有地图系统，默认可行（但通常不应该发生）


# 修改 _complete_current_task
# 修改 _complete_current_task
func _complete_current_task(waiter: WaiterRuntimeData):
	waiter.current_task = null
	# 检查是否有更高优先级任务由于刚才在忙被压后了，重新排下序
	waiter.task_queue.sort_custom(func(a, b): return a.priority < b.priority)
	_execute_next_task(waiter)



# ========================================================
# 新增：各种派遣任务的接口
# WaiterSystem.gd

func dispatch_greeting_task(customer: CustomerData) -> bool:
	# 1. 询问客人系统：现在这个客人能不能动？
	var status = manager.customer_system.check_and_assign_table(customer)
	
	# 如果判定是“需要等桌子”，返回 false。
	# 这会让上面的 _waiter_scan_for_work 继续往下走去点餐。
	if status == "wait_for_table":
		return false
	
	# 2. 如果是 ready (领位) 或 reject (劝退)，寻找闲人
	var waiter = _find_nearest_available_waiter()
	if not waiter: return false
	
	# 3. 寻找位置并检查路径 (逻辑同前...)
	var target_pos = _find_greeting_position(waiter.pos)
	if target_pos == Vector3i(-999, -999, -999):
		target_pos = manager.map_system.get_closest_walkable_cell(waiter.pos)
	
	if target_pos == Vector3i(-999, -999, -999) or \
	   (manager.map_system and not manager.map_system.is_point_reachable(waiter.pos, target_pos)):
		return false

	# 4. 组装任务
	var task = Task.new()
	task.type = TaskType.GREETING
	task.priority = TaskType.GREETING
	task.customer = customer
	task.target_pos = target_pos
	
	# 5. 只有成功 assign 任务，才修改客人 meta
	if assign_task_to_waiter(waiter.id, task):
		customer.set_meta("assigned_waiter_id", waiter.id)
		customer.set_meta("greeting_dispatched", true)
		return true
		
	return false



#
#func dispatch_greeting_task(customer: CustomerData) -> bool:
	## 1. 先让客人系统判断一下当前情况（分配桌子 或 决定拒绝）
	#if manager.customer_system:
		## 我们需要调用一个新函数，只做判断不发任务
		#var status = manager.customer_system.check_and_assign_table(customer)
		#
		## 如果状态是 "wait_for_table"，说明还没桌子，服务员此时不应该接任务
		#if status == "wait_for_table":
			#return false
	#
	## 2. 寻找合适的服务员 (可以是传入的 ID，或者是最近的空闲者)
	## 这里的逻辑主要是为了配合 _waiter_scan_for_work 的自动查找
	## 如果是自动扫描调用的，我们希望把自己指派过去
	#
	## 为了通用性，我们还是找最近的空闲服务员
	#var waiter = _find_nearest_available_waiter() 
	#
	## 如果找到了服务员，还需要检查他能不能走到迎客位
	#if not waiter: return false
	#
	#var target_pos = _find_greeting_position(waiter.pos)
	#if target_pos == Vector3i(-999, -999, -999): return false
	#
	## 再次确认可达性
	#if manager.map_system and not manager.map_system.is_point_reachable(waiter.pos, target_pos):
		#return false
#
	## 3. 创建任务
	#var task = Task.new()
	#task.type = TaskType.GREETING
	#task.priority = TaskType.GREETING
	#task.customer = customer
	#task.target_pos = target_pos
	#
	## 标记客人
	#customer.set_meta("assigned_waiter_id", waiter.id)
	#customer.set_meta("greeting_dispatched", true)
	#
	#return assign_task_to_waiter(waiter.id, task)






# WaiterSystem.gd
# WaiterSystem.gd

# 派遣点餐任务（完整修复版）
func dispatch_ordering_task(customer: CustomerData, table_node: Node3D) -> bool:
	# 1. 基础检查：客人是否有效且还在排队/入座列表中
	if not fc.playerData.waiting_customers.has(customer):
		# print("WaiterSystem: 客人已不在列表中，取消派单")
		return false
	
	# 2. 去重检查：是否已经有服务员接了这个任务？
	# 避免多个闲着的服务员同时冲向同一桌
	if has_waiter_handling_task(TaskType.ORDERING, table_node):
		return true # 视为成功，因为已经有人在管了
	
	# 3. 确定目标服务员 ID
	var final_waiter_id = ""
	
	# 3.1 获取该桌子原本分配的服务员（负责人）
	var assigned_id = manager.furniture_system.get_assigned_waiter_id(table_node)
	
	# 3.2 检查负责人是否“合格”
	# 合格条件：存在 + 已放置在场景中 + 能走到这张桌子
	var assigned_is_valid = false
	if assigned_id != "" and waiter_data_map.has(assigned_id):
		var waiter_obj = waiter_data_map[assigned_id]
		# 【关键】路径可达性检查：负责人在里面出不来，就不能派给他
		if _can_waiter_reach_node(waiter_obj, table_node):
			assigned_is_valid = true
	
	# 3.3 尝试分配给负责人
	# 如果负责人合格，且不是很忙（任务少于2个），优先给他
	if assigned_is_valid:
		if not _is_waiter_busy(assigned_id):
			final_waiter_id = assigned_id
	
	# 3.4 兜底机制：找其他替补
	# 如果没定下来（没负责人，或者负责人被墙挡住了，或者负责人太忙了）
	if final_waiter_id == "":
		# 【关键】查找最近的、空闲的、且【能走到这张桌子】的服务员
		var best_backup = _find_nearest_available_waiter(table_node)
		if best_backup:
			final_waiter_id = best_backup.id
	
	# 3.5 强制兜底
	# 如果所有人都忙，但负责人是能走到桌子的，那就强制塞给负责人排队（总比没人理好）
	if final_waiter_id == "" and assigned_is_valid:
		final_waiter_id = assigned_id
	
	# 4. 最终检查：还是没人能接（所有人都被围起来了，或者没招人）
	if final_waiter_id == "":
		# print("WaiterSystem: 警告 - 没有服务员能到达桌子或接单")
		return false
	
	# 5. 创建并分派任务
	var task = Task.new()
	task.type = TaskType.ORDERING
	task.priority = TaskType.ORDERING
	task.customer = customer
	task.table_node = table_node
	# 寻找该服务员视角下，桌子旁边的空位
	task.target_pos = find_empty_spot_near_table(final_waiter_id, table_node)
	
	return assign_task_to_waiter(final_waiter_id, task)

# 【新增辅助】判断服务员是否太忙
# 辅助函数：判断服务员是否太忙
func _is_waiter_busy(waiter_id: String) -> bool:
	var w = waiter_data_map.get(waiter_id)
	if not w: return true
	
	# 判定标准：
	# 1. 任务队列里已经积压了超过 2 个任务
	# 2. 或者当前正在执行任务且队列里还有 1 个以上
	if w.task_queue.size() >= 2:
		return true
		
	return false


# 3. 取菜任务 (KitchenSystem完成后调用)
func dispatch_pickup_task(order) -> bool:
	# 找到负责该桌的服务员
	var waiter_id = manager.furniture_system.get_assigned_waiter_id(order.table_node)
	if waiter_id == "" or not waiter_data_map.has(waiter_id): return false
	
	# 寻找传菜口家具位置
	var pickups = manager.furniture_system.get_all_furniture_by_limit("传菜口")
	if pickups.is_empty(): return false
	var pickup_node = pickups[0]["node_ref"]
	
	var task = Task.new()
	task.type = TaskType.PICKUP
	task.priority = TaskType.PICKUP
	task.customer = order.customer
	task.table_node = pickup_node # 目标是传菜口
	task.data = {"order": order, "real_table": order.table_node}
	task.target_pos = find_empty_spot_near_table(waiter_id, pickup_node)
	
	return assign_task_to_waiter(waiter_id, task)


# 派遣上菜任务（由厨房系统调用）
func dispatch_serving_task(order) -> bool:
	var waiter_id = manager.furniture_system.get_assigned_waiter_id(order.table_node)
	if waiter_id == "" or not waiter_data_map.has(waiter_id): return false
	
	var task = Task.new()
	task.type = TaskType.SERVING
	task.priority = TaskType.SERVING
	task.customer = order.customer
	task.table_node = order.table_node
	task.dishes = order.dishes
	task.target_pos = find_empty_spot_near_table(waiter_id, order.table_node)
	
	return assign_task_to_waiter(waiter_id, task)

# 4. 收银任务 (OrderingSystem用餐结束后)
func dispatch_payment_task(cashier_node: Node3D) -> bool:
	# 找到负责收银的服务员(通常是收银台绑定的那个)
	var waiter_id = manager.furniture_system.get_assigned_waiter_id(cashier_node)
	if waiter_id == "":
		var aw = _find_nearest_available_waiter()
		if not aw: return false
		waiter_id = aw.id

	var task = Task.new()
	task.type = TaskType.PAYMENT
	task.priority = TaskType.PAYMENT
	task.table_node = cashier_node
	task.target_pos = find_empty_spot_near_table(waiter_id, cashier_node)
	
	return assign_task_to_waiter(waiter_id, task)


# 派遣收拾任务（由客人系统调用）
func dispatch_cleaning_task(table_node: Node3D) -> bool:
	var waiter_id = manager.furniture_system.get_assigned_waiter_id(table_node)
	if waiter_id == "" or not waiter_data_map.has(waiter_id):
		var aw = _find_nearest_available_waiter()
		if not aw: return false
		waiter_id = aw.id
	
	var task = Task.new()
	task.type = TaskType.CLEANING
	task.priority = TaskType.CLEANING
	task.table_node = table_node
	task.target_pos = find_empty_spot_near_table(waiter_id, table_node)
	
	return assign_task_to_waiter(waiter_id, task)

# 辅助函数：找到最近的可用的服务员

# 修改 _find_nearest_available_waiter
# 增加一个可选参数 target_node，用来判断是否可达
func _find_nearest_available_waiter(target_node: Node3D = null) -> WaiterRuntimeData:
	var candidates = []
	
	for waiter in waiter_data_map.values():
		# 状态筛选 (IDLE 或 空任务队列的 MOVING)
		var is_available = (waiter.state == WaiterState.IDLE) or \
						   (waiter.state == WaiterState.MOVING and waiter.task_queue.is_empty() and waiter.current_task == null)
		
		if is_available:
			# 【核心新增】如果指定了目标，必须检查可达性！
			if target_node:
				if _can_waiter_reach_node(waiter, target_node):
					candidates.append(waiter)
				# else: 排除这个被隔离的服务员
			else:
				candidates.append(waiter)
	
	# 如果没找到闲人，且没指定目标，才尝试找任务少的人作为最后保底
	# 但如果指定了目标（比如必须去某张桌子），就不能随便找个到不了的人凑数
	if candidates.is_empty() and target_node == null:
		for waiter in waiter_data_map.values():
			if waiter.task_queue.size() < 2:
				candidates.append(waiter)

	if candidates.is_empty():
		return null
	
	# 下面计算距离最近的代码保持不变...
	# 这里只展示修改了候选人筛选的部分
	
	var best_waiter = candidates[0]
	var min_dist = INF
	
	# 如果有目标节点，直接算到目标节点的距离
	var dest_pos = Vector3i.ZERO
	if target_node:
		dest_pos = find_empty_spot_near_table(best_waiter.id, target_node) # 临时算一个目标点
	else:
		# 如果没目标，默认按迎客位算（原逻辑）
		dest_pos = _find_greeting_position(best_waiter.pos)
		
	if dest_pos == Vector3i(-999, -999, -999):
		return candidates[0]

	for waiter in candidates:
		var dist = waiter.pos.distance_squared_to(dest_pos) # 简单欧式距离，因为前面已经做过连通性检查了
		if dist < min_dist:
			min_dist = dist
			best_waiter = waiter
			
	return best_waiter
# 【新增】计算路径长度的辅助函数
func _calculate_path_length(start: Vector3i, target: Vector3i) -> int:
	if start == target:
		return 0
	
	# 使用BFS计算实际路径长度
	var visited = { str(start): true }
	var queue = [{ "pos": start, "dist": 0 }]
	var directions = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		for dir in directions:
			var next = current.pos + dir
			var key = str(next)
			
			if not visited.has(key) and manager.map_system.is_cell_walkable(next):
				if next == target:
					return current.dist + 1
				
				visited[key] = true
				queue.append({ "pos": next, "dist": current.dist + 1 })
	
	return INF  # 不可达






# 执行当前任务
func _execute_current_task(waiter: WaiterRuntimeData):
	var task = waiter.current_task
	if not task: return

	match task.type:
		TaskType.GREETING:
			add_skill_value(waiter,1)
			_execute_greeting(waiter)
		TaskType.ORDERING:
			add_skill_value(waiter,0)
			_execute_ordering(waiter)
		TaskType.PICKUP:
			_execute_pickup(waiter)
		TaskType.SERVING:
			_execute_serving(waiter)
		TaskType.PAYMENT:
			_execute_payment(waiter)
		TaskType.CLEANING:
			add_skill_value(waiter,2)
			_execute_cleaning(waiter)
		TaskType.TOILET_CLEANING:
			_execute_toilet_cleaning(waiter)
		TaskType.DELIVERY_TAKEAWAY: # 【新增】
			_execute_delivery_takeaway(waiter)

func _execute_toilet_cleaning(waiter: WaiterRuntimeData):
	waiter.state = WaiterState.CLEANING 
	var toilet_node = waiter.current_task.table_node
	
	# 这里直接通过 manager 访问 furniture_system 是没问题的，因为 WaiterSystem 本身就在场景里
	var current_val = manager.furniture_system.get_toilet_cleanliness(toilet_node)
	manager.furniture_system.update_toilet_cleanliness(toilet_node, min(100.0, current_val + 50.0))
	
	manager.furniture_system.hide_talk_icon(toilet_node)
	_complete_current_task(waiter)
	
func dispatch_toilet_cleaning_task(toilet_node: Node3D) -> bool:
	var waiter_id = manager.furniture_system.get_assigned_waiter_id(toilet_node)
	if waiter_id == "" or not waiter_data_map.has(waiter_id):
		return false
	
	if has_waiter_handling_task(TaskType.TOILET_CLEANING, toilet_node):
		return true

	var task = Task.new()
	task.type = TaskType.TOILET_CLEANING
	task.priority = TaskType.TOILET_CLEANING
	task.table_node = toilet_node
	task.target_pos = find_empty_spot_near_table(waiter_id, toilet_node)
	
	# 显示打扫图标
	manager.furniture_system.show_talk_icon(toilet_node, "res://pic/ui/talk2_qingsao.png")
	
	return assign_task_to_waiter(waiter_id, task)
	

func add_skill_value(waiter,type):
	if randi_range(0,1)==0:#随机提升经验值
		for i in fc.playerData.waiters:
			if i.id==waiter.id:
				i.skill_experience[type]+=1
				if i.skill_experience[type]>100:
					i.skill_experience[type]=100
				break



func _execute_greeting(waiter: WaiterRuntimeData):
	waiter.state = WaiterState.GREETING
	
	if waiter.current_task.customer and manager.customer_system:
		manager.customer_system.finalize_greeting(waiter.current_task.customer,waiter.id)
	_complete_current_task(waiter)

# 修改 _execute_ordering 函数
# WaiterSystem.gd

# 修改 _execute_ordering 函数
func _execute_ordering(waiter: WaiterRuntimeData):
	waiter.state = WaiterState.ORDERING
	
	# 动作模拟延迟
	
	
	# 【核心修复】在 await 之后，必须再次检查 current_task 是否存在！
	# 因为在等待期间，客人可能已经离开，任务可能已经被 cancel_customer_tasks 清空了
	if waiter.current_task == null:
		#print("WaiterSystem: 等待期间任务被取消，停止执行点餐")
		# 任务没了，直接恢复状态即可，不需要调用 complete，因为任务已经没了
		waiter.state = WaiterState.IDLE
		change_cloth(waiter, "待机")
		return

	# 再次检查必要数据是否完整
	if not waiter.current_task.customer or not is_instance_valid(waiter.current_task.table_node):
		#print("WaiterSystem: 警告 - 任务数据失效")
		_complete_current_task(waiter)
		return
	
	if not manager.ordering_system:
		_complete_current_task(waiter)
		return
	
	# 执行点餐逻辑
	manager.ordering_system.on_waiter_arrived_for_ordering(waiter.id, waiter.current_task.customer, waiter.current_task.table_node)
	
	change_cloth(waiter, "待机")
	_complete_current_task(waiter)


# WaiterSystem.gd

func _execute_pickup(waiter: WaiterRuntimeData):
	waiter.state = WaiterState.PICKUP
	var pickup_node = waiter.current_task.table_node
	var order = waiter.current_task.data.get("order")
	
	# 动作延迟
	
	
	# 【安全检查】
	if waiter.current_task == null:
		waiter.state = WaiterState.IDLE
		change_cloth(waiter, "待机")
		return
	
	if is_instance_valid(pickup_node):
		var pending = pickup_node.get_meta("pending_pickup", [])
		
		# 只有当这个特定的订单还在传菜口时才处理
		if order in pending:
			pending.erase(order)
			pickup_node.set_meta("pending_pickup", pending)
		
		# 【重要修复】图标隐藏逻辑：只有当真的没有“待取”订单时才隐藏
		if pending.is_empty():
			manager.furniture_system.hide_talk_icon(pickup_node)
		else:
			# 如果还有菜，确保图标是亮着的（防止被其他过期的任务误隐藏）
			manager.furniture_system.show_talk_icon(pickup_node, "res://pic/ui/talk2_nacai.png")
	
	# 拿到菜后，变更为送餐任务
	waiter.current_task.type = TaskType.SERVING
	waiter.current_task.priority = TaskType.SERVING
	var real_table = waiter.current_task.data.get("real_table")
	waiter.current_task.table_node = real_table
	waiter.current_task.target_pos = find_empty_spot_near_table(waiter.id, real_table)
	
	waiter.state = WaiterState.MOVING
	change_cloth(waiter,"上菜")
	_start_move_to_position(waiter, waiter.current_task.target_pos)
	

func _execute_serving(waiter: WaiterRuntimeData):
	waiter.state = WaiterState.SERVING
	# 模拟摆菜动作
	
	
	if is_instance_valid(waiter.current_task.table_node):
		# 1. 更新桌子显示：有菜了（图片根据 group_size 变化）
		manager.furniture_system.update_table_visual(waiter.current_task.table_node)
		# 2. 告诉客人开始吃
		if manager.ordering_system:
			manager.ordering_system.start_eating(waiter.current_task.customer, waiter.current_task.table_node)
	
	change_cloth(waiter,"待机")
	_complete_current_task(waiter)

# --- 核心修复：完善收银逻辑，支持连续处理 ---
func _execute_payment(waiter: WaiterRuntimeData):
	waiter.state = WaiterState.PAYMENT
	var cashier_node = waiter.current_task.table_node
	
	
	
	# 【安全检查】
	if waiter.current_task == null:
		waiter.state = WaiterState.IDLE
	
	if is_instance_valid(cashier_node):
		var queue = cashier_node.get_meta("pay_queue", [])
		if not queue.is_empty():
			var job = queue.pop_front()
			cashier_node.set_meta("pay_queue", queue)
			
			if job.customer:
				var order = job.customer.get_meta("order_result")
				fc.playerData.money += order.total_cost
				fc.playerData.pay_today+=order.total_cost
				
				manager.ordering_system.change_show_info()
				
				fc.play_se_fx("cash")
				if manager.customer_system:
					manager.customer_system._customer_leave(job.customer, "客人结账离开，支付了 %s" %fc.format_money(order.total_cost))
			
			# 【重要：连续收银逻辑】
			# 如果收银台还有人在排队，服务生不要急着走，继续生成一个收银任务塞进队列首部
			if not queue.is_empty():
				var continuous_pay = Task.new()
				continuous_pay.type = TaskType.PAYMENT
				continuous_pay.priority = TaskType.PAYMENT # 高优先级
				continuous_pay.table_node = cashier_node
				continuous_pay.target_pos = waiter.pos # 就在原地
				waiter.task_queue.insert(0, continuous_pay)
			else:
				manager.furniture_system.hide_talk_icon(cashier_node)
	
	_complete_current_task(waiter)

func _execute_cleaning(waiter: WaiterRuntimeData):
	waiter.state = WaiterState.CLEANING

	
	# 【核心修复】必须检查任务是否还在！
	if waiter.current_task == null:
		waiter.state = WaiterState.IDLE
		change_cloth(waiter, "待机")
		return
	
	if is_instance_valid(waiter.current_task.table_node):
		manager.furniture_system._reset_table_state(waiter.current_task.table_node)
		manager.furniture_system.hide_talk_icon(waiter.current_task.table_node)
	
	change_cloth(waiter,"待机")
	_complete_current_task(waiter)





# ========================================================
# 移动相关函数
# ========================================================
func _start_move_to_position(waiter: WaiterRuntimeData, target_pos: Vector3i):
	#print("开始移动，从 ", waiter.pos, " 到 ", target_pos)
	var callback = func(): _on_waiter_arrived(waiter)
	_start_move_with_jump(waiter, target_pos, callback)


func _on_waiter_arrived(waiter: WaiterRuntimeData):
	# 【关键修复】确保到达后Y轴正确
	var base_y = _get_waiter_base_height(waiter)
	waiter.node_ref.position.y = base_y
	
	waiter.state = WaiterState.IDLE
	# 【修复】检查是否有任务
	if waiter.current_task:
		# 到达后立即执行任务
		_execute_current_task(waiter)
	else:
		#print("服务员到达但没有任务: ", waiter.id)
		# 【新增】如果没有任务，确保状态为空闲
		waiter.state = WaiterState.IDLE


func _start_move_with_jump(waiter: WaiterRuntimeData, target_pos: Vector3i, callback: Callable):
	# 0. 【关键修复】杀掉之前的动画 Tween，防止动画冲突（乱跳、平移、瞬移）
	if waiter.active_tween_xz and is_instance_valid(waiter.active_tween_xz):
		waiter.active_tween_xz.kill()
		waiter.active_tween_xz = null
		
	if waiter.active_tween_y and is_instance_valid(waiter.active_tween_y):
		waiter.active_tween_y.kill()
		waiter.active_tween_y = null

	var current_pos = waiter.pos
	var node = waiter.node_ref
	
	# 检查是否到达
	if current_pos == target_pos:
		callback.call()
		return
	
	# 计算下一步
	var next_pos = manager.map_system.get_next_step(current_pos, target_pos)
	if next_pos == Vector3i(-999,-999,-999):
		callback.call()
		return
	
	# 速度折算
	var duration = 0.4
	
	# 【关键修复】强制重置Y轴到基准高度
	var base_y = _get_waiter_base_height(waiter)
	
	var start_world = node.position
	start_world.y = base_y  # 强制重置Y轴
	
	var next_world_global = manager.grid_map_node.to_global(manager.grid_map_node.map_to_local(next_pos))
	var next_world_local = furniture_holder.to_local(next_world_global)
	next_world_local.y = base_y  # 【关键】确保目标位置Y轴正确
	
	var jump_height = 0.8
	
	# 强制修正旋转
	node.rotation = Vector3.ZERO
	fc.play_se_ui("jump")
	
	# 创建蹦跳动画
	var tween_xz = create_tween()
	tween_xz.set_parallel(true)
	tween_xz.tween_property(node, "position:x", next_world_local.x, duration)
	tween_xz.tween_property(node, "position:z", next_world_local.z, duration)
	
	# 【保存引用】
	waiter.active_tween_xz = tween_xz
	
	var tween_y = create_tween()
	# 【关键修复】从基准高度开始跳跃
	tween_y.tween_property(node, "position:y", base_y + jump_height, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	# 【关键修复】确保落回基准高度
	tween_y.tween_property(node, "position:y", base_y, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
		
	# 【保存引用】
	waiter.active_tween_y = tween_y
	
	# 递归调用
	tween_xz.chain().tween_callback(func():
		waiter.pos = next_pos
		# 【关键修复】确保位置更新后Y轴正确
		node.position.y = base_y
		_update_waiter_pos_data(waiter.id, current_pos, next_pos)
		
		# 【关键】递归前清空引用，允许被下一帧覆盖
		waiter.active_tween_xz = null
		waiter.active_tween_y = null
		
		_start_move_with_jump(waiter, target_pos, callback)
	)


# 获取服务员应该站立的标准高度
func _get_waiter_base_height(waiter: WaiterRuntimeData) -> float:
	# 方法1：从放置时的数据获取
	for item in placed_waiters_data:
		if item["waiter_id"] == waiter.id:
			# 返回放置时的高度
			return item["pos"].y * manager.grid_map_node.cell_size.y + 0.2
	
	# 方法2：使用默认高度
	return 0.2



# ========================================================
# 辅助函数
# ========================================================
# 修改 waiter_system.gd 中的 _find_greeting_position 函数
func _find_greeting_position(waiter_pos: Vector3i) -> Vector3i:
	if not manager.furniture_system:
		return Vector3i(-999, -999, -999)
	
	var greeting_furniture_list = manager.furniture_system.get_all_furniture_by_limit("迎客位")
	if greeting_furniture_list.is_empty():
		return Vector3i(-999, -999, -999)
	
	var all_access_points: Array[Vector3i] = []
	for furniture in greeting_furniture_list:
		var f_pos = furniture["pos"]
		var f_size = Vector2i(furniture["size"][0], furniture["size"][1])
		var points = manager.map_system.get_furniture_access_points(f_pos, f_size)
		for p in points:
			all_access_points.append(p)
	
	if all_access_points.is_empty():
		return Vector3i(-999, -999, -999)
	
	# 【关键修复】找到该服务员能到达的、路径最短的迎客位格子
	var best_point = all_access_points[0]
	var min_path_length = INF
	
	for point in all_access_points:
		if manager.map_system.is_point_reachable(waiter_pos, point):
			var path_length = _calculate_path_length(waiter_pos, point)
			if path_length < min_path_length:
				min_path_length = path_length
				best_point = point
	
	#print("WaiterSystem: 服务员 ", waiter_pos, " 选择迎客位 ", best_point, " 路径长度: ", min_path_length)
	return best_point


func _find_nearest_point_to_waiter(waiter_pos: Vector3i, points: Array[Vector3i]) -> Vector3i:
	if points.is_empty():
		return Vector3i(-999, -999, -999)
	
	var nearest = points[0]
	var min_dist = INF
	
	for point in points:
		var dist = waiter_pos.distance_to(point)
		if dist < min_dist:
			min_dist = dist
			nearest = point
	
	return nearest

func _find_customer_by_id(customer_id: String) -> CustomerData:
	if not manager.customer_system:
		return null
	
	for customer in fc.playerData.waiting_customers:
		if customer.id == customer_id:
			return customer
	return null

func _update_waiter_pos_data(waiter_id: String, old_pos: Vector3i, new_pos: Vector3i):
	var old_key = str(old_pos.x) + "," + str(old_pos.z)
	var new_key = str(new_pos.x) + "," + str(new_pos.z)
	
	if occupied_waiter_cells.has(old_key):
		var data = occupied_waiter_cells[old_key]
		occupied_waiter_cells.erase(old_key)
		occupied_waiter_cells[new_key] = data




# ========================================================
# 其他必要函数（从原代码保留并适配）
# ========================================================
# 1. 检查位置是否可以放置服务生
func check_area_available(grid_pos: Vector3i) -> bool:
	# A. 检查是否有地板
	if grid_map.get_cell_item(grid_pos) == GridMap.INVALID_CELL_ITEM:
		return false
	
	# B. 检查是否被其他服务生占用
	var key = str(grid_pos.x) + "," + str(grid_pos.z)
	if occupied_waiter_cells.has(key):
		return false
	
	# C. 检查是否被家具占用
	if manager.furniture_system:
		if manager.furniture_system.get_furniture_node_at(grid_pos) != null:
			return false
			
	return true

func _create_waiter_node(grid_pos: Vector3i, waiter_data, color: Color) -> Node3D:
	var scene_path = "res://sc/waiter_show_2.tscn"
	
	var waiter_node = null
	var visual_node = null
	
	if ResourceLoader.exists(scene_path):
		waiter_node = load(scene_path).instantiate()
		var pic_node = waiter_node.get_node_or_null("pic")
		if pic_node:
			var gender_suffix = "_man" if waiter_data.gender == "male" else "_woman"
			var tex_path = "res://pic/npc/fuwuyuan/waiter_type" + str(fc.playerData.clothtype) + gender_suffix + ".png"
			pic_node.texture = load(tex_path)
			visual_node = pic_node
			pic_node.scale = Vector3(1, 1, 1)
			
			waiter_node.rotation_degrees = Vector3(0, 0, 0)
			
			if pic_node is Sprite3D:
				pic_node.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				pic_node.rotation_degrees = Vector3(0, 0, 0)
	else:
		waiter_node = Node3D.new() # 容错
# --- 【核心新增：添加底座色块】 ---
	
	if manager.current_context == RandmapManager.Context.BUZHI:
		var indicator = MeshInstance3D.new()
		var plane = PlaneMesh.new()
		plane.size = Vector2(4.0, 4.0) # 对应格子大小
		indicator.mesh = plane
		indicator.name = "WaiterIndicator"
		
		# 设置材质和颜色
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.albedo_color.a = 0.6 # 半透明
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		indicator.material_override = mat
		
		# 标记为指示器，方便高亮系统识别
		indicator.set_meta("is_indicator", true)
		indicator.set_meta("assigned_color", mat)
		
		waiter_node.add_child(indicator)
		indicator.position = Vector3(0, 0.05, 0) # 稍微抬高防止闪烁
	
	furniture_holder.add_child(waiter_node)
	
	var target_pos_on_grid = grid_map.map_to_local(grid_pos)
	var global_pos = grid_map.to_global(target_pos_on_grid)
	var final_local_pos = furniture_holder.to_local(global_pos)
		
	waiter_node.position = final_local_pos + Vector3(0, 0.2, 0)
	
	waiter_node.set_meta("highlight_node", visual_node)
	waiter_node.set_meta("original_color", color)
	
	return waiter_node

# 从原代码保留的函数（需要适配新结构）
func find_empty_spot_near_table(waiter_id: String, furniture_node: Node3D) -> Vector3i:
	if not is_instance_valid(furniture_node): return Vector3i(-999, -999, -999)
	var waiter = waiter_data_map.get(waiter_id)
	var f_data = manager.furniture_system.get_furniture_data_by_node(furniture_node)
	if f_data.is_empty(): return Vector3i(-999, -999, -999)
	
	var access_points = manager.map_system.get_furniture_access_points(f_data["pos"], Vector2i(f_data["size"][0], f_data["size"][1]))
	if access_points.is_empty(): return f_data["pos"] # 保底返回原点
	
	# 过滤掉不可行走的格子，选最近的一个
	var valid_points = access_points.filter(func(p): return manager.map_system.is_cell_walkable(p))
	if valid_points.is_empty(): return access_points[0]
	
	valid_points.sort_custom(func(a, b): return waiter.pos.distance_to(a) < waiter.pos.distance_to(b))
	return valid_points[0]



func get_waiter_state(waiter_id: String) -> String:
	var waiter = waiter_data_map.get(waiter_id)
	if waiter:
		# 【修复】返回枚举值转为字符串
		match waiter.state:
			WaiterState.IDLE:
				return "idle"
			WaiterState.MOVING:
				return "moving"
			WaiterState.GREETING:
				return "greeting"
			WaiterState.ORDERING:
				return "ordering"
			WaiterState.SERVING:
				return "serving"
			WaiterState.CLEANING:
				return "cleaning"
	return "idle"


func set_waiter_state(waiter_id: String, state: String):
	var waiter = waiter_data_map.get(waiter_id)
	if waiter:
		# 【修复】根据字符串设置枚举值
		match state:
			"idle":
				waiter.state = WaiterState.IDLE
			"moving":
				waiter.state = WaiterState.MOVING
			"greeting":
				waiter.state = WaiterState.GREETING
			"ordering":
				waiter.state = WaiterState.ORDERING
			"serving":
				waiter.state = WaiterState.SERVING
			"cleaning":
				waiter.state = WaiterState.CLEANING

# 修改 has_waiter_in_state 函数，使用枚举比较
func has_waiter_in_state(target_state: String) -> bool:
	var target_enum
	match target_state:
		"idle":
			target_enum = WaiterState.IDLE
		"moving":
			target_enum = WaiterState.MOVING
		"greeting":
			target_enum = WaiterState.GREETING
		"ordering":
			target_enum = WaiterState.ORDERING
		"serving":
			target_enum = WaiterState.SERVING
		"cleaning":
			target_enum = WaiterState.CLEANING
		_:
			return false
	
	for waiter in waiter_data_map.values():
		if waiter.state == target_enum:
			return true
	return false


# 存档读档函数（保持兼容性）
func save_waiters_to_global():
	var save_list = []
	for item in placed_waiters_data:
		save_list.append({
			"waiter_id": item["waiter_id"],
			"pos": item["pos"],
			"color": item["color"].to_html()
		})
	fc.playerData.saved_waiters = save_list

# 修改 load_waiters_from_global 函数
# 修改 load_waiters_from_global 函数
# WaiterSystem.gd

func load_waiters_from_global():
	var save_list = fc.playerData.saved_waiters
	if save_list.is_empty():
		_clear_all_waiters()
		return
	
	_clear_all_waiters()
	
	var hired_map = {}
	for w in fc.playerData.waiters:
		if w is WaiterData:
			hired_map[w.id] = w
	
	for saved_item in save_list:
		var w_id = saved_item["waiter_id"]
		var pos = saved_item["pos"]
		if typeof(pos) != TYPE_VECTOR3I:
			pos = fc.string_to_vector3i_1(pos)
		var color = Color.from_string(saved_item.get("color", "white"), Color.WHITE)
		
		if hired_map.has(w_id):
			# 【关键】通过 place_waiter 加载，会自动处理 runtime 字典和定时器
			place_waiter(pos, hired_map[w_id], color)
		else:
			print("WaiterSystem: 警告 - 找不到该服务员的数据: ", w_id)
	
	# 【修改】加载完成后，立即根据当前营业状态设置图片
	if manager.current_context == RandmapManager.Context.GAME_SCENE:
		# 检查当前是否在营业时间内
		var current_time = fc.playerData.now_time
		var is_business_hours = fc.is_within_business_hours(current_time)
		
		# 如果在营业时间内但当前是关门状态，设置为打扫状态
		if is_business_hours and not fc.playerData.is_open:
			set_all_waiters_cleaning()
			update_waiter_appearance(false)  # 【新增】立即更新外观
		elif not is_business_hours:
			# 非营业时间，设置为打扫状态
			set_all_waiters_cleaning()
			update_waiter_appearance(false)  # 【新增】立即更新外观
		else:
			# 营业时间且开门，设置为工作状态
			set_all_waiters_working()
			update_waiter_appearance(true)   # 【新增】立即更新外观




func _clear_all_waiters():
	# 停止所有定时器
	for waiter in waiter_data_map.values():
		var waiter_data = waiter as WaiterRuntimeData
		if waiter_data.check_timer and is_instance_valid(waiter_data.check_timer):
			waiter_data.check_timer.queue_free()
	
	# 删除所有节点
	for item in placed_waiters_data:
		if is_instance_valid(item["node_ref"]):
			item["node_ref"].queue_free()
	
	# 清空数据
	placed_waiters_data.clear()
	occupied_waiter_cells.clear()
	waiter_data_map.clear()
	# 【修复】不需要清理 waiter_states，因为新版本没有这个字典


# 其他需要的辅助函数
func _get_placed_waiter_data(id: String) -> Dictionary:
	for item in placed_waiters_data:
		if item["waiter_id"] == id:
			return item
	return {}

func _calculate_path_distance(start: Vector3i, target: Vector3i) -> int:
	if start == target:
		return 0
	
	if not manager.map_system.is_cell_walkable(start):
		return -1
	if not manager.map_system.is_cell_walkable(target):
		return -1
	
	var visited = { str(start): true }
	var queue = [{ "pos": start, "dist": 0 }]
	var directions = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		for dir in directions:
			var next = current.pos + dir
			var key = str(next)
			
			if not visited.has(key) and manager.map_system.is_cell_walkable(next):
				if next == target:
					return current.dist + 1
				
				visited[key] = true
				queue.append({ "pos": next, "dist": current.dist + 1 })
	
	return -1

func get_waiter_node_at(grid_pos: Vector3i) -> Node3D:
	var key = str(grid_pos.x) + "," + str(grid_pos.z)
	if occupied_waiter_cells.has(key):
		for item in placed_waiters_data:
			if item["pos"] == grid_pos:
				return item["node_ref"]
	return null

# WaiterSystem.gd

func set_waiter_highlight(waiter_node: Node3D, active: bool):
	if not is_instance_valid(waiter_node): return
	
	# 1. 人物模型高亮（原有逻辑）
	var visual = waiter_node.get_meta("highlight_node", null)
	if visual:
		if active:
			visual.modulate = Color(2, 2, 2, 1) # 变亮
		else:
			visual.modulate = Color.WHITE

	# 2. 底座色块高亮（新增逻辑）
	for child in waiter_node.get_children():
		if child is MeshInstance3D and child.has_meta("is_indicator"):
			if active:
				child.material_override = _highlight_mat # 变成亮黄色
			else:
				# 恢复原来的队伍颜色
				if child.has_meta("assigned_color"):
					child.material_override = child.get_meta("assigned_color")

# 4. 检查服务生是否已在场 (用于 UI 刷新)
func is_waiter_placed(waiter_id: String) -> bool:
	for item in placed_waiters_data:
		if item["waiter_id"] == waiter_id:
			return true
	return false



# 在 waiter_system.gd 的任意位置添加这些函数

# 检查所有服务生是否能到达其负责的区域
func check_all_waiters_paths() -> Array:
	var errors = []
	
	if not manager.map_system or not manager.furniture_system:
		return []
		
	# 1. 刷新路径缓存
	manager.map_system.rebuild_empty_cells_map(manager.furniture_system)
	
	# 2. 遍历所有服务生
	for item in placed_waiters_data:
		var waiter_id = item["waiter_id"]
		var start_pos = item["pos"]
		var waiter_name = _get_waiter_name(waiter_id)
		
		# 2.1 检查迎客位
		var greetings = manager.furniture_system.get_all_furniture_by_limit("迎客位")
		for g in greetings:
			if not _can_reach_furniture(start_pos, g):
				# 特殊类型直接返回中文名，business_info 需要做兼容处理
				errors.append([waiter_name, "迎客位"])
				
		# 2.2 检查传菜口
		var windows = manager.furniture_system.get_all_furniture_by_limit("传菜口")
		for w in windows:
			if not _can_reach_furniture(start_pos, w):
				errors.append([waiter_name, "传菜口"])
				
		# 2.3 检查分配的家具
		var assignments = manager.furniture_system.furniture_waiter_assignment
		for furniture_node in assignments:
			var info = assignments[furniture_node]
			if info["waiter_id"] == waiter_id:
				var f_data = manager.furniture_system.get_furniture_data_by_node(furniture_node)
				if not f_data.is_empty():
					if not _can_reach_furniture(start_pos, f_data):
						# 【关键】返回家具 ID (例如 "1001")，方便 UI 查询名字
						# 如果没有 ID，返回 limit 类型
						var target_id = f_data.get("ID", f_data.get("limit", "未知家具"))
						errors.append([waiter_name, target_id])

	return errors

func _can_reach_furniture(start_pos: Vector3i, furniture_data: Dictionary) -> bool:
	var f_pos = furniture_data["pos"]
	var f_size = Vector2i(furniture_data["size"][0], furniture_data["size"][1])
	
	# 获取家具周围的所有入口点
	var access_points = manager.map_system.get_furniture_access_points(f_pos, f_size)
	
	if access_points.is_empty():
		return false # 家具被围死了
		
	# 只要能到达任意一个入口点就算通过
	for target in access_points:
		if manager.map_system.is_point_reachable(start_pos, target):
			return true
			
	return false

func _get_waiter_name(id: String) -> String:
	# 简单查找名字
	for w in fc.playerData.waiters:
		if w.id == id: return w.name
	return "未知服务生"

# 更新服务生外观的函数
func update_waiter_appearance(is_open: bool):
	for item in placed_waiters_data:
		var waiter_node = item["node_ref"]
		var waiter_id = item["waiter_id"]
		
		if not is_instance_valid(waiter_node):
			continue
			
		var pic_node = waiter_node.get_node_or_null("pic")
		if not pic_node:
			continue
		
		# 获取服务员数据
		var waiter_data = null
		for w in fc.playerData.waiters:
			if w.id == waiter_id:
				waiter_data = w
				break
		
		if not waiter_data:
			continue
		
		var tex_path = ""
		
		if is_open:
			# 开店状态：使用工作图片
			var gender_suffix = "_man" if waiter_data.gender == "male" else "_woman"
			tex_path = "res://pic/npc/fuwuyuan/waiter_type" + str(fc.playerData.clothtype) + gender_suffix + ".png"
			
			# 【关键】更新记录的图片路径
			item["current_texture_path"] = tex_path
			
		else:
			# 关店状态：检查是否已经有打扫图片
			if item.has("current_texture_path") and item["current_texture_path"].begins_with("res://pic/npc/fuwuyuan/dasao"):
				# 【关键】复用已有的打扫图片，不再随机
				tex_path = item["current_texture_path"]
			else:
				# 第一次关门，随机选择并记录
				var cleaning_num = randi() % 2 + 1
				tex_path = "res://pic/npc/fuwuyuan/dasao" + str(cleaning_num) + ".png"
				item["current_texture_path"] = tex_path
		
		# 加载并设置新图片
		var new_texture = load(tex_path)
		if new_texture:
			pic_node.texture = new_texture
		else:
			print("WaiterSystem: 无法加载图片: ", tex_path)

# 批量更新所有服务员为打扫状态
# 修改 set_all_waiters_cleaning 函数
func set_all_waiters_cleaning():
	# 先清空所有任务
	clear_all_tasks()
	
	# 然后设置所有服务生为打扫状态
	for waiter_id in waiter_data_map:
		var waiter = waiter_data_map[waiter_id]
		waiter.state = WaiterState.CLEANING
	
	# 更新外观
	update_waiter_appearance(false)


# 批量更新所有服务员为工作状态
func set_all_waiters_working():
	# 设置所有服务生为工作状态（空闲）
	for waiter_id in waiter_data_map:
		var waiter = waiter_data_map[waiter_id]
		waiter.state = WaiterState.IDLE
	# 更新外观
	update_waiter_appearance(true)

# 获取服务员当前使用的图片路径（用于调试）
func get_waiter_current_texture(waiter_id: String) -> String:
	for item in placed_waiters_data:
		if item["waiter_id"] == waiter_id:
			var waiter_node = item["node_ref"]
			if is_instance_valid(waiter_node):
				var pic_node = waiter_node.get_node_or_null("pic")
				if pic_node and pic_node.texture:
					return pic_node.texture.resource_path
	return ""

# 新增：处理下一个任务
func process_next_task(waiter_id: String):
	var waiter = waiter_data_map.get(waiter_id)
	if not waiter:
		return
	
	# 完成当前任务
	if waiter.current_task:
		waiter.task_queue.erase(waiter.current_task)
		waiter.current_task = null
	
	# 立即执行下一个任务
	_execute_next_task(waiter)

# 新增：清空所有服务员的任务
# 增强版 clear_all_tasks 函数
func clear_all_tasks():
	#print("WaiterSystem: 清空所有服务员的任务队列")
	
	for waiter_id in waiter_data_map:
		var waiter = waiter_data_map[waiter_id]
		
		# 如果正在执行任务，可能需要停止动画
		if waiter.current_task:
			match waiter.current_task.type:
				TaskType.ORDERING:
					# 如果正在点餐，通知客人系统
					if waiter.current_task.customer and manager.customer_system:
						#print("  取消点餐任务，客人: ", waiter.current_task.customer.id)
						change_cloth(waiter, "待机")
				TaskType.SERVING:
					# 如果正在上菜，可能需要特殊处理
					#print("  取消上菜任务")
					change_cloth(waiter, "待机")
				_:
					print("  取消任务类型: ", waiter.current_task.type)
		
		# 如果正在执行非待机任务，恢复服装
		if waiter.current_task and waiter.current_task.type != TaskType.GREETING:
			change_cloth(waiter, "待机")
		
		# 清空任务队列
		waiter.task_queue.clear()
		
		# 清空当前任务
		waiter.current_task = null
		
		# 重置状态为空闲
		waiter.state = WaiterState.IDLE
		
		#print("  服务员 ", waiter_id, " 任务已清空，状态重置为空闲")



# 3. 移除服务生 (用于拾取和移动)
# WaiterSystem.gd

func remove_waiter_at(grid_pos: Vector3i) -> WaiterData:
	var key = str(grid_pos.x) + "," + str(grid_pos.z)
	if not occupied_waiter_cells.has(key):
		return null
	
	var entry = occupied_waiter_cells[key]
	var w_id = entry["waiter_id"]
	var waiter_data = entry["waiter_data"]
	
	# 1. 清理逻辑字典和定时器
	if waiter_data_map.has(w_id):
		var runtime = waiter_data_map[w_id]
		if is_instance_valid(runtime.check_timer):
			runtime.check_timer.queue_free()
		waiter_data_map.erase(w_id)
	
	# 2. 清理 3D 节点
	if is_instance_valid(entry["node_ref"]):
		entry["node_ref"].queue_free()
	
	# 3. 清理数据列表
	placed_waiters_data.erase(entry)
	occupied_waiter_cells.erase(key)
	
	return waiter_data

func change_cloth(waiter, state):
	if not waiter or not waiter.node_ref:
		return
	
	var pic_node = waiter.node_ref.get_node_or_null("pic")
	if not pic_node:
		return
	
	var waiter_data = null
	for w in fc.playerData.waiters:
		if w.id == waiter.id:
			waiter_data = w
			break
	
	if not waiter_data:
		return
	
	var gender_suffix = "_man" if waiter_data.gender == "male" else "_woman"
	var tex_path = ""
	
	match state:
		"待机":
			tex_path = "res://pic/npc/fuwuyuan/waiter_type" + str(fc.playerData.clothtype) + gender_suffix + ".png"
		"点菜":
			tex_path = "res://pic/npc/fuwuyuan/waiter_type" + str(fc.playerData.clothtype) + gender_suffix + "_diancai.png"
		"上菜":
			tex_path = "res://pic/npc/fuwuyuan/waiter_type" + str(fc.playerData.clothtype) + gender_suffix + "_shangcai.png"
		"收拾":
			tex_path = "res://pic/npc/fuwuyuan/waiter_type" + str(fc.playerData.clothtype) + gender_suffix + "_shoushi.png"
	
	var texture = load(tex_path)
	if texture:
		pic_node.texture = texture
	else:
		print("WaiterSystem: 无法加载图片: ", tex_path)


# 添加检查和修复卡住服务员的函数
func check_and_fix_stuck_waiters():
	for waiter_id in waiter_data_map:
		var waiter = waiter_data_map[waiter_id]
		
		# 如果服务员在移动状态但没有当前任务，说明卡住了
		if waiter.state == WaiterState.MOVING and not waiter.current_task:
			print("WaiterSystem: 发现卡住的服务员 ", waiter_id, "，强制重置为空闲状态")
			waiter.state = WaiterState.IDLE
		
		# 如果服务员有任务但任务已经无效，也重置
		elif waiter.current_task and not _is_task_valid(waiter.current_task):
			print("WaiterSystem: 服务员 ", waiter_id, " 的任务无效，清理并重置")
			waiter.current_task = null
			waiter.state = WaiterState.IDLE

# 修改 _is_task_valid 函数，添加更严格的检查
func _is_task_valid(task: Task) -> bool:
	if not task: return false
	
	match task.type:
		TaskType.GREETING:
			# 检查客人是否还在等待且在队列中
			if not task.customer: return false
			if task.customer.status != "waiting": return false
			if not fc.playerData.waiting_customers.has(task.customer): return false
			return true
			
		TaskType.ORDERING:
			# 检查桌子和客人是否有效
			if not is_instance_valid(task.table_node): return false
			if not task.customer: return false
			# 检查客人是否还在队列中
			if not fc.playerData.waiting_customers.has(task.customer): return false
			return true
			
		TaskType.SERVING:
			return is_instance_valid(task.table_node) and task.customer
			
		TaskType.CLEANING:
			return is_instance_valid(task.table_node)
			
		TaskType.PAYMENT:
			return is_instance_valid(task.table_node)
			
		_:
			return true

# 在 waiter_system.gd 中添加
func cancel_customer_tasks(waiter_id: String, customer: CustomerData):
	var waiter = waiter_data_map.get(waiter_id)
	if not waiter: return
	
	# 清理与该客户相关的任务
	var tasks_to_remove = []
	for i in range(waiter.task_queue.size()):
		var task = waiter.task_queue[i]
		if task.customer == customer:
			tasks_to_remove.append(i)
	
	# 倒序删除避免索引问题
	for i in range(tasks_to_remove.size() - 1, -1, -1):
		waiter.task_queue.remove_at(tasks_to_remove[i])
	
	# 如果当前任务与该客户相关，清理并重置
	if waiter.current_task and waiter.current_task.customer == customer:
		#print("WaiterSystem: 清理服务员 ", waiter_id, " 的当前客户任务")
		waiter.current_task = null
		waiter.state = WaiterState.IDLE
		change_cloth(waiter, "待机")

# WaiterSystem.gd
# WaiterSystem.gd

# 【新增】检查是否有服务员正在（或准备）接待特定客人
func is_greeting_task_active(customer: CustomerData) -> bool:
	for waiter in waiter_data_map.values():
		# 1. 检查正在执行的任务
		if waiter.current_task:
			if waiter.current_task.type == TaskType.GREETING and waiter.current_task.customer == customer:
				return true
		
		# 2. 检查排队中的任务
		for task in waiter.task_queue:
			if task.type == TaskType.GREETING and task.customer == customer:
				return true
				
	return false

# 检查当前是否有服务生已经在处理（或排队处理）某个特定位置的任务
func has_waiter_handling_task(task_type: TaskType, target_node: Node3D) -> bool:
	for waiter in waiter_data_map.values():
		# 1. 检查当前正在执行的任务
		if waiter.current_task != null:
			if waiter.current_task.type == task_type and waiter.current_task.table_node == target_node:
				return true
		
		# 2. 检查任务队列里排队的任务
		for task in waiter.task_queue:
			if task.type == task_type and task.table_node == target_node:
				return true
	return false

# 在 WaiterSystem.gd 中添加派发外卖任务的函数
func dispatch_takeaway_delivery_task(order) -> bool:
	# 1. 寻找空闲服务员
	var waiter = _find_nearest_available_waiter()
	if not waiter: return false
	
	# 2. 确定目标位置（外卖柜台旁边）
	# order.takeaway_counter_node 应该是 Node3D
	var target_pos = find_empty_spot_near_table(waiter.id, order.takeaway_counter_node)
	
	# 3. 创建任务
	var task = Task.new()
	task.type = TaskType.DELIVERY_TAKEAWAY
	task.priority = TaskType.PICKUP # 优先级等同于取菜，较高
	task.data = {"order": order}
	task.table_node = order.takeaway_counter_node # 记录柜台节点
	task.target_pos = target_pos
	
	return assign_task_to_waiter(waiter.id, task)

# 在 WaiterSystem.gd 中添加执行外卖配送的函数
func _execute_delivery_takeaway(waiter: WaiterRuntimeData):
	waiter.state = WaiterState.MOVING # 移动状态
	
	# 到达目标后的逻辑在 _on_waiter_arrived 中处理，
	# 但为了简单，我们可以假设到达后直接结算。
	# 这里我们不需要 await 动画，因为 _start_move_to_position 会处理移动。
	# 我们只需要确保到达时执行结算。
	
	# 由于 _execute_current_task 是在到达后调用的，
	# 这里实际上是到达柜台后的操作。
	
	var order = waiter.current_task.data.get("order")
	var counter_node = waiter.current_task.table_node
	
	if not order or not is_instance_valid(counter_node):
		_complete_current_task(waiter)
		return
		
	# 1. 计算总价
	var total_cost = 0.0
	for dish_id in order.dishes:
		total_cost += fc.dish_data_manager.get_dish_price(dish_id)
		
	# 2. 结算收入
	fc.playerData.money += total_cost
	fc.playerData.pay_today += total_cost
	
	# 3. 记录销量（只记录主菜）
	for dish_id in order.dishes:
		if fc.dish_data_manager.get_dish_category(dish_id) == "主菜":
			fc.playerData.record_dish_sale(dish_id)
			
	# 4. 播放音效
	fc.play_se_fx("cash")
	
	# 5. 隐藏外卖柜台的“接单”图标
	manager.furniture_system.hide_talk_icon(counter_node)
	
	# 6. 完成任务
	change_cloth(waiter, "待机")
	_complete_current_task(waiter)
