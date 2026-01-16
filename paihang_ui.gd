extends Control

var show_guesttype_score = preload("res://sc/show_guesttype_score.tscn")



func _ready():
	$Panel/base/point.text = str(fc.playerData.ratings_data["global"]["average"])
	$Panel/base/lv.text = str(fc.playerData.mapStar)
	
	if fc.playerData.top_lv==99:
		$Panel/base/paiming.text = "未进榜单"
	else:
		$Panel/base/paiming.text = str(fc.playerData.top_lv)
	
	$Panel/base/StarRatingDisplay.set_rating(float(fc.playerData.mapStar*0.5))
	
	
	for i in fc.playerData.ratings_data["types"]:
		var obj = show_guesttype_score.instantiate()
		obj.get_node("name").text = i
		obj.get_node("name5").text = str(fc.playerData.ratings_data["types"][i]["average"])
		$Panel/base/VBoxContainer.add_child(obj)
	

	var data = paihang.get_ui_leaderboard()
	for i in 15:
		var paishow=$Panel/base/VBoxContainer2.get_child(i)
		var item = data[i]
		var rank = i + 1
		var canting_name = item["name"]
		
		# 玩家高亮显示
		if item["is_player"]:
			paishow.get_node("name").text=fc.playerData.name
			paishow.get_node("paiming").text=str(rank)
			paishow.get_node("name").add_theme_color_override("font_color",Color("e33e2bff"))
			$RankList.set_item_custom_fg_color(i, Color.YELLOW)
		else:
			paishow.get_node("name").add_theme_color_override("font_color",Color("333333ff"))
			paishow.get_node("name").text=canting_name
			paishow.get_node("paiming").text=str(rank)

			


func _on_yes_pressed():
	var window = get_tree().get_current_scene().popup_windows[0]
	get_tree().get_current_scene()._on_popup_window_closed(window)
