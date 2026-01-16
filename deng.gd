# main_game_sc.gd
extends Node3D


# --- 节点引用 ---
@onready var camera = $Camera3D
@onready var world_env = $WorldEnvironment
@onready var sun_light = $DirectionalLight3D

@onready var maplight = $maplight as OmniLight3D  # 【修改】明确类型

@onready var map_holder = $MapHolder

# --- 窗口穿透的标记点引用 ---
@onready var marker_tl = $MarkerTL
@onready var marker_tr = $MarkerTR
@onready var marker_br = $MarkerBR
@onready var marker_bl = $MarkerBL

# --- 日夜循环配置 ---
var day_sun_color = Color("fdfcdc")
var day_sun_energy = 1.0
var day_ambient_color = Color("e8e4d9")
var day_ambient_energy = 0.6

var night_sun_color = Color("cad2ef")
var night_sun_energy = 0.1
var night_ambient_color = Color("a6e0fd")
var night_ambient_energy = 0.3

# 【新增】地图灯光配置 - OmniLight3D专用
var maplight_day_color = Color("ffffff")  # 白天颜色（白色）
var maplight_day_energy = 0.0  # 白天关闭
var maplight_night_color = Color("ffd1af")  # 夜晚暖黄色（类似灯泡）
var maplight_night_energy = 3.0  # 夜晚亮度（根据场景调整）

# 【新增】OmniLight3D特定配置
var maplight_range = 20.0  # 灯光照射范围
var maplight_attenuation = 1.0  # 衰减系数（0.5-1.5之间，数值越小衰减越快）
var maplight_shadow_enabled = false  # 是否启用阴影

# --- 状态变量 ---
var is_night = false
var dragging = false
var drag_start_position = Vector2()

# 【修改】改为三个UI窗口实例的数组
var ui_windows: Array[Window] = []
# 【修改】改为三个拖动状态的数组
var is_ui_draggings: Array[bool] = []
# 【修复】统一使用Vector2i类型
var ui_drag_start_poses: Array[Vector2i] = []
var ui_window_start_poses: Array[Vector2i] = []

# 【新增】UI场景配置 - 使用预加载避免路径问题
var ui_scenes: Array[PackedScene] = []
# 预加载场景路径（您需要创建这些场景文件）
var UI_SCENE_PATH_1 = "res://sc/main_info_ui.tscn"
var UI_SCENE_PATH_2 = "res://sc/financial_situation.tscn"  # 请确保这个场景存在
var UI_SCENE_PATH_3 = "res://sc/business_info.tscn"   # 请确保这个场景存在
var UI_SCENE_PATH_4 = "res://sc/button_show_ui.tscn"   # 请确保这个场景存在

@export var AUTO_SAVE_INTERVAL: float = 60.0  # 自动保存间隔（秒）
var auto_save_timer: Timer
# =================================================================
# 【新增】时间流动系统 - 配置与状态
# =================================================================

# --- 时间流速配置 (单位：现实秒 / 游戏内1分钟) ---
@export var BASE_SECONDS_PER_MINUTE: float = 0.5       # 基础流速：0.5秒=游戏1分钟
@export var PEAK_SECONDS_PER_MINUTE: float = 2        # 高峰期流速：2秒=游戏1分钟 (最慢)
@export var SUB_PEAK_SECONDS_PER_MINUTE: float = 1    # 次高峰期流速：1秒=游戏1分钟 (次慢)

# --- 时间系统状态 ---
var is_time_paused: bool = false
var current_game_minutes: int = 0 # 从00:00开始计算的总分钟数
var time_timer: Timer
var main_info_ui_window: Window # 用于引用第一个UI窗口


# main_game_sc.gd 的 _ready() 函数 (终极 idle_frame 版)

func _ready():
	fc.playerData.now_time="18:26"
	
	
	
	fc.playerData.from_main_game = true  # 标记来自main_game_sc


	# 1. 基础窗口设置：透明、无边框、置顶
	get_window().transparent_bg = true
	get_window().borderless = true
	get_window().always_on_top = true
	get_window().unfocusable = true
	
	# 2. 【关键修复】立即将窗口移动到右下角，不等待
	move_window_to_bottom_right_sync()
	

	
	# 3. 【新增】生成地图
	var randmap = map_holder.get_node("Randmap")
	var data = fc.get_row_from_csv_data("walldoorData","ID",fc.playerData.floor_id)
	randmap.replace_map_tiles_with(data["zhuan_id"])

	# 4. 【关键新增】等待一帧，确保地图数据更新后，设置自适应相机
	await get_tree().process_frame
	_setup_camera_for_map()

	# 5. 初始化灯光状态（包括maplight）
	apply_day_state(true)

	# 6. 【关键】等待Randmap加载完毕后，修正所有物体的旋转
	await get_tree().process_frame
	_correct_all_rotations()
	
	# 7. 【关键】等待一帧后，设置窗口穿透，确保地图已渲染
	await get_tree().process_frame
	update_mouse_passthrough()
	
	# 8. 【修改】显示三个信息UI窗口
	await setup_all_ui_windows()
	
	#print("✅ 场景和UI全部加载完成。")

	# 【新增】所有UI就绪后，启动时间流动系统
	_setup_time_system()
	_start_time_flow()
	fc.save_game(fc.save_num)
	
	get_window().close_requested.connect(_on_window_close_requested)
	# 初始化自动保存系统
	_setup_auto_save()


# --- UI窗口管理 (多窗口版) ---
# 设置所有UI窗口
# --- UI窗口管理 (多窗口版) ---
# 设置所有UI窗口
func setup_all_ui_windows():
	#print("开始创建所有UI窗口...")
	
	# 初始化数组
	ui_windows = []
	is_ui_draggings = []
	ui_drag_start_poses = []
	ui_window_start_poses = []
	
	# 预加载场景
	ui_scenes = []
	
	# 【修改】尝试加载四个场景
	var scene_paths = [UI_SCENE_PATH_1, UI_SCENE_PATH_2, UI_SCENE_PATH_3, UI_SCENE_PATH_4]
	
	for path in scene_paths:
		if ResourceLoader.exists(path):
			ui_scenes.append(load(path))
		else:
			print("⚠️ 场景文件不存在: ", path)
			ui_scenes.append(null)  # 添加null作为占位符
	
	# 【修改】创建四个UI窗口
	for i in range(scene_paths.size()): # 使用 scene_paths.size() 更灵活
		var success = await setup_single_ui_window(i)
		if not success:
			print("❌ 创建第", i+1, "个UI窗口失败")
			continue
	
	# 等待所有窗口初始化完成
	await get_tree().process_frame
	
	# 排列前三个窗口的位置
	arrange_ui_windows_horizontal()
	
	# 【关键新增】为第四个窗口设置特殊的位置和拖动
	if ui_windows.size() > 3:
		_arrange_special_ui_window() # 定位第四个窗口
		_setup_special_window_dragging(ui_windows[3], 3) # 设置特殊拖动
	
	print("✅ 所有UI窗口创建完成")


# 设置单个UI窗口
# 设置单个UI窗口
func setup_single_ui_window(index: int) -> bool:
	print("创建第", index+1, "个UI窗口...")
	
	# 检查是否有预加载的场景
	if index >= ui_scenes.size() or ui_scenes[index] == null:
		print("❌ 第", index+1, "个UI场景未预加载或为空")
		return await _create_placeholder_window(index)
	
	var ui_scene = ui_scenes[index]
	var ui_instance = ui_scene.instantiate()
	
	# 设置为无边框窗口
	ui_instance.borderless = true
	ui_instance.transparent = false
	ui_instance.always_on_top = true
	ui_instance.unfocusable = false
	ui_instance.title = "UI窗口" + str(index + 1)
	
	# 添加到场景树
	get_tree().root.add_child(ui_instance)
	
	# 等待窗口初始化
	await get_tree().process_frame
	
	# 【关键修改】第四个窗口（索引为3）不使用通用拖动设置
	if index != 3:
		_setup_window_dragging(ui_instance, index)
	
	# 添加到数组
	ui_windows.append(ui_instance)
	is_ui_draggings.append(false)
	ui_drag_start_poses.append(Vector2i())
	ui_window_start_poses.append(Vector2i())
	
	# 显示窗口
	ui_instance.show()
	
	#print("✅ 第", index+1, "个UI窗口已创建")
	return true


# 创建占位窗口（用于测试）
func _create_placeholder_window(index: int) -> bool:
	#print("创建第", index+1, "个占位窗口...")
	
	var placeholder_window = Window.new()
	placeholder_window.borderless = true
	placeholder_window.transparent = false
	placeholder_window.always_on_top = true
	placeholder_window.unfocusable = false
	placeholder_window.title = "占位窗口" + str(index + 1)
	placeholder_window.size = Vector2i(400, 300)  # 默认大小
	
	# 添加一些内容以便识别
	var label = Label.new()
	label.text = "这是第" + str(index + 1) + "个UI窗口\n场景文件未找到"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = placeholder_window.size
	placeholder_window.add_child(label)
	
	get_tree().root.add_child(placeholder_window)
	await get_tree().process_frame
	
	# 设置拖动功能
	_setup_window_dragging(placeholder_window, index)
	
	# 添加到数组
	ui_windows.append(placeholder_window)
	is_ui_draggings.append(false)
	# 【修复】统一使用Vector2i类型
	ui_drag_start_poses.append(Vector2i())
	ui_window_start_poses.append(Vector2i())
	
	placeholder_window.show()
	#print("✅ 第", index+1, "个占位窗口已创建")
	return true

# 【新增】水平排列所有UI窗口的位置（从左到右依次排列）
# 【修复】水平排列所有UI窗口的位置
func arrange_ui_windows_horizontal():
	# 获取屏幕信息
	var main_window = get_window()
	var screen_id = DisplayServer.window_get_current_screen(main_window.get_window_id())
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
	
	# 窗口之间的间距
	var margin_bottom = 100  # 距离底部边缘的距离（给3D窗口留出空间）
	var margin_between = 20  # 窗口之间的水平间距
	
	# 计算总宽度
	var total_width = 0
	var window_sizes = []
	
	for i in range(ui_windows.size()):
		var window_instance = ui_windows[i]
		if not window_instance:
			continue
			
		# 获取窗口大小（如果没有设置，使用默认值）
		var win_size = window_instance.size
		if win_size.x == 0 or win_size.y == 0:
			win_size = Vector2i(400, 300)  # 默认大小
		
		window_sizes.append(win_size)
		total_width += win_size.x
		
		# 如果不是最后一个窗口，加上间距
		if i < ui_windows.size() - 1:
			total_width += margin_between
	
	# 如果总宽度超过屏幕宽度，等比缩放
	if total_width > screen_rect.size.x * 0.9:
		var scale_factor = (screen_rect.size.x * 0.9) / total_width
		for i in range(window_sizes.size()):
			window_sizes[i] = Vector2i(
				int(window_sizes[i].x * scale_factor),
				window_sizes[i].y
			)
		total_width = int(total_width * scale_factor)
	
	# 计算起始X位置（水平居中）
	var start_x = screen_rect.position.x + (screen_rect.size.x - total_width) / 2
	var current_x = start_x
	
	# 设置每个窗口的位置
	for i in range(ui_windows.size()):
		var window_instance = ui_windows[i]
		if not window_instance:
			continue
			
		var win_size = window_sizes[i]
		
		# 计算垂直位置（屏幕底部，但要确保在3D窗口上方）
		var target_y = screen_rect.position.y + screen_rect.size.y - win_size.y - margin_bottom
		
		# 设置窗口位置
		window_instance.position = Vector2i(current_x, target_y)
		
		print("窗口", i+1, "已移动到位置: ", window_instance.position, ", 大小: ", win_size)
		
		# 为下一个窗口更新X位置
		current_x += win_size.x + margin_between

# 【修改】设置窗口拖动功能（支持多窗口）
func _setup_window_dragging(window_instance: Window, window_index: int):
	if not window_instance:
		return
		
	# 查找标题栏节点
	var title_bar = window_instance.get_node_or_null("TitleBar")
	if not title_bar:
		title_bar = window_instance.get_node_or_null("Panel/TitleBar")
	
	if title_bar:
		# 连接标题栏的输入事件
		title_bar.gui_input.connect(_on_ui_window_input.bind(window_index))
		print("✅ 窗口", window_index+1, "标题栏拖动功能已设置")
	else:
		# 如果没有标题栏，创建拖动覆盖层
		_create_drag_overlay_for_window(window_instance, window_index)
		print("⚠️ 窗口", window_index+1, "未找到标题栏，创建拖动覆盖层")

# 【修改】为指定窗口创建拖动覆盖层
func _create_drag_overlay_for_window(window_instance: Window, window_index: int):
	if not window_instance:
		return
		
	# 创建一个全屏透明Control作为拖动区域
	var drag_overlay = Control.new()
	drag_overlay.name = "DragOverlay"
	drag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drag_overlay.mouse_filter = Control.MOUSE_FILTER_PASS  # 允许事件穿透
	window_instance.add_child(drag_overlay)
	
	# 连接拖动事件
	drag_overlay.gui_input.connect(_on_ui_window_input.bind(window_index))
	print("✅ 窗口", window_index+1, "拖动覆盖层已创建")

# 【修改】UI窗口输入事件处理（支持多窗口）
func _on_ui_window_input(event: InputEvent, window_index: int):
	if window_index < 0 or window_index >= ui_windows.size():
		return
		
	var window_instance = ui_windows[window_index]
	if not window_instance:
		return
	
	_handle_drag_input_for_window(event, window_instance, window_index)

# 【新增】处理指定窗口的拖动输入
func _handle_drag_input_for_window(event: InputEvent, window_instance: Window, window_index: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_ui_draggings[window_index] = event.pressed
			if event.pressed:
				# 获取鼠标在屏幕上的位置
				ui_drag_start_poses[window_index] = DisplayServer.mouse_get_position()
				ui_window_start_poses[window_index] = window_instance.position
	
	elif event is InputEventMouseMotion and is_ui_draggings[window_index]:
		# 使用屏幕鼠标位置计算新位置
		var current_mouse_pos = DisplayServer.mouse_get_position()
		var delta = current_mouse_pos - ui_drag_start_poses[window_index]
		window_instance.position = ui_window_start_poses[window_index] + delta

# --- 其他现有函数保持不变 ---
func move_window_to_bottom_right():
	await get_tree().process_frame
	var window_id = get_window().get_window_id()
	var screen_id = DisplayServer.window_get_current_screen(window_id)
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
	var win_size = get_window().size
	var margin = Vector2i(20, 20)
	var target_pos = screen_rect.position + screen_rect.size - win_size - margin
	get_window().position = target_pos

# 【修复】更新鼠标穿透的函数 - 只在需要时调用
func update_mouse_passthrough():
	# 只在标记点都有效时更新穿透
	if not marker_tl or not marker_tr or not marker_br or not marker_bl:
		return
		
	var point_1 = camera.unproject_position(marker_tl.global_position)
	var point_2 = camera.unproject_position(marker_tr.global_position)
	var point_3 = camera.unproject_position(marker_br.global_position)
	var point_4 = camera.unproject_position(marker_bl.global_position)
	var polygon = PackedVector2Array([point_1, point_2, point_3, point_4])
	if polygon.size() >= 3:
		DisplayServer.window_set_mouse_passthrough(polygon)


func _correct_all_rotations():
	var randmap = map_holder.get_node("Randmap")
	if not randmap: return
	
	await get_tree().process_frame
	var furniture_holder = randmap.get_node_or_null("FurnitureHolder")
	if furniture_holder:
		for item_root in furniture_holder.get_children():
			for child in item_root.get_children():
				if child is Node3D:
					if child is Sprite3D:
						child.billboard = BaseMaterial3D.BILLBOARD_DISABLED
						child.rotation_degrees = Vector3(90, 0, 0)
					elif child.has_node("pic"):
						var pic_node = child.get_node("pic")
						if pic_node is Sprite3D:
							pic_node.billboard = BaseMaterial3D.BILLBOARD_DISABLED
							pic_node.rotation_degrees = Vector3(90, 0, 0)

	for waiter_data in randmap.placed_waiters_data:
		var node_ref = waiter_data.get("node_ref")
		if is_instance_valid(node_ref):
			node_ref.rotation_degrees.x = 0

# 【修改】添加OmniLight3D特定配置
func _configure_maplight():
	if not maplight:
		return
	
	# 【修改】确保maplight是OmniLight3D
	if maplight is OmniLight3D:
		# 设置OmniLight3D特定属性
		maplight.omni_range = maplight_range
		maplight.omni_attenuation = maplight_attenuation
		maplight.shadow_enabled = maplight_shadow_enabled
		
		# 默认白天状态
		maplight.light_color = maplight_day_color
		maplight.light_energy = maplight_day_energy
		maplight.visible = false
		
		print("💡 OmniLight3D配置完成，范围:", maplight_range, "衰减:", maplight_attenuation)
	else:
		print("⚠️ maplight不是OmniLight3D，可能是其他类型灯光")

@warning_ignore("unused_parameter")
func apply_day_state(instant: bool):
	sun_light.light_color = day_sun_color
	sun_light.light_energy = day_sun_energy
	world_env.environment.ambient_light_color = day_ambient_color
	world_env.environment.ambient_light_energy = day_ambient_energy
	
	# 【修改】白天时关闭地图灯光
	if maplight:
		# 确保配置正确
		if maplight is OmniLight3D:
			_configure_maplight()
		
		maplight.visible = false
		maplight.light_color = maplight_day_color
		maplight.light_energy = maplight_day_energy

@warning_ignore("unused_parameter")
func apply_night_state(instant: bool):
	sun_light.light_color = night_sun_color
	sun_light.light_energy = night_sun_energy
	world_env.environment.ambient_light_color = night_ambient_color
	world_env.environment.ambient_light_energy = night_ambient_energy
	
	# 【修改】夜晚时开启地图灯光
	if maplight:
		# 确保配置正确
		if maplight is OmniLight3D:
			_configure_maplight()
		
		maplight.visible = true
		maplight.light_color = maplight_night_color
		maplight.light_energy = maplight_night_energy
		print("💡 OmniLight3D地图灯光已开启，能量:", maplight.light_energy, "范围:", maplight_range)

func toggle_day_night():
	is_night = !is_night
	if is_night:
		transition_to_night()
	else:
		transition_to_day()

func transition_to_day():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sun_light, "light_color", day_sun_color, 2.0)
	tween.tween_property(sun_light, "light_energy", day_sun_energy, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_color", day_ambient_color, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_energy", day_ambient_energy, 2.0)
	
	# 【修改】渐变关闭地图灯光
	if maplight:
		# 确保配置正确
		if maplight is OmniLight3D:
			_configure_maplight()
		
		tween.tween_property(maplight, "light_energy", maplight_day_energy, 2.0)
		tween.tween_property(maplight, "light_color", maplight_day_color, 2.0)
		# 在动画结束后隐藏灯光
		await get_tree().create_timer(1.9).timeout  # 稍微提前一点
		if not is_night:  # 确保我们仍然在白天状态
			maplight.visible = false

func transition_to_night():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sun_light, "light_color", night_sun_color, 2.0)
	tween.tween_property(sun_light, "light_energy", night_sun_energy, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_color", night_ambient_color, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_energy", night_ambient_energy, 2.0)
	
	# 【修改】渐变开启地图灯光
	if maplight:
		# 确保配置正确
		if maplight is OmniLight3D:
			_configure_maplight()
		
		maplight.visible = true  # 立即显示但能量从0开始
		maplight.light_energy = 0.0  # 从0开始渐变
		tween.tween_property(maplight, "light_energy", maplight_night_energy, 2.0)
		tween.tween_property(maplight, "light_color", maplight_night_color, 2.0)

func _input(event):
	if event.is_action_pressed("ui_cancel"): 
		get_tree().quit()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				drag_start_position = event.position

	if event is InputEventMouseMotion and dragging:
		var new_pos = DisplayServer.mouse_get_position() - Vector2i(drag_start_position)
		get_window().position = new_pos
		
		# 窗口移动后，需要更新鼠标穿透区域
		update_mouse_passthrough()

func _setup_camera_for_map():
	print("--- 开始设置自适应相机 (精确距离版) ---")
	var randmap = map_holder.get_node("Randmap")
	if not randmap:
		print("❌ 找不到 Randmap 节点。")
		return

	var floor_gridmap = randmap.get_node_or_null("Floor") 
	if not floor_gridmap:
		print("❌ 找不到名为 'Floor' 的主地板节点。")
		return

	var used_cells = floor_gridmap.get_used_cells()
	if used_cells.is_empty():
		print("❌ 主地板 'Floor' 为空。")
		return

	var min_bound = Vector3(1e9, 0, 1e9)
	var max_bound = Vector3(-1e9, 0, -1e9)

	for cell in used_cells:
		min_bound.x = min(min_bound.x, cell.x)
		min_bound.z = min(min_bound.z, cell.z)
		max_bound.x = max(max_bound.x, cell.x)
		max_bound.z = max(max_bound.z, cell.z)

	var map_center_cell = (min_bound + max_bound) / 2.0
	var map_center_world = floor_gridmap.map_to_local(map_center_cell)

	var map_size_x = max_bound.x - min_bound.x + 1
	var map_size_z = max_bound.z - min_bound.z + 1
	var map_size = max(map_size_x, map_size_z)

	var min_map_size = 5.0
	var max_map_size = 120.0
	var min_camera_pos = Vector3(0, 60.0, 100.0)
	var max_camera_pos = Vector3(5, 80.0, 158.0)

	var log_min = log(min_map_size)
	var log_max = log(max_map_size)
	var log_current = log(map_size)
	var t = inverse_lerp(log_min, log_max, log_current)
	t = clamp(t, 0.0, 1.0)

	var final_offset = lerp(min_camera_pos, max_camera_pos, t)
	camera.global_position = map_center_world + final_offset
	var pitch_angle = lerp(-25.0, -30.0, t)
	camera.rotation_degrees = Vector3(pitch_angle, 0, 0)
	camera.fov = lerp(25.0, 30.0, t)



# 在 main_game_sc.gd 中添加这个新函数
# 将3D场景设置为纯黑的加载状态，用于隐藏加载过程
func _apply_loading_state():
	sun_light.light_color = Color.BLACK
	sun_light.light_energy = 0.0
	world_env.environment.ambient_light_color = Color.BLACK
	world_env.environment.ambient_light_energy = 0.0

# 在 main_game_sc.gd 中添加这个新函数
# 同步版本的移动窗口函数，内部没有任何await
# 在 main_game_sc.gd 中添加这个新函数
# 同步版本的移动窗口函数，内部没有任何await
# 【修复】立即将窗口移动到右下角，不修改窗口大小
func move_window_to_bottom_right_sync():
	var window_id = get_window().get_window_id()
	var screen_id = DisplayServer.window_get_current_screen(window_id)
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
	
	# 不要修改窗口大小！使用当前窗口大小
	var win_size = get_window().size
	var margin = Vector2i(20, 20)
	
	# 如果窗口大小为0（可能是初始状态），使用默认大小
	if win_size.x == 0 or win_size.y == 0:
		win_size = Vector2i(800, 600)  # 使用与项目设置一致的默认大小
		print("⚠️ 窗口大小检测为0，使用默认大小:", win_size)
	
	var target_pos = screen_rect.position + screen_rect.size - win_size - margin
	get_window().position = target_pos
	
	print("📌 窗口已移动到右下角: ", target_pos, " 大小: ", win_size)
	
# =================================================================
# 【新增】第四个窗口（按钮面板）的特殊处理逻辑
# =================================================================

# 定位第四个窗口到指定位置
func _arrange_special_ui_window():
	if ui_windows.size() < 4:
		print("⚠️ UI窗口数量不足，无法定位第四个窗口。")
		return
		
	var button_window = ui_windows[3]
	var leftmost_window = ui_windows[0] # 第一个窗口
	
	# 确保窗口大小有效
	var button_win_size = button_window.size
	if button_win_size.x == 0 or button_win_size.y == 0:
		button_win_size = Vector2i(400, 200) # 给一个默认大小
		print("⚠️ 第四个窗口大小为0，使用默认大小:", button_win_size)

	# 计算目标位置：对齐第一个窗口的左上角，并在其上方
	var spacing = 10 # 窗口之间的间距
	var target_pos = Vector2i(
		leftmost_window.position.x,
		leftmost_window.position.y - button_win_size.y - spacing
	)
	
	button_window.position = target_pos
	print("✅ 第四个窗口已定位到: ", target_pos)


# 为第四个窗口设置特殊的拖动（通过命名节点）
func _setup_special_window_dragging(window_instance: Window, window_index: int):
	if not window_instance:
		return

	# 【关键】通过节点名获取内部的拖动区域
	# 请确保你的 button_show_ui.tscn 场景中，作为背景的 Control 节点被命名为 "DragArea"
	var drag_area = window_instance.get_node_or_null("DragArea") as Control
	
	if drag_area:
		# 【调试】打印 DragArea 的关键属性
		#print("✅ 找到 'DragArea' 节点，类型: ", drag_area.get_class(), ", mouse_filter: ", drag_area.mouse_filter)
		drag_area.gui_input.connect(_on_special_ui_window_input.bind(window_index))
		#print("✅ 第四个窗口的特殊拖动功能已设置 (通过 'DragArea' 节点)。")
	else:
		pass
		#print("❌ 错误：在第四个窗口中找不到名为 'DragArea' 的节点！")
		#print("   请在 button_show_ui.tscn 中将作为拖动背景的 Control 节点命名为 'DragArea'。")


# 第四个窗口的输入事件处理
func _on_special_ui_window_input(event: InputEvent, window_index: int):
	# 【调试】打印收到的每一个事件
	#print("DEBUG: _on_special_ui_window_input 收到事件: ", event.as_text(), " 来自窗口: ", window_index)
	
	# 复用原有的拖动逻辑，但只针对第四个窗口
	_handle_drag_input_for_window(event, ui_windows[window_index], window_index)


# =================================================================
# 【新增】时间流动系统 - 核心逻辑
# =================================================================

# 初始化时间系统
func _setup_time_system():
	# 保存第一个UI窗口的引用，方便更新时间显示
	if ui_windows.size() > 0:
		main_info_ui_window = ui_windows[0]
	else:
		#print("❌ 错误：UI窗口数组为空，无法初始化时间系统！")
		return
	
	# 创建并配置计时器
	time_timer = Timer.new()
	time_timer.wait_time = BASE_SECONDS_PER_MINUTE # 先设置一个默认值
	time_timer.one_shot = false # 循环计时
	time_timer.timeout.connect(_on_time_timer_timeout)
	add_child(time_timer) # 将计时器添加到当前节点
	
	#print("✅ 时间系统初始化完毕。")

# 开始时间流动
func _start_time_flow():
	if not time_timer:
		#print("❌ 错误：时间计时器未初始化！")
		return
		
	# 从开店时间开始
	var open_time_str = fc.playerData.now_time
	current_game_minutes = _time_string_to_minutes(open_time_str)
	
	is_time_paused = false
	_update_time_display() # 立即显示一次时间
	time_timer.wait_time = _get_time_speed() # 根据初始时间设置流速
	time_timer.start()
	
	#print("🕒 时间流动开始，起始时间: ", _minutes_to_time_string(current_game_minutes))

# 计时器超时回调
# 修改时间系统，添加天空更新
func _on_time_timer_timeout():
	if is_time_paused:
		return
		
	# 时间前进1分钟
	current_game_minutes += 1
	
	# 更新UI显示
	_update_time_display()

	# 检查并更新流速
	time_timer.wait_time = _get_time_speed()
	
	# 每10分钟自动保存一次
	if current_game_minutes % 10 == 0:
		print("🕒 游戏时间到达10分钟倍数，触发保存...")
		save_current_state_before_exit()
	
	# 检查是否更换晚上来
	if current_game_minutes >= _time_string_to_minutes("18:30"):
		# 【新增】切换到夜晚并开启地图灯光
		if not is_night:
			is_night = true
			apply_night_state(true)
			print("🌙 已切换到夜晚模式，地图灯光已开启")
	
	# 检查是否到达关店时间
	var close_time_minutes = _time_string_to_minutes(fc.playerData.close_time)
	if current_game_minutes >= close_time_minutes:
		_trigger_close_shop_flow()

# 添加新的光照状态函数
func apply_dawn_state():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sun_light, "light_color", Color("FFE4B5"), 2.0)
	tween.tween_property(sun_light, "light_energy", 0.7, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_color", Color("FFE4B5"), 2.0)
	tween.tween_property(world_env.environment, "ambient_light_energy", 0.4, 2.0)

func apply_dusk_state():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sun_light, "light_color", Color("FF6B35"), 2.0)
	tween.tween_property(sun_light, "light_energy", 0.5, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_color", Color("FF6B35"), 2.0)
	tween.tween_property(world_env.environment, "ambient_light_energy", 0.3, 2.0)


# 根据当前游戏时间，获取对应的流速（秒/分钟）
func _get_time_speed() -> float:
	var current_time_str = _minutes_to_time_string(current_game_minutes)
	var hour = current_time_str.split(":")[0].to_int()
	var minute = current_time_str.split(":")[1].to_int()
	
	# 午餐高峰: 12:00 - 13:30
	if hour == 12 or (hour == 13 and minute <= 30):
		return PEAK_SECONDS_PER_MINUTE
	
	# 晚餐高峰: 18:30 - 20:00
	if (hour == 18 and minute >= 30) or (hour == 19):
		return PEAK_SECONDS_PER_MINUTE
		
	# 晚餐后段: 20:00 - 21:30
	if (hour == 20) or (hour == 21 and minute <= 30):
		return SUB_PEAK_SECONDS_PER_MINUTE
	
	# 其他时间：基础流速
	return BASE_SECONDS_PER_MINUTE

# 更新主界面上的时间显示
func _update_time_display():
	if not main_info_ui_window:
		return
		
	# 假设你的 main_info_ui 场景中有一个名为 "TimeLabel" 的 Label 节点
	var time_label = main_info_ui_window.time
	if time_label:
		time_label.text = _minutes_to_time_string(current_game_minutes)
	else:
		# 如果找不到 TimeLabel，打印一个警告，方便你调试
		pass

# 触发关店流程
func _trigger_close_shop_flow():
	print("🚨 关店时间到！准备进入关店流程。")
	is_time_paused = true
	time_timer.stop()
	
	# 【标识】更新玩家数据步骤，你可以根据这个标识来处理后续逻辑
	fc.playerData.state = "打烊"
	
	# 这里可以播放关店音效、弹出结算界面等

# =================================================================
# 【新增】时间流动系统 - 外部接口与辅助函数
# =================================================================

# 供按钮调用的暂停/继续函数
# 修改 toggle_time_pause 函数
func toggle_time_pause():
	is_time_paused = not is_time_paused
	
	# 暂停/恢复时保存状态
	save_current_state_before_exit()
	
	if is_time_paused:
		print("⏸️ 时间流动已暂停。")
	else:
		print("▶️ 时间流动已恢复。")
		time_timer.wait_time = _get_time_speed()


# 辅助函数：将 "HH:MM" 字符串转换为从00:00开始的总分钟数
func _time_string_to_minutes(time_str: String) -> int:
	var parts = time_str.split(":")
	var hour = parts[0].to_int()
	var minute = parts[1].to_int()
	return hour * 60 + minute

# 辅助函数：将总分钟数转换为 "HH:MM" 格式的字符串
func _minutes_to_time_string(total_minutes: int) -> String:
	@warning_ignore("integer_division")
	var hour = (total_minutes / 60) % 24
	var minute = total_minutes % 60
	return "%02d:%02d" % [hour, minute]



# 在 main_game_sc.gd 中添加以下函数


# 清理所有UI窗口并退出到主菜单
func cleanup_and_exit_to_main():
	print("🔄 开始清理3D场景并退出到主菜单...")
	
	# 1. 停止时间系统
	if time_timer:
		time_timer.stop()
		is_time_paused = true
	
	# 2. 关闭所有UI窗口
	close_all_ui_windows()
	

# 关闭所有UI窗口
func close_all_ui_windows():
	print("🔒 关闭所有UI窗口...")
	
	for window in ui_windows:
		if is_instance_valid(window):
			window.queue_free()
	
	ui_windows.clear()
	is_ui_draggings.clear()
	ui_drag_start_poses.clear()
	ui_window_start_poses.clear()
	
	#保存离开3d场景前的所有场景内数据
	save_current_state_before_exit()
	
# 新增：窗口关闭处理函数
func _on_window_close_requested():
	#print("🚨 检测到窗口关闭，保存游戏状态...")
	
	# 保存当前状态
	save_current_state_before_exit()
	
	# 确保所有UI窗口正确关闭
	close_all_ui_windows()
	
	# 退出游戏
	get_tree().quit()



# 同时保留 _notification 作为备用
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 备用处理，防止信号连接失败
		_on_window_close_requested()

# 设置自动保存系统
func _setup_auto_save():
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	auto_save_timer.one_shot = false  # 循环
	auto_save_timer.timeout.connect(_on_auto_save_timeout)
	add_child(auto_save_timer)
	auto_save_timer.start()
	#print("⏰ 自动保存系统已启动，间隔: ", AUTO_SAVE_INTERVAL, "秒")

# 自动保存超时处理
func _on_auto_save_timeout():
	#print("🔄 执行定期自动保存...")
	save_current_state_before_exit()

# 修改保存函数，添加时间戳
func save_current_state_before_exit():
	#print("💾 保存游戏状态...")
	
	# 保存当前游戏时间
	fc.playerData.now_time = _minutes_to_time_string(current_game_minutes)
	
	# 保存其他重要状态
	#fc.playerData.saved_time_paused = is_time_paused
	

	# 执行保存
	fc.save_game(fc.save_num)
