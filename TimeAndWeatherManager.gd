# WeatherAndDateSystem.gd
# 中国餐厅模拟游戏 - 天气与日期系统
# 支持东西南北四个地区特点，初始日期为1月1日周一

extends Node

# 地区枚举
enum RegionType {
	EAST,    # 东部：沿海湿润，夏季多台风，冬季温和
	SOUTH,   # 南方：四季分明，夏季炎热潮湿，冬季温和少雪（四川属于此区域）
	WEST,    # 西部：内陆干燥，昼夜温差大，冬季寒冷
	NORTH    # 北方：冬季严寒多雪，夏季炎热短暂
}

# 天气类型枚举
enum WeatherType {
	SUNNY,        # 晴天
	CLOUDY,       # 多云
	DRIZZLE,      # 小雨
	HEAVY_RAIN,   # 大雨
	SNOW,         # 雪天
}

# 地区天气配置 - 使用英文键
var region_weather_config = {
	RegionType.EAST: {
		"spring": {"SUNNY": 30, "CLOUDY": 25, "DRIZZLE": 20, "RAINY": 15, "FOG": 10},
		"summer": {"SUNNY": 20, "CLOUDY": 15, "RAINY": 25, "HEAVY_RAIN": 30, "STORM": 10},
		"autumn": {"SUNNY": 35, "CLOUDY": 30, "DRIZZLE": 20, "RAINY": 10, "FOG": 5},
		"winter": {"SUNNY": 25, "CLOUDY": 30, "DRIZZLE": 15, "SNOW": 20, "FOG": 10}
	},
	RegionType.SOUTH: {
		"spring": {"SUNNY": 35, "CLOUDY": 30, "DRIZZLE": 20, "RAINY": 10, "FOG": 5},
		"summer": {"SUNNY": 25, "CLOUDY": 20, "RAINY": 30, "HEAVY_RAIN": 20, "STORM": 5},
		"autumn": {"SUNNY": 40, "CLOUDY": 35, "DRIZZLE": 15, "RAINY": 8, "FOG": 2},
		"winter": {"SUNNY": 30, "CLOUDY": 40, "DRIZZLE": 20, "SNOW": 5, "FOG": 5}
	},
	RegionType.WEST: {
		"spring": {"SUNNY": 40, "CLOUDY": 30, "DRIZZLE": 15, "RAINY": 10, "FOG": 5},
		"summer": {"SUNNY": 45, "CLOUDY": 25, "RAINY": 20, "HEAVY_RAIN": 8, "STORM": 2},
		"autumn": {"SUNNY": 50, "CLOUDY": 30, "DRIZZLE": 12, "RAINY": 6, "FOG": 2},
		"winter": {"SUNNY": 35, "CLOUDY": 25, "SNOW": 30, "FOG": 10}
	},
	RegionType.NORTH: {
		"spring": {"SUNNY": 35, "CLOUDY": 30, "DRIZZLE": 15, "RAINY": 12, "FOG": 8},
		"summer": {"SUNNY": 40, "CLOUDY": 25, "RAINY": 25, "HEAVY_RAIN": 8, "STORM": 2},
		"autumn": {"SUNNY": 45, "CLOUDY": 30, "DRIZZLE": 15, "RAINY": 8, "FOG": 2},
		"winter": {"SUNNY": 30, "CLOUDY": 20, "SNOW": 40, "FOG": 8, "STORM": 2}
	}
}

# 月份天数（非闰年）
var month_days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# 【新增】节日数据字典
# 键格式为 "月日" (例如: 101 代表1月1日)
var festival_data = {
	# --- 公历节日 ---
	101: "元旦",
	214: "情人节",
	501: "五一劳动节",
	1001: "国庆节",
	1002: "国庆节",
	1003: "国庆节",
	1004: "国庆节",
	1005: "国庆节",
	1006: "国庆节",
	1007: "国庆节",
	1224: "平安夜",
	1225: "圣诞节",
	
	# --- 农历节日（使用固定的公历日期近似）---
	# 春节 (按2月10日-12日近似)
	210: "春节",
	211: "春节",
	212: "春节",
	# 元宵节 (按2月25日近似)
	225: "元宵节",
	# 清明节 (按4月5日固定)
	405: "清明节",
	# 端午节 (按6月10日近似)
	610: "端午节",
	# 七夕 (按8月15日近似)
	815: "七夕节",
	# 中秋节 (按9月20日近似)
	920: "中秋节",
	# 重阳节 (按10月15日近似)
	1015: "重阳节",
}



# 当前设置
var current_region: int = RegionType.SOUTH  # 默认四川属于南方
@warning_ignore("shadowed_global_identifier")
var seed: int = 0  # 随机种子，用于确定性随机
var initial_date = {  # 初始日期：1月1日周一
	"year": fc.playerData.game_year,
	"month": fc.playerData.game_month,
	"day": fc.playerData.game_day,
	"weekday": fc.playerData.game_week  # 1=周一, 7=周日
}


# 设置随机种子
func set_seed(new_seed: int):
	seed = new_seed

# 设置地区
func set_region(region: int):
	if region >= 0 and region < RegionType.size():
		current_region = region

# 获取指定天数后的日期和天气信息
# 获取指定天数后的日期和天气信息
func get_date_and_weather(day_offset: int) -> Dictionary:
	var result = {}
	
	# 计算日期
	var date = calculate_date(day_offset)
	result["date"] = date
	
	# 计算星期
	var weekday = calculate_weekday(day_offset)
	result["weekday"] = weekday
	result["weekday_name"] = get_weekday_name(weekday)
	
	# 计算季节
	var season = get_season(date.month, date.day)
	result["season"] = season
	result["season_name"] = get_season_name(season)
	
	# 计算季节英文键（用于天气配置）
	var season_key = get_season_key(season)
	
	# 计算天气
	var weather = generate_weather(date.month, date.day, season_key)
	result["weather"] = weather
	result["weather_name"] = get_weather_name(weather)
	
	# 计算平均温度（替换了原来的温度范围）
	var temperature = calculate_temperature(season, weather)
	result["temperature"] = temperature  # 单个平均温度
	
	# 【新增】查询并添加节日信息
	result["festival"] = get_festival(date.month, date.day)
	
	return result


# 计算指定天数后的日期
func calculate_date(day_offset: int) -> Dictionary:
	var current_year = int(initial_date.year)
	var current_month = int(initial_date.month)
	var current_day = int(initial_date.day)
	var days_remaining = day_offset
	
	# 处理闰年
	@warning_ignore("shadowed_variable")
	var is_leap_year = (current_year % 4 == 0 and current_year % 100 != 0) or (current_year % 400 == 0)
	
	while days_remaining > 0:
		var days_in_month = month_days[current_month - 1]
		if current_month == 2 and is_leap_year:
			days_in_month = 29
		
		if current_day + days_remaining <= days_in_month:
			current_day += days_remaining
			days_remaining = 0
		else:
			days_remaining -= (days_in_month - current_day + 1)
			current_day = 1
			current_month += 1
			
			if current_month > 12:
				current_month = 1
				current_year += 1
				is_leap_year = (current_year % 4 == 0 and current_year % 100 != 0) or (current_year % 400 == 0)
	
	return {
		"year": int(current_year),
		"month": int(current_month),
		"day": int(current_day)
	}

# 计算星期几
func calculate_weekday(day_offset: int) -> int:
	# 初始是周一（1），每过一天加1，超过7则取模
	var weekday = (int(initial_date.weekday) + day_offset) % 7
	if weekday == 0:
		weekday = 7  # 7代表周日
	return weekday

# 获取星期名称
func get_weekday_name(weekday: int) -> String:
	var weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
	return weekdays[weekday - 1]

# 获取季节（基于月份）
# 0: 春季, 1: 夏季, 2: 秋季, 3: 冬季
@warning_ignore("unused_parameter")
func get_season(month: int, day: int) -> int:
	if month == 3 or month == 4 or month == 5:
		return 0  # 春季
	elif month == 6 or month == 7 or month == 8:
		return 1  # 夏季
	elif month == 9 or month == 10 or month == 11:
		return 2  # 秋季
	else:
		return 3  # 冬季

# 获取季节中文名称
func get_season_name(season: int) -> String:
	var seasons = ["春季", "夏季", "秋季", "冬季"]
	return seasons[season]

# 获取季节英文键（用于天气配置）
func get_season_key(season: int) -> String:
	var season_keys = ["spring", "summer", "autumn", "winter"]
	return season_keys[season]

# 生成天气（基于季节、月份和随机性）
func generate_weather(month: int, day: int, season_key: String) -> int:
	# 设置随机种子确保同一天天气确定
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(seed, month, day, current_region, season_key))
	
	# 获取当前地区的天气配置 - 使用英文键
	var weather_config = region_weather_config[current_region][season_key]
	
	# 计算总权重
	var total_weight = 0
	for weather_name in weather_config:
		total_weight += weather_config[weather_name]
	
	# 生成随机数
	var random_value = rng.randi_range(0, total_weight - 1)
	var cumulative_weight = 0
	
	# 确定天气类型
	for weather_name in weather_config:
		cumulative_weight += weather_config[weather_name]
		if random_value < cumulative_weight:
			# 将字符串转换为WeatherType枚举值
			match weather_name:
				"SUNNY": return WeatherType.SUNNY
				"CLOUDY": return WeatherType.CLOUDY
				"DRIZZLE": return WeatherType.DRIZZLE

				"HEAVY_RAIN": return WeatherType.HEAVY_RAIN
				"SNOW": return WeatherType.SNOW

	
	return WeatherType.SUNNY  # 默认

# 获取天气名称
func get_weather_name(weather_type: int) -> String:
	match weather_type:
		WeatherType.SUNNY: return "晴天"
		WeatherType.CLOUDY: return "多云"
		WeatherType.DRIZZLE: return "小雨"
		WeatherType.HEAVY_RAIN: return "大雨"
		WeatherType.SNOW: return "雪天"

		_: return "未知"

# 计算温度范围（基于季节和天气）
func calculate_temperature(season: int, weather: int) -> float:
	var base_temps = {
		0: 16.0,  # 春季平均温度
		1: 28.5,  # 夏季平均温度  
		2: 14.0,  # 秋季平均温度
		3: 2.5    # 冬季平均温度
	}
	
	# 根据地区调整基础温度
	var temp = base_temps[season]
	
	match current_region:
		RegionType.NORTH:
			if season == 3:  # 冬季
				temp -= 8.0  # 北方冬天更冷
			elif season == 1:  # 夏季
				temp += 2.0  # 北方夏天更热
		RegionType.SOUTH:
			if season == 3:  # 冬季
				temp += 6.0  # 南方冬天更暖
			elif season == 1:  # 夏季
				temp += 2.0  # 南方夏天更湿热
		RegionType.EAST:
			if season == 1:  # 夏季
				temp += 1.5  # 东部夏天更湿
		RegionType.WEST:
			if season == 1:  # 夏季
				temp += 3.0  # 西部夏天更热
			elif season == 3:  # 冬季
				temp -= 3.0  # 西部冬天更冷
			else:  # 春秋季温差大
				if season == 0 or season == 2:
					temp -= 1.0
	
	# 根据天气调整
	match weather:
		WeatherType.SUNNY:
			temp += 2.0
		WeatherType.CLOUDY:
			temp -= 1.0
		WeatherType.DRIZZLE:
			temp -= 2.0
		WeatherType.HEAVY_RAIN:
			temp -= 3.5
		WeatherType.SNOW:
			temp = min(temp, 1.0)  # 雪天温度很低
			temp -= 4.0

	# 确保温度在合理范围内
	temp = clamp(temp, -20.0, 40.0)
	
	return temp

# 静态方法：获取地区枚举值（方便外部调用）
static func get_region_south() -> int:
	return RegionType.SOUTH

static func get_region_north() -> int:
	return RegionType.NORTH

static func get_region_east() -> int:
	return RegionType.EAST

static func get_region_west() -> int:
	return RegionType.WEST
	
# 添加到 WeatherAndDateSystem.gd 脚本中

# 根据指定日期获取天气信息（年月日格式）
func get_date_and_weather_by_date(target_year: int, target_month: int, target_day: int) -> Dictionary:
	# 验证日期有效性
	if !is_valid_date(target_year, target_month, target_day):
		push_error("无效的日期: %d-%d-%d" % [target_year, target_month, target_day])
		return {}
	
	# 计算从初始日期到目标日期的天数差
	var day_offset = calculate_days_between_dates(initial_date.year, initial_date.month, initial_date.day, 
											   target_year, target_month, target_day)
	
	# 获取天气信息
	return get_date_and_weather(day_offset)

# 验证日期是否有效
func is_valid_date(year: int, month: int, day: int) -> bool:
	if month < 1 or month > 12:
		return false
	
	var days_in_month = get_days_in_month(year, month)
	return day >= 1 and day <= days_in_month

# 获取指定年月的天数
func get_days_in_month(year: int, month: int) -> int:
	var days = month_days[month - 1]
	if month == 2 and is_leap_year(year):
		return 29
	return days

# 判断是否为闰年
func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)

# 计算两个日期之间的天数差
func calculate_days_between_dates(start_year: int, start_month: int, start_day: int, 
								  end_year: int, end_month: int, end_day: int) -> int:
	# 计算从公元元年到每个日期的总天数，然后相减
	var start_total_days = calculate_total_days_since_epoch(start_year, start_month, start_day)
	var end_total_days = calculate_total_days_since_epoch(end_year, end_month, end_day)
	
	return end_total_days - start_total_days

# 计算从公元元年到指定日期的总天数
func calculate_total_days_since_epoch(year: int, month: int, day: int) -> int:
	var total_days = 0
	
	# 计算年份贡献的天数
	for y in range(1, year):
		total_days += 365
		if is_leap_year(y):
			total_days += 1
	
	# 计算月份贡献的天数
	for m in range(1, month):
		total_days += get_days_in_month(year, m)
	
	# 加上天数
	total_days += day
	
	return total_days

# =================================================================
# 新增功能：与全局游戏日期交互
# =================================================================

# 将游戏日期推进一天，并更新全局的 fc.playerData
# 返回新一天的完整天气信息
func advance_one_day() -> Dictionary:
	# 检查 fc.playerData 是否存在，以防出错
	if not fc or not fc.playerData:
		push_error("全局的 fc.playerData 未找到，无法推进日期。")
		return {}

	# 1. 从全局变量中获取当前日期
	var current_year = fc.playerData.game_year
	var current_month = fc.playerData.game_month
	var current_day = fc.playerData.game_day

	# 2. 计算明天的日期
	# 我们先计算出当前日期是初始日期后的第几天
	var current_day_offset = calculate_days_between_dates(initial_date.year, initial_date.month, initial_date.day, current_year, current_month, current_day)
	# 然后获取下一天（偏移量+1）的信息
	var tomorrow_info = get_date_and_weather(current_day_offset + 1)

	
	# 3. 将新日期保存回全局变量
	fc.playerData.game_year = tomorrow_info.date.year
	fc.playerData.game_month = tomorrow_info.date.month
	fc.playerData.game_day = tomorrow_info.date.day

	
	#print("日期已推进到: %d年%d月%d日" % [fc.playerData.game_year, fc.playerData.game_month, fc.playerData.game_day])

	# 4. 返回新一天的完整信息，方便调用者使用
	return tomorrow_info


# 获取当前游戏日期（从 fc.playerData 读取）的天气信息
func get_current_date_and_weather() -> Dictionary:
	# 检查 fc.playerData 是否存在
	if not fc or not fc.playerData:
		push_error("全局的 fc.playerData 未找到，无法获取当前日期。")
		return {}

	# 从全局变量中读取当前日期
	var current_year = fc.playerData.game_year
	var current_month = fc.playerData.game_month
	var current_day = fc.playerData.game_day

	# 调用已有的函数来获取天气
	return get_date_and_weather_by_date(current_year, current_month, current_day)

# 如果没有节日，返回空字符串 ""
func get_festival(month: int, day: int) -> String:
	var key = month * 100 + day # 将月和日组合成 "月日" 格式的键，例如 10月1日 -> 1001
	if festival_data.has(key):
		return festival_data[key]
	else:
		return ""
		
		
		
