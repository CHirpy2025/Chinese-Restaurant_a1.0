# InteractionSystem.gd
extends Node
class_name InteractionSystem

var manager: RandmapManager
var floating_tip: Control = null
var default_tip: Control = null
var current_hovered_table: Node3D = null

var talbe_info = preload("res://sc/show_guest_data.tscn")
var normal_info = preload("res://sc/show_normal_info.tscn")

func setup(randmap_manager: RandmapManager):
	manager = randmap_manager
	_init_ui()

func _init_ui():
	call_deferred("_create_ui_elements")

func _create_ui_elements():
	# 创建CanvasLayer确保UI在最上层，独立于3D场景
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # 最高层
	canvas_layer.name = "InteractionUI"
	
	# 将CanvasLayer添加到主场景
	var main_scene = manager.get_tree().current_scene
	if main_scene:
		main_scene.add_child(canvas_layer)
	
	# 创建默认提示面板
	default_tip = normal_info.instantiate()
	default_tip.z_index = 1000
	canvas_layer.add_child(default_tip)
	default_tip.hide()

	# 创建客人详情面板
	var guest_tip_scene = load("res://sc/show_guest_data.tscn")
	if guest_tip_scene:
		floating_tip = guest_tip_scene.instantiate()
		floating_tip.z_index = 1000
		canvas_layer.add_child(floating_tip)
		floating_tip.hide()





# InteractionSystem.gd

func _process(_delta):
	# 获取视口尺寸（即可用屏幕空间）
	var viewport = get_viewport()
	if not viewport: return
	
	var screen_size = viewport.get_visible_rect().size
	var mouse_pos = viewport.get_mouse_position()
	var offset = Vector2(20, 20) # 鼠标偏移量
	
	# --- 更新默认提示面板 ---
	if default_tip and default_tip.visible:
		var panel_size = default_tip.size
		var target_pos = mouse_pos + offset
		
		# X轴边界检测
		if target_pos.x + panel_size.x > screen_size.x:
			# 如果右边超出了，改到鼠标左边显示
			target_pos.x = mouse_pos.x - panel_size.x - offset.x
			
		# Y轴边界检测
		if target_pos.y + panel_size.y > screen_size.y:
			# 如果下边超出了，改到鼠标上边显示
			target_pos.y = mouse_pos.y - panel_size.y - offset.y
			
		# 确保不会超出左上边界 (小于0)
		target_pos.x = max(0, target_pos.x)
		target_pos.y = max(0, target_pos.y)
		
		default_tip.position = target_pos
	
	# --- 更新客人详情面板 (同样逻辑) ---
	if floating_tip and floating_tip.visible:
		var panel_size = floating_tip.size
		var target_pos = mouse_pos + offset
		
		if target_pos.x + panel_size.x > screen_size.x:
			target_pos.x = mouse_pos.x - panel_size.x - offset.x
			
		if target_pos.y + panel_size.y > screen_size.y:
			target_pos.y = mouse_pos.y - panel_size.y - offset.y
			
		target_pos.x = max(0, target_pos.x)
		target_pos.y = max(0, target_pos.y)
		
		floating_tip.position = target_pos



func add_furniture_interaction(furniture_node: Node3D, furniture_data: Dictionary):
	if not furniture_node:
		return
	
	# 查找现有的Area3D
	var area3d = _find_area3d(furniture_node)
	if not area3d:
		print("警告: 家具节点未找到Area3D: ", furniture_node.name)
		return
	

	# 连接信号
	if not area3d.mouse_entered.is_connected(_on_furniture_mouse_entered):
		area3d.mouse_entered.connect(_on_furniture_mouse_entered.bind(furniture_node, furniture_data))
	if not area3d.mouse_exited.is_connected(_on_furniture_mouse_exited):
		area3d.mouse_exited.connect(_on_furniture_mouse_exited.bind(furniture_node, furniture_data))

# 递归查找Area3D
func _find_area3d(node: Node3D) -> Area3D:
	# 递归查找Area3D
	for child in node.get_children():
		if child is Area3D:
			return child
		var result = _find_area3d(child)
		if result:
			return result
	return null

# 鼠标进入桌子
# 修改鼠标进入处理
func _on_furniture_mouse_entered(furniture_node: Node3D, furniture_data: Dictionary):
	current_hovered_table = furniture_node
	var limit_type = furniture_data.get("limit", "无")
	
	if limit_type == "桌椅":
		# 桌椅类家具的特殊处理
		var occupied_customers = _get_occupied_customers(furniture_node)
		if occupied_customers.size() > 0:
			_show_guest_data(occupied_customers)
		else:
			_show_default_tip(furniture_node, furniture_data)
	else:
		# 非桌椅类家具，都显示normal_info
		_show_default_tip(furniture_node, furniture_data)

# 修改鼠标离开处理
func _on_furniture_mouse_exited(_furniture_node: Node3D, _furniture_data: Dictionary):
	current_hovered_table = null
	_hide_all_tips()

# 获取桌子上的客人信息
func _get_occupied_customers(table_node: Node3D) -> Array:
	if table_node.has_meta("occupied_customers"):
		return table_node.get_meta("occupied_customers")
	return []

# 显示客人详情面板
# InteractionSystem.gd

# InteractionSystem.gd 

# InteractionSystem.gd

func _show_guest_data(occupied_customers: Array):
	if not floating_tip:
		return
	
	if default_tip: default_tip.hide()
	
	var detailed_customers = []
	
	for customer_info in occupied_customers:
		var customer_id = customer_info.get("customer_id", "")
		var customer_data: CustomerData = null
		
		# 1. 查找对应的客人数据对象
		for c in fc.playerData.waiting_customers:
			if c.id == customer_id:
				customer_data = c
				break
		
		if customer_data:
			# --- 2. 解析评价数据 ---
			var reviews = customer_data.get("review_result")
			
			# --- 3. 获取点菜列表 ---
			var dish_names = []
			if customer_data.has_meta("order_result"):
				var order_res = customer_data.get_meta("order_result")
				# 从 OrderResult 的 selected_dishes (ID数组) 转换为菜名
				if order_res and order_res.get("selected_dishes"):
					for dish_id in order_res.selected_dishes:
						var dish_info = fc.dish_data_manager.get_dish_full_info(dish_id)
						dish_names.append(dish_info.get("name", "未知菜品"))

			# --- 4. 构建传输字典 ---
			detailed_customers.append({
				"id": customer_data.id,
				"type": customer_data.type,
				"status": _get_status_text(customer_data.status),
				
				# 基础属性
				"satisfaction": customer_data.satisfaction,   # 满意度
				"sex_age_list": customer_data.sex_age_list,   # 性别/年龄/持有金钱列表
				"order_list": dish_names,                     # 已点的菜品名数组
				
				# 评价系统数据
				"reviews": {
					"env": reviews.get("environment", {"text": "等待观察...", "level": 0}),
					"service": reviews.get("service", {"text": "等待服务...", "level": 0}),
					"taste": reviews.get("taste", {"text": "等待品尝...", "level": 0}),
					"variety": reviews.get("variety", {"text": "等待下单...", "level": 0}),
					"price": reviews.get("price", {"text": "等待结账...", "level": 0}),
					"wait_time": reviews.get("wait_time", {"text": "希望快点上菜...", "level": 0})
				}
			})
	
	# 发送给 UI 脚本 (show_guest_data.gd)
	if floating_tip.has_method("show_msg"):
		floating_tip.show_msg(detailed_customers)
	
	floating_tip.show()

# 辅助函数：转换状态文本
func _get_status_text(status: String) -> String:
	match status:
		"waiting": return "等待中"
		"being_greeted": return "接待中"
		"seated": return "已入座"
		"ordering": return "点餐中"
		"waiting_pay": return "待付款"
		"eating": return "用餐中"
		_: return "等餐中"


func _show_default_tip(furniture_node: Node3D, furniture_data: Dictionary):
	if not default_tip:
		return
	
	# 隐藏客人面板
	if floating_tip:
		floating_tip.hide()
	
	# 显示家具信息
	if default_tip.has_method("show_info"):
		default_tip.show_info(furniture_data.get("itemtype", "未知"))
	
	# 【新增】如果是厕所类型，显示cesuo节点和清洁度
	if furniture_data.get("limit") == "厕所":
		_show_toilet_info(furniture_node, furniture_data)
	else:
		_hide_toilet_info()
	
	default_tip.show()

# 【新增】显示厕所信息
func _show_toilet_info(furniture_node: Node3D, furniture_data: Dictionary):
	if not default_tip:
		return
	
	# 查找cesuo节点（在normal_info预制体中）
	var cesuo_node = default_tip.get_node_or_null("cesuo")
	if cesuo_node:
		cesuo_node.show()  # 显示cesuo节点
		
		# 查找bar节点并设置清洁度
		var bar_node = cesuo_node.get_node_or_null("bar")
		if bar_node and bar_node.has_method("set_value"):
			var cleanliness = furniture_data.get("cleanliness", 100.0)
			bar_node.value = cleanliness

# 【新增】隐藏厕所信息
func _hide_toilet_info():
	if not default_tip:
		return
	
	var cesuo_node = default_tip.get_node_or_null("cesuo")
	if cesuo_node:
		cesuo_node.hide()



# 在InteractionSystem中添加公共方法
func update_furniture_tip_display(furniture_node: Node3D):
	# 检查是否正在显示这个家具的提示
	if current_hovered_table == furniture_node and default_tip and default_tip.visible:
		# 重新获取家具数据并更新显示
		var furniture_data = manager.furniture_system.get_furniture_data_by_node(furniture_node)
		if not furniture_data.is_empty():
			_show_default_tip(furniture_node, furniture_data)


	




# 隐藏所有提示
func _hide_all_tips():
	if default_tip:
		default_tip.hide()
	if floating_tip:
		floating_tip.hide()

# 清理资源
func cleanup():
	if default_tip:
		default_tip.queue_free()
	if floating_tip:
		floating_tip.queue_free()
