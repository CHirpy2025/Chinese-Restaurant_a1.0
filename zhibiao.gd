extends Control

@onready var pic =$Jiating
@onready var bar =$ProgressBar
@onready var type =$type

@export var showtype = "烟火气"

func _ready():
	show_state()
	
func set_value():
	bar.value = fc.playerData.style[showtype]
	
func set_value_sp(value):
	bar.value=value
	
	
	
func show_state():
	type.text = showtype
	
	bar.value = fc.playerData.style[showtype]
	match showtype:
		"烟火气":
			pic.texture = load("res://pic/ui/yanhuoqi.png")
			change_color("#c3211f")
		"时尚度":
			pic.texture = load("res://pic/ui/shishangdu.png")
			change_color("#c939f1")
		"文化感":
			pic.texture = load("res://pic/ui/wenhuagan.png")
			change_color("#3654c2")
		"舒适度":
			pic.texture = load("res://pic/ui/shushidu.png")
			change_color("#6abb5f")
		"独特性":
			pic.texture = load("res://pic/ui/dutexing.png")
			change_color("#24b8e0")
		"私密性":
			pic.texture = load("res://pic/ui/simixing.png")
			change_color("#ffe117")



func change_color(color):
	var new_stylebox_normal = bar.get_theme_stylebox("fill").duplicate()
	new_stylebox_normal.modulate_color = Color(color)
	bar.add_theme_stylebox_override("fill", new_stylebox_normal)
