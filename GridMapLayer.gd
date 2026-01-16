extends Node
class_name MapSystem

var manager: RandmapManager
var grid_map: GridMap
var base_floor: GridMap



# 配置参数
var default_tile_id: int = 2
var max_block_count: int = 20
var min_tile_pixel_size: float = 80.0
var viewport_size: Vector2 = Vector2(1200, 900)

# 缓存数据
var name_to_id_cache: Dictionary = {}
var empty_floor_cells: Array[Vector3i] = [] # 供寻路使用

func setup(randmap_manager: RandmapManager):
	manager = randmap_manager
	grid_map = manager.grid_map_node
	base_floor = manager.base_floor_node
	
  # ========== 关键修复：延迟缓存构建 ==========
	# 先确保网格存在
	if grid_map and grid_map.mesh_library:
		_build_name_cache()
	

	
	# 如果是营业模式，加载存档
	if manager.current_context == RandmapManager.Context.GAME_SCENE or manager.current_context == RandmapManager.Context.BUZHI:
		load_map()

# ========================================================
# 地图生成逻辑
# ========================================================

func set_viewport_size(size: Vector2):
	viewport_size = size

func set_max_block_count(count: int):
	max_block_count = count

func generate_random_map():
	if not grid_map: return
	grid_map.clear()
	
	# 计算生成边界
	var max_width_tiles = int(viewport_size.x / min_tile_pixel_size)
	var max_height_tiles = int(viewport_size.y / min_tile_pixel_size)
	@warning_ignore("integer_division")
	var limit_x = int(max_width_tiles / 2)
	var limit_z = max_height_tiles - 2 
	
	var current_cells = []
	var center = Vector3i(0, 0, 0)
	_place_cell(center)
	current_cells.append(center)
	
	var safety = 0
	while current_cells.size() < max_block_count and safety < 5000:
		safety += 1
		var origin = current_cells.pick_random()
		var dirs = [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
		var target = origin + dirs.pick_random()
		
		if abs(target.x) > limit_x: continue
		if target.z < 0 or target.z > limit_z: continue
		
		if grid_map.get_cell_item(target) == GridMap.INVALID_CELL_ITEM:
			_place_cell(target)
			current_cells.append(target)
			
	fit_map_to_viewport()
   # ========== 关键修复：强制更新路径缓存 ==========
	if manager and manager.furniture_system:
		rebuild_empty_cells_map(manager.furniture_system)
	# ========== 关键修复：显式验证(0,0,0)格子 ==========
	_verify_origin_cell()

# 新增函数：验证并修复(0,0,0)格子
func _verify_origin_cell():
	var origin = Vector3i(0, 0, 0)
	if grid_map.get_cell_item(origin) == GridMap.INVALID_CELL_ITEM:
		print("MapSystem: 修复 - (0,0,0)格子不存在，重新放置")
		_place_cell(origin)
		# 重新更新缓存
		if manager and manager.furniture_system:
			rebuild_empty_cells_map(manager.furniture_system)


func _place_cell(pos: Vector3i):
	grid_map.set_cell_item(pos, default_tile_id)

# 调整地图位置使其居中（可选）
func fit_map_to_viewport():
	# 这里可以放原本 set_viewport 里的适配逻辑
	pass

# ========================================================
# 地图操作逻辑
# ========================================================

func close_base_floor():
	if base_floor:
		base_floor.visible = false

func replace_map_tiles_with(new_tile_name: String) -> bool:
	if not name_to_id_cache.has(new_tile_name):
		print("MapSystem: 找不到名为 '", new_tile_name, "' 的砖块")
		return false
	
	var new_id = name_to_id_cache[new_tile_name]
	var used_cells = grid_map.get_used_cells()
	
	for cell_pos in used_cells:
		grid_map.set_cell_item(cell_pos, new_id)
		
	return true

func _build_name_cache():
	name_to_id_cache.clear()
	if not grid_map or not grid_map.mesh_library: return
	
	var item_list = grid_map.mesh_library.get_item_list()
	for id in item_list:
		var item_name = grid_map.mesh_library.get_item_name(id)
		if item_name != "":
			name_to_id_cache[item_name] = id

# ========================================================
# 存档与读档
# ========================================================

func save_map():
	var map_data = []
	var used_cells = grid_map.get_used_cells()
	for cell_pos in used_cells:
		var tile_id = grid_map.get_cell_item(cell_pos)
		map_data.append({"pos": cell_pos, "id": tile_id})
	
	fc.playerData.saved_map = map_data
	#print("MapSystem: 地图已保存，共 ", map_data.size(), " 格")

func load_map():
	var map_data = fc.playerData.saved_map
	if map_data.is_empty():
		return
		
	grid_map.clear()
	for data in map_data:
		var pos = data["pos"]
		if typeof(pos) != TYPE_VECTOR3I:
			pos = fc.string_to_vector3i_1(pos)
		grid_map.set_cell_item(pos, data["id"])
	
	_build_name_cache() # 重新构建缓存，以防万一
	#print("MapSystem: 地图已加载")

# ========================================================
# 工具函数 (供其他系统使用)
# ========================================================

# 获取所有合法的地面格子（不考虑家具，只考虑有没有地块）
func get_all_floor_cells() -> Array[Vector3i]:
	return grid_map.get_used_cells()

# 构建空白格子地图 (每次地图改变或家具改变后调用)
# 注意：这个函数通常由 FurnitureSystem 在放置/移除家具后调用
func rebuild_empty_cells_map(furniture_system_ref):
	empty_floor_cells.clear()
	var used_cells = grid_map.get_used_cells()
	
	for cell in used_cells:
		if _is_cell_walkable(cell, furniture_system_ref):
			empty_floor_cells.append(cell)
			
	#print("MapSystem: 空白格子地图已更新，可通行格子数: ", empty_floor_cells.size())

func _is_cell_walkable(cell: Vector3i, furniture_system_ref) -> bool:
	# 1. 必须有地板
	if grid_map.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM:
		return false
		
	# 2. 必须没有家具 (调用 FurnitureSystem 查询)
	if furniture_system_ref:
		# 这里我们假设 FurnitureSystem 有一个高效的查询方法
		# 或者直接访问它的 occupied_cells
		var key = str(cell.x) + "," + str(cell.z)
		if furniture_system_ref.occupied_cells.has(key):
			return false
			
	return true

# 判断某个格子是否可通行
func is_cell_walkable(cell: Vector3i) -> bool:
	return empty_floor_cells.has(cell)

# MapSystem.gd

# --- 寻路核心算法 ---

# 检查两点是否连通 (BFS 搜索)
func is_point_reachable(start: Vector3i, target: Vector3i) -> bool:
	if start == target: return true
	
	# 检查起点和终点是否在合法列表中
	# 注意：target 往往是家具旁边的空地，必须是 empty_floor_cells 里有的
	if not empty_floor_cells.has(start):
		# 如果起点不在空地里（可能服务生刚放下还没更新空地缓存，或者站在了非法位置）
		# 尝试放宽条件：只要它是地板且没被家具堵死就行
		if not _is_cell_walkable_dynamic(start):
			return false
			
	if not empty_floor_cells.has(target):
		if not _is_cell_walkable_dynamic(target):
			return false

	# BFS 初始化
	var visited = { str(start): true }
	var queue = [start]
	var directions = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	
	var steps = 0
	var max_steps = 2000 # 防止死循环
	
	while queue.size() > 0:
		steps += 1
		if steps > max_steps: return false
		
		var current = queue.pop_front()
		if current == target: return true
		
		for dir in directions:
			var next = current + dir
			var key = str(next)
			
			if not visited.has(key):
				# 必须是空地才能走
				if empty_floor_cells.has(next) or next == target:
					visited[key] = true
					queue.append(next)
					
	return false

# 动态检查格子是否可行走 (不依赖缓存，用于起点检查)
func _is_cell_walkable_dynamic(cell: Vector3i) -> bool:
	if grid_map.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM: return false
	
	if manager.furniture_system:
		var node = manager.furniture_system.get_furniture_node_at(cell)
		if node: return false
	return true

# 获取家具周围的可达格子
# MapSystem.gd

func get_furniture_access_points(pos: Vector3i, size: Vector2i) -> Array[Vector3i]:
	var access_points: Array[Vector3i] = []
	# 检查家具四周的一圈格子
	# 上边缘 (z-1)
	for x in range(size.x):
		var p = pos + Vector3i(x, 0, -1)
		if is_cell_walkable(p): access_points.append(p)
	# 下边缘 (z+size.y)
	for x in range(size.x):
		var p = pos + Vector3i(x, 0, size.y)
		if is_cell_walkable(p): access_points.append(p)
	# 左边缘 (x-1)
	for z in range(size.y):
		var p = pos + Vector3i(-1, 0, z)
		if is_cell_walkable(p): access_points.append(p)
	# 右边缘 (x+size.x)
	for z in range(size.y):
		var p = pos + Vector3i(size.x, 0, z)
		if is_cell_walkable(p): access_points.append(p)
	return access_points


# MapSystem.gd

# 获取从 current 到 target 的下一步格子 (基于 BFS 距离场或 A*)
# MapSystem.gd

func get_next_step(current: Vector3i, target: Vector3i) -> Vector3i:
	if current == target: return current
	
	# --- BFS 寻路 ---
	var queue = [current]
	var came_from = { str(current): null }
	var found = false
	
	# 【关键修复】确保目标点附近的点也被视为有效，防止最后一步走不到
	# (这里不做改动，主要看下面的遍历)
	
	var max_steps = 1000 
	var steps = 0
	
	while queue.size() > 0:
		steps += 1
		if steps > max_steps: break
		
		var curr = queue.pop_front()
		if curr == target:
			found = true
			break
			
		var dirs = [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
		for d in dirs:
			var next = curr + d
			var key = str(next)
			
			if not came_from.has(key):
				# 【核心修复】放宽通行条件
				# 1. 如果 next 是目标点，允许进入
				# 2. 如果 next 是可通行空地，允许进入
				# 3. 如果 next 就在 target 旁边 (距离<=1)，允许尝试逼近
				var is_target = (next == target)
				var is_walkable = is_cell_walkable(next)
				# 容错：有些时候坐标转换有微小误差，导致目标点偏离空地，这里允许最后一步强行贴近
				
				if is_walkable or is_target:
					came_from[key] = curr
					queue.append(next)
	
	if not found: 
		# print("MapSystem: 寻路失败，无法从 ", current, " 到 ", target)
		return Vector3i(-999,-999,-999) 
	
	# 回溯路径
	var path_curr = target
	while came_from[str(path_curr)] != current:
		path_curr = came_from[str(path_curr)]
		if path_curr == null: return Vector3i(-999,-999,-999) 
		
	return path_curr
