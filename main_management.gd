# main_management.gd (即 fuwusheng.gd)
extends Control

# --- 节点引用 ---
@onready var waiter_grid_container: GridContainer = $Panel/base/GridContainer
@onready var show_3dmap_node: Control = $Panel/base/show3Dmap # 这是 show3dmap.gd

@onready var status_label: Label = $Panel/base/AutoSizeLabel

# --- 场景与资源预加载 ---
const WAITER_BUTTON_SCENE = preload("res://sc/waiter_anpai.tscn")
const TIPS_SCENE = preload("res://sc/waiter_show_nengli.tscn")
const WARNING_ICON_SCENE = preload("res://sc/warning_icon_3d.tscn")

# --- 服务生颜色配置 ---
var WAITER_COLORS: Array[Color] = [
	Color.RED, Color.DARK_ORCHID, Color.CADET_BLUE, Color.BURLYWOOD,
	Color.MEDIUM_PURPLE, Color.CYAN, Color.ORANGE, Color.PALE_GREEN
]

# --- 状态管理 ---
enum State {
	IDLE,               # 空闲状态
	PLACING_WAITER,     # 正在布置服务生
	ASSIGNING_WAITER    # 正在给家具分配服务生
}

var current_state: State = State.IDLE
var current_waiter_data: WaiterData = null
var selected_furniture_root: Node3D = null
var waiter_manager = null
var active_warning_icons: Array[Node3D] = []
var tips_instance: Control = null

func _ready():
	fc._ensure_window_centered()
	fc.playerData.step="第7步"
	
	waiter_manager = preload("res://sc/WaiterGenerator.gd").new()
	add_child(waiter_manager)
	
	# ========================================================
	# 【关键修复】初始化顺序
	# ========================================================
	var randmap_manager = show_3dmap_node.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap")
	
	if randmap_manager:
		# 1. 初始化管理器 (但不自动加载任何东西)
		randmap_manager.setup_for_context(RandmapManager.Context.BUZHI)
		
		# 2. 先加载地图形状 (MapSystem)
		if randmap_manager.map_system:
			randmap_manager.map_system.load_map()
	
		# 3. 【核心】调整视口和相机 (这会移动 GridMap 节点)
	show_3dmap_node.closeBase()
	if show_3dmap_node.has_method("set_viewport"):
		show_3dmap_node.set_viewport()
	elif show_3dmap_node.has_method("set_viewpot"):
		show_3dmap_node.set_viewpot()
		
# 4. 【核心等待】必须等待两帧，确保 GridMap 的 global_position 已经更新到位
	# 一帧可能不够，两帧更稳妥
	await get_tree().process_frame
	await get_tree().process_frame
	# ========================================================
	# 【核心修复】严格的初始化顺序
	# 5. 现在 GridMap 位置定死了，再去加载家具和服务生
	if randmap_manager:
		# 先加载家具 (因为服务生依赖家具位置检查)
		if randmap_manager.furniture_system:
			#print("调试：开始手动加载家具...")
			randmap_manager.furniture_system.load_furniture_from_global()
			
		# 再加载服务生
		if randmap_manager.waiter_system:
			#print("调试：开始手动加载服务生...")
			randmap_manager.waiter_system.load_waiters_from_global()
	
	# 6. 最后加载 UI 和 Tips
	_setup_tips()
	_load_waiter_buttons() # 按钮状态依赖于 WaiterSystem 的数据，所以必须最后加载
	_update_deployment_status_UI()
		
	GuiTransitions.show("peizhi")
	await GuiTransitions.show_completed

# --- UI 初始化与加载 (保持不变) ---
func _setup_tips():
	if not TIPS_SCENE: return
	tips_instance = TIPS_SCENE.instantiate()
	add_child(tips_instance)
	tips_instance.visible = false
	tips_instance.z_index = 200

func _load_waiter_buttons():
	for child in waiter_grid_container.get_children():
		child.queue_free()
		
	var hired_waiters = fc.playerData.waiters
	if not hired_waiters is Array: return

	for i in range(hired_waiters.size()):
		var waiter_data = hired_waiters[i]
		if not waiter_data: continue
			
		var button_instance = WAITER_BUTTON_SCENE.instantiate()
		var color_index = i % WAITER_COLORS.size()
		var dizuo_node = button_instance.get_node_or_null("dizuo")
		if dizuo_node:
			dizuo_node.modulate = WAITER_COLORS[color_index]
			
		button_instance.set_meta("waiter_data", waiter_data)
		button_instance.set_meta("color_index", color_index)
		button_instance.get_node("name").text = waiter_data.name
		
		var pic = "res://pic/npc/fuwuyuan/waiter_type"+str(fc.playerData.clothtype)+"_" + ("man" if waiter_data.gender == "male" else "woman") + ".png"
		button_instance.get_node("npc").texture = load(pic)
		
		button_instance.pressed.connect(_on_waiter_button_pressed.bind(button_instance))
		button_instance.mouse_entered.connect(_on_waiter_button_hover.bind(button_instance, true))
		button_instance.mouse_exited.connect(_on_waiter_button_hover.bind(button_instance, false))

		waiter_grid_container.add_child(button_instance)

	_refresh_waiter_button_states()

# --- 核心输入处理 ---
func _input(event):
	match current_state:
		State.PLACING_WAITER:
			_handle_placing_waiter_input(event)
		State.ASSIGNING_WAITER:
			_handle_assigning_waiter_input(event)
		State.IDLE:
			_handle_idle_input(event)

# --- 状态处理 ---

# 1. 布置服务生
func _handle_placing_waiter_input(event):
	if event is InputEventMouseMotion:
		var mouse_pos = get_global_mouse_position()
		var color_index = _get_waiter_color_index(current_waiter_data)
		var waiter_color = WAITER_COLORS[color_index]
		# show3dmap 已经适配了 WaiterSystem
		show_3dmap_node.update_waiter_placement_ghost(mouse_pos, current_waiter_data, waiter_color)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var success = show_3dmap_node.try_place_current_waiter(get_global_mouse_position(), current_waiter_data)
			if success:
				$Panel/base/tips2.visible=false
				current_state = State.IDLE
				current_waiter_data = null
				show_3dmap_node.hide_ghost()
				_refresh_waiter_button_states()
				_update_deployment_status_UI()
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_current_action()

# 2. 分配服务生 (UI操作，无需输入检测)
@warning_ignore("unused_parameter")
func _handle_assigning_waiter_input(event):
	pass

# 3. 空闲 (拾取服务生 / 选中家具)
func _handle_idle_input(event):
	if event is InputEventMouseMotion:
		var mouse_pos = get_global_mouse_position()
		show_3dmap_node.update_hover_highlight(mouse_pos)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_global_mouse_position()
			
			# A. 尝试拾取服务生 (show3dmap -> WaiterSystem.remove_waiter_at)
			var picked_waiter = show_3dmap_node.try_pick_up_waiter(mouse_pos)
			if picked_waiter:
				_start_moving_waiter(picked_waiter)
				_update_deployment_status_UI() # 拾取后更新状态
				return
				
			# B. 尝试选中家具 (show3dmap -> FurnitureSystem.get_furniture_at -> select_furniture_at)
			# 注意：show3dmap 里的 select_furniture_at 只是高亮并返回数据，不删除
			var selected_furniture_data = show_3dmap_node.select_furniture_at(mouse_pos)
			if not selected_furniture_data.is_empty():
				_handle_furniture_selection(selected_furniture_data)
			else:
				show_3dmap_node._clear_highlight()

func _handle_furniture_selection(furniture_data: Dictionary):
	var limit_type = furniture_data.get("limit", "")
	if limit_type != "无":
		if limit_type != "迎客位" and limit_type != "传菜口":
			_start_assigning_waiter(furniture_data)
		else:
			var message = "【" + limit_type + "】不需要分配固定服务员。"
			if limit_type == "迎客位": message += "空闲服务员会自动接待客人。"
			elif limit_type == "传菜口": message += "服务员会自动传菜。"
			fc.show_msg(message)
			await fc.endshow
	else:
		fc.show_msg("这个家具不需要分配服务生。")
		await fc.endshow

# --- 按钮响应 ---

func _on_waiter_button_pressed(button: Button):
	match current_state:
		State.ASSIGNING_WAITER:
			_perform_waiter_assignment(button)
		State.IDLE:
			_start_placing_waiter(button)

func _on_waiter_button_hover(button: Button, is_hovering: bool):
	if is_hovering:
		var waiter_data = button.get_meta("waiter_data")
		var mouse_pos = get_global_mouse_position()
		_show_waiter_tips(waiter_data, mouse_pos)
	else:
		_hide_tips()

# --- 动作逻辑 ---

func _start_placing_waiter(button: Button):
	current_state = State.PLACING_WAITER
	current_waiter_data = button.get_meta("waiter_data")
	$Panel/base/tips2.visible=true
	_refresh_waiter_button_states()

func _start_moving_waiter(waiter_data: WaiterData):
	current_state = State.PLACING_WAITER
	current_waiter_data = waiter_data
	_refresh_waiter_button_states()

func _start_assigning_waiter(furniture_data: Dictionary):
	current_state = State.ASSIGNING_WAITER
	selected_furniture_root = furniture_data.get("node_ref")
	
	var limit_type = furniture_data.get("limit", "")
	$Panel/base/tips1.text = "请选择一个服务员分配给【" + limit_type + "】"
	$Panel/base/tips1.visible = true
	
	_refresh_waiter_button_states()

func _perform_waiter_assignment(button: Button):
	if not selected_furniture_root: return
		
	var waiter_data = button.get_meta("waiter_data")
	var color_index = button.get_meta("color_index")
	var waiter_color = WAITER_COLORS[color_index]
	
	# 【核心修复】调用 FurnitureSystem 的分配接口
	# 由于家具数据归 FurnitureSystem 管，绑定关系也存在那边
	var randmap_manager = show_3dmap_node.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap")
	if randmap_manager and randmap_manager.furniture_system:
		# 我们需要在 FurnitureSystem 增加 assign_waiter 方法
		# 或者直接操作 furniture_waiter_assignment 字典 (不推荐)
		# 建议在 FurnitureSystem 加一个 public 方法
		_assign_waiter_via_system(randmap_manager.furniture_system, selected_furniture_root, waiter_data.id, waiter_color)
		
	$Panel/base/tips1.visible=false
	_cancel_current_action()

func _assign_waiter_via_system(sys, node_ref, w_id, color):
	# 这个函数需要你在 FurnitureSystem.gd 中实现
	# furniture_waiter_assignment[node_ref] = { "waiter_id": w_id, "color": color }
	# 并在视觉上给家具上色
	if sys.has_method("assign_waiter_to_furniture"):
		sys.assign_waiter_to_furniture(node_ref, w_id, color)
	else:
		print("FurnitureSystem 缺少 assign_waiter_to_furniture 方法")

# --- 辅助与刷新 ---

func _cancel_current_action():
	current_state = State.IDLE
	current_waiter_data = null
	selected_furniture_root = null
	
	show_3dmap_node.hide_ghost()
	_hide_tips()
	show_3dmap_node._clear_highlight()
	
	_refresh_waiter_button_states()
	_update_deployment_status_UI()

func _show_waiter_tips(waiter_data: WaiterData, mouse_pos: Vector2):
	if not tips_instance: return
	
	var id = 0
	for skill in waiter_data.skills:
		var level = waiter_data.skills[skill]
		var skill_name = waiter_manager.SKILL_NAMES[int(skill)]
		if id < tips_instance.get_node("checktag").get_child_count():
			var tag = tips_instance.get_node("checktag").get_child(id)
			tag.get_node("type").text = skill_name
			tag.get_node("lv").set_rating(float(level * 0.5))
		id += 1
	
	# 位置计算
	var tips_size = tips_instance.size
	var screen_size = get_viewport().get_visible_rect().size
	var pos = mouse_pos + Vector2(20, 20)
	if pos.x + tips_size.x > screen_size.x: pos.x = mouse_pos.x - tips_size.x - 20
	if pos.y + tips_size.y > screen_size.y: pos.y = mouse_pos.y - tips_size.y - 20
	tips_instance.global_position = pos
	tips_instance.visible = true

func _hide_tips():
	if tips_instance: tips_instance.visible = false

func _get_waiter_color_index(waiter_data: WaiterData) -> int:
	var hired_waiters = fc.playerData.waiters
	for i in range(hired_waiters.size()):
		if hired_waiters[i].id == waiter_data.id:
			return i % WAITER_COLORS.size()
	return 0

# 刷新按钮状态
func _refresh_waiter_button_states():
	if not waiter_grid_container: return
	
	var randmap_manager = show_3dmap_node.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap")
	if not randmap_manager: return
	
	var furniture_sys = randmap_manager.furniture_system
	var waiter_sys = randmap_manager.waiter_system
	
	# 获取当前家具绑定的 waiter_id
	var assigned_id = ""
	if selected_furniture_root and furniture_sys:
		assigned_id = furniture_sys.get_assigned_waiter_id(selected_furniture_root)
	
	for button in waiter_grid_container.get_children():
		var waiter_data = button.get_meta("waiter_data")
		var waiter_id = waiter_data.id
		var dizuo_node = button.get_node_or_null("dizuo")
		var gouzi = button.get_node_or_null("gou")
		
		# 1. 检查是否放置 (WaiterSystem)
		var is_placed = waiter_sys.is_waiter_placed(waiter_id) if waiter_sys else false
		
		# 2. 检查分配
		var is_assigned_to_current = (waiter_id == assigned_id)
		
		match current_state:
			State.PLACING_WAITER:
				button.disabled = true
				if dizuo_node: dizuo_node.modulate = Color.GRAY
				
			State.ASSIGNING_WAITER:
				button.disabled = false
				if gouzi: gouzi.visible = false
				if dizuo_node:
					var color_idx = button.get_meta("color_index")
					var base_color = WAITER_COLORS[color_idx]
					dizuo_node.modulate = base_color.lightened(0.5) if is_assigned_to_current else base_color
					
			State.IDLE:
				button.disabled = is_placed
				if dizuo_node:
					var color_idx = button.get_meta("color_index")
					dizuo_node.modulate = WAITER_COLORS[color_idx]
				if gouzi: gouzi.visible = is_placed

# 保存与退出
func _on_yes_pressed():
	var randmap_manager = show_3dmap_node.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap")
	if not randmap_manager: return
	
	# 【核心修复】获取状态需要同时查询两个系统
	var status = _get_deployment_status(randmap_manager)
	
	if status.waiters.unplaced > 0:
		fc.show_msg("还有未配置到饭店里的服务员，请检查。")
		return
	if not status.furniture.unassigned_furniture_data.is_empty():
		fc.show_msg("还有未配置的家具，请检查。")
		return
	
	
	# 保存数据
	if randmap_manager.furniture_system: randmap_manager.furniture_system.save_furniture()
	if randmap_manager.waiter_system: randmap_manager.waiter_system.save_waiters_to_global()
	
	fc.save_game(fc.save_num)
	
	if fc.playerData.from_main_game==true:
		get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
	else:
		get_tree().change_scene_to_file("res://sc/management_ui.tscn")

# 统计状态 (替换原来的 get_deployment_status)
func _get_deployment_status(manager) -> Dictionary:
	var status = {
		"waiters": {"total": 0, "placed": 0, "unplaced": 0},
		"furniture": {"unassigned_furniture_data": []}
	}
	
	var hired = fc.playerData.waiters
	status.waiters.total = hired.size()
	
	if manager.waiter_system:
		for w in hired:
			if manager.waiter_system.is_waiter_placed(w.id):
				status.waiters.placed += 1
			else:
				status.waiters.unplaced += 1
	
	if manager.furniture_system:
		for item in manager.furniture_system.placed_furniture_data:
			var limit = item.get("limit", "无")
			# 排除无限制、传菜口、迎客位
			if limit != "无" and limit != "传菜口" and limit != "迎客位":
				var assigned_id = manager.furniture_system.get_assigned_waiter_id(item["node_ref"])
				if assigned_id == "":
					status.furniture.unassigned_furniture_data.append(item)
					
	return status

# UI 更新
func _update_deployment_status_UI():
	var randmap_manager = show_3dmap_node.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap")
	if not randmap_manager or not status_label: return
	
	_clear_all_warning_icons()
	var status = _get_deployment_status(randmap_manager)
	
	var w_text = "服务员: %d/%d 已布置 (未布置: %d)" % [status.waiters.placed, status.waiters.total, status.waiters.unplaced]
	var f_text = ""
	
	if status.furniture.unassigned_furniture_data.is_empty():
		f_text = "所有需要服务员的家具均已分配。"
	else:
		var names = []
		for item in status.furniture.unassigned_furniture_data:
			names.append(item["limit"])
			var node = item["node_ref"]
			if is_instance_valid(node):
				var icon = WARNING_ICON_SCENE.instantiate()
				node.add_child(icon)
				icon.position.y += 2.0
				active_warning_icons.append(icon)
		f_text = "⚠️ 警告：以下家具未分配服务员 -> " + ", ".join(names)
		
	status_label.text = w_text + "\n" + f_text

func _clear_all_warning_icons():
	for icon in active_warning_icons:
		if is_instance_valid(icon): icon.queue_free()
	active_warning_icons.clear()
