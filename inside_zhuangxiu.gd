extends Control

@onready var show_map=$Panel/base/show3Dmap

@onready var showpic=$Panel/base/Control/show

@onready var floor_name = $Panel/base/base4/name
@onready var floor_info = $Panel/base/base5/info
@onready var floor_need_money = $Panel/base/base6/money

@onready var floor_nextBT=$Panel/base/next
@onready var floor_lastBT=$Panel/base/last

@onready var mymoney=$Panel/base/NinePatchRect3/money



var floor_id = 0
var floor_list=[]
var money_floor=0


func _ready():
	# 【新增】确保窗口居中
	fc._ensure_window_centered()
	
	fc.playerData.step="第4步"
	floor_nextBT.pressed.connect(change_floor.bind(1))
	floor_lastBT.pressed.connect(change_floor.bind(-1))
	
	
	var data = fc.load_csv_to_rows("walldoorData")
	for i in data:
		if i["type"]=="地面":
			if i["lv"]<=fc.playerData.mapStar:
				floor_list.append(i["ID"])
	
	for i in floor_list.size():
		if floor_list[i]==fc.playerData.floor_id:
			floor_id=i
			break
	
	
	if floor_id==-1:
		floor_id=0
	
	
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
		
	await get_tree().process_frame
	await get_tree().process_frame
	show_map.closeBase()
	
	# 4. 【关键】等待两帧，确保 GridMap 移动到位

	
	show_floor()

	mymoney.text = fc.format_money(fc.playerData.money)
	
	#await get_tree().process_frame 
	##var jiajuNode=show_map.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap/Floor")
	##if jiajuNode.has_node("FurnitureHolder"):
		##jiajuNode.get_node("FurnitureHolder").visible=false
	#
	
	GuiTransitions.show("showinside")
	await GuiTransitions.show_completed
	
	
	
	
	
func show_floor():
	var data = fc.get_row_from_csv_data("walldoorData","ID",floor_list[floor_id])
	show_map.change_to_floor(data["zhuan_id"])

	
	
	var rock_num=fc.playerData.saved_map.size()
	
	showpic.texture = load("res://pic/floor/"+data["show"]+".jpg")
	
	
	floor_name.text  = data["name"]
	floor_info.text  = data["info"]
	floor_need_money.text  = fc.format_money(int(data["money"])*rock_num*2)

	if fc.playerData.floor_id!=floor_list[floor_id]:
		money_floor = int(data["money"])*rock_num*2
	else:
		money_floor = 0
	
	





func change_floor(num):
	floor_id+=num
	if floor_id<0:
		floor_id = floor_list.size()-1
	elif floor_id == floor_list.size():
		floor_id=0
	
	show_floor()
	
	
	



func _on_yes_pressed():
	if fc.playerData.floor_id != floor_list[floor_id]:
		fc.playerData.money-=money_floor
		fc.play_se_fx("cash")
		var data = fc.load_csv_to_rows("walldoorData")
		for i in data:
			if i["type"]=="地面":
				if i["ID"]==fc.playerData.floor_id:
					fc.playerData.style["烟火气"]-=i["yanhuoqi"]
					fc.playerData.style["时尚度"]-=i["shishangdu"]
					fc.playerData.style["文化感"]-=i["wenhuagan"]
					fc.playerData.style["舒适度"]-=i["shushidu"]
					fc.playerData.style["独特性"]-=i["dutexing"]
					fc.playerData.style["私密性"]-=i["simixing"]
				if i["ID"]==floor_list[floor_id]:
					fc.playerData.style["烟火气"]+=i["yanhuoqi"]
					fc.playerData.style["时尚度"]+=i["shishangdu"]
					fc.playerData.style["文化感"]+=i["wenhuagan"]
					fc.playerData.style["舒适度"]+=i["shushidu"]
					fc.playerData.style["独特性"]+=i["dutexing"]
					fc.playerData.style["私密性"]+=i["simixing"]
		
		fc.playerData.floor_id = floor_list[floor_id]
		fc.save_game(fc.save_num)

		
	if fc.playerData.from_main_game==true:
		get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
	else:
		get_tree().change_scene_to_file("res://sc/buzhi.tscn")
