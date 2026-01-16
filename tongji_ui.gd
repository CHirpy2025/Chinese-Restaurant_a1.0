extends Control

@onready var show_base=$Panel/base/base
@onready var show_type=$Panel/base/type2
@onready var buttons: Array[BaseButton] = [
	$Panel/base/type/type1,
	$Panel/base/type/type2
]

var tip_guest=preload("res://sc/tongji_guest_tip.tscn")
var tip_cai=preload("res://sc/tongji_cai_tip.tscn")

func _ready():

	
	for button in buttons:
		button.toggled.connect(_on_button_toggled.bind(button))
	
	_on_button_toggled(true,buttons[0])
	

func _on_button_toggled(button_pressed: bool, button: BaseButton):
	if button_pressed:
		handle_button_pressed(button)
	
func handle_button_pressed(pressed_button: BaseButton):
	show_base.visible=false
	show_type.visible=false
	match pressed_button.name:
		"type1":
			show_base.visible=true
			refresh_ui()
		"type2":
			show_type.visible=true
			$Panel/base/type2/PieChartPanel.update_charts()


func refresh_ui():
	$Panel/base/base/value.text = str(fc.playerData.total_guest)
	
	refresh_top_types_ui()
	#refresh_top_dishes_ui()


# 假设你有一个名为 $TopTypesList 的 ItemList 节点
func refresh_top_types_ui():
	for i in $Panel/base/base/GridContainer.get_children():
		i.queue_free()
	
	
	var top_types = fc.playerData.get_top_5_customer_types()
	
	if top_types.is_empty():
		#$Panel/base/base/GridContainer.add_item("暂无客源数据")
		return
		
	for item in top_types:
		if item["percent"]!=0:
			var type_name = item["type"]
			var percent = item["percent"]
			var pic = fc.get_row_from_csv_data("guestData","type",type_name)["pic"]
			# 使用 snapped 保留一位小数
			var obj = tip_guest.instantiate()
			obj.get_node("type6").text = type_name
			obj.get_node("type7").text =  "%s%%"%snapped(percent, 0.1)
			obj.get_node("pic").texture = load("res://pic/npc/keren/"+pic+".png")
			$Panel/base/base/GridContainer.add_child(obj)
		
	

# 假设你有一个名为 $TopDishesList 的 ItemList 节点
func refresh_top_dishes_ui():
	for i in $Panel/base/base/GridContainer2.get_children():
		i.queue_free()

	var top_dishes = fc.playerData.get_top_10_dishes()
	
	if top_dishes.is_empty():
		#$TopDishesList.add_item("暂无销量数据")
		return
		
	for item in top_dishes:
		var itemname = item["name"]
		var count = item["count"]
		# 使用 snapped 保留一位小数
		var obj = tip_cai.instantiate()
		obj.get_node("type6").text = itemname
		obj.get_node("type7").text =  "%d 份"%count
		$Panel/base/base/GridContainer2.add_child(obj)


func _on_yes_pressed():
	var window = get_tree().get_current_scene().popup_windows[0]
	get_tree().get_current_scene()._on_popup_window_closed(window)
