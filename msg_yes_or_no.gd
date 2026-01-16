extends Control

signal endshow


func _ready():
	fc.play_se_ui("msg")
	$mainTitle/base/HBoxContainer/yes.pressed.connect(msgclose.bind(true))
	$mainTitle/base/HBoxContainer/no.pressed.connect(msgclose.bind(false))



func show_msg(msg):
	msg = msg.replace("[c]", "[color=e95d5d][b]")
	msg = msg.replace("[/c]", "[/b][/color]")
	
	$mainTitle/base/tips.text  =  msg
	
	GuiTransitions.show("msg")
	await GuiTransitions.hide_completed
	



func msgclose(state):
	GuiTransitions.hide("msg")
	await GuiTransitions.hide_completed
	
	
	emit_signal("endshow",state)
	queue_free()
