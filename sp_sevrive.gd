extends Control

@onready var ads_check=$Panel/base/VBoxContainer
@onready var ads_pay=$Panel/base/VBoxContainer2
@onready var ads_effect=$Panel/base/VBoxContainer3

var ads_money = [500,1500, 250, 400, 1200, 600, 6000, 5000, 6000,12000]
var check_ads=[]

func _ready():
	# 1. 复制数据
	check_ads = fc.playerData.ads.duplicate()
	
	fc._ensure_window_centered()
	
	for i in range(ads_check.get_child_count()):
		var btn = ads_check.get_child(i)
		if not btn.toggled.is_connected(change_ads):
			btn.toggled.connect(change_ads.bind(i))
		if i < check_ads.size(): # 确保数组索引不越界
			btn.button_pressed = check_ads[i] 
		else:
			btn.button_pressed = false
			
	# 3. 设置价格文字
		if i < ads_pay.get_child_count():
			ads_pay.get_child(i).text = fc.format_money(ads_money[i])
	
	$Panel/base/NinePatchRect3/money.text = fc.format_money(fc.playerData.money)



func change_ads(if_toggled,num):#安保措施
	fc.playerData.ads[num]=if_toggled




func _on_yes_pressed():
	var pay_money=0
	for i in 10:
		if check_ads[i]!=fc.playerData.ads[i]&&fc.playerData.ads[i]==true:
			pay_money+=ads_money[i]
			
	if pay_money>0:
		fc.playerData.money-=pay_money
		fc.play_se_fx("cash")
	
	fc.save_game(fc.save_num)
	get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
