extends Button

@export var se = "click"

func _ready():
	mouse_entered.connect(mouse_in)
	pressed.connect(clickbt)
	

func mouse_in():
	fc.play_se_ui("mouse_in")

	

func clickbt():
	fc.play_se_ui(se)
