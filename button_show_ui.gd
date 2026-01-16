extends Window


@onready var info=$DragArea/bg/info
@onready var btlist=$DragArea/bg/GridContainer
var showlist=[
	"地图","外装","内装","家具","配置","招聘","人员","菜单","菜谱","广告","一般","","排行榜","财报","统计","系统","离开","开门关门"
]

var choice_map_window = null


func _ready():
	change_state(fc.playerData.is_open)

	for i in btlist.get_child_count():
		if btlist.get_child(i) is Button:
			btlist.get_child(i).mouse_entered.connect(showtip.bind(i))
			btlist.get_child(i).mouse_exited.connect(endtip.bind())
			btlist.get_child(i).pressed.connect(checkBt.bind(i))
			btlist.get_child(i).set_meta("name",showlist[i])

	
	$DragArea/bg/closeopen.mouse_entered.connect(showtip.bind(17))
	$DragArea/bg/closeopen.mouse_exited.connect(endtip.bind())
	$DragArea/bg/closeopen.pressed.connect(checkBt.bind(17))
	
	
	# 为所有按钮启用Tooltip
	GuiTransitions.show("btshow")
	await GuiTransitions.show_completed

func showtip(num):
	var type=showlist[num]
	match type:
		"地图":
			info.text = "店铺搬家，更换店铺所在地区和铺面大小"
		"外装":
			info.text = "更换店铺的门面和墙壁"
		"内装":
			info.text = "更换店铺的地板"
		"家具":
			info.text = "更换店里的家具，更换家具位置"
		"配置":
			info.text = "把家具配置给服务生"
		"招聘":
			info.text = "招聘服务生或者厨师"
		"人员":
			info.text = "管理已有的员工"
		"菜单":
			info.text = "更换菜单，调整每日进货数量"
		"菜谱":
			info.text = "让厨师研发新的菜式"
		"广告":
			info.text = "在各种渠道推广宣传饭店"
		"一般":
			info.text = "更换营业时间，服务生服饰风格，饭店背景音乐，饭店安保，厕所打扫间隔"
		"财报":
			info.text = "饭店的经营情况财务报告"
		"排行榜":
			info.text = "查看全民美食排行榜上的排名"
		"统计":
			info.text = "饭店的评价和经营统计信息"
		"系统":
			info.text = "音乐音量修改，语言设置"
		"离开":
			info.text = "结束游戏"
		"开门关门":
			if fc.is_within_business_hours(fc.playerData.now_time)==true:
				if fc.playerData.is_open==true:
					info.text = "临时关门修整，可以进行饭店装修或者家具布置，人员安排等事宜"
				else:
					info.text = "继续开门营业，坐等客人上门"
				

func endtip():
	info.text = ""

func checkBt(num):
	var type=showlist[num]
	match type:
		"地图":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/choice_map.tscn")
		"外装":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/out_zhuangiu.tscn")
		"内装":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/inside_zhuangxiu.tscn")
		"家具":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/buzhi.tscn")
		"配置":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/main_management.tscn")
		"招聘":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/schedule_staff.tscn")
		"人员":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/renshi.tscn")
		"菜单":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/management_ui.tscn")
		"菜谱":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/caipu.tscn")
		"广告":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/sp_sevrive.tscn")
		"一般":
			get_tree().get_current_scene().cleanup_and_exit_to_main()
			get_tree().change_scene_to_file("res://sc/business_settings.tscn")
		"财报":
			get_tree().get_current_scene().open_popup_window("caibao")

		"排行榜":
			get_tree().get_current_scene().open_popup_window("paihang")
			
		"统计":
			get_tree().get_current_scene().open_popup_window("tongji")
		"系统":
			get_tree().get_current_scene().open_popup_window("sys")
		"离开":
			_on_exit_to_main_menu()
		"开门关门":
			if fc.is_within_business_hours(fc.playerData.now_time)==true:
				if fc.playerData.is_open==true:
					get_tree().get_current_scene().force_close_restaurant()
				else:
					get_tree().get_current_scene().manually_open_restaurant()
			
			change_state(fc.playerData.is_open)
	
	
	
	
	#
#
					#
					#

func change_state(state):
	if state:#开门
		for i in $DragArea/bg/GridContainer.get_children():
			if i is Button:
				var btname = i.get_meta("name")
				if  btname in ["系统","离开","财报","排行榜","统计"]:
					i.disabled=false
				else:
					i.disabled=true
		
		$DragArea/bg/closeopen.disabled=false
		$DragArea/bg/closeopen.text = "饭店关门修整"
	else:#关门
		for i in $DragArea/bg/GridContainer.get_children():
			if i is Button:
				i.disabled=false

		if fc.is_within_business_hours(fc.playerData.now_time)==false:
			$DragArea/bg/closeopen.disabled=true
			$DragArea/bg/closeopen.text = "等待营业时间到"
		else:
			$DragArea/bg/closeopen.text = "重新开门营业"
			$DragArea/bg/closeopen.disabled=false
			
	



# 新增：处理退出到主菜单的函数
func _on_exit_to_main_menu():
	#print("🚨 收到退出到主菜单信号")
	# 获取main_game_sc的引用
	var main_game = get_tree().get_current_scene()
	if main_game.has_method("cleanup_and_exit_to_main"):
		# 【关键】标记正在退出，避免重复清理
		var choice_map_instance = choice_map_window.get_child(0)
		choice_map_instance.is_exiting_to_main = true
		main_game.cleanup_and_exit_to_main()

	
