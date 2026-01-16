extends Control

@onready var showbg=$Panel/base/Control/showBG

@onready var door_nextBT=$Panel/base/showdoor/next
@onready var door_lastBT=$Panel/base/showdoor/last

@onready var wall_nextBT=$Panel/base/showwall/next
@onready var wall_lastBT=$Panel/base/showwall/last

@onready var door_name = $Panel/base/showdoor/base4/name
@onready var door_info = $Panel/base/showdoor/base5/info
@onready var door_need_money = $Panel/base/showdoor/base6/money
@onready var door_need_day = $Panel/base/showdoor/base7/day

@onready var wall_name = $Panel/base/showwall/base4/name
@onready var wall_info = $Panel/base/showwall/base5/info
@onready var wall_need_money = $Panel/base/showwall/base6/money
@onready var wall_need_day = $Panel/base/showwall/base7/day


@onready var mymoney=$Panel/base/NinePatchRect2/money
@onready var need_moeny=$Panel/base/needmoney
@onready var need_day=$Panel/base/needday

var door_id = -1
var wall_id = -1
var old_wall_id = 0

var door_list=[]
var wall_list=[]


var money_door = 0
var money_wall = 0
var day_door = 0
var day_wall = 0


func _ready():
	# 【新增】确保窗口居中
	fc._ensure_window_centered()
	
	fc.playerData.step="第3步"
	wall_nextBT.pressed.connect(change_wall.bind(1))
	wall_lastBT.pressed.connect(change_wall.bind(-1))
	
	door_nextBT.pressed.connect(change_door.bind(1))
	door_lastBT.pressed.connect(change_door.bind(-1))
	
	
	var data = fc.load_csv_to_rows("walldoorData")
	for i in data:
		if i["type"]=="大门":
			if i["lv"]<=fc.playerData.mapStar:
				door_list.append(i["ID"])
		if i["type"]=="墙壁":
			if i["lv"]<=fc.playerData.mapStar:
				wall_list.append(i["ID"])

	for i in door_list.size():
		if door_list[i]==fc.playerData.door_id:
			door_id=i
			break
		
	
	if door_id==-1:
		door_id=0

		
			
			
	for i in wall_list.size():
		if wall_list[i]==fc.playerData.wall_id:
			wall_id=i
			old_wall_id=i
			break
			
	if wall_id==-1:
		wall_id=0

	

	
	
	show_door()
	show_wall()
	jiesuan()
	mymoney.text = fc.format_money(fc.playerData.money)
	
	

		
	GuiTransitions.show("outzhuangxiu")
	await GuiTransitions.show_completed
		
	
func show_door():
	var data = fc.get_row_from_csv_data("walldoorData","ID",door_list[door_id])
	showbg.get_node("UI_3D_Viewer").set_newDoor(data["show"])
	door_name.text  = data["name"]
	door_info.text  = data["info"]
	door_need_money.text  = fc.format_money(int(data["money"]))
	door_need_day.text  = str(data["day"])
	
	if fc.playerData.door_id!=door_list[door_id]:
		money_door = int(data["money"])
		day_door = int(data["day"])
	else:
		money_door = 0
		day_door = 0
	

	jiesuan()

			
func show_wall():
	var data = fc.get_row_from_csv_data("walldoorData","ID",wall_list[wall_id])
	var data2 = fc.get_row_from_csv_data("walldoorData","ID",wall_list[old_wall_id])
	showbg.get_node("UI_3D_Viewer").set_newWall(data2["show"],data["show"])
	old_wall_id=wall_id
	wall_name.text  = data["name"]
	wall_info.text  = data["info"]
	wall_need_money.text  = fc.format_money(int(data["money"]))
	wall_need_day.text  = str(data["day"])
	
	
	if fc.playerData.wall_id!=wall_list[wall_id]:
		money_wall = int(data["money"])
		day_wall = int(data["day"])
	else:
		money_wall = 0
		day_wall = 0
	
	jiesuan()

func change_door(num):
	door_id+=num
	if door_id<0:
		door_id = door_list.size()-1
	elif door_id == door_list.size():
		door_id=0
	
	show_door()
	
	
	
	
func change_wall(num):
	wall_id+=num
	if wall_id<0:
		wall_id = wall_list.size()-1
	elif wall_id == wall_list.size():
		wall_id=0
	
	show_wall()
	
	
	
func jiesuan():
	need_day.text = str(day_door+day_wall)
	need_moeny.text = fc.format_money(money_door+money_wall)
	
	
	
	


func start_zhuangxiu():#决定装修
	#日期流动
	if money_door+money_wall>0:
		var weather_system = load("res://sc/TimeAndWeatherManager.gd").new()
		add_child(weather_system)

		var date=weather_system.calculate_date(day_door+day_wall)
		fc.playerData.game_year = date["year"]
		fc.playerData.game_month= date["month"]
		fc.playerData.game_day = date["day"]
		
		fc.playerData.game_week=weather_system.calculate_weekday(day_door+day_wall)
		
		fc.playerData.money-=money_door+money_wall
		fc.play_se_fx("cash")
	
	var data = fc.load_csv_to_rows("walldoorData")
	if fc.playerData.wall_id!=wall_list[wall_id]:
		for i in data:
			if i["type"]=="墙壁":
				if i["ID"]==fc.playerData.wall_id:
					fc.playerData.style["烟火气"]-=i["yanhuoqi"]
					fc.playerData.style["时尚度"]-=i["shishangdu"]
					fc.playerData.style["文化感"]-=i["wenhuagan"]
					fc.playerData.style["舒适度"]-=i["shushidu"]
					fc.playerData.style["独特性"]-=i["dutexing"]
					fc.playerData.style["私密性"]-=i["simixing"]
				if i["ID"]==wall_list[wall_id]:
					fc.playerData.style["烟火气"]+=i["yanhuoqi"]
					fc.playerData.style["时尚度"]+=i["shishangdu"]
					fc.playerData.style["文化感"]+=i["wenhuagan"]
					fc.playerData.style["舒适度"]+=i["shushidu"]
					fc.playerData.style["独特性"]+=i["dutexing"]
					fc.playerData.style["私密性"]+=i["simixing"]
				
		fc.playerData.wall_id = wall_list[wall_id]
	
	if fc.playerData.door_id != door_list[door_id]:
		for i in data:
			if i["type"]=="大门":
				if i["ID"]==fc.playerData.door_id:
					fc.playerData.style["烟火气"]-=i["yanhuoqi"]
					fc.playerData.style["时尚度"]-=i["shishangdu"]
					fc.playerData.style["文化感"]-=i["wenhuagan"]
					fc.playerData.style["舒适度"]-=i["shushidu"]
					fc.playerData.style["独特性"]-=i["dutexing"]
					fc.playerData.style["私密性"]-=i["simixing"]
				if i["ID"]==door_list[door_id]:
					fc.playerData.style["烟火气"]+=i["yanhuoqi"]
					fc.playerData.style["时尚度"]+=i["shishangdu"]
					fc.playerData.style["文化感"]+=i["wenhuagan"]
					fc.playerData.style["舒适度"]+=i["shushidu"]
					fc.playerData.style["独特性"]+=i["dutexing"]
					fc.playerData.style["私密性"]+=i["simixing"]
					
		fc.playerData.door_id = door_list[door_id]

	fc.save_game(fc.save_num)
	# 添加窗口关闭处理
	if fc.playerData.from_main_game==true:
		get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
	else:
		get_tree().change_scene_to_file("res://sc/inside_zhuangxiu.tscn")
	
	
