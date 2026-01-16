extends Control


func _ready():
	$Panel/NinePatchRect/title.text = "庆祝【%s】正式开店" % [fc.playerData.name]

	fc.play_se_fx("logu")
	
	GuiTransitions.show("timeUI")
	await GuiTransitions.show_completed
	
	

func _on_panel_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				fc.play_se_ui("opendoor")
				fc.playerData.now_time="6:00"
				get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
