extends Window

@onready var show_money=$Control/base/showtype1/HBoxContainer/AutoSizeLabel2
@onready var show_guest_num=$Control/base/showtype2/HBoxContainer/AutoSizeLabel2
@onready var show_money_today=$Control/base/showtype3/HBoxContainer/AutoSizeLabel2

func _ready():
	show_info()

	GuiTransitions.show("financial")
	await GuiTransitions.show_completed
	
func show_info():
	show_money.text=fc.format_money(fc.playerData.money)
	show_guest_num.text=str(int(fc.playerData.total_guest_now_day))
	show_money_today.text=fc.format_money(fc.playerData.pay_today)
