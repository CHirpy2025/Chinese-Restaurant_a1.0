extends Node3D

class_name GridMapPreviewSystem

# --- 节点引用 ---
@onready var viewport = $SubViewport
@onready var preview_camera = $SubViewport/PreviewCamera
@onready var preview_display = $PreviewUI/PreviewDisplay
@onready var shape_buttons_container = $PreviewUI/ShapeButtons
@onready var preview_gridmaps = $SubViewport/PreviewGridMaps

# --- 配置参数 ---
@export var preview_size: Vector2i = Vector2i(256, 256)
@export var camera_height: float = 20.0
@export var camera_distance: float = 15.0
@export var preview_scale: float = 1.0

# --- GridMap数据 ---
var gridmap_scenes: Array[PackedScene] = []
var current_gridmap_index: int = 0
var gridmap_instances: Array[GridMap] = []

func _ready():
	setup_viewport()
	setup_camera()
	setup_ui()
	load_gridmaps()
	show_gridmap(0)

# --- 设置Viewport ---
func setup_viewport():
	viewport.size = preview_size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# 将Viewport纹理显示到UI
	preview_display.texture = viewport.get_texture()
	preview_display.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

# --- 设置相机 ---
func setup_camera():
	preview_camera.position = Vector3(0, camera_height, 0)
	preview_camera.rotation_degrees = Vector3(-90, 0, 0)  # 顶视角
	preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	preview_camera.size = camera_distance

# --- 设置UI ---
func setup_ui():
	# 动态创建形状选择按钮
	create_shape_buttons()

func create_shape_buttons():
	# 清除现有按钮
	for child in shape_buttons_container.get_children():
		child.queue_free()
	
	# 为每个GridMap创建按钮
	for i in range(gridmap_scenes.size()):
		var button = Button.new()
		button.text = "形状 " + str(i + 1)
		button.pressed.connect(_on_shape_button_pressed.bind(i))
		shape_buttons_container.add_child(button)

# --- 加载GridMap ---
func load_gridmaps():
	# 方法1：直接在编辑器中设置
	# 在检查器中将GridMap场景拖拽到gridmap_scenes数组
	
	# 方法2：从文件夹自动加载
	# auto_load_gridmaps_from_folder("res://gridmaps/")
	
	# 方法3：手动添加
	# gridmap_scenes.append(preload("res://scenes/gridmap_shape1.tscn"))
	
	# 实例化所有GridMap
	for i in range(gridmap_scenes.size()):
		if gridmap_scenes[i] != null:
			var instance = gridmap_scenes[i].instantiate()
			if instance is GridMap:
				preview_gridmaps.add_child(instance)
				gridmap_instances.append(instance)
				instance.visible = false

# --- 显示指定GridMap ---
func show_gridmap(index: int):
	if index < 0 or index >= gridmap_instances.size():
		return
	
	# 隐藏所有GridMap
	for gridmap in gridmap_instances:
		gridmap.visible = false
	
	# 显示选中的GridMap
	gridmap_instances[index].visible = true
	current_gridmap_index = index
	
	# 自动调整相机以适应GridMap
	adjust_camera_to_gridmap(gridmap_instances[index])
	
	# 更新按钮状态
	update_button_states()

# --- 调整相机以适应GridMap ---
func adjust_camera_to_gridmap(gridmap: GridMap):
	var used_cells = gridmap.get_used_cells()
	if used_cells.is_empty():
		return
	
	# 计算GridMap的边界
	var min_x = used_cells[0].x
	var max_x = used_cells[0].x
	var min_z = used_cells[0].z
	var max_z = used_cells[0].z
	
	for cell in used_cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_z = min(min_z, cell.z)
		max_z = max(max_z, cell.z)
	
	# 计算中心点
	var center_x = (min_x + max_x) / 2.0
	var center_z = (min_z + max_z) / 2.0
	
	# 计算所需的大小
	var size_x = max_x - min_x + 1
	var size_z = max_z - min_z + 1
	var required_size = max(size_x, size_z) * preview_scale
	
	# 更新相机位置和大小
	preview_camera.position = Vector3(center_x, camera_height, center_z)
	preview_camera.size = required_size

# --- 按钮事件处理 ---
func _on_shape_button_pressed(index: int):
	show_gridmap(index)

# --- 更新按钮状态 ---
func update_button_states():
	var buttons = shape_buttons_container.get_children()
	for i in range(buttons.size()):
		if i == current_gridmap_index:
			buttons[i].modulate = Color.WHITE
		else:
			buttons[i].modulate = Color.GRAY

# --- 公共接口 ---
func set_preview_size(new_size: Vector2i):
	preview_size = new_size
	viewport.size = new_size

func set_camera_height(height: float):
	camera_height = height
	preview_camera.position.y = height

func get_current_gridmap() -> GridMap:
	if current_gridmap_index >= 0 and current_gridmap_index < gridmap_instances.size():
		return gridmap_instances[current_gridmap_index]
	return null

# --- 自动从文件夹加载GridMap ---
func auto_load_gridmaps_from_folder(folder_path: String):
	var dir = DirAccess.open(folder_path)
	if not dir:
		print("无法打开文件夹: ", folder_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var full_path = folder_path + "/" + file_name
			var scene = load(full_path)
			if scene:
				gridmap_scenes.append(scene)
				print("加载GridMap: ", full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
