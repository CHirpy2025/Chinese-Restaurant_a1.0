extends Control

@onready var style= $Panel/base/base2/name
@onready var style_nextBT=$Panel/base/next
@onready var style_lastBT=$Panel/base/last
@onready var mymoney=$Panel/base/NinePatchRect3/money
@onready var zhishu=$Panel/base/fengge
@onready var show_jiaju=$Panel/base/showjiaju/jiaju

@onready var show_map=$Panel/base/show3Dmap # 这是 show3dmap.gd

var itemBT = preload("res://sc/jiaju_bt.tscn")

@onready var check_tag_node = $Panel/base/checktag
@onready var btn_next_scene = $Panel/base/yes

# 资源预加载
var tex_yes = preload("res://pic/ui/yesBT.png")
var tex_no = preload("res://pic/ui/no.png")

# Tips相关
var tips_instance: Control = null
var last_hovered_item_root: Node3D = null

# 节点名映射
var limit_check_map = {
	"check1": "收银台",
	"check2": "迎客位",
	"check3": "厕所",
	"check4": "传菜口"
}

# 道具相关变量
var current_item = null
var item_sprite: TextureRect
var is_placing = false
var show_3dmap_node: Control # 这个其实就是 show_map，为了兼容你的代码习惯保留变量名
var current_item_data = null  
var style_list=[]
var style_id = -1

# [新增变量] 移动逻辑的核心：记录家具移动前的数据，用于右键取消时复原
var original_move_data: Dictionary = {}

# 出售相关
@export var sell_area_node: NinePatchRect
var is_moving_existing: bool = false
const SELL_REFUND_RATIO: float = 0.5 

func _ready():
	fc._ensure_window_centered()
	fc.playerData.step="第5步"
	
	# 引用赋值
	show_3dmap_node = $Panel/base/show3Dmap
	
	style_nextBT.pressed.connect(change_style.bind(1))
	style_lastBT.pressed.connect(change_style.bind(-1))
	if btn_next_scene:
		btn_next_scene.pressed.connect(_on_go_next_pressed)
	
	# 初始化拖拽图标
	item_sprite = TextureRect.new()
	item_sprite.visible = false
	item_sprite.z_index = 100 
	item_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE # 关键：防止图标阻挡射线检测
	add_child(item_sprite)
	

# ========================================================
	# 【核心修复】严格的初始化顺序
	# ========================================================
	var randmap_manager = show_map.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap")
	
	if randmap_manager:
		# 1. 初始化管理器
		randmap_manager.setup_for_context(RandmapManager.Context.BUZHI)
		
		# 2. 加载地图形状
		if randmap_manager.map_system:
			randmap_manager.map_system.load_map()
	
# 3. 调整视口 (移动 GridMap)
	if show_map.has_method("set_viewport"):
		show_map.set_viewport()
	elif show_map.has_method("set_viewpot"):
		show_map.set_viewpot()
	show_map.closeBase()
	
	# 4. 【关键】等待两帧，确保 GridMap 移动到位
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 初始化风格列表
	var data = fc.load_csv_to_rows("walldoorData")
	for i in data:
		if i["type"]=="风格":
			if i["lv"]<=fc.playerData.mapStar:
				style_list.append(i["ID"])
	
	for i in style_list.size():
		if style_list[i]==fc.playerData.style_id:
			style_id=i
			break
	if style_id==-1: style_id=0
	

	
# 5. 加载家具和服务生 (此时坐标才准确)
	if randmap_manager:
		if randmap_manager.furniture_system:
			randmap_manager.furniture_system.load_furniture_from_global()
			
		# 【新增】必须加载服务生，否则 check_area_available 检测不到服务生占用
		if randmap_manager.waiter_system:
			randmap_manager.waiter_system.load_waiters_from_global()
	
	show_newinfo()
	show_style()
	
	# 初始化 Tips
	var tips_scene = load("res://sc/show_tips.tscn")
	if tips_scene:
		tips_instance = tips_scene.instantiate()
		tips_instance.visible = false
		tips_instance.z_index = 200
		tips_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tips_instance)

	GuiTransitions.show("buzhi")
	await GuiTransitions.show_completed

func show_style():
	for i in show_jiaju.get_children():
		i.queue_free()
	
	var data = fc.get_row_from_csv_data("walldoorData","ID",style_list[style_id])
	style.text  = data["name"]
	
	var itemlist=[]
	var itemdata = fc.load_csv_to_rows("itemData")
	for i in itemdata:
		if i["type"]== data["name"]:
			itemlist.append(i)
	
	for i in itemlist:
		var item = itemBT.instantiate()
		item.get_node("name").text = i["itemtype"]
		item.get_node("money").text = fc.format_money(int(i["money"]))
		item.get_node("pos").text = str(i["pos_need_x"])+"x"+str(i["pos_need_y"])
		item.get_node("pic").texture = load("res://pic/jiaju/"+i["pic"]+".png")
		
		item.pressed.connect(_on_item_button_pressed.bind(i))
		show_jiaju.add_child(item)
		
	update_checklist_status()

func change_style(num):
	style_id+=num
	if style_id<0:
		style_id = style_list.size()-1
	elif style_id == style_list.size():
		style_id=0
	show_style()

# buzhi.gd

# 道具按钮点击事件
func _on_item_button_pressed(item_data: Dictionary):
	# ========================================================
	# [修复] 唯一性检查 (Limit Check)
	# ========================================================
	var limit_type = item_data.get("limit", "无") # 获取配置的 limit 属性
	
	# 【核心修复】定义哪些类型是全图只能有一个的 (黑名单)
	# 只有在这个列表里的类型，才会被检查唯一性
	var unique_types = ["收银台", "迎客位", "厕所", "传菜口", "外卖柜台"]
	
	# 检查逻辑改为：只有当它是“无”以外，且在“唯一列表”中时，才检查是否存在
	if limit_type != "无" and limit_type != "" and (limit_type in unique_types):
		# 询问 show3dmap 场景里是否已经有了
		if show_3dmap_node.is_limit_exist(limit_type):
			# 触发错误提示
			fc.show_msg("场景里已经有" + limit_type + "了，不用再摆放了。")
			await fc.endshow # 等待提示结束
			return # [关键] 直接返回，不再进入放置模式
	
	# ========================================================
	# 下面是正常的放置逻辑 (保持不变)
	# ========================================================
	current_item = item_data["itemtype"]
	current_item_data = item_data
	is_placing = true
	is_moving_existing = false # 标记为新购买
	original_move_data.clear()
	
	_update_drag_icon(item_data)

func _update_drag_icon(item_data):
	var item_texture = load("res://pic/jiaju/" + item_data["pic"] + ".png")
	item_sprite.texture = item_texture
	var base_size = 800
	item_sprite.size = Vector2(base_size, base_size)
	item_sprite.scale = Vector2(0.1, 0.1)
	item_sprite.pivot_offset = item_sprite.size / 2
	item_sprite.visible = true

func _input(event):
	# ==========================================================
	# 状态 A: 正在布置/移动中
	# ==========================================================
	if is_placing and current_item_data:
		
		if event is InputEventMouseMotion:
			var mouse_pos = get_global_mouse_position()
			# 更新图标位置 (居中)
			item_sprite.global_position = mouse_pos - (item_sprite.size * item_sprite.scale / 2)
			
			# 1. 检测是否在出售区域内
			var in_sell_zone = false
			if sell_area_node and sell_area_node.get_global_rect().has_point(mouse_pos):
				in_sell_zone = true
			
			if in_sell_zone:
				show_3dmap_node.hide_ghost()
				item_sprite.visible = true
				sell_area_node.modulate = Color(1, 0.5, 0.5) 
			else:
				if sell_area_node: sell_area_node.modulate = Color(1, 1, 1) 
				
				# 更新3D幽灵 (调用 show3dmap -> RandmapManager -> FurnitureSystem 检查)
				var is_in_3d_view = show_3dmap_node.update_placement_ghost(mouse_pos, current_item_data)
				
				if is_in_3d_view:
					item_sprite.visible = false
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) 
				else:
					item_sprite.visible = true
					show_3dmap_node.hide_ghost()

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_pos = get_global_mouse_position()
			
			# 2. 优先检测出售
			if sell_area_node and sell_area_node.get_global_rect().has_point(mouse_pos):
				_perform_sell()
			else:
				# 3. 正常放置
				var success = show_3dmap_node.try_place_current_item(mouse_pos, current_item_data)
				if success:
					#print("放置成功")
					fc.play_se_fx("cash")
					
					# 只有是新买的才扣钱
					if not is_moving_existing:
						_apply_purchase_cost()
					
					original_move_data.clear() # 落定后清除撤销数据
					show_newinfo()
					update_checklist_status()
					cancel_placement()
				else:
					fc.play_se_fx("quxiao") # 播放失败音效

		# 4. 右键取消 (撤销)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_cancel_placement()

	# ==========================================================
	# 状态 B: 空闲状态 (检测鼠标悬停高亮 & 拾取)
	# ==========================================================
	elif not is_placing:
		if event is InputEventMouseMotion:
			var mouse_pos = get_global_mouse_position()
			# show3dmap.update_hover_highlight 现在应该返回高亮的节点 (item_root)
			var item_root = show_3dmap_node.update_hover_highlight(mouse_pos)
			
			# Tips 逻辑
			if item_root and tips_instance:
				if item_root != last_hovered_item_root:
					_update_tips_content(item_root)
					last_hovered_item_root = item_root
				
				tips_instance.visible = true
				tips_instance.global_position = mouse_pos + Vector2(20, -100)
			else:
				if tips_instance: tips_instance.visible = false
				last_hovered_item_root = null
			
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_pos = get_global_mouse_position()
			# 尝试拾取 (调用 show3dmap -> FurnitureSystem.remove_furniture_at)
			# 注意：remove_furniture_at 会把家具删掉并返回数据
			var picked_data = show_3dmap_node.try_pick_up_item(mouse_pos)
			if not picked_data.is_empty():
				_start_moving_item(picked_data)

# [关键修改] 处理取消放置/撤销移动
func _handle_cancel_placement():
	# 如果正在移动旧家具，取消意味着“放回原位”
	if is_moving_existing and not original_move_data.is_empty():
		#print("撤销移动，放回原位")
		var randmap_manager = show_3dmap_node.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap")
		if randmap_manager and randmap_manager.furniture_system:
			# 强行放回原位（is_loading=true 表示不扣钱，不检查复杂规则）
			randmap_manager.furniture_system.place_furniture(original_move_data["pos"], current_item_data, true)
			
	cancel_placement()

func cancel_placement():
	is_placing = false
	is_moving_existing = false
	original_move_data.clear()
	
	item_sprite.visible = false
	current_item = null
	current_item_data = null
	show_3dmap_node.hide_ghost()
	if sell_area_node: sell_area_node.modulate = Color(1, 1, 1)

# 开始移动家具
func _start_moving_item(saved_data: Dictionary):
	# 1. 查找完整静态数据
	var full_data = {}
	var all_items = fc.load_csv_to_rows("itemData")
	for item in all_items:
		if str(item["ID"]) == str(saved_data["ID"]):
			full_data = item.duplicate()
			break
			
	if full_data.is_empty():
		return
	
	# ========================================================
	# 【核心修复】保留分配数据
	# ========================================================
	# saved_data 是从 FurnitureSystem.remove_furniture_at 返回的
	# 里面包含了我们刚才打包的 saved_assignment
	if saved_data.has("saved_assignment"):
		#print("DEBUG: 正在移动带有服务生的家具")
		full_data["saved_assignment"] = saved_data["saved_assignment"]
	# ========================================================

	if tips_instance: tips_instance.visible = false
	last_hovered_item_root = null

	original_move_data = saved_data.duplicate()

	current_item = full_data["itemtype"]
	current_item_data = full_data # 这里现在包含了 saved_assignment
	is_placing = true
	is_moving_existing = true 
	
	_update_drag_icon(full_data)
	
	fc.play_se_fx("click")
	update_checklist_status()

# [修改] 更新 Tips 内容
# 由于 RandmapManager 结构改变，我们需要从 FurnitureSystem 查找数据
func _update_tips_content(item_root: Node3D):
	var randmap_manager = show_3dmap_node.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap")
	if not randmap_manager or not randmap_manager.furniture_system:
		return

	# 遍历 FurnitureSystem 的数据查找对应的 item_root
	var saved_data = {}
	for data in randmap_manager.furniture_system.placed_furniture_data:
		if data["node_ref"] == item_root:
			saved_data = data
			break
	
	if saved_data.is_empty():
		return

	# 获取完整静态数据
	var full_data = {}
	var all_items = fc.load_csv_to_rows("itemData")
	for item in all_items:
		if str(item["ID"]) == str(saved_data["ID"]):
			full_data = item
			break
	
	if full_data.is_empty():
		return

	# 更新 UI
	if tips_instance.has_node("value/name"):
		tips_instance.get_node("value/name").text = str(full_data.get("itemtype", ""))
	if tips_instance.has_node("value/style"):
		tips_instance.get_node("value/style").text = str(full_data.get("type", ""))
	if tips_instance.has_node("value/money"):
		@warning_ignore("integer_division")
		var half_price = int(full_data.get("money", 0)) / 2
		tips_instance.get_node("value/money").text = str(half_price)

# 更新 limit 图标状态
func update_checklist_status():
	if not check_tag_node: return

	for node_name in limit_check_map:
		var limit_name = limit_check_map[node_name]
		# 这里的 is_limit_exist 会透传到 FurnitureSystem
		var exists = show_3dmap_node.is_limit_exist(limit_name)
		var pic_node = check_tag_node.get_node_or_null(node_name + "/pic")
		if pic_node:
			pic_node.texture = tex_yes if exists else tex_no

func show_newinfo():
	var showzhishu = ["烟火气", "时尚度", "文化感", "舒适度", "独特性", "私密性"]
	for i in 6:
		var value = fc.playerData.style[showzhishu[i]]
		zhishu.get_child(i).set_value_sp(value)
	mymoney.text=fc.format_money(fc.playerData.money)

# 执行出售逻辑
func _perform_sell():
	if not current_item_data: return
	
	var original_price = int(current_item_data["money"])
	var refund = int(original_price * SELL_REFUND_RATIO)
	
	if is_moving_existing:
		fc.playerData.style["烟火气"] -= int(current_item_data["yanhuoqi"])
		fc.playerData.style["时尚度"] -= int(current_item_data["shishangdu"])
		fc.playerData.style["文化感"] -= int(current_item_data["wenhuagan"])
		fc.playerData.style["舒适度"] -= int(current_item_data["shushidu"])
		fc.playerData.style["独特性"] -= int(current_item_data["dutexing"])
		fc.playerData.style["私密性"] -= int(current_item_data["simixing"])
		fc.play_se_fx("cash")
		fc.playerData.money += refund
		update_checklist_status()
	
	show_newinfo()
	cancel_placement()

# 购买扣费
func _apply_purchase_cost():
	fc.playerData.money -= int(current_item_data["money"])
	fc.playerData.style["烟火气"] += int(current_item_data["yanhuoqi"])
	fc.playerData.style["时尚度"] += int(current_item_data["shishangdu"])
	fc.playerData.style["文化感"] += int(current_item_data["wenhuagan"])
	fc.playerData.style["舒适度"] += int(current_item_data["shushidu"])
	fc.playerData.style["独特性"] += int(current_item_data["dutexing"])
	fc.playerData.style["私密性"] += int(current_item_data["simixing"])

# 切换场景检查
func _on_go_next_pressed():
	var required_limits = ["收银台", "迎客位", "传菜口", "厕所"]
	for limit_name in required_limits:
		if not show_3dmap_node.is_limit_exist(limit_name):
			fc.play_se_fx("quxiao")
			fc.show_msg("缺少开店必须的【" + limit_name + "】，请检查。")
			await fc.endshow
			return
	
	if show_3dmap_node:
		show_3dmap_node.save_all_data()
	
	fc.play_se_fx("click")
	fc.save_game(fc.save_num)

	if fc.playerData.from_main_game==true:
		get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
	else:
		get_tree().change_scene_to_file("res://sc/schedule_staff.tscn")
