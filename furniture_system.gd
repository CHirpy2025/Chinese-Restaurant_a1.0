extends Node
class_name FurnitureSystem

var manager: RandmapManager
var grid_map: GridMap
var furniture_holder: Node3D

# 数据存储
var placed_furniture_data: Array = []
var occupied_cells: Dictionary = {}
var furniture_waiter_assignment: Dictionary = {}

# 材质缓存
var _gray_mat: StandardMaterial3D
var _highlight_mat: StandardMaterial3D

# 配置
var base_height_offset: float = 0.2
var object_render_layer: int = 1

# ========================================================
# 初始化
# ========================================================
func setup(randmap_manager: RandmapManager):
	manager = randmap_manager
	grid_map = manager.grid_map_node
	furniture_holder = manager.furniture_holder
	
	_init_materials() # 初始化材质
	

func _init_materials():
	# 灰色材质 (默认占位)
	_gray_mat = StandardMaterial3D.new()
	_gray_mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5) # 半透明灰
	_gray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # 无光照，保持颜色纯正
	
	# 高亮材质 (黄色)
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.5) # 半透明黄
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

# ========================================================
# 核心功能：放置家具
# ========================================================


# ========================================================
# 辅助函数
# ========================================================
# ========================================================
# 【新增】灰色底块与高亮逻辑
# ========================================================

func _add_gray_indicators(item_root: Node3D, start_grid_pos: Vector3i, size: Vector2i):
	# 遍历家具占用的每一个格子
	for x in range(size.x):
		for z in range(size.y):
			var current_grid_pos = start_grid_pos + Vector3i(x, 0, z)
			
			# 创建平面网格
			var mesh_inst = MeshInstance3D.new()
			var plane = PlaneMesh.new()
			plane.size = Vector2(4.0, 4.0) # 假设格子大小是 4x4
			mesh_inst.mesh = plane
			mesh_inst.name = "Indicator_%d_%d" % [x, z]
			
			# 挂载到 item_root 下，这样移动家具时底块也会跟着动
			item_root.add_child(mesh_inst)
			
			# 设置默认材质 (灰色)
			mesh_inst.material_override = _gray_mat
			
			# --- 坐标对齐 (核心) ---
			# 我们需要把底块精准放到对应的格子中心
			# 1. 算出该格子在世界空间的中心
			var cell_world_pos = grid_map.to_global(grid_map.map_to_local(current_grid_pos))
			
			# 2. 转为 item_root 的本地坐标
			var local_pos = item_root.to_local(cell_world_pos)
			
			# 3. 设置位置 (高度稍微比家具原点低一点，或者是地板高度)
			# item_root 的原点通常在地板上或者稍微抬高，我们将指示器放在 item_root 的 y=0 处即可
			# 或者为了防止与地面 Z-fighting，稍微抬高 0.05
			mesh_inst.position = local_pos
			mesh_inst.position.y = 0.05 
			
			# 标记一下，方便后续查找高亮
			mesh_inst.set_meta("is_indicator", true)

# FurnitureSystem.gd

func set_item_highlight(item_root: Node3D, active: bool):
	if not is_instance_valid(item_root): return
	
	for child in item_root.get_children():
		if child is MeshInstance3D and child.has_meta("is_indicator"):
			if active:
				child.material_override = _highlight_mat
			else:
				# 【关键】优先检查是否有分配颜色
				if child.has_meta("assigned_color"):
					child.material_override = child.get_meta("assigned_color")
				else:
					# 没有分配才变回灰色
					child.material_override = _gray_mat
				
func _mark_cells_occupied(grid_pos: Vector3i, size: Vector2i, node_ref: Node3D):
	for x in range(size.x):
		for z in range(size.y):
			var pos = grid_pos + Vector3i(x, 0, z)
			var key = str(pos.x) + "," + str(pos.z)
			occupied_cells[key] = node_ref

func get_furniture_node_at(grid_pos: Vector3i) -> Node3D:
	var key = str(grid_pos.x) + "," + str(grid_pos.z)
	return occupied_cells.get(key, null)


# grid_pos: 格子坐标
# 3. 【核心修复】放置家具时，恢复分配数据
func place_furniture(grid_pos: Vector3i, item_data: Dictionary, is_loading: bool = false) -> bool:
	var size = Vector2i(int(item_data["pos_need_x"]), int(item_data["pos_need_y"]))
	
	if not is_loading:
		if not check_area_available(grid_pos, size, item_data):
			return false

	var item_root = _create_furniture_node(grid_pos, item_data, size)
	var limit = item_data.get("limit", "无")
	if limit == "桌椅":
		item_root.set_meta("needs_cleaning", false)
		item_root.set_meta("occupied_customers", [])
	elif limit == "传菜口":
		item_root.set_meta("pending_pickup", [])
	elif limit == "收银台":
		item_root.set_meta("pay_queue", [])
	
	
	if manager.current_context == RandmapManager.Context.BUZHI:
		_add_gray_indicators(item_root, grid_pos, size)
	
	_mark_cells_occupied(grid_pos, size, item_root)
	
	var furniture_entry = {
		"ID": item_data["ID"],
		"itemtype": item_data["itemtype"],
		"pos": grid_pos,
		"size": [size.x, size.y],
		"node_ref": item_root,
		"limit": item_data.get("limit", "无"),
		"cleanliness": 100.0  # 【新增】添加清洁度，默认100%
	}
	
	placed_furniture_data.append(furniture_entry)
	
	# 【关键】检查是否有保存的分配信息，如果有，立即恢复
	if item_data.has("saved_assignment"):
		var info = item_data["saved_assignment"]
		# 调用分配函数，这会同时更新字典和视觉颜色
		assign_waiter_to_furniture(item_root, info["waiter_id"], info["color"])
		
		# 同时把数据写入 placed_furniture_data 以便存档
		furniture_entry["assigned_waiter_id"] = info["waiter_id"]
		furniture_entry["assigned_waiter_color"] = info["color"].to_html()
	
	if manager.current_context == RandmapManager.Context.GAME_SCENE:
		if item_data.get("limit") == "桌椅":
			_add_table_interaction(item_root)
			 #通知InteractionSystem添加交互
		if manager.interaction_system:
			manager.interaction_system.add_furniture_interaction(item_root, furniture_entry)

	return true

# ========================================================
# 核心功能：移除家具
# ========================================================

# 2. 【核心修复】移除家具时，打包分配数据
func remove_furniture_at(grid_pos: Vector3i) -> Dictionary:
	var item_root = get_furniture_node_at(grid_pos)
	if not item_root: return {}
	
	var data_index = -1
	var removed_data = {}
	
	for i in range(placed_furniture_data.size()):
		if placed_furniture_data[i]["node_ref"] == item_root:
			data_index = i
			removed_data = placed_furniture_data[i].duplicate() # 复制一份
			break
	
	if data_index == -1: return {}

	# 【关键】检查是否有分配信息，如果有，打包进返回数据中
	if furniture_waiter_assignment.has(item_root):
		removed_data["saved_assignment"] = furniture_waiter_assignment[item_root]
		furniture_waiter_assignment.erase(item_root)

	# 清理占用和节点
	var keys_to_erase = []
	for key in occupied_cells:
		if occupied_cells[key] == item_root:
			keys_to_erase.append(key)
	for key in keys_to_erase:
		occupied_cells.erase(key)
		
	placed_furniture_data.remove_at(data_index)
	item_root.queue_free()
	
	return removed_data

# ========================================================
# 辅助逻辑：节点生成与坐标计算
# ========================================================
# FurnitureSystem.gd

func _create_furniture_node(grid_pos: Vector3i, item_data: Dictionary, size: Vector2i) -> Node3D:
	var item_root = Node3D.new()
	item_root.name = "Item_" + str(item_data["itemtype"])
	furniture_holder.add_child(item_root)
	
	# --- 1. 计算在 GridMap 本地坐标系下的理想位置 ---
	var target_pos_on_grid = grid_map.map_to_local(grid_pos)
	var cell_size = grid_map.cell_size.x
	
	# 【核心修复】通用中心对齐公式 (适用于奇数和偶数)
	# 逻辑：从左上角格子的中心，向右下偏移 (尺寸-1)/2 个单位
	# Size 1: 偏移 0
	# Size 2: 偏移 0.5 * cell_size
	# Size 3: 偏移 1.0 * cell_size
	target_pos_on_grid.x += (size.x - 1) * cell_size * 0.5
	target_pos_on_grid.z += (size.y - 1) * cell_size * 0.5
	
	# --- 2. 坐标空间转换过桥 (保持不变) ---
	var global_pos = grid_map.to_global(target_pos_on_grid)
	var final_local_pos = furniture_holder.to_local(global_pos)
	
	# --- 3. 应用高度偏移 (保持不变) ---
	var height = base_height_offset
	if manager.current_context == RandmapManager.Context.BUZHI:
		height = base_height_offset 
		
	item_root.position = final_local_pos + Vector3(0, height, 0)
	
	# --- 加载模型 (保持不变) ---
	var scene_path = ""
	if manager.current_context == RandmapManager.Context.BUZHI:
		scene_path = "res://sc/jiaju_" + str(size.x) + "_" + str(size.y) + ".tscn"
	else:
		scene_path = "res://sc/jiaju_show_" + str(size.x) + "_" + str(size.y) + ".tscn"
	
	var prop_instance = null
	if ResourceLoader.exists(scene_path):
		prop_instance = load(scene_path).instantiate()
		if prop_instance.has_node("pic"):
			var pic = prop_instance.get_node("pic")
			pic.texture = load("res://pic/jiaju/" + item_data["pic"] + ".png")
			# 【核心修复】设置层级和旋转
			if manager.current_context == RandmapManager.Context.GAME_SCENE:
				pic.layers = object_render_layer
				
				# 游戏场景：强制垂直站立
				if pic is Sprite3D:
					pic.billboard = BaseMaterial3D.BILLBOARD_DISABLED
					pic.rotation_degrees = Vector3(0, 0, 0) # 0度是垂直站立
					
			elif manager.current_context == RandmapManager.Context.BUZHI:
				# 布置模式：保持倾斜
				prop_instance.rotation_degrees.x = -45 
	else:
		prop_instance = MeshInstance3D.new()
		prop_instance.mesh = BoxMesh.new()
		prop_instance.scale = Vector3(size.x * 4.0, 2.0, size.y * 4.0)
		
	item_root.add_child(prop_instance)
	
	return item_root



# ========================================================
# 规则检查
# ========================================================

# FurnitureSystem.gd

func check_area_available(grid_pos: Vector3i, size: Vector2i, item_data = null) -> bool:
	for x in range(size.x):
		for z in range(size.y):
			var check_pos = grid_pos + Vector3i(x, 0, z)
			
			# ========== 关键修复：增强(0,0,0)检测 ==========
			if check_pos == Vector3i(0, 0, 0):
				# 特殊处理原点格子
				if grid_map.get_cell_item(check_pos) == GridMap.INVALID_CELL_ITEM:
					print("FurnitureSystem: 警告 - (0,0,0)格子无效，尝试修复")
					if manager.map_system:
						manager.map_system._verify_origin_cell()
	   
			# 1. 检查是否有地板
			# 1. 检查是否有地板
			if grid_map.get_cell_item(check_pos) == GridMap.INVALID_CELL_ITEM:
				# ========== 关键修复：二次验证 ==========
				if manager.map_system and manager.map_system.grid_map.get_cell_item(check_pos) != GridMap.INVALID_CELL_ITEM:
					print("FurnitureSystem: 二次验证通过 - 格子实际存在")
				else:
					return false
			
			# 2. 检查是否被家具占用
			var key = str(check_pos.x) + "," + str(check_pos.z)
			if occupied_cells.has(key):
				return false
			
			# 3. 【核心修复】检查是否被服务生占用
			if manager.waiter_system:
				# WaiterSystem 需要提供一个查询占用的方法
				# 假设 occupied_waiter_cells 是公开的，或者提供 is_cell_occupied
				if manager.waiter_system.occupied_waiter_cells.has(key):
					# 如果是移动已有家具，且家具原本的位置和服务生重叠(这不应该发生)，这里会阻止
					# 但通常移动时家具已被拿起，occupied_cells已清空，只需检查服务生
					return false
			
	# 4. 特殊规则检查
	if item_data:
		var err = validate_placement_rules(grid_pos, item_data)
		if err != "": return false
		
	return true

func validate_placement_rules(grid_pos: Vector3i, item_data: Dictionary) -> String:
	var limit = item_data.get("limit", "无")
	if limit == "无" or limit == "": return ""
	
	# 第一行规则
	if limit in ["收银台", "迎客位", "外卖柜台"]:
		if grid_pos.z != 0: return "只能放在第一行"
		
	# 靠墙规则 (左右边缘)
	if limit in ["传菜口", "厕所"]:
		var size_x = int(item_data["pos_need_x"])
		var left_check = grid_pos + Vector3i(-1, 0, 0)
		var right_check = grid_pos + Vector3i(size_x, 0, 0)
		
		# 检查左边或右边是否没有地板 (即边缘)
		var is_left_edge = (grid_map.get_cell_item(left_check) == GridMap.INVALID_CELL_ITEM)
		var is_right_edge = (grid_map.get_cell_item(right_check) == GridMap.INVALID_CELL_ITEM)
		
		if not is_left_edge and not is_right_edge:
			return "需要靠左右墙边"
			
	return ""

# ========================================================
# 存档与读档
# ========================================================

func save_furniture():
	var save_list = []
	for item in placed_furniture_data:
		var data = {
			"ID": item["ID"],
			"pos": item["pos"],
			"cleanliness": item.get("cleanliness", 100.0)  # 【新增】保存清洁度
		}
		# 保存绑定的服务生
		if furniture_waiter_assignment.has(item["node_ref"]):
			var assign = furniture_waiter_assignment[item["node_ref"]]
			data["assigned_waiter_id"] = assign["waiter_id"]
			data["assigned_waiter_color"] = assign["color"].to_html()
			
		save_list.append(data)
		
	fc.playerData.saved_furniture = save_list
	#print("FurnitureSystem: 已保存 ", save_list.size(), " 个家具")

# FurnitureSystem.gd

func load_furniture_from_global():
	var save_list = fc.playerData.saved_furniture
	if save_list.is_empty():
		print("FurnitureSystem: 存档为空，跳过加载")
		return
	
	#print("--- 开始加载家具 ---")
	
	_clear_all_furniture()
	
	var all_items = fc.load_csv_to_rows("itemData")
	if all_items.is_empty():
		return
		
	var loaded_count = 0
	
	for i in range(save_list.size()):
		var saved_item = save_list[i]
		
		if not saved_item.has("ID"): continue
		
		# ========================================================
		# 【核心修复】ID 格式化 (去除 .0)
		# ========================================================
		var raw_id = saved_item["ID"]
		var target_id = ""
		
		# 1. 如果是浮点数 (1001.0)，先转 int 再转 string，去掉小数
		if typeof(raw_id) == TYPE_FLOAT:
			target_id = str(int(raw_id))
		# 2. 如果是字符串但带小数点 ("1001.0")
		elif typeof(raw_id) == TYPE_STRING and "." in raw_id:
			if raw_id.is_valid_float():
				target_id = str(int(float(raw_id)))
			else:
				target_id = raw_id
		# 3. 其他情况 (整数或纯字符串)
		else:
			target_id = str(raw_id)
			
		# ========================================================
			
		var pos = saved_item["pos"]
		if typeof(pos) != TYPE_VECTOR3I:
			pos = fc.string_to_vector3i_1(pos)
			
		var item_data = {}
		for row in all_items:
			# 表里的 ID 也做同样的净化处理，确保万无一失
			var row_raw_id = row["ID"]
			var row_id_str = ""
			if typeof(row_raw_id) == TYPE_FLOAT:
				row_id_str = str(int(row_raw_id))
			else:
				row_id_str = str(row_raw_id)
				
			if row_id_str == target_id:
				item_data = row.duplicate()
				# 【新增】加载保存的清洁度
				if saved_item.has("cleanliness"):
					item_data["cleanliness"] = saved_item["cleanliness"]
				else:
					item_data["cleanliness"] = 100.0  # 默认值
				
				break
		
		if item_data.is_empty():
			print("匹配失败: ID ", target_id)
			continue
		
		if saved_item.has("assigned_waiter_id"):
			item_data["saved_assignment"] = {
				"waiter_id": saved_item["assigned_waiter_id"],
				"color": Color.from_string(saved_item["assigned_waiter_color"], Color.WHITE)
			}
			
		var success = place_furniture(pos, item_data, true)
		if success: 
			loaded_count += 1
		
		# 【核心新增】放置后，强制清理桌子的占用数据和图片
			# 因为这是刚加载进来，默认为空桌
			if item_data.get("limit") == "桌椅":
				var node = placed_furniture_data.back()["node_ref"]
				_reset_table_state(node)
		
	#print("FurnitureSystem: 加载结束，成功加载 ", loaded_count, " / ", save_list.size())

# 新增辅助函数：重置桌子
# 重置桌子状态（清空占用数据，恢复空桌图片）
func _reset_table_state(table_node: Node3D):
	if not is_instance_valid(table_node): return
	
	
	# 1. 清除占用元数据
	table_node.set_meta("occupied_customers", []) 
	# 2. 清除脏桌子标记
	table_node.set_meta("needs_cleaning", false)
	# 3. 隐藏所有对话图标
	hide_talk_icon(table_node)
	

	# 2. 恢复默认图片 (sit_0.png)
	# 4. 恢复默认图片 (table1.png 是你定义的空桌图片)
	var pic_node = _find_pic_node(table_node)
	if pic_node:
		var path = "res://pic/jiaju/table1.png"
		if ResourceLoader.exists(path):
			pic_node.texture = load(path)
			if manager.current_context == RandmapManager.Context.GAME_SCENE:
				if pic_node is Sprite3D:
					pic_node.billboard = BaseMaterial3D.BILLBOARD_DISABLED
					pic_node.rotation_degrees = Vector3(0, 0, 0)

# --- 辅助函数：递归查找名为 "pic" 的节点 ---
func _find_pic_node(node: Node) -> Node:
	if node.name == "pic": 
		return node
	
	for child in node.get_children():
		var res = _find_pic_node(child)
		if res: 
			return res
			
	return null


func _clear_all_furniture():
	for item in placed_furniture_data:
		if is_instance_valid(item["node_ref"]):
			item["node_ref"].queue_free()
	placed_furniture_data.clear()
	occupied_cells.clear()
	furniture_waiter_assignment.clear()

# ========================================================
# 工具与查询
# ========================================================


func check_limit_exists(limit_name: String) -> bool:
	for item in placed_furniture_data:
		if item["limit"] == limit_name:
			return true
	return false

# 修改_add_table_interaction函数
func _add_table_interaction(node: Node3D):
	# 递归查找并确保Area3D存在
	var area3d = _find_or_create_area3d(node)
	if area3d:
		area3d.collision_layer = 1 << 2  # 设置为第2层
		area3d.collision_mask = 1 << 2

func _find_or_create_area3d(node: Node) -> Area3D:
	# node 是 Item_ 根节点，需要递归查找 MeshInstance3D 下的 Area3D
	
	# 方法1：递归查找所有子节点中的 Area3D
	var area3d = _find_area3d_recursive(node)
	if area3d:
		return area3d
	
	# 方法2：如果没有找到，尝试在第一个子节点的 MeshInstance3D 下查找
	if node.get_child_count() > 0:
		var first_child = node.get_child(0)
		if first_child.has_node("Area3D"):
			return first_child.get_node("Area3D")
		
		# 在所有 MeshInstance3D 子节点下查找
		for child in first_child.get_children():
			if child is MeshInstance3D and child.has_node("Area3D"):
				return child.get_node("Area3D")
	
	# 方法3：如果还是没找到，在所有子节点的 MeshInstance3D 下查找 Area3D
	for child in node.get_children():
		if child is MeshInstance3D:
			if child.has_node("Area3D"):
				return child.get_node("Area3D")
			# 递归查找 MeshInstance3D 的子节点
			for subchild in child.get_children():
				if subchild is Area3D:
					return subchild
	
	# 如果真的没有找到，创建一个新的（作为后备方案）
	print("警告: 未找到预设的 Area3D，创建新的交互区域")
	var area3d_new = Area3D.new()
	area3d_new.name = "InteractionArea"
	node.add_child(area3d_new)
	
	# 添加碰撞形状
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 0.1, 4)  # 根据家具大小调整
	collision_shape.shape = shape
	area3d_new.add_child(collision_shape)
	
	return area3d_new

# 辅助函数：递归查找 Area3D
func _find_area3d_recursive(parent_node: Node) -> Area3D:
	for child in parent_node.get_children():
		if child is Area3D:
			return child
		var result = _find_area3d_recursive(child)
		if result:
			return result
	return null

	
# 添加更新桌子视觉的函数
func update_table_visual(table_node: Node3D):
	var pic_node = table_node.get_child(0).get_node_or_null("pic")

	if not pic_node:
		return
	
	
	# 计算当前总人数
	var total_customers = 0
	if table_node.has_meta("occupied_customers"):
		var occupied_customers = table_node.get_meta("occupied_customers")
		for customer_info in occupied_customers:
			total_customers += customer_info.get("group_size", 1)
	
	
	# 检查是否所有客人都处于用餐状态
	var all_eating = true
	if table_node.has_meta("occupied_customers"):
		var occupied_customers = table_node.get_meta("occupied_customers")
		for customer_info in occupied_customers:
			# 需要通过customer_id找到对应的CustomerData
			var customer_id = customer_info.get("customer_id", "")
			for customer in fc.playerData.waiting_customers:
				if customer.id == customer_id:
					if customer.status != "eating":
						all_eating = false
					break
	
	# 根据状态选择图片
	var pic_path = ""
	if all_eating and total_customers > 0:
		# 所有人都在用餐，显示用餐状态图片
		pic_path = "res://pic/keren/sit_%d_eat.png" % total_customers
	elif total_customers > 0:
		# 有人但没都在用餐，显示普通就座图片
		pic_path = "res://pic/keren/sit_%d.png" % total_customers
	else:
		# 没有人，显示空桌图片
		pic_path = "res://pic/jiaju/table1.png"
	
	# 加载并设置图片
	var texture = load(pic_path)
	if texture:
		pic_node.texture = texture
	else:
		print("FurnitureSystem: 桌子图片不存在: ", pic_path)
	
	## 加载对应的图片
	#var pic_path = "res://pic/keren/sit_%d.png" % total_customers
	#if ResourceLoader.exists(pic_path):
		#pic_node.texture = load(pic_path)
	#else:
		#print("警告: 桌子图片不存在: ", pic_path)
	
	
# 分配服务生到家具
# 1. 【核心修复】分配服务生并改变颜色
func assign_waiter_to_furniture(furniture_root: Node3D, waiter_id: String, color: Color):
	if not is_instance_valid(furniture_root): return
	
	# 记录数据
	furniture_waiter_assignment[furniture_root] = {
		"waiter_id": waiter_id,
		"color": color
	}
	
	# 视觉反馈：遍历子节点找到指示器，并修改材质
	for child in furniture_root.get_children():
		# 我们之前在 _add_gray_indicators 里给这些底块加了 meta 标记
		if child is MeshInstance3D and child.has_meta("is_indicator"):
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.albedo_color.a = 0.6 # 保持半透明
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			
			# 赋值给 override
			child.material_override = mat
			
			# 【关键】更新 item_data 里的记录，确保 set_item_highlight 恢复时能恢复成这个颜色
			# 这样鼠标移开高亮后，它会变回服务生颜色，而不是变回灰色
			child.set_meta("assigned_color", mat)

# 获取分配的服务生ID
func get_assigned_waiter_id(furniture_root: Node3D) -> String:
	if furniture_waiter_assignment.has(furniture_root):
		return furniture_waiter_assignment[furniture_root]["waiter_id"]
	return ""

# FurnitureSystem.gd

# 根据坐标获取家具数据（只读，不删除）
func get_furniture_data_at(grid_pos: Vector3i) -> Dictionary:
	# 1. 先通过坐标找到节点 (利用 occupied_cells 字典)
	var item_root = get_furniture_node_at(grid_pos)
	if not item_root:
		return {}
	
	# 2. 遍历数据列表，找到对应节点的原始数据
	for data in placed_furniture_data:
		if data["node_ref"] == item_root:
			return data
			
	return {}

# 当家具发生变化时，通知 MapSystem 更新寻路数据
func _update_map_pathfinding():
	if manager.map_system:
		manager.map_system.rebuild_empty_cells_map(self)

# 在 place_furniture 的最后调用:
# _update_map_pathfinding()

# 在 remove_furniture_at 的最后调用:
# _update_map_pathfinding()

# --- 新增查询接口 ---

# 获取所有指定类型的家具数据
func get_all_furniture_by_limit(limit_type: String) -> Array:
	var result = []
	for item in placed_furniture_data:
		if item.get("limit") == limit_type:
			result.append(item)
	return result

# 检查节点是否是已被占用的桌子
func is_table_occupied(table_node: Node3D) -> bool:
	if table_node.has_meta("occupied_customers"):
		var list = table_node.get_meta("occupied_customers")
		return list.size() > 0
	return false

# FurnitureSystem.gd
func get_furniture_data_by_node(node: Node3D) -> Dictionary:
	for data in placed_furniture_data:
		if data["node_ref"] == node:
			return data
	return {}


# FurnitureSystem.gd

# 查询全场是否有桌子能容纳这么多人（用于判断 Constraint 2）
func has_table_capacity_for(group_size: int) -> bool:
	var tables = get_all_furniture_by_limit("桌椅")
	if tables.is_empty(): return false
	
	for t in tables:
		# 读取配置表里的最大人数
		var item_cfg = fc.get_row_from_csv_data("itemData", "ID", t["ID"])
		var max_num = int(item_cfg.get("maxnum", 0))
		if max_num >= group_size:
			return true
	return false

# 查找最适合的空桌子（用于 Constraint 3, 4）
func find_best_free_table(group_size: int) -> Dictionary:
	var tables = get_all_furniture_by_limit("桌椅")
	var candidates = []
	
	for t in tables:
		var node = t["node_ref"]
		if not is_instance_valid(node): continue
		
		# 检查是否已被物理占用
		if is_table_occupied(node): continue
		
		# --- 【关键修复】检查是否还没扫 ---
		if node.get_meta("needs_cleaning", false):
			continue
		
		# 检查容量
		var item_cfg = fc.get_row_from_csv_data("itemData", "ID", t["ID"])
		var max_num = int(item_cfg.get("maxnum"))
		
		if max_num >= group_size:
			candidates.append({"data": t, "capacity": max_num})
	
	if candidates.is_empty():
		return {}
		
	# 排序：优先选容量最接近的
	candidates.sort_custom(func(a, b):
		return a.capacity < b.capacity
	)
	
	return candidates[0]["data"]


# 【修改】更新厕所清洁度
func update_toilet_cleanliness(table_node: Node3D, new_cleanliness: float):
	for item in placed_furniture_data:
		if item["node_ref"] == table_node:
			item["cleanliness"] = new_cleanliness
			# 如果正在悬停这个厕所，立即刷新浮动提示面板
			if manager.interaction_system:
				manager.interaction_system.update_furniture_tip_display(table_node)
			break
		



# 【新增】获取厕所清洁度
func get_toilet_cleanliness(table_node: Node3D) -> float:
	var furniture_data = get_furniture_data_by_node(table_node)
	if not furniture_data.is_empty() and furniture_data.get("limit") == "厕所":
		return furniture_data.get("cleanliness", 100.0)
	return 100.0

# 在 furniture_system.gd 中添加这些函数

# 显示对话图标
func show_talk_icon(table_node: Node3D, texture_path: String):
	if not is_instance_valid(table_node):
		return
	
	# 查找或创建 talk 节点
	var shownode = table_node.get_child(0).get_node_or_null("talk")
	# 设置图片
	var texture = load(texture_path)
	if texture:
		shownode.texture = texture
		shownode.visible = true



# 隐藏对话图标
func hide_talk_icon(table_node: Node3D):
	if not is_instance_valid(table_node):
		return
		
	var shownode = table_node.get_child(0).get_node_or_null("talk")
	if shownode:
		shownode.visible = false
		#print("FurnitureSystem: 隐藏对话图标")
