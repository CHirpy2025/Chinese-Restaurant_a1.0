extends Control


# 新增：用于记录基准状态
var base_salary: float = 0.0
var base_stress: float = 0.0

# 新增：压力系数配置（每500元变动多少压力）
# 你可以把它暴露到编辑器，或者写死
const STRESS_FACTOR_PER_500: float = 5.0 
@export var buttons: Array[BaseButton] = [

]
var chef_manager
var waiter_manager

@onready var show_name=$Panel/base/name
@onready var jiegu_bt=$Panel/base/jiegu
@onready var next_bt=$Panel/base/next
@onready var last_bt=$Panel/base/last
@onready var showpic=$Panel/base/showpic
#厨师参数
@onready var chef_data_age=$Panel/base/chef/base5/age
@onready var chef_data_salary_day=$Panel/base/chef/base6/time
@onready var chef_data_pay=$Panel/base/chef/pay
@onready var chef_data_payshow=$Panel/base/chef/money
@onready var chef_data_cooking_skill=$Panel/base/chef/GridContainer/shuxing/value
@onready var chef_data_innovation_skill=$Panel/base/chef/GridContainer/shuxing2/value
@onready var chef_data_speed_skill=$Panel/base/chef/GridContainer/shuxing3/value
@onready var chef_data_yali=$Panel/base/chef/GridContainer/shuxing4/value

@onready var chef_data_skill=[
	$Panel/base/chef/jineng/jineng,
	$Panel/base/chef/jineng/jineng2,
	$Panel/base/chef/jineng/jineng3,
	$Panel/base/chef/jineng/jineng4
	]
#服务生参数
@onready var waiter_data_salary_day=$Panel/base/fuwusheng/base6/time
@onready var waiter_data_pay=$Panel/base/fuwusheng/pay
@onready var waiter_data_payshow=$Panel/base/fuwusheng/money
@onready var waiter_data_speed=$Panel/base/fuwusheng/GridContainer/shuxing/value
@onready var waiter_data_charm=$Panel/base/fuwusheng/GridContainer/shuxing2/value
@onready var waiter_data_affinity=$Panel/base/fuwusheng/GridContainer/shuxing3/value
@onready var waiter_data_yali=$Panel/base/fuwusheng/GridContainer/shuxing4/value

@onready var waite_data_skill=[
	$Panel/base/fuwusheng/jineng/jineng,
	$Panel/base/fuwusheng/jineng/jineng2,
	$Panel/base/fuwusheng/jineng/jineng3,
	]


@onready var chef_data=$Panel/base/chef
@onready var waiter_data=$Panel/base/fuwusheng
var choice_num=0
var choice_state=0

func _ready():
	# 【新增】确保窗口居中
	fc._ensure_window_centered()
	
	chef_manager = preload("res://sc/chef_manager.gd").new()
	add_child(chef_manager)
	
	waiter_manager = preload("res://sc/WaiterGenerator.gd").new()
	add_child(waiter_manager)
	
	for button in buttons:
		button.toggled.connect(_on_button_toggled.bind(button))
	
	
	jiegu_bt.pressed.connect(jiegu_npc)
	
	last_bt.pressed.connect(change_choice.bind(-1))
	next_bt.pressed.connect(change_choice.bind(1))
	
	_on_button_toggled(true,buttons[0])
	
	chef_data_pay.value_changed.connect(_on_chef_pay_change)
	waiter_data_pay.value_changed.connect(_on_waiter_pay_change)
	
	
	
func change_choice(value):
	choice_num+=value
	if choice_state==0:
		if choice_num==fc.playerData.chefs.size():
			choice_num=0
		elif choice_num<0:
			choice_num=fc.playerData.chefs.size()-1
		show_chef_data()
		
	else:
		if choice_num==fc.playerData.waiters.size():
			choice_num=0
		elif choice_num<0:
			choice_num=fc.playerData.waiters.size()-1
		
		show_waiter_data()
	
	
	
	

func _on_button_toggled(button_pressed: bool, button: BaseButton):
	if button_pressed:
		handle_button_pressed(button)
	
func handle_button_pressed(pressed_button: BaseButton):
	chef_data.visible=false
	waiter_data.visible=false
	choice_num=0
	match pressed_button.name:
		"type1":
			choice_state=0
			chef_data.visible=true
			show_chef_data()
		"type2":
			choice_state=1
			waiter_data.visible=true
			show_waiter_data()
			




func show_chef_data():
	var chef=fc.playerData.chefs[choice_num]
	show_name.text = chef["name"]
	showpic.texture = load(chef["avatar_path"])
	
	chef_data_age.text = str(chef["age"])
	chef_data_salary_day.text = "每月"+str(chef["salary_day"])+"日"
	
	# --- 修改开始 ---
	# 1. 记录基准数据
	base_salary = chef["salary"]
	base_stress = chef["yali"]
	
	# 2. 设置滚动条值（这里会触发 value_changed 信号，所以要确保基准值先设置好）
	chef_data_pay.value = base_salary
	chef_data_payshow.text = fc.format_money(int(base_salary))
	
	chef_data_cooking_skill.value = chef["cooking_skill"]
	chef_data_innovation_skill.value = chef["innovation_skill"]
	chef_data_speed_skill.value = chef["speed_skill"]
	chef_data_yali.value = chef["yali"]
	for i in 4:
		chef_data_skill[i].visible=false
	
	var num=0
	for cuisine_type in chef.cuisines:
		var level = chef.cuisines[cuisine_type]
		var cuisine_name = chef_manager.CUISINE_NAMES[int(cuisine_type)]
		chef_data_skill[num].visible=true
		chef_data_skill[num].get_node("value2").value = chef["cuisines_experience"][num]
		chef_data_skill[num].get_node("type").text = cuisine_name
		chef_data_skill[num].get_node("lv").set_rating(float(level*0.5))
		num+=1
		

func _on_chef_pay_change(new_value: float):
	# 1. 计算薪资变化了多少
	var salary_diff = new_value - base_salary
	var calculated_stress = base_stress - (salary_diff / 500.0) * STRESS_FACTOR_PER_500
	
	# 3. 钳制压力在 0-100 之间
	var final_stress = clamp(calculated_stress, 0.0, 100.0)
	
	# 4. 更新 target_employee (如果你的其他逻辑需要用到这个节点)
	# 5. 更新数据字典
	var chef = fc.playerData.chefs[choice_num]
	chef["salary"] = int(new_value)
	chef["yali"] = int(final_stress)
	fc.playerData.chefs[choice_num] = chef
	
	# 6. 更新界面显示
	# 只更新数值，不要调用 show_chef_data()！
	chef_data_payshow.text = fc.format_money(int(new_value))
	chef_data_yali.value = final_stress
	


func _on_waiter_pay_change(new_value: float):
	# 1. 计算薪资变化了多少
	var salary_diff = new_value - base_salary
	var calculated_stress = base_stress - (salary_diff / 500.0) * STRESS_FACTOR_PER_500
	
	# 3. 钳制压力在 0-100 之间
	var final_stress = clamp(calculated_stress, 0.0, 100.0)
	
	# 4. 更新 target_employee (如果你的其他逻辑需要用到这个节点)
	# 5. 更新数据字典
	var waiter = fc.playerData.waiters[choice_num]
	waiter["salary"] = int(new_value)
	waiter["yali"] = int(final_stress)
	fc.playerData.waiters[choice_num] = waiter
	
	# 6. 更新界面显示
	# 只更新数值，不要调用 show_chef_data()！
	waiter_data_payshow.text = fc.format_money(int(new_value))
	waiter_data_yali.value = final_stress

	
	
	
func show_waiter_data():
	var waiter=fc.playerData.waiters[choice_num]
	show_name.text = waiter["name"]
	showpic.texture = load(waiter["avatar_path"])
	

	waiter_data_salary_day.text = "每月"+str(waiter["salary_day"])+"日"
	
	# --- 修改开始 ---
	# 1. 记录基准数据
	base_salary = waiter["salary"]
	base_stress = waiter["yali"]
	
	# 2. 设置滚动条值（这里会触发 value_changed 信号，所以要确保基准值先设置好）
	waiter_data_pay.value = base_salary
	waiter_data_payshow.text = fc.format_money(int(base_salary))
 
	waiter_data_speed.value = waiter["speed"]
	waiter_data_charm.value = waiter["charm"]
	waiter_data_affinity.value = waiter["affinity"]
	waiter_data_yali.value = waiter["yali"]
	for i in 3:
		waite_data_skill[i].visible=false
	
	var num=0
	for skill in waiter.skills:
		var level = waiter.skills[skill]
		waite_data_skill[num].visible=true
		waite_data_skill[num].get_node("value2").value = waiter["skill_experience"][num]
		waite_data_skill[num].get_node("lv").set_rating(float(level*0.5))
		num+=1
		
		
	
func jiegu_npc():
	# 解雇厨师逻辑
	if choice_state == 0:
		if fc.playerData.chefs.size() == 1:
			fc.show_msg("这是饭店仅有的厨师，不能解雇。")
			await fc.endshow
		else:
			fc.show_yesorno("确定要解雇这名厨师吗？")
			var the_end = await fc.endshow
			if the_end:
				var chef = fc.playerData.chefs[choice_num]
				
				# ==========================================
				# 【关键修改】清理菜品数据中的厨师关联
				# ==========================================
				_clear_chef_from_dishes(choice_num)
				
				# 执行解雇
				chef_manager.fire_chef(chef)
				fc.show_event("已经解雇了这名员工", "解雇厨师")
				await fc.endshow
				choice_num = 0
				show_chef_data()
	
	# 解雇服务生逻辑保持不变
	else:
		if fc.playerData.waiters.size() == 1:
			fc.show_msg("这是饭店仅有的服务生，不能解雇。")
			await fc.endshow
		else:
			fc.show_yesorno("确定要解雇这名服务生吗？")
			var the_end = await fc.endshow
			if the_end:
				var waiter = fc.playerData.waiters[choice_num]
				
				# 清理家具存档中的关联数据
				_clear_waiter_from_saved_furniture(waiter.id)
				
				waiter_manager.fire_waiter(waiter)
				fc.show_event("已经解雇了这名员工", "解雇服务生")
				await fc.endshow
				choice_num = 0
				show_waiter_data()


# ==========================================
# 【新增辅助函数】清理菜品中的厨师关联
# ==========================================
func _clear_chef_from_dishes(fired_chef_index: int):
	# 1. 检查存档中是否有菜品数据
	var dishes_data = fc.playerData.Total_dishes_list
	# 2. 遍历所有菜品
	for dish_id_str in dishes_data:
		var dish = dishes_data[dish_id_str]
		
		# 3. 检查该菜品是否由被解雇的厨师负责
		# 注意：菜品数据中的 chef 字段是索引值（int），不是 ID
		if dish.has("chef") and int(dish["chef"]) == fired_chef_index:
			# 4. 将其重置为第一个厨师（索引 0）
			dish["chef"] = 0


# 新增辅助函数：清理存档里的家具关联
func _clear_waiter_from_saved_furniture(waiter_id: String):
	# 1. 检查存档中是否有家具数据
	var furniture_list = fc.playerData.saved_furniture
	# 2. 遍历所有保存的家具数据
	for item in furniture_list:
		# 3. 检查该家具是否分配给了当前被解雇的服务生
		# 注意：根据 furniture_system.gd，存档里的字段名是 "assigned_waiter_id"
		if item.has("assigned_waiter_id") and item["assigned_waiter_id"] == waiter_id:
			# 4. 清空分配，设为空字符串
			item["assigned_waiter_id"] = ""
			
			# 可选：同时也清空颜色数据，保持数据整洁
			if item.has("assigned_waiter_color"):
				item["assigned_waiter_color"] = ""
			



func _on_yes_pressed():
	fc.save_game(fc.save_num)

	get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
