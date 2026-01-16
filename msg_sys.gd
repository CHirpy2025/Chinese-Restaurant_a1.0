extends Control

signal endshow


func _ready():
	fc.play_se_ui("msg")
	$mainTitle/base/yesBT.pressed.connect(msgclose.bind())




func show_msg(msg):
	msg = msg.replace("[c]", "[color=e95d5d][b]")
	msg = msg.replace("[/c]", "[/b][/color]")
	
	$mainTitle/base/tips.text  =  msg
	
	GuiTransitions.show("msg")
	await GuiTransitions.hide_completed
	



func msgclose():
	
	
	GuiTransitions.hide("msg")
	await GuiTransitions.hide_completed
	
	
	emit_signal("endshow")
	queue_free()
