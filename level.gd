# main.gd - 精简版，只保留核心全局功能
extends Node3D

# --- 节点引用 ---
@onready var sun_light = $SunLight
@onready var world_env = $WorldEnvironment
#@onready var grid_map = $Floor
@onready var camera = $Camera3D

# --- 窗口穿透的标记点引用 ---
@onready var marker_tl = $MarkerTL
@onready var marker_tr = $MarkerTR
@onready var marker_br = $MarkerBR
@onready var marker_bl = $MarkerBL

# --- 日夜循环配置 ---
# 白天的配置
var day_sun_color = Color("ffffff") # 暖白光
var day_sun_energy = 14.0
var day_ambient_color = Color("f8ece4") # 环境光较亮
var day_ambient_energy = 0.5

# 黑夜的配置 (关键：用蓝色模拟黑夜)
var night_sun_color = Color("6876bc") # 冷蓝光 (模拟月光)
var night_sun_energy = 0.3 # 变暗
var night_ambient_color = Color("2d3656") # 环境光很暗且偏蓝
var night_ambient_energy = 0.2

# --- 网格边界 ---
var grid_x_min: int
var grid_x_max: int
var grid_z_min: int

# --- 状态变量 ---
var is_night = false


# --- 这里保留之前的拖拽代码 ---
var dragging = false
var drag_start_position = Vector2()

# 方法B (推荐)：代码动态加载，保持层级整洁
var game_ui_scene = null # 请确保路径正确
var game_ui_instance: Window = null



func _ready():
	# 基础窗口设置
	get_tree().root.transparent_bg = true
	get_window().transparent = true
	
	# 初始化日夜状态
	apply_day_state(true)
	
	# 计算地板边界
	#calculate_grid_bounds()
	
# --- 新增：将窗口移动到右下角 ---
	move_window_to_bottom_right()
	
# --- 新增函数 ---
func move_window_to_bottom_right():
	# 1. 等待一帧，确保窗口尺寸初始化完成
	await get_tree().process_frame
	
	# 2. 获取当前窗口 ID
	var window_id = get_window().get_window_id()
	
	# 3. 【修正点】获取当前屏幕 ID (API名称修正)
	var screen_id = DisplayServer.window_get_current_screen(window_id)
	
	# 4. 获取屏幕的“可用区域” (会自动减去任务栏高度)
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
	
	# 5. 获取窗口大小和设置边距
	var win_size = get_window().size
	var margin = Vector2i(20, 20) # 距离右下角边缘的像素距离
	
	# 6. 计算目标位置 (屏幕右下角 - 窗口大小 - 边距)
	var target_pos = screen_rect.position + screen_rect.size - win_size - margin
	
	# 7. 设置位置
	get_window().position = target_pos
# --- 新增：初始化 UI 窗口 ---
	#

func setup_ui_window():
	game_ui_instance = game_ui_scene.instantiate()
	# --- 关键修改开始 ---
	
	# 1. 设为从属窗口 (Transient)
	# 这告诉操作系统：这个 UI 属于主窗口，请务必把它画在主窗口上面。
	# 注意：必须在 add_child 或 show 之前设置，或者在设置后重新 show
	game_ui_instance.transient = true 
	
	# 2. 确保 UI 也是总在最前
	add_child(game_ui_instance)
	# 3. 确保初始居中 (防止 transient 导致的初始位置偏移)
	game_ui_instance.center_window_on_screen()
	game_ui_instance.show_with_animation()


# --- 新增：控制 UI 显示/隐藏 ---
# main.gd
func toggle_ui():
	if game_ui_instance!=null:
		# --- 关闭 UI 的逻辑 ---
		
		game_ui_instance.hide_with_animation()
		
		# 【关键修复】：显式地让主窗口夺回焦点！
		# 如果不加这句，焦点会丢失，导致你必须点一下 3D 场景才能操作
		get_window().grab_focus()
		
		print("UI关闭，焦点归还主窗口")
		



@warning_ignore("unused_parameter")
func _process(delta):
	# 只负责更新窗口形状
	update_mouse_passthrough()




func _input(event):
	# 只保留最基础的输入：拖动窗口和紧急退出
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

	if event.is_action_pressed("ui_accept"): # 测试天黑
		toggle_day_night()

# 测试：按空格键打开/关闭 UI
	if event.is_action_pressed("ui_left"): 
		$Randmap.max_block_count = randi_range(36,120)
		print($Randmap.max_block_count)
		$Randmap.generate_random_map()






# --- 日夜循环函数 ---
@warning_ignore("unused_parameter")
func apply_day_state(instant: bool):
	sun_light.light_color = day_sun_color
	sun_light.light_energy = day_sun_energy
	world_env.environment.ambient_light_color = day_ambient_color
	world_env.environment.ambient_light_energy = day_ambient_energy

func toggle_day_night():
	is_night = !is_night
	if is_night:
		transition_to_night()
	else:
		transition_to_day()

func transition_to_day():
	print("切换到白天")
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sun_light, "light_color", day_sun_color, 2.0)
	tween.tween_property(sun_light, "light_energy", day_sun_energy, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_color", day_ambient_color, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_energy", day_ambient_energy, 2.0)
	turn_lamps_off()

func transition_to_night():
	print("切换到黑夜")
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sun_light, "light_color", night_sun_color, 2.0)
	tween.tween_property(sun_light, "light_energy", night_sun_energy, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_color", night_ambient_color, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_energy", night_ambient_energy, 2.0)
	turn_lamps_on()

func turn_lamps_on():
	get_tree().call_group("lamps", "toggle_light", true)

func turn_lamps_off():
	get_tree().call_group("lamps", "toggle_light", false)

# --- 窗口穿透函数 ---
func update_mouse_passthrough():
	# 1. 获取这四个点在屏幕上的 2D 坐标
	var point_1 = camera.unproject_position(marker_tl.global_position)
	var point_2 = camera.unproject_position(marker_tr.global_position)
	var point_3 = camera.unproject_position(marker_br.global_position)
	var point_4 = camera.unproject_position(marker_bl.global_position)
	
	# 2. 构造一个多边形数组
	var polygon = PackedVector2Array([point_1, point_2, point_3, point_4])
	
	# 3. 设置穿透区域
	if polygon.size() >= 3:
		DisplayServer.window_set_mouse_passthrough(polygon)

## --- 辅助函数 ---
#func calculate_grid_bounds():
	#var used_cells = grid_map.get_used_cells()
	#if used_cells.is_empty():
		#return
	#
	#grid_x_min = used_cells[0].x
	#grid_x_max = used_cells[0].x
	#grid_z_min = used_cells[0].z
	#
	#for cell in used_cells:
		#if cell.x < grid_x_min: grid_x_min = cell.x
		#if cell.x > grid_x_max: grid_x_max = cell.x
		#if cell.z < grid_z_min: grid_z_min = cell.z
	#
	#print("GridMap 边界: X(", grid_x_min, " 到 ", grid_x_max, "), Z最小值:", grid_z_min)
