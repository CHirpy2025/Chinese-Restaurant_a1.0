extends Window

@onready var time = $bg/base/timebar/time
@onready var show_weather=$bg/base/tianqi/weather
@onready var show_temperature=$bg/base/tianqi/AutoSizeLabel2
@onready var show_rili=$bg/base/tianqi/AutoSizeLabel3
@onready var show_week=$bg/base/tianqi/AutoSizeLabel4
@onready var show_jieri=$bg/base/tianqi/AutoSizeLabel5

func _ready():
	# 设置随机种子（可使用当前时间或固定值）
	# 设置地区（四川属于南方）
	fc.weather_system.set_seed(12345)
	fc.weather_system.set_region(fc.weather_system.get_region_south())
	var current_weather = fc.weather_system.get_current_date_and_weather()

	match current_weather.weather_name:
		"晴天":
			show_weather.texture = load("res://pic/ui/weather1.png")
		"多云":
			show_weather.texture = load("res://pic/ui/weather2.png")
		"小雨":
			show_weather.texture = load("res://pic/ui/weather3.png")
		"大雨":
			show_weather.texture = load("res://pic/ui/weather4.png")
		"雪天":
			show_weather.texture = load("res://pic/ui/weather5.png")
			
	show_temperature.text = "%.1f°C" % [current_weather.temperature]
	
	show_rili.text = "第%d年%d月%d日" % [fc.playerData.game_year,fc.playerData.game_month,fc.playerData.game_day]
	
	show_week.text = "%s" % [current_weather.weekday_name]
	
	show_jieri.text="平日"
	if current_weather.weekday_name=="周日"||current_weather.weekday_name=="周六":
		show_jieri.text="假日"

	if current_weather.festival!="":
		show_jieri.text=current_weather.festival
	
	$bg/base/city.text = fc.get_row_from_csv_data("mapinfo","ID",fc.playerData.choice_map_ID)["city"]
	$bg/base/diduan.text = fc.playerData.choice_diduan_name
	
	$bg/base/StarRatingDisplay.set_rating(float(fc.playerData.mapStar*0.5))
	
	GuiTransitions.show("mainInfo")
	await GuiTransitions.show_completed
	
	
	
	
