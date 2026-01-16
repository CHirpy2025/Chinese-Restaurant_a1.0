extends Control


@onready var weizhi_show=$Panel/NinePatchRect3/maptitle
@onready var weizhi_bt_last=$Panel/NinePatchRect3/last_map
@onready var weizhi_bt_next=$Panel/NinePatchRect3/next_map

@onready var weizhi_tag=[
	$Panel/NinePatchRect3/show2,
	$Panel/NinePatchRect3/show3
]


@onready var weizhi_diduan=$Panel/NinePatchRect3/editname

@onready var weizhi_zujin=$Panel/NinePatchRect3/needmoney

@onready var show_map=$Panel/NinePatchRect3/show3Dmap

var choicetag=[]
var zujin=0
var base_money=0
var mapMaxID= 0

var is_exiting_to_main = false

func _ready():
	fc._ensure_window_centered()
	
	mapMaxID = fc.load_csv_to_rows("mapinfo").size()
	
	
	
	if fc.playerData.from_main_game==false:
		fc.playerData.step = "第2步"
		$Panel/VBoxContainer/back.visible=false
	else:
		$Panel/VBoxContainer/back.visible=true
	
	weizhi_bt_last.pressed.connect(change_map.bind(-1))
	weizhi_bt_next.pressed.connect(change_map.bind(1))
	
	for i in 2:
		weizhi_tag[i].visible = false

	# 【关键流程】
	# 1. 关闭底图 (调用 show3dmap -> RandmapManager -> MapSystem)
	show_map.closeBase()
	# 2. 生成随机地图
	show_map.generate_random_map()
	
	show_money()
	show_map_info()
	
	# 3. 隐藏不需要的家具容器 (如果存在)
	# 由于架构调整，我们需要通过管理器来找
	await get_tree().process_frame 
	
	# 这里尝试获取 furniture_holder 并隐藏
	var randmap = show_map.get_node("SubViewportContainer/SubViewport/MapHolder/Randmap")
	if randmap and "furniture_holder" in randmap:
		if randmap.furniture_holder:
			randmap.furniture_holder.visible = false

	GuiTransitions.show("showmap")
	await GuiTransitions.show_completed
	
	
	
	
func show_money():
	$Panel/NinePatchRect2/money.text = fc.format_money(fc.playerData.money)
	
	
	
	
func show_map_info():
	var data = fc.get_row_from_csv_data("mapinfo","ID",fc.playerData.choice_map_ID)
	weizhi_show.text = data["city"]

	base_money=int(data["basemoney"])
	
	_on_change_pressed()

# 更换地图逻辑
func _on_change_pressed():
	for i in 2:
		weizhi_tag[i].visible = false
	
	var list = [20]
	#var money_list = [10,30,50,70,90]

	var star_levels = [
		[30],           # 星级 < 1
		[30, 40],       # 星级 < 2
		[30, 40, 50, 60],       # 星级 < 3
		[30, 40, 50, 60, 70, 80],       # 星级 < 4
		[30, 40, 50, 60, 70, 80, 90, 100, 110, 120]  # 星级 >= 4
	]

	var level_index = clamp(fc.playerData.mapStar, 0, 4)
	list.append_array(star_levels[level_index])
	
	var map_num = fc.pick_n_unique_elements(list,1)[0]
	show_map.change_max(map_num)
	
	#抽取tag
	var basedata=fc.load_csv_to_rows("diduan")
	var taglist=[]
	for i in basedata:
		taglist.append(i["name"])
		
	choicetag=[]
	choicetag = fc.pick_n_unique_elements(taglist,randi_range(1,2))
	for i in choicetag.size():
		weizhi_tag[i].get_node("value").text = choicetag[i]
		weizhi_tag[i].visible = true
		
	var tag_value1=0.0
	var tag_value2=0.0
	
	for i in basedata:
		if i["name"]==choicetag[0]:
			tag_value1=float(i["zujin_base"])  
		if choicetag.size()==2:
			if i["name"]==choicetag[1]:
				tag_value2=float(i["zujin_base"])  

	zujin = int((base_money * (1 + (tag_value1 + tag_value2) * 0.9))*map_num*2)
	weizhi_zujin.text = fc.format_money(zujin)
	
	# 【关键调用】更改地图最大块数并重新生成
	


#切换城市
func change_map(type):
	fc.playerData.choice_map_ID+=type
	if fc.playerData.choice_map_ID<1:
		fc.playerData.choice_map_ID = mapMaxID
	if fc.playerData.choice_map_ID == mapMaxID+1:
		fc.playerData.choice_map_ID = 1
	show_map_info()
	
	
	
	

func _on_yes_pressed():
	# 检查是否有旧家具需要处理 (这里涉及家具系统，暂时保留逻辑，只要数据在 fc.playerData 里就是安全的)
	if fc.playerData.saved_furniture.size() != 0:
		fc.show_yesorno("如果要更换店铺，必须把所有的已有家具半价处理掉，确认吗？")
		var the_end = await fc.endshow
		if the_end:
			for i in fc.playerData.saved_furniture:
				var current_item_data = fc.get_row_from_csv_data("itemData", "ID", i["ID"])
				var refund = int(current_item_data["money"] * 0.5)
				fc.playerData.style["烟火气"] -= int(current_item_data["yanhuoqi"])
				fc.playerData.style["时尚度"] -= int(current_item_data["shishangdu"])
				fc.playerData.style["文化感"] -= int(current_item_data["wenhuagan"])
				fc.playerData.style["舒适度"] -= int(current_item_data["shushidu"])
				fc.playerData.style["独特性"] -= int(current_item_data["dutexing"])
				fc.playerData.style["私密性"] -= int(current_item_data["simixing"])
				fc.playerData.money += refund
				
			fc.playerData.saved_furniture = []
			fc.playerData.saved_waiters = []
			set_map()
	else:
		set_map()

func set_map():
	if weizhi_diduan.text=="":
		fc.show_msg("给地段取个名字吧")
		return
	
	fc.playerData.choice_diduan_name=weizhi_diduan.text
	
	fc.playerData.zujin = zujin
	fc.playerData.money -= zujin
	fc.play_se_fx("cash")
	
	# 【关键调用】保存地图
	show_map.savemap()
	
	# 如果有家具数据保存需求，在 savemap 内部已经预留了 save_all_data 的接口
	show_map.save_all_data() 
	
	fc.playerData.choice_diduan_tag=choicetag
	
	
	fc.playerData.from_main_game=false
	fc.save_game(fc.save_num)
	get_tree().change_scene_to_file("res://sc/out_zhuangiu.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
