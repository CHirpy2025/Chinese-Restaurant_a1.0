# time_system.gd
# time_system.gd
extends Node
class_name TimeSystem

signal time_changed(current_time: String)
signal business_state_changed(new_state: int)
signal day_changed

enum BusinessState { OPEN, CLOSING, LUNCH_BREAK, CLOSED }
var current_business_state: BusinessState = BusinessState.CLOSED

var current_game_minutes: int = 0
var time_accumulator: float = 0.0
var is_time_paused: bool = false # 用于处理事件时的临时暂停

var player_data: PlayerData
var main_game: Node  

func setup(main_game_ref: Node, player_data_ref: PlayerData):
	main_game = main_game_ref
	player_data = player_data_ref
	# 加载时从全局数据恢复时间
	current_game_minutes = _time_to_minutes(player_data.now_time)
	_init_business_state()

func _process(delta):
	# 如果正在处理事件，或者切换场景导致节点不在树上，时间自动不走
	if is_time_paused: return
	
	# 根据状态决定流速（营业正常，关门极速）
	var speed = 0.5 if (current_business_state == BusinessState.OPEN or current_business_state == BusinessState.CLOSING) else 0.01
	
	time_accumulator += delta
	if time_accumulator >= speed:
		time_accumulator = 0
		_advance_minute()

func _advance_minute():
	current_game_minutes += 1
	_check_toilet_cleaning_cycle()
	if current_game_minutes >= 1440: current_game_minutes = 0
	
	player_data.now_time = _minutes_to_time_string(current_game_minutes)
	time_changed.emit(player_data.now_time)
	
	# 【新增】非营业时间自动清理肮脏值
	_handle_dirty_cleanup()

	_check_business_logic()

func _check_toilet_cleaning_cycle():
	# 只有在营业期间才自动产生打扫任务（或者你希望随时产生）
	if current_business_state != BusinessState.OPEN: return
	
	# 转换小时为分钟
	var interval = int(max(1, fc.playerData.toilet_clean_time) * 60)
	
	if current_game_minutes % interval == 0:
		var toilets = main_game.randmap_manager.furniture_system.get_all_furniture_by_limit("厕所")
		for t_data in toilets:
			var node = t_data["node_ref"]
			# 只要不全满，就派发打扫
			if main_game.randmap_manager.furniture_system.get_toilet_cleanliness(node) < 100:
				main_game.randmap_manager.waiter_system.dispatch_toilet_cleaning_task(node)


# 【新增】清理逻辑
func _handle_dirty_cleanup():
	# 只有在 CLOSED (正式打烊) 或 LUNCH_BREAK (午休) 状态下才清理
	if current_business_state == BusinessState.CLOSED or current_business_state == BusinessState.LUNCH_BREAK:
		# 每10分钟减少1点
		if current_game_minutes % 10 == 0:
			if fc.playerData.dirty > 0:
				fc.playerData.dirty -= 1
				# print("打扫中...当前肮脏值: ", fc.playerData.dirty)

# TimeSystem.gd

# TimeSystem.gd

func _check_business_logic():
	var cur_time = player_data.now_time
	
	# 1. 开门逻辑保持不变
	if cur_time == player_data.open_time:
		if current_business_state != BusinessState.OPEN:
			_set_business_state(BusinessState.OPEN, "早上开门")
	elif cur_time == "17:00" and player_data.lunch_break_enabled:
		if current_business_state != BusinessState.OPEN:
			_set_business_state(BusinessState.OPEN, "午休结束开门")

	# 2. 触发清场点
	var is_lunch_start = (cur_time == "14:00" and player_data.lunch_break_enabled)
	var is_day_end = (cur_time == player_data.close_time)
	
	if is_lunch_start or is_day_end:
		# 只有在营业时才触发清场
		if current_business_state == BusinessState.OPEN:
			_set_business_state(BusinessState.CLOSING, "时间到，进入清场流程")

	# 3. 核心：清场中的逻辑检测
	if current_business_state == BusinessState.CLOSING:
		# 每一分钟都会检查是否全走光了
		if main_game.all_customers_left():
			var next_state: BusinessState = BusinessState.CLOSED
			
			# 判断是去午休还是彻底关门
			if player_data.lunch_break_enabled and _is_lunch_time(cur_time):
				next_state = BusinessState.LUNCH_BREAK
			else:
				next_state = BusinessState.CLOSED
			
			_set_business_state(next_state, "清场完成")
			
			# 每天营业结束自动存档
			if next_state == BusinessState.CLOSED:
				fc.save_game(fc.save_num)
				

func _set_business_state(new_state: BusinessState, msg: String, manual: bool = false):
	if manual:
		player_data.set_meta("is_manually_closed", (new_state == BusinessState.CLOSING))
	
	current_business_state = new_state
	business_state_changed.emit(new_state)
	player_data.is_open = (new_state == BusinessState.OPEN)
	

func _init_business_state():
	var is_in_hours = fc.is_within_business_hours(player_data.now_time)
	var manual_closed = player_data.get_meta("is_manually_closed", false)
	
	if is_in_hours and not manual_closed:
		current_business_state = BusinessState.OPEN
	else:
		current_business_state = BusinessState.CLOSED

# 辅助转换函数同前...

# 辅助函数：判断是否在午休区间 (对应你func里的14:00-17:00)
func _is_lunch_time(time_str: String) -> bool:
	if not player_data.lunch_break_enabled: 
		return false
	var m = _time_to_minutes(time_str)
	return m >= 840 and m < 1020 # 14:00 - 17:00

func _time_to_minutes(time_str: String) -> int:
	var parts = time_str.split(":")
	return parts[0].to_int() * 60 + parts[1].to_int()

func _minutes_to_time_string(minutes: int) -> String:
	@warning_ignore("integer_division")
	var h = minutes / 60
	var m = minutes % 60
	return "%02d:%02d" % [h, m]



# 新的一天开始
func _on_new_day_start():
	fc.playerData.game_day += 1
	if fc.playerData.game_day > 30:
		fc.playerData.game_day = 1
		fc.playerData.game_month += 1
		if fc.playerData.game_month > 12:
			fc.playerData.game_month = 1
			fc.playerData.game_year += 1
	
	fc.playerData.game_week = (fc.playerData.game_week % 7) + 1
	
	#print("📅 新的一天开始！日期: ", player_data.game_year, "年", player_data.game_month, "月", player_data.game_day, "日")
	day_changed.emit(fc.playerData.game_day, fc.playerData.game_month, fc.playerData.game_year)

# 更新时间显示
func _update_time_display():
	time_changed.emit(_minutes_to_time_string(current_game_minutes))

# 获取当前状态信息
func get_current_state_info() -> Dictionary:
	return {
		"state": current_business_state,
		"time": _minutes_to_time_string(current_game_minutes),
		"is_paused": is_time_paused,
		"is_business_open": fc.playerData.is_open
	}

# 辅助函数
func _time_string_to_minutes(time_str: String) -> int:
	var parts = time_str.split(":")
	var hour = parts[0].to_int()
	var minute = parts[1].to_int()
	return hour * 60 + minute
