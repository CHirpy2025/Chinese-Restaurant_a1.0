extends HSlider

@export var se = "select"

func _ready():
	mouse_entered.connect(mouse_in)
	drag_ended.connect(clickbt)
	

func mouse_in():
	fc.play_se_ui("mouse_in")

	

func clickbt(value_change):
	if value_change:
		fc.play_se_ui(se)
