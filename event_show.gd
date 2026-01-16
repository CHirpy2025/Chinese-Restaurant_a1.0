extends Control

signal endshow

@onready var showpic=$mainTitle/base/pic
func _ready():
	fc.play_se_ui("event")
	$mainTitle/AnimationPlayer.play("play")
	$mainTitle/base/yesBT.pressed.connect(msgclose.bind())




func show_msg(msg,type):
	msg = msg.replace("[c]", "[color=e95d5d][b]")
	msg = msg.replace("[/c]", "[/b][/color]")
	match type:
		"新服务生":
			showpic.texture = load("res://pic/event/newfuwusheng.png")
		"新厨师":
			showpic.texture = load("res://pic/event/chefnew.png")
		"学得新菜":
			showpic.texture = load("res://pic/event/newcai.png")
		"解雇厨师":
			showpic.texture = load("res://pic/event/jiegu_chef.png")
		"解雇服务生":
			showpic.texture = load("res://pic/event/jiegu_waiter.png")
		"解锁菜品":
			showpic.texture = load("res://pic/event/jiesuocaipu.png")
		"电视台采访":
			showpic.texture = load("res://pic/event/huanyin.png")
		"明星拜访":
			showpic.texture = load("res://pic/event/huanyin.png")
		"网红探店":
			showpic.texture = load("res://pic/event/wanghong.png")
		
		
		
	$mainTitle/base/tips.text  =  msg
	
	GuiTransitions.show("event")
	await GuiTransitions.hide_completed
	



func msgclose():
	GuiTransitions.hide("event")
	await GuiTransitions.hide_completed
	
	
	emit_signal("endshow")
	queue_free()
