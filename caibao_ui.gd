extends Control


@export var buttons: Array[BaseButton] = [

]

@onready var dayshow=$Panel/base/day
@onready var monthshow=$Panel/base/month
@onready var yearshow=$Panel/base/year
func _ready():
	for button in buttons:
		button.toggled.connect(_on_button_toggled.bind(button))

	
	_on_button_toggled(true,buttons[0])
	
	

func _on_button_toggled(button_pressed: bool, button: BaseButton):
	if button_pressed:
		handle_button_pressed(button)
	
func handle_button_pressed(pressed_button: BaseButton):
	dayshow.visible=false
	monthshow.visible=false
	yearshow.visible=false
	
	match pressed_button.name:
		"type1":
			dayshow.visible=true
			show_today_info()
		"type2":
			dayshow.visible=true
			show_lastday_info()
		"type3":
			monthshow.visible=true
			show_month_info()
		"type4":
			yearshow.visible=true
			show_year_info()
			
	
func show_month_info():
	$Panel/base/month/Control/type.text = str(fc.playerData.total_guest_month)
	$Panel/base/month/GridContainer/Control2/type.text = fc.format_money(fc.playerData.monthly_stats_revenue[str(fc.playerData.game_month)])
	$Panel/base/month/GridContainer/Control3/type.text = fc.format_money(fc.playerData.monthly_stats_cost[str(fc.playerData.game_month)])
	$Panel/base/month/GridContainer/Control5/type.text = fc.format_money(fc.playerData.get_monthly_profit(fc.playerData.game_month))
	$Panel/base/month/GridContainer/Control6/type.text = fc.playerData.get_monthly_profit_margin_text(fc.playerData.game_month)
#计算利润

func show_year_info():
	var rev = fc.playerData.get_annual_revenue()
	var cost = fc.playerData.get_annual_cost()
	var profit = fc.playerData.get_annual_profit()
	
	$Panel/base/year/GridContainer/Control2/type.text=fc.format_money(rev)
	$Panel/base/year/GridContainer/Control3/type.text=fc.format_money(cost)
	$Panel/base/year/GridContainer/Control5/type.text=fc.format_money(profit)
	$Panel/base/year/Control/type.text=str(fc.playerData.total_guest_year)
	
	
	
	
func show_today_info():#本日财报
	$Panel/base/day/GridContainer/Control2/type.text = fc.format_money(fc.playerData.pay_today)
	$Panel/base/day/Control/type.text = str(fc.playerData.total_guest_now_day)
	#采购成本
	$Panel/base/day/GridContainer/Control3/type.text = fc.format_money(fc.playerData.pay_caigou)
	#电费
	$Panel/base/day/GridContainer/Control4/type.text = fc.format_money(fc.playerData.pay_dian)
	#利润
	var lirun=fc.playerData.pay_today-fc.playerData.pay_caigou-fc.playerData.pay_dian
	$Panel/base/day/GridContainer/Control5/type.text = fc.format_money(lirun)
	$Panel/base/day/CustomerChart.stats=fc.playerData.hourly_stats
	$Panel/base/day/CustomerChart.update_chart()
	

func show_lastday_info():#前一日财报
	$Panel/base/day/GridContainer/Control2/type.text = fc.format_money(fc.playerData.pay_last_day)
	$Panel/base/day/Control/type.text = str(fc.playerData.total_guest_last_day)
	#采购成本
	$Panel/base/day/GridContainer/Control3/type.text = fc.format_money(fc.playerData.pay_last_caigou)
	#电费
	$Panel/base/day/GridContainer/Control4/type.text = fc.format_money(fc.playerData.pay_last_dian)
	#利润
	var lirun=fc.playerData.pay_last_day-fc.playerData.pay_last_caigou-fc.playerData.pay_last_dian
	$Panel/base/day/GridContainer/Control5/type.text = fc.format_money(lirun)
	$Panel/base/day/CustomerChart.stats=fc.playerData.hourly_stats_last
	$Panel/base/day/CustomerChart.update_chart()


func _on_yes_pressed():
	var window = get_tree().get_current_scene().popup_windows[0]
	get_tree().get_current_scene()._on_popup_window_closed(window)
