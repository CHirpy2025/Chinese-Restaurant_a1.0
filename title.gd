extends Control

@export var showlogo:Node
@onready var inputname=$mainTitle/base/editname
@onready var loadBT=$mainTitle/saveload/VBoxContainer/load
@onready var saveBT=$mainTitle/saveload/VBoxContainer/new

@onready var yesbt=$mainTitle/base/yesBT


func _ready():
	loadBT.pressed.connect(saveload.bind())
	saveBT.pressed.connect(start_new_game.bind())
	
	
	GuiTransitions.show("logo1")
	await GuiTransitions.show_completed
	await get_tree().create_timer(0.5).timeout
	GuiTransitions.hide("logo1")
	await GuiTransitions.hide_completed
	await get_tree().create_timer(0.5).timeout
	
	GuiTransitions.show("logo2")
	await GuiTransitions.show_completed
	await get_tree().create_timer(1).timeout
	
	$mainTitle.visible=true
	
	if fc.check_save(fc.save_num):
		GuiTransitions.show("saveload")
		await GuiTransitions.show_completed
	else:
		$mainTitle/saveload.visible=false
		start_new_game()
		




func saveload():
	fc.load_game(fc.save_num)
	await get_tree().create_timer(0.1).timeout
	

	if fc.playerData.from_main_game==false:
		match fc.playerData.step:
			"第1步":
				get_tree().change_scene_to_file("res://sc/choice_map.tscn")#选地图
			"第2步":
				get_tree().change_scene_to_file("res://sc/out_zhuangiu.tscn")#外装
			"第3步":
				get_tree().change_scene_to_file("res://sc/inside_zhuangxiu.tscn")#内装
			"第4步":
				get_tree().change_scene_to_file("res://sc/buzhi.tscn")#布置桌椅
			"第5步":
				get_tree().change_scene_to_file("res://sc/schedule_staff.tscn")#招聘
			"第6步":
				get_tree().change_scene_to_file("res://sc/main_management.tscn")#安放人员
			"第7步":
				get_tree().change_scene_to_file("res://sc/management_ui.tscn")#菜单
			"第8步":
				get_tree().change_scene_to_file("res://sc/business_settings.tscn")#其他设定
			"第9步":
				get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")#其他设定
	else:
		get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
	
	
		
func start_new_game():
	GuiTransitions.show("nameedit")
	await GuiTransitions.show_completed
	
	




func _on_open_pressed():
	showlogo.save_num = 0
	showlogo._on_SelectImageButton_pressed()
	
func _on_del_pressed():
	showlogo.save_num = 0
	showlogo.delete_saved_image()



func _on_yes_pressed():
	if inputname.text=="":
		fc.show_msg(tr("nameerror"))
		await fc.endshow
	else:
		fc.playerData.name = inputname.text
		fc.playerData.pic = showlogo.check_pic()
		paihang.generate_virtual_restaurants()
		
		#创建初始菜单
		fc.dish_data_manager.unlock_dish(1001)
		fc.dish_data_manager.unlock_dish(2001)
		fc.dish_data_manager.unlock_dish(3001)
		fc.dish_data_manager.unlock_dish(4001)

		
		get_tree().change_scene_to_file("res://sc/choice_map.tscn")
		
