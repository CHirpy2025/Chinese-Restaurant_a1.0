extends Control

@export var buttons: Array[BaseButton] = [

]

@onready var list=$Panel/base/ScrollContainer/ItemContainer
@onready var point=$Panel/base/point

var total_shipu={}
var bt
var caipu = preload("res://sc/caipu_tip.tscn")

func _ready():
	# 【新增】确保窗口居中
	fc._ensure_window_centered()
	
	for button in buttons:
		button.toggled.connect(_on_button_toggled.bind(button))
		
	
	handle_button_pressed(buttons[0])
	show_point()
	
func _on_button_toggled(button_pressed: bool, button: BaseButton):
	if button_pressed:
		bt=button
		handle_button_pressed(button)
	
	
func handle_button_pressed(pressed_button: BaseButton):
	for i in list.get_children():
		i.queue_free()
	
	total_shipu={}
	match pressed_button.name:
		"type1":
			for i in fc.playerData.Total_dishes_list:
				var shipu=fc.playerData.Total_dishes_list[i]
				if shipu["category"]=="主菜":
					total_shipu[i]=shipu
		"type2":
			for i in fc.playerData.Total_dishes_list:
				var shipu=fc.playerData.Total_dishes_list[i]
				if shipu["category"]=="主菜":
					if shipu["is_locked"]==true:
						total_shipu[i]=shipu
		"type3":
			for i in fc.playerData.Total_dishes_list:
				var shipu=fc.playerData.Total_dishes_list[i]
				if shipu["category"]=="主菜":
					if shipu["is_locked"]==false:
						total_shipu[i]=shipu
	show_shipu()
			
func show_shipu():
	for i in total_shipu:
		var shipu=total_shipu[i]
		var obj  = caipu.instantiate()
		obj.get_node("name").text = shipu["name"]
		obj.get_node("price").text = fc.format_money(shipu["price"])
		
		obj.get_node("open").visible=shipu["is_locked"]
		if shipu["is_locked"]:
			obj.get_node("open").pressed.connect(open_caipu.bind(shipu["ID"]))
			obj.get_node("$open/point").text=str(shipu["unlock_cost"])

		for k in 6:
			obj.get_node("GridContainer").get_child(k).visible=false
			
		var tag=fc.tag_manager.get_dish_tags(shipu["ID"])
		for k in tag.size():
			match fc.tag_manager.get_tag_category(tag[k]):
				0:
					obj.get_node("GridContainer").get_child(k).get_node("bg").self_modulate = Color("5da9e9")
				1:
					obj.get_node("GridContainer").get_child(k).get_node("bg").self_modulate = Color("e95d5d")
				2:
					obj.get_node("GridContainer").get_child(k).get_node("bg").self_modulate = Color("2c6bab")
				3:
					obj.get_node("GridContainer").get_child(k).get_node("bg").self_modulate = Color("bb9770")
			
			obj.get_node("GridContainer").get_child(k).get_node("show").text = tag[k]
			obj.get_node("GridContainer").get_child(k).visible=true
		list.add_child(obj)
	
func open_caipu(id):
	var shipu=fc.playerData.Total_dishes_list[id]
	if fc.playerData.chuangyi>shipu["unlock_cost"]:
		fc.playerData.chuangyi-=shipu["unlock_cost"]
		fc.playerData.Total_dishes_list[id]["is_locked"]=false
		fc.show_event("饭店厨师学会了新的菜式，可以在菜单里上架了。","解锁菜品")
		await fc.endshow
		
		show_point()
		
	else:
		fc.show_msg("创意点不足，无法解锁这个菜品。")
		await fc.endshow
		
	handle_button_pressed(bt)
	
	
func show_point():
	$Panel/base/point.text=str(fc.playerData.chuangyi)
	


func _on_yes_pressed():
	fc.save_game(fc.save_num)

	get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
