extends Node3D
class_name GridMapNameReplacer

@onready var grid_map: GridMap = $GridMap

# 名字到ID的缓存
var name_to_id_cache: Dictionary = {}

func _ready():
	if grid_map == null:
		grid_map = find_child("GridMap") as GridMap
	build_name_cache()
	
#替换所有的门显示
func replace_door(which):
	for i in range(1,7):
		get_node("type"+str(i)).visible=false
		get_node("type"+str(i)).get_node("title").visible=false
		get_node("type"+str(i)).get_node("Sprite3D").visible=false
		
		
	get_node(which).visible=true


# 构建名字缓存
func build_name_cache():
	name_to_id_cache.clear()
	
	if grid_map.mesh_library == null:
		print("错误：GridMap没有设置MeshLibrary")
		return
	
	var item_list = grid_map.mesh_library.get_item_list()
	
	for id in item_list:
		var item_name = grid_map.mesh_library.get_item_name(id)
		if item_name != "":
			name_to_id_cache[item_name] = id
	
	#print("砖块名字缓存完成，共 ", name_to_id_cache.size(), " 个砖块")

# 核心函数：通过名字替换砖块
func replace_tile_by_name(old_name: String, new_name: String) -> bool:
	#print("开始替换: ", old_name, " -> ", new_name)
	
	# 检查名字是否存在
	if not name_to_id_cache.has(old_name):
		#print("错误：找不到砖块 '", old_name, "'")
		#print("可用的砖块：", name_to_id_cache.keys())
		return false
	
	if not name_to_id_cache.has(new_name):
		#print("错误：找不到砖块 '", new_name, "'")
		#print("可用的砖块：", name_to_id_cache.keys())
		return false
	
	# 获取对应的ID
	var old_id = name_to_id_cache[old_name]
	var new_id = name_to_id_cache[new_name]
	
	# 执行替换
	var used_cells = grid_map.get_used_cells()
	var replaced_count = 0
	
	for cell in used_cells:
		if grid_map.get_cell_item(cell) == old_id:
			grid_map.set_cell_item(cell, new_id)
			replaced_count += 1
	
	#print("替换完成，共替换 ", replaced_count, " 个砖块")
	
	# 强制刷新显示
	if replaced_count > 0:
		refresh_gridmap()
	
	return replaced_count > 0

# 刷新GridMap显示
func refresh_gridmap():
	# 临时隐藏再显示
	grid_map.visible = false
	await get_tree().process_frame
	grid_map.visible = true
	
	# 重新设置MeshLibrary
	var current_library = grid_map.mesh_library
	grid_map.mesh_library = null
	await get_tree().process_frame
	grid_map.mesh_library = current_library
