extends Control

#备菜面板
@onready var beicai_cooking_time=$Panel/base/base/beicai/CookingControlPanel
@onready var beicai_kucun=$Panel/base/base/beicai/StockProgressBarControl
@onready var beicai_price=$Panel/base/base/beicai/PriceSliderControl
@onready var beicai_setINMenu = $Panel/base/base/beicai/setINMenu
@onready var beicai_zhaopai = $Panel/base/base/beicai/zhaopai

@onready var beicai_choice_chef_speed = $Panel/base/base/beicai/chef/speed
@onready var beicai_choice_chef_cooking = $Panel/base/base/beicai/chef/cook
@onready var beicai_choice_chef_next = $Panel/base/base/beicai/chef/next
@onready var beicai_choice_chef_last = $Panel/base/base/beicai/chef/last
@onready var beicai_choice_chef_name = $Panel/base/base/beicai/chef/name
@onready var beicai_cai_pic = $Panel/base/base/beicai/show/pic
@onready var beicai_cai_name = $Panel/base/base/beicai/name/type
@onready var beicai_dish_list = $Panel/base/base/beicai/ScrollContainer/ItemContainer


@onready var other_cai_setINMenu = $Panel/base/base/other/setINMenu

#其他菜准备
@onready var other_cai_name = $Panel/base/base/other/name2/type
@onready var other_cai_time = $Panel/base/base/other/type
@onready var other_cai_pic = $Panel/base/base/other/show/pic
@onready var other_cai_price = $Panel/base/base/other/PriceSliderControl

@onready var other_cai_stock = $Panel/base/base/other/StockProgressBarControl
@onready var other_cai_list = $Panel/base/base/other/ScrollContainer/ItemContainer


@onready var add_total = $Panel/base/base/MenuSystemControl/total_add

var current_dish = 0
var choice_chef_num = 0

@onready var mymoney=$Panel/base/base/MenuSystemControl/NinePatchRect3/money

@export var dish_button_scene: PackedScene  # 拖入你制作好的dish_bt场景文件
@export var dish_group: ButtonGroup       # 创建一个新的ButtonGroup资源并拖入这里
var dish_buttons: Array[BaseButton] = []


# 引用所有按钮（通过编辑器拖拽或代码获取）
@export var buttons: Array[BaseButton] = [

]
var shuaxin=false
@onready var menu_panel=$Panel/base/base/MenuSystemControl
@onready var cai_ready=$Panel/base/base/beicai
@onready var other_ready=$Panel/base/base/other
var tagshow = preload("res://sc/tag_show.tscn")



var checktype=[]
var cai_list=[]
# 当前选中的分类
var current_category = "主菜"
var choice_type_num=0

@onready var caigou_money_show = $Panel/base/base/MenuSystemControl/needmoney
var caigou_money = 0 
var chef_manager
func _ready():
	# 【新增】确保窗口居中
	fc._ensure_window_centered()
	
	
	fc.playerData.step="第8步"
	# 假设这是一道“麻辣香锅”的风味
	for button in buttons:
		button.toggled.connect(_on_button_toggled.bind(button))
		
	beicai_choice_chef_next.pressed.connect(_on_choice_chef.bind(1))
	beicai_choice_chef_last.pressed.connect(_on_choice_chef.bind(-1))
	
	beicai_setINMenu.pressed.connect(setINMenu.bind())
	beicai_zhaopai.pressed.connect(_on_signature_button_pressed.bind())
	
	beicai_cooking_time.cooking_changed.connect(fresh_dish_data_cooking)
	beicai_price.price_changed.connect(fresh_dish_data_price)
	beicai_kucun.stock_changed.connect(fresh_dish_data_stock)
	
	other_cai_setINMenu.pressed.connect(setINMenu.bind())
	other_cai_price.price_changed.connect(fresh_dish_data_price)
	other_cai_stock.stock_changed.connect(fresh_dish_data_stock)
	
	add_total.pressed.connect(addall.bind())
	
	chef_manager = preload("res://sc/chef_manager.gd").new()
	add_child(chef_manager)
	

	cai_ready.visible=false
	menu_panel.visible=false
	other_ready.visible=false
	
	mymoney.text = fc.format_money(fc.playerData.money)
	
	menu_panel.visible=true

	jiesuan_caigou()
	
	
	show_menu()
	
	
	GuiTransitions.show("menu")
	await GuiTransitions.show_completed
	
	
	
func _show_dishes_by_category():
	# 获取当前分类的菜品
	var dishes = fc.dish_data_manager.get_dishes_by_category(current_category)
	
	if current_category=="主菜":
	# 更新菜品列表显示
		_update_dish_list(dishes)
	else:
		_update_dish_list_other(dishes)
	
func _update_dish_list_other(dishes: Array):
	# 清空现有列表
	for child in other_cai_list.get_children():
		child.queue_free()
	
	dish_buttons.clear()
	
	
	for dish_id in dishes:
		
		var new_dish_button = dish_button_scene.instantiate()
		new_dish_button.set_meta("id", dish_id)
		
		# 设置菜品信息
		var dish_info = fc.playerData.Total_dishes_list[dish_id]
		new_dish_button.get_node("name").text = dish_info.get("name", "未知")
		new_dish_button.get_node("pic").texture = load("res://pic/cai/" + str(int(dish_info["base_id"])) + ".png")
		
		# 显示是否在菜单中
		if dish_id in fc.playerData.MYdisheslist:
			new_dish_button.get_node("gou").visible = true
		
		# 连接信号
		new_dish_button.toggled.connect(_on_otherdish_button_toggled.bind(new_dish_button))
		new_dish_button.button_group = dish_group
		
		other_cai_list.add_child(new_dish_button)
		dish_buttons.append(new_dish_button)
	

	# 默认选中第一个
	if dish_buttons.size() > 0:
		dish_buttons[0].set_pressed_no_signal(true)
		_on_otherdish_button_toggled(true, dish_buttons[0])
	
	
	
func _update_dish_list(dishes: Array):
	# 清空现有列表
	for child in beicai_dish_list.get_children():
		child.queue_free()
	
	dish_buttons.clear()
	
	
	for dish_id in dishes:
		
		var new_dish_button = dish_button_scene.instantiate()
		new_dish_button.set_meta("id", dish_id)
		
		# 设置菜品信息
		var dish_info = fc.playerData.Total_dishes_list[dish_id]
		new_dish_button.get_node("name").text = dish_info.get("name", "未知")
		var showpic=int(fc.playerData.Total_dishes_list[dish_id]["base_id"])
		new_dish_button.get_node("pic").texture = load("res://pic/cai/" + str(showpic) + ".png")
		
		# 显示是否在菜单中
		if dish_id in fc.playerData.MYdisheslist:
			new_dish_button.get_node("gou").visible = true
			
		# 连接信号
		new_dish_button.toggled.connect(_on_dish_button_toggled.bind(new_dish_button))
		new_dish_button.button_group = dish_group
		
		beicai_dish_list.add_child(new_dish_button)
		dish_buttons.append(new_dish_button)
	

	# 默认选中第一个
	if dish_buttons.size() > 0:
		dish_buttons[0].set_pressed_no_signal(true)
		_on_dish_button_toggled(true, dish_buttons[0])
	

	
	
# 招牌菜按钮
# 招牌菜按钮
func _on_signature_button_pressed():

	var dish_data = fc.playerData.Total_dishes_list[str(current_dish)]
	var is_signature = dish_data.get("is_signature", false)
	
	if is_signature:
		# 如果当前菜品已经是招牌，取消招牌
		fc.tag_manager.remove_tag_from_dish(current_dish, "本店招牌")
	else:
		# 如果当前菜品不是招牌，先取消所有其他菜品的招牌，再设置当前为招牌
		_clear_all_signature_tags()
		fc.tag_manager.add_tag_to_dish(current_dish, "本店招牌")
	
	# 刷新显示
	_refresh_current_dish_display()

# 新增：清除所有招牌标签
func _clear_all_signature_tags():
	for dish_id_str in fc.playerData.Total_dishes_list:
		var dish_data = fc.playerData.Total_dishes_list[dish_id_str]
		if dish_data.get("is_signature", false):
			fc.tag_manager.remove_tag_from_dish(dish_id_str, "本店招牌")
			#print("取消菜品 ", dish_data.get("name", "未知"), " 的招牌标签")



# 新增：刷新当前菜品显示
func _refresh_current_dish_display():
	# 根据当前所在的界面刷新显示
	if cai_ready.visible:
		# 在主菜界面
		_on_dish_button_toggled(true, _get_current_selected_button())
	elif other_ready.visible:
		# 在其他菜品界面
		_on_otherdish_button_toggled(true, _get_current_selected_button())

# 新增：获取当前选中的按钮
func _get_current_selected_button() -> BaseButton:
	for button in dish_buttons:
		if button.button_pressed:
			return button
	return null

	
	

		
	
func show_menu():
	if fc.playerData.MYdisheslist.size()==0:
		$Panel/base/base/MenuSystemControl/AutoSizeLabel.visible=true
	else:
		$Panel/base/base/MenuSystemControl/AutoSizeLabel.visible=false
	
	
	menu_panel.load_menu()


		
		
func _on_otherdish_button_toggled(button_pressed: bool, button: BaseButton):
	if button_pressed:#显示菜品属性
		current_dish = button.get_meta("id")
		if fc.playerData.MYdisheslist.has(current_dish):
			other_cai_setINMenu.text = "从菜单删除菜品"
		else:
			beicai_setINMenu.text = "把菜品录入菜单"
		var showpic=int(fc.playerData.Total_dishes_list[current_dish]["base_id"])
		other_cai_pic.texture = load("res://pic/cai/"+str(showpic)+".png")
		other_cai_name.text=fc.playerData.Total_dishes_list[current_dish]["name"]
		#价格
		other_cai_price.cost_price = int(fc.playerData.Total_dishes_list[current_dish]["base_price"])
		other_cai_price.price_slider.value = fc.playerData.Total_dishes_list[str(current_dish)]["price"]
		other_cai_price.update_cost_price_indicator()
		other_cai_price.update_current_price_label()
		#时间
		other_cai_time.text = str(fc.playerData.Total_dishes_list[str(current_dish)]["time"])
		#当前数量
		other_cai_stock.set_stock(fc.playerData.Total_dishes_list[str(current_dish)]["stock"],fc.playerData.Total_dishes_list[str(current_dish)]["need_stock"])
		
		for i in $Panel/base/base/other/tag.get_children():
			i.queue_free()
		
		for i in fc.tag_manager.get_dish_tags(current_dish):
			var obj = tagshow.instantiate()
			
			match fc.tag_manager.get_tag_category(i):
				0:
					obj.get_node("bg").self_modulate = Color("5da9e9")
				1:
					obj.get_node("bg").self_modulate = Color("e95d5d")
				2:
					obj.get_node("bg").self_modulate = Color("2c6bab")
				3:
					obj.get_node("bg").self_modulate = Color("bb9770")
			
			obj.get_node("show").text = i
			$Panel/base/base/other/tag.add_child(obj)

		
		
# 9. 信号处理函数：当任意按钮切换状态时调用
func _on_dish_button_toggled(button_pressed: bool, button: BaseButton):
	# 重要：只处理被按下的按钮（button_pressed 为 true 时）
	if button_pressed:#显示菜品属性
		current_dish = button.get_meta("id")
		if fc.playerData.MYdisheslist.has(current_dish):
			beicai_setINMenu.text = "从菜单删除菜品"
		else:
			beicai_setINMenu.text = "把菜品录入菜单"
		
		var showpic=int(fc.playerData.Total_dishes_list[current_dish]["base_id"])
		beicai_cai_pic.texture = load("res://pic/cai/"+str(showpic)+".png")
		beicai_cai_name.text=fc.playerData.Total_dishes_list[str(current_dish)]["name"]

		#价格
		beicai_price.cost_price = int(fc.playerData.Total_dishes_list[str(current_dish)]["base_price"])

		beicai_price.price_slider.value = int(fc.playerData.Total_dishes_list[str(current_dish)]["price"])
		beicai_price.update_cost_price_indicator()
		beicai_price.update_current_price_label()
		#时间

		beicai_cooking_time.initialize_cooking(
			fc.playerData.Total_dishes_list[current_dish]["time"],
			int(fc.playerData.Total_dishes_list[current_dish]["shudu"]),
			int(fc.playerData.Total_dishes_list[current_dish]["shudu_value"]))

		#当前数量
		beicai_kucun.set_stock(fc.playerData.Total_dishes_list[str(current_dish)]["stock"],fc.playerData.Total_dishes_list[str(current_dish)]["need_stock"])
		choice_chef_num=fc.playerData.Total_dishes_list[str(current_dish)]["chef"]
		
		show_new_chef()
		
		for i in $Panel/base/base/beicai/tag.get_children():
			i.queue_free()
		
		
		for i in fc.tag_manager.get_dish_tags(current_dish):
			var obj = tagshow.instantiate()
			
			match fc.tag_manager.get_tag_category(i):
				0:
					obj.get_node("bg").self_modulate = Color("5da9e9")
				1:
					obj.get_node("bg").self_modulate = Color("e95d5d")
				2:
					obj.get_node("bg").self_modulate = Color("2c6bab")
				3:
					obj.get_node("bg").self_modulate = Color("bb9770")
			
			obj.get_node("show").text = i
			$Panel/base/base/beicai/tag.add_child(obj)
			
	


	
	
func show_new_chef():#刷新负责的厨师
	#当前厨师
	var chef=fc.playerData.chefs[choice_chef_num]
	beicai_choice_chef_name.text = chef["name"]
	beicai_choice_chef_speed.value = chef["speed_skill"]
	beicai_choice_chef_cooking.value = chef["cooking_skill"]
	



	
	

func _on_button_toggled(button_pressed: bool, button: BaseButton):
	if button_pressed:
		handle_button_pressed(button)
	
func handle_button_pressed(pressed_button: BaseButton):
	cai_ready.visible=false
	menu_panel.visible=false
	other_ready.visible=false
	
	menu_panel.clear_menu()
	
	other_cai_setINMenu.text = "把菜品录入菜单"
	beicai_setINMenu.text = "把菜品录入菜单"
	match pressed_button.name:
		"type1":
			menu_panel.visible=true
			show_menu()
			add_total.visible=true
		"type2":
			cai_ready.visible=true
			current_category = "主菜"
			_show_dishes_by_category()
		"type3":
			other_ready.visible=true
			current_category = "主食"
			_show_dishes_by_category()
		"type4":
			other_ready.visible=true
			current_category = "小吃"
			_show_dishes_by_category()
		"type5":
			other_ready.visible=true
			current_category = "酒水"
			_show_dishes_by_category()
		"type6":
			other_ready.visible=true
			current_category = "饮料"
			_show_dishes_by_category()
	
	

func _on_choice_chef(num):#切换负责的厨师
	choice_chef_num+=num
	if choice_chef_num==fc.playerData.chefs.size():
		choice_chef_num=0
	elif choice_chef_num<0:
		choice_chef_num=fc.playerData.chefs.size()-1
	fc.playerData.Total_dishes_list[str(current_dish)]["chef"]=choice_chef_num
	show_new_chef()
	
	
	
func fresh_dish_data_cooking():
	var data=beicai_cooking_time.get_cooking_status()
	fc.playerData.Total_dishes_list[str(current_dish)]["shudu"] = data["area"]
	fc.playerData.Total_dishes_list[str(current_dish)]["shudu_value"]=data["percentage"]
	fc.playerData.Total_dishes_list[str(current_dish)]["time"]=data["calculated_time"]


	
func fresh_dish_data_price(price):
	fc.playerData.Total_dishes_list[str(current_dish)]["price"]=int(price)
	
func fresh_dish_data_stock(stock):
	fc.playerData.Total_dishes_list[str(current_dish)]["need_stock"]=int(stock)
	jiesuan_caigou()

	
	
	



func setINMenu():
	var id_int = current_dish # 强转
	if fc.playerData.MYdisheslist.has(id_int):
		var xuhao = fc.playerData.MYdisheslist.find(id_int)
		fc.playerData.MYdisheslist.remove_at(xuhao)
		if current_category=="主菜":
			for i in beicai_dish_list.get_children():
				if i.get_meta("id") in fc.playerData.MYdisheslist:
					i.get_node("gou").visible = true
				else:
					i.get_node("gou").visible = false
			beicai_setINMenu.text = "把菜品录入菜单"
		else:
			for i in other_cai_list.get_children():
				if i.get_meta("id") in fc.playerData.MYdisheslist:
					i.get_node("gou").visible = true
				else:
					i.get_node("gou").visible = false
					
		
			other_cai_setINMenu.text = "把菜品录入菜单"
	else:
		if fc.playerData.MYdisheslist.has(id_int)==false:
			fc.playerData.MYdisheslist.append(id_int)
		
		if current_category=="主菜":
			for i in beicai_dish_list.get_children():
				if i.get_meta("id") in fc.playerData.MYdisheslist:
					i.get_node("gou").visible = true
				else:
					i.get_node("gou").visible = false
			beicai_setINMenu.text = "从菜单删除菜品"
		else:
			for i in other_cai_list.get_children():
				if i.get_meta("id") in fc.playerData.MYdisheslist:
					i.get_node("gou").visible = true
				else:
					i.get_node("gou").visible = false
			
		
		
			other_cai_setINMenu.text = "从菜单删除菜品"
	
	
	jiesuan_caigou()
	
func jiesuan_caigou():
	caigou_money=0
	for i in fc.playerData.MYdisheslist:
		var money = int(fc.playerData.Total_dishes_list[str(i)]["base_price"])*fc.playerData.Total_dishes_list[str(i)]["need_stock"]
		caigou_money+=money
	
	caigou_money_show.text=fc.format_money(caigou_money)



func _on_finish_menu_pressed():
	var check=false
	for i in fc.playerData.MYdisheslist:
		if fc.playerData.Total_dishes_list[i]["category"]=="主菜":
			check=true
			break
	
	if check==false:
		fc.show_msg("开店至少需要在菜单上上架一个主菜！")
		return # 阻止后续代码执行

	
	fc.save_game(fc.save_num)
	# 添加窗口关闭处理
	if fc.playerData.from_main_game==true:
		get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
	else:
		get_tree().change_scene_to_file("res://sc/business_settings.tscn")

func addall():
	for i in fc.playerData.MYdisheslist:
		var newnum=fc.dish_data_manager.get_dish_stock(i)
		newnum+=10
		fc.dish_data_manager.set_dish_stock(i,newnum)
	menu_panel.clear_menu()
	jiesuan_caigou()
	show_menu()
