extends Control

# 场景引用
@onready var map_holder: Node3D = $SubViewportContainer/SubViewport/MapHolder
@onready var ui_camera: Camera3D = $SubViewportContainer/SubViewport/Camera3D
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport

# 【关键修改】引用 RandmapManager
# 注意：节点路径还是原来的 Randmap，但挂载的脚本已经是 RandmapManager 了
@onready var randmap_manager: RandmapManager = $SubViewportContainer/SubViewport/MapHolder/Randmap

# GridMap 场景资源列表 (用于 display_shape，如果你的地图形状是预制体的话)
@export var gridmap_scenes: Array[PackedScene]
# [新增] 记录当前高亮的家具，防止重复设置
var current_highlighted_item: Node3D = null
# 边距系数
const MARGIN_SCALE: float = 1.2 

var current_map_index: int = 0

# --- 临时变量 (稍后移入 InteractionSystem) ---
var current_waiter_ghost_color: Color = Color.WHITE
var highlighted_waiter: Node3D = null
var ghost_mesh_instance: MeshInstance3D = null
var green_mat: StandardMaterial3D
var red_mat: StandardMaterial3D

func _ready():
	# 确保相机是正交投影
	ui_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	
	# 初始化预览材质 (保留用于家具预览)
	_init_materials()
	
	# 【关键修改】初始化 RandmapManager
	# 这里如果是选地图界面，设置为 CHOICE_MAP；如果是布置界面，在 buzhi.gd 里可能会再次覆盖设置
	# 默认先初始化系统引用
	if randmap_manager:
		# 我们假设 show3dmap 主要用于布置或选图，这里先设为 CHOICE_MAP 上下文，
		# 具体的上下文 (BUZHI) 可以在 buzhi.gd 中再次调用 setup_for_context 覆盖
		randmap_manager.setup_for_context(RandmapManager.Context.CHOICE_MAP)

	# 初始显示
	# 如果你是用 gridmap_scenes 预制体切换形状：
	if not gridmap_scenes.is_empty():
		display_shape(current_map_index)


func _init_materials():
	green_mat = StandardMaterial3D.new()
	green_mat.albedo_color = Color(0, 1, 0, 0.5)
	green_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	green_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	red_mat = StandardMaterial3D.new()
	red_mat.albedo_color = Color(1, 0, 0, 0.5)
	red_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

# ========================================================
# 地图系统接口对接 (MapSystem)
# ========================================================

# 重设显示的gridmap地图比例
func set_viewport(): # 修正拼写 set_viewpot -> set_viewport
	if not randmap_manager or not randmap_manager.map_system:
		return
		
	# 调用 MapSystem 设置参数
	randmap_manager.map_system.set_viewport_size(sub_viewport.size)
	
	# 适配相机 (依然在 show3dmap 处理，因为它持有 ui_camera)
	fit_map_to_viewport()

# 更改生成的地图的gridmap砖块最大值
func change_max(num: int):
	if not randmap_manager or not randmap_manager.map_system:
		return

	# 调用 MapSystem
	randmap_manager.map_system.set_max_block_count(num)
	randmap_manager.map_system.set_viewport_size(sub_viewport.size)
	randmap_manager.map_system.generate_random_map()
	
	# 生成后等待一帧适配相机
	await get_tree().process_frame
	fit_map_to_viewport()

# 关闭基础地板
func closeBase():
	if randmap_manager and randmap_manager.map_system:
		randmap_manager.map_system.close_base_floor()

# 替换地图地板块
func change_to_floor(newfloor: String):
	if randmap_manager and randmap_manager.map_system:
		randmap_manager.map_system.replace_map_tiles_with(newfloor)

# 生成随机地图
func generate_random_map():
	if randmap_manager and randmap_manager.map_system:
		randmap_manager.map_system.generate_random_map()
		await get_tree().process_frame
		fit_map_to_viewport()

# 保存地图
func savemap():
	if randmap_manager and randmap_manager.map_system:
		randmap_manager.map_system.save_map()
		# 如果将来有 FurnitureSystem，也要在这里调用 furniture_system.save_furniture()

# ========================================================
# 相机适配逻辑 (保留在 show3dmap)
# ========================================================

func fit_map_to_viewport(gridmap: GridMap = null):
	# 如果没有传入 gridmap，自动从 manager 获取
	if gridmap == null:
		if randmap_manager:
			gridmap = randmap_manager.grid_map_node
	
	if not gridmap: return

	var used_cells = gridmap.get_used_cells()
	if used_cells.is_empty(): return

	# 1. 计算 AABB
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	var cell_size = gridmap.cell_size
	
	for cell in used_cells:
		var center_pos = gridmap.map_to_local(cell)
		var cell_min = center_pos - (cell_size / 2.0)
		var cell_max = center_pos + (cell_size / 2.0)
		min_pos = min_pos.min(cell_min)
		max_pos = max_pos.max(cell_max)
	
	var map_size = max_pos - min_pos
	var map_center = (min_pos + max_pos) / 2.0
	
	# 2. 居中地图 (移动 GridMap 节点)
	# 注意：RandmapManager 脚本挂在 Randmap 节点上，而 GridMap 是其子节点 Floor
	# 我们移动 GridMap (Floor) 的位置，或者移动 MapHolder 的位置
	# 之前的逻辑是移动 gridmap 本身
	gridmap.global_position = -map_center
	gridmap.global_position.y = 0 
	
	# 3. 计算相机 Size (Orthogonal)
	var vp_size = sub_viewport.size
	var vp_aspect = float(vp_size.x) / float(vp_size.y) 
	
	var map_width_3d = map_size.x
	var map_height_3d = map_size.z
	
	var size_based_on_height = map_height_3d
	var size_based_on_width = map_width_3d / vp_aspect
	
	var final_cam_size = max(size_based_on_height, size_based_on_width)
	
	var tween = create_tween()
	tween.tween_property(ui_camera, "size", final_cam_size * MARGIN_SCALE, 0.5).set_trans(Tween.TRANS_CUBIC)

# ========================================================
# 形状切换逻辑 (保留)
# ========================================================

func _on_next_button_pressed():
	current_map_index += 1
	if current_map_index >= gridmap_scenes.size():
		current_map_index = 0
	display_shape(current_map_index)

func _on_prev_button_pressed():
	current_map_index -= 1
	if current_map_index < 0:
		current_map_index = gridmap_scenes.size() - 1
	display_shape(current_map_index)

func display_shape(index: int):
	if gridmap_scenes.is_empty(): return
	if index < 0 or index >= gridmap_scenes.size(): return
	
	# 这里比较特殊，因为现在 Randmap 变成了 Manager，结构变了
	# 如果你的 display_shape 是为了替换整个 Randmap 节点，那逻辑需要大改
	# 如果只是为了替换里面的 GridMap 数据，建议改为调用 MapSystem 的加载功能
	# 为了不破坏现有结构，假设 gridmap_scenes 里的场景依然是合法的子节点结构
	# 这里暂时保留原逻辑，但需要注意 scene_resource 实例化出来的内容
	pass 

# ========================================================
# 临时：交互与家具相关 (等待 FurnitureSystem 拆解)
# ========================================================
# 下面的函数需要等到 FurnitureSystem 和 InteractionSystem 拆解完才能完全工作
# 这里先保留函数定义，防止 choicemap.gd 或 buzhi.gd 报错

# show3dmap.gd

func update_placement_ghost(global_mouse_pos: Vector2, item_data: Dictionary) -> bool:
	if not _is_mouse_in_container(global_mouse_pos): 
		hide_ghost()
		return false
	
	var mouse_grid_pos = _get_grid_pos_from_mouse(global_mouse_pos)
	
	# 【核心修复】必须显式检查 null，否则 (0,0,0) 会被当成 false 跳过
	if mouse_grid_pos == null: 
		hide_ghost()
		return false
	
	var size = Vector2i(int(item_data["pos_need_x"]), int(item_data["pos_need_y"]))
	
	# 【核心修复 1】计算锚点 (左上角)
	var anchor_pos = mouse_grid_pos - Vector3i(size.x / 2, 0, size.y / 2)
	
	# 检查合法性 (使用锚点检查)
	var is_valid = false
	if randmap_manager.furniture_system:
		is_valid = randmap_manager.furniture_system.check_area_available(anchor_pos, size, item_data)
	
	var ghost = get_ghost_node()
	ghost.visible = true
	
	# 【核心修复 2】计算幽灵的显示中心 (使用通用公式)
	var grid_map = randmap_manager.grid_map_node
	var cell_size = 4.0 # 确保这里和 GridMap 一致
	
	var local_pos = grid_map.map_to_local(anchor_pos)
	local_pos.x += (size.x - 1) * cell_size * 0.5
	local_pos.z += (size.y - 1) * cell_size * 0.5
	
	ghost.global_position = grid_map.to_global(local_pos)
	
	# 设置颜色和缩放
	ghost.material_override = green_mat if is_valid else red_mat
	var target_scale = Vector3(size.x * cell_size, 2.0, size.y * cell_size)
	ghost.scale = target_scale
	
	return true

  

func try_place_current_item(global_mouse_pos: Vector2, item_data: Dictionary) -> bool:
	if not _is_mouse_in_container(global_mouse_pos): return false
	
	var mouse_grid_pos = _get_grid_pos_from_mouse(global_mouse_pos)
	# 【核心修复】显式检查 null
	if mouse_grid_pos == null: return false
	# 获取尺寸
	var size_x = int(item_data["pos_need_x"])
	var size_y = int(item_data["pos_need_y"])
	
	# 【核心修复】计算锚点 (左上角)
	# 让鼠标位置尽量处于中心
	# 3 / 2 = 1 -> 锚点 = 鼠标 - 1 (鼠标在中间)
	# 2 / 2 = 1 -> 锚点 = 鼠标 - 1 (鼠标在右下半区)
	var anchor_pos = mouse_grid_pos - Vector3i(size_x / 2, 0, size_y / 2)
	
	if randmap_manager.furniture_system:
		# 传入计算好的锚点
		return randmap_manager.furniture_system.place_furniture(anchor_pos, item_data)
	return false

func update_hover_highlight(global_mouse_pos: Vector2) -> Node3D:
	var container = $SubViewportContainer
	
	# 范围检查
	if not container.get_global_rect().has_point(global_mouse_pos):
		_clear_highlight()
		return null
		
	# 射线检测 -> 获取格子坐标
	var grid_pos = _get_grid_pos_from_mouse(global_mouse_pos)
	if grid_pos == null: 
		_clear_highlight()
		return null
	
	# 询问 FurnitureSystem 这个格子有没有家具
	var item_root = null
	if randmap_manager.furniture_system:
		item_root = randmap_manager.furniture_system.get_furniture_node_at(grid_pos)
	
	# 2. 如果没有家具，检查服务生
	var waiter_root = null
	if not item_root and randmap_manager.waiter_system:
		waiter_root = randmap_manager.waiter_system.get_waiter_node_at(grid_pos)
	
	
	# 处理高亮逻辑
	_clear_highlight() # 简单粗暴，先清空旧的
	
	if item_root:
		current_highlighted_item = item_root
		randmap_manager.furniture_system.set_item_highlight(item_root, true)
		return item_root
	
	if waiter_root:
		highlighted_waiter = waiter_root
		randmap_manager.waiter_system.set_waiter_highlight(waiter_root, true)
		return waiter_root
		
	return null

func _clear_highlight():
	if current_highlighted_item and is_instance_valid(current_highlighted_item):
		if randmap_manager.furniture_system:
			randmap_manager.furniture_system.set_item_highlight(current_highlighted_item, false)
	current_highlighted_item = null
	
	# 清除服务生高亮
	if highlighted_waiter and is_instance_valid(highlighted_waiter):
		if randmap_manager.waiter_system:
			randmap_manager.waiter_system.set_waiter_highlight(highlighted_waiter, false)
	highlighted_waiter = null
	

# 2. 拾取家具 (用于移动)
func try_pick_up_item(global_mouse_pos: Vector2) -> Dictionary:
	if not _is_mouse_in_container(global_mouse_pos): return {}
	
	var grid_pos = _get_grid_pos_from_mouse(global_mouse_pos)
	
	if grid_pos == null: return {}


	
	# 调用 FurnitureSystem
	if randmap_manager.furniture_system:
		return randmap_manager.furniture_system.remove_furniture_at(grid_pos)
	return {}

# 3. 检查 Limit
func is_limit_exist(limit_name: String) -> bool:
	if randmap_manager.furniture_system:
		return randmap_manager.furniture_system.check_limit_exists(limit_name)
	return false

func save_all_data():
	if randmap_manager:
		if randmap_manager.map_system:
			randmap_manager.map_system.save_map()
		if randmap_manager.furniture_system:
			randmap_manager.furniture_system.save_furniture()


func get_ghost_node() -> MeshInstance3D:
	if ghost_mesh_instance and is_instance_valid(ghost_mesh_instance):
		return ghost_mesh_instance
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	mesh_inst.mesh = box
	mesh_inst.name = "GhostCursor"
	map_holder.add_child(mesh_inst)
	ghost_mesh_instance = mesh_inst
	return mesh_inst

func hide_ghost():
	if ghost_mesh_instance:
		ghost_mesh_instance.visible = false

# 4. 辅助函数：统一的坐标计算 (复用给 update_placement_ghost)
func _get_grid_pos_from_mouse(global_mouse_pos: Vector2):
	var local_mouse = $SubViewportContainer.get_local_mouse_position()
	var origin = ui_camera.project_ray_origin(local_mouse)
	var normal = ui_camera.project_ray_normal(local_mouse)
	if abs(normal.y) < 0.001: return null
	
	var t = -origin.y / normal.y
	var hit_pos_world = origin + normal * t
	var grid_map = randmap_manager.grid_map_node
	var local_hit = grid_map.to_local(hit_pos_world)
	return grid_map.local_to_map(local_hit)

func _is_mouse_in_container(global_mouse_pos: Vector2) -> bool:
	return $SubViewportContainer.get_global_rect().has_point(global_mouse_pos)


# --- 服务生布置预览 ---
func update_waiter_placement_ghost(global_mouse_pos: Vector2, waiter_data: WaiterData, waiter_color: Color) -> bool:
	if not _is_mouse_in_container(global_mouse_pos): 
		hide_ghost()
		return false
	
	var grid_pos = _get_grid_pos_from_mouse(global_mouse_pos)
	
	if grid_pos == null: 
		hide_ghost()
		return false
	
	# 检查位置合法性
	var is_valid = false
	if randmap_manager.waiter_system:
		is_valid = randmap_manager.waiter_system.check_area_available(grid_pos)
	
	# 更新幽灵
	var ghost = get_ghost_node()
	ghost.visible = true
# 【修复 A】强制重置缩放为 1 (防止之前的家具缩放影响)
	ghost.scale = Vector3.ONE 
	
	# 使用方块作为幽灵，或者你可以加载 waiter_show.tscn 的网格
	ghost.mesh = BoxMesh.new() 
	ghost.mesh.size = Vector3(4.0, 0.2, 4.0)
	
	# 坐标对齐 (与 WaiterSystem 一致)
	var grid_map = randmap_manager.grid_map_node
	var local_pos = grid_map.map_to_local(grid_pos)
	# 稍微抬高
	local_pos.y += 0.6 
	ghost.global_position = grid_map.to_global(local_pos)
	
	# 设置材质
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	if is_valid:
		mat.albedo_color = waiter_color # 合法时显示队伍颜色
	else:
		mat.albedo_color = Color(1, 0, 0, 0.5) # 不合法显示红色
		
	ghost.material_override = mat
	current_waiter_ghost_color = waiter_color # 记录颜色给放置用
	
	return true

# --- 放置服务生 ---
func try_place_current_waiter(global_mouse_pos: Vector2, waiter_data: WaiterData) -> bool:
	if not _is_mouse_in_container(global_mouse_pos): return false
	var grid_pos = _get_grid_pos_from_mouse(global_mouse_pos)
	if grid_pos == null: 
		return false
	
	
	
	if randmap_manager.waiter_system:
		return randmap_manager.waiter_system.place_waiter(grid_pos, waiter_data, current_waiter_ghost_color)
	return false

# --- 拾取/移动服务生 ---
# show3dmap.gd 修复 try_pick_up_waiter

func try_pick_up_waiter(global_mouse_pos: Vector2) -> WaiterData:
	if not _is_mouse_in_container(global_mouse_pos): return null
	
	# 1. 获取鼠标指向的格子
	var grid_pos = _get_grid_pos_from_mouse(global_mouse_pos)
	if grid_pos == null: return null
	
	# 2. 调用 WaiterSystem 执行移除并获取数据
	if randmap_manager.waiter_system:
		var data = randmap_manager.waiter_system.remove_waiter_at(grid_pos)
		if data:
			_clear_highlight() # 拾取后清除高亮
			return data
	return null
# show3dmap.gd

# 选中家具（返回数据，并高亮）
func select_furniture_at(global_mouse_pos: Vector2) -> Dictionary:
	# 1. 范围检查
	if not _is_mouse_in_container(global_mouse_pos): 
		return {}
	
	# 2. 获取格子坐标
	var grid_pos = _get_grid_pos_from_mouse(global_mouse_pos)
	if grid_pos == null: 
		return {}
	
	if randmap_manager.furniture_system:
		# 获取数据
		var data = randmap_manager.furniture_system.get_furniture_data_at(grid_pos)
		
		# 顺便处理高亮反馈 (可选，提升体验)
		if not data.is_empty():
			var item_root = data["node_ref"]
			_clear_highlight() # 清除旧高亮
			current_highlighted_item = item_root
			randmap_manager.furniture_system.set_item_highlight(item_root, true)
			
		return data
		
	return {}
