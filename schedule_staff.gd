extends Control

@onready var show_chef=$Panel/base/VBoxContainer/door/showpic2
@onready var zhaopin_chef=$Panel/base/VBoxContainer/door/get
@onready var next_chef=$Panel/base/VBoxContainer/door/next
@onready var last_chef=$Panel/base/VBoxContainer/door/last
@onready var show_chef_name=$Panel/base/VBoxContainer/door/VBoxContainer/HBoxContainer/base4/name
@onready var show_chef_info=$Panel/base/VBoxContainer/door/VBoxContainer/HBoxContainer2/base5/info
@onready var show_chef_pay=$Panel/base/VBoxContainer/door/VBoxContainer/HBoxContainer3/base6/money
@onready var show_chef_num=$Panel/base/VBoxContainer/door/TextureRect/AutoSizeLabel

@onready var mymoney=$Panel/base/NinePatchRect3/money

@onready var show_waiter=$Panel/base/VBoxContainer/door2/showpic2
@onready var zhaopin_waiter=$Panel/base/VBoxContainer/door2/get
@onready var next_waiter=$Panel/base/VBoxContainer/door2/next
@onready var last_waiter=$Panel/base/VBoxContainer/door2/last
@onready var show_waiter_name=$Panel/base/VBoxContainer/door2/VBoxContainer/HBoxContainer/base4/name
@onready var show_waiter_info=$Panel/base/VBoxContainer/door2/VBoxContainer/HBoxContainer2/base5/info
@onready var show_waiter_pay=$Panel/base/VBoxContainer/door2/VBoxContainer/HBoxContainer3/base6/money
@onready var show_waiter_num=$Panel/base/VBoxContainer/door2/TextureRect/AutoSizeLabel




@onready var check_chef_jineng=[
	$Panel/base/VBoxContainer/door/checktag/checkcaixi,
	$Panel/base/VBoxContainer/door/checktag/checkcaixi2,
	$Panel/base/VBoxContainer/door/checktag/checkcaixi3,
	$Panel/base/VBoxContainer/door/checktag/checkcaixi4,
]

@onready var check_waiter_jineng=[
	$Panel/base/VBoxContainer/door2/checktag/checkcaixi,
	$Panel/base/VBoxContainer/door2/checktag/checkcaixi2,
	$Panel/base/VBoxContainer/door2/checktag/checkcaixi3
]

var waiter_manager: Node
var chef_manager: Node

var waiter_list=[]
var waiter_ID=0

var chef_list=[]
var chef_ID=0


func _ready():
	# 【新增】确保窗口居中
	fc._ensure_window_centered()
	
	fc.playerData.step="第6步"
	next_chef.pressed.connect(change_chef.bind(1))
	last_chef.pressed.connect(change_chef.bind(-1))
	zhaopin_chef.pressed.connect(get_chef)
	
	next_waiter.pressed.connect(change_waiter.bind(1))
	last_waiter.pressed.connect(change_waiter.bind(-1))
	zhaopin_waiter.pressed.connect(get_waiter)
	

	
	for i in 4:
		check_chef_jineng[i].visible=false
		
	chef_manager = preload("res://sc/chef_manager.gd").new()
	add_child(chef_manager)
	
	waiter_manager = preload("res://sc/WaiterGenerator.gd").new()
	add_child(waiter_manager)
	
	chef_list = chef_manager.generate_recruitment_chefs(10)
	waiter_list = waiter_manager.generate_recruitment_waiters(10)
	
	show_chef_data()
	show_waiter_data()
	
	show_worker_num()
	
	show_newinfo()
	

		
		
	GuiTransitions.show("zhaopin")
	await GuiTransitions.show_completed
	

func show_worker_num():
	show_chef_num.text="厨师："+str(fc.playerData.chefs.size())
	show_waiter_num.text="服务生："+str(fc.playerData.waiters.size())


func show_waiter_data():
	var waiter=waiter_list[waiter_ID]
	show_waiter_name.text = waiter.name
	show_waiter_pay.text = fc.format_money(waiter.salary)
	show_waiter.texture = load(waiter.avatar_path)
	
	#能力描述
	var show_list2=[]
	var show_list3=[]
	var show_list4=[]
	var data= fc.load_csv_to_rows("workerShowData")
	for i in data:
		if i["zhiye"]=="服务员":

			if i["shuxing"]=="服务速度":
				if waiter.speed<=30:
					if i["valuecheck"]=="低":
						show_list2.append(i["info"])
				elif waiter.speed>30&&waiter.speed<=65:
					if i["valuecheck"]=="中":
						show_list2.append(i["info"])
				elif waiter.speed>65:
					if i["valuecheck"]=="高":
						show_list2.append(i["info"])
					
			if i["shuxing"]=="魅力":
				if waiter.charm<=30:
					if i["valuecheck"]=="低":
						show_list3.append(i["info"])
				elif waiter.charm>30&&waiter.charm<=65:
					if i["valuecheck"]=="中":
						show_list3.append(i["info"])
				elif waiter.charm>65:
					if i["valuecheck"]=="高":
						show_list3.append(i["info"])
					
			if i["shuxing"]=="亲和力":
				if waiter.affinity<=30:
					if i["valuecheck"]=="低":
						show_list4.append(i["info"])
				elif waiter.affinity>30&&waiter.affinity<=65:
					if i["valuecheck"]=="中":
						show_list4.append(i["info"])
				elif waiter.affinity>65:
					if i["valuecheck"]=="高":
						show_list4.append(i["info"])
				
	
	show_waiter_info.text=""
	show_waiter_info.text=show_waiter_info.text+show_list2[randi_range(0,show_list2.size()-1)]+"，"
	show_waiter_info.text=show_waiter_info.text+show_list3[randi_range(0,show_list4.size()-1)]+"，"
	show_waiter_info.text=show_waiter_info.text+show_list4[randi_range(0,show_list3.size()-1)]+"。"

	#擅长菜系
	var id=0
	for skill in waiter.skills:
		var level = waiter.skills[skill]
		var skill_name = waiter_manager.SKILL_NAMES[skill]
		check_waiter_jineng[id].get_node("type").text = skill_name

		check_waiter_jineng[id].get_node("lv").set_rating(float(level*0.5))
		id+=1



#展示待招聘的厨师档案
func show_chef_data():
	for i in 4:
		check_chef_jineng[i].visible=false
	
	
	var chef=chef_list[chef_ID]
	show_chef_name.text = chef.name
	show_chef_pay.text = fc.format_money(chef.salary)
	show_chef.texture = load(chef.avatar_path)
	
	#能力描述
	var show_list1=[]
	var show_list2=[]
	var show_list3=[]
	var show_list4=[]
	var data= fc.load_csv_to_rows("workerShowData")
	for i in data:
		if i["zhiye"]=="厨师":
			if i["shuxing"]=="年龄":
				if chef.age<=35&&i["valuecheck"]=="低":
					show_list1.append(i["info"])
				if chef.age>35&&chef.age<=55&&i["valuecheck"]=="中":
					show_list1.append(i["info"])
				if chef.age>55&&i["valuecheck"]=="高":
					show_list1.append(i["info"])
					

			if i["shuxing"]=="厨艺":
				if chef.cooking_skill<=30:
					if i["valuecheck"]=="低":
						show_list2.append(i["info"])
				elif chef.cooking_skill>30&&chef.cooking_skill<=65:
					if i["valuecheck"]=="中":
						show_list2.append(i["info"])
				elif chef.cooking_skill>65:
					if i["valuecheck"]=="高":
						show_list2.append(i["info"])
					
			if i["shuxing"]=="速度":
				if chef.speed_skill<=30:
					if i["valuecheck"]=="低":
						show_list3.append(i["info"])
				elif chef.speed_skill>30&&chef.speed_skill<=65:
					if i["valuecheck"]=="中":
						show_list3.append(i["info"])
				elif chef.speed_skill>65:
					if i["valuecheck"]=="高":
						show_list3.append(i["info"])
					
			if i["shuxing"]=="创新":
				if chef.innovation_skill<=30:
					if i["valuecheck"]=="低":
						show_list4.append(i["info"])
				elif chef.innovation_skill>30&&chef.innovation_skill<=65:
					if i["valuecheck"]=="中":
						show_list4.append(i["info"])
				elif chef.innovation_skill>65:
					if i["valuecheck"]=="高":
						show_list4.append(i["info"])
				
	
	show_chef_info.text=show_list1[randi_range(0,show_list1.size()-1)]+"，"
	show_chef_info.text=show_chef_info.text+show_list2[randi_range(0,show_list2.size()-1)]+"，"
	show_chef_info.text=show_chef_info.text+show_list3[randi_range(0,show_list3.size()-1)]+"，"
	show_chef_info.text=show_chef_info.text+show_list4[randi_range(0,show_list4.size()-1)]+"。"

	#擅长菜系
	var id=0
	for cuisine_type in chef.cuisines:
		var level = chef.cuisines[cuisine_type]
		var cuisine_name = chef_manager.CUISINE_NAMES[cuisine_type]
		check_chef_jineng[id].visible=true
		check_chef_jineng[id].get_node("type").text = cuisine_name
		check_chef_jineng[id].get_node("lv").set_rating(float(level*0.5))
		id+=1



func _on_yes_pressed():
	if fc.playerData.chefs.size()==0:
		fc.show_msg("开店最少需要一个厨师！")
		await fc.endshow
	else:
		if fc.playerData.waiters.size()==0:
			fc.show_msg("开店最少需要一个服务员！")
			await fc.endshow
		else:
			#默认解锁菜单
			fc.save_game(fc.save_num)
			# 添加窗口关闭处理
			if fc.playerData.from_main_game==true:
				get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
			else:
				get_tree().change_scene_to_file("res://sc/main_management.tscn")


func change_chef(num):
	chef_ID+=num
	if chef_ID<0:
		chef_ID = chef_list.size()-1
	elif chef_ID >= chef_list.size():
		chef_ID=0
	
	show_chef_data()
	
func change_waiter(num):
	waiter_ID+=num
	if waiter_ID<0:
		waiter_ID = waiter_list.size()-1
	elif waiter_ID >= waiter_list.size():
		waiter_ID=0
	
	show_waiter_data()
	
#雇佣厨师
func get_waiter():
	if fc.playerData.mapStar+3==fc.playerData.waiters.size():
		fc.show_msg("按照现在的饭店星级，已经不能招募更多的服务员了……")
		await fc.endshow
	else:
		var waiter=waiter_list[waiter_ID]
		waiter_manager.hire_waiter(waiter)

		if waiter.gender=="male":
			fc.play_se_fx("guanzhao_man")
		else:
			fc.play_se_fx("guanzhao_woman")

				
		fc.show_event("[c]"+waiter.name+"[/c]加入了饭店一起工作了，热烈欢迎！","新服务生")
		await fc.endshow
		
		
		show_worker_num()
		waiter_list.remove_at(waiter_ID)
		change_waiter(1)
	
#雇佣厨师
func get_chef():
	if fc.playerData.mapStar+1==fc.playerData.chefs.size():
		fc.show_msg("按照现在的饭店星级，已经不能招募更多的厨师了……")
		await fc.endshow
	else:
		var chef=chef_list[chef_ID]
		chef_manager.hire_chef(chef)

		if chef.age<50:
			if chef.gender=="male":
				fc.play_se_fx("guanzhao_man")
			else:
				fc.play_se_fx("guanzhao_woman")
		else:
			if chef.gender=="male":
				fc.play_se_fx("guanzhao_oldman")
			else:
				fc.play_se_fx("guanzhao_oldwoman")
				
		fc.show_event("[c]"+chef.name+"[/c]加入了饭店一起工作了，热烈欢迎！","新厨师")
		await fc.endshow
		
		for i in range(3):
			var cuisine_keys = chef.cuisines.keys()
			if cuisine_keys.size() > 0:
				var cuisine_type = cuisine_keys[randi_range(0,cuisine_keys.size()-1)]# 随机寻找厨师的一个菜系
				var cuisine_level = chef.cuisines[cuisine_type]
				# 生成
				var new_dish_id = fc.dish_data_manager.generate_procedural_dish(
					cuisine_type,      # 菜系枚举
					chef.innovation_skill, # 创新能力
					cuisine_level,     # 技能等级
					true               # true 表示直接变菜品(解锁)
				)

		#fc.dish_data_manager.unlock_dish(new_dish_id)
		#print(fc.playerData.Total_dishes_list)
		
		
		
		show_worker_num()
		chef_list.remove_at(chef_ID)
		change_chef(1)
		
		
		
		
func show_newinfo():
	mymoney.text=fc.format_money(fc.playerData.money)
