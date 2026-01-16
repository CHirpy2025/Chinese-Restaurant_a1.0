# time_settings_panel.gd
extends Control

# --- 节点引用 ---
@onready var open_time_container: HBoxContainer = $Panel/VBoxContainer/OpenTimeContainer
@onready var close_time_container: HBoxContainer = $Panel/VBoxContainer/CloseTimeContainer

# 【修改】更新为新的午休控件引用
@onready var lunch_break_container: HBoxContainer = $Panel/VBoxContainer/LunchBreakContainer
@onready var enable_lunch_button: Button = $Panel/VBoxContainer/LunchBreakContainer/EnableLunchButton
@onready var disable_lunch_button: Button = $Panel/VBoxContainer/LunchBreakContainer/DisableLunchButton
@onready var lunch_time_label: Label = $Panel/VBoxContainer/LunchBreakContainer/LunchTimeLabel

# 时间按钮
const timeBT = preload("res://sc/timebt.tscn")

# --- 时间选项数据 ---
var open_time_options: Array[String] = ["10:00", "10:30", "11:00", "11:30", "12:00"]
var close_time_options: Array[String] = ["22:00", "22:30", "23:00", "23:30", "00:00", "00:30", "01:00"]

# --- 当前选中的值 ---
var current_open_time: String = ""
var current_close_time: String = ""
var is_lunch_break_enabled: bool = false

# --- 信号 ---
#signal settings_confirmed(open_time: String, close_time: String, lunch_break: bool)

func _ready():
	_populate_time_buttons()
	_connect_signals()
	_load_current_settings()
	_update_ui()

# 填充时间按钮
func _populate_time_buttons():
	# 创建开店时间按钮
	for time_str in open_time_options:
		var btn = timeBT.instantiate()
		btn.text = time_str
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		open_time_container.add_child(btn)
		
	# 创建关店时间按钮
	for time_str in close_time_options:
		var btn = timeBT.instantiate()
		btn.text = time_str
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		close_time_container.add_child(btn)

# 连接信号
func _connect_signals():
	# 为所有开店时间按钮连接信号
	for btn in open_time_container.get_children():
		btn.pressed.connect(_on_open_time_button_pressed.bind(btn))
	# 为所有关店时间按钮连接信号
	for btn in close_time_container.get_children():
		btn.pressed.connect(_on_close_time_button_pressed.bind(btn))
	# 【修改】连接新的午休按钮信号
	enable_lunch_button.pressed.connect(_on_enable_lunch_pressed)
	disable_lunch_button.pressed.connect(_on_disable_lunch_pressed)

# 从全局数据加载当前设置
func _load_current_settings():
	current_open_time = fc.playerData.open_time
	current_close_time = fc.playerData.close_time
	is_lunch_break_enabled = fc.playerData.lunch_break_enabled

# 根据当前数据更新UI显示
func _update_ui():
	# 更新开店时间按钮
	for btn in open_time_container.get_children():
		btn.button_pressed = (btn.text == current_open_time)
	# 更新关店时间按钮
	for btn in close_time_container.get_children():
		btn.button_pressed = (btn.text == current_close_time)
	
	# 【修改】更新午休按钮和提示标签
	if is_lunch_break_enabled:
		_on_enable_lunch_pressed() # 模拟点击效果，更新UI
	else:
		_on_disable_lunch_pressed()

# --- 信号回调函数 ---

func _on_open_time_button_pressed(pressed_button: Button):
	current_open_time = pressed_button.text
	for btn in open_time_container.get_children():
		btn.button_pressed = (btn == pressed_button)

func _on_close_time_button_pressed(pressed_button: Button):
	current_close_time = pressed_button.text
	for btn in close_time_container.get_children():
		btn.button_pressed = (btn == pressed_button)

# 【新增】启用午休按钮的回调
func _on_enable_lunch_pressed():
	is_lunch_break_enabled = true
	enable_lunch_button.button_pressed = true
	disable_lunch_button.button_pressed = false
	lunch_time_label.visible = true


# 【新增】不启用午休按钮的回调
func _on_disable_lunch_pressed():
	is_lunch_break_enabled = false
	enable_lunch_button.button_pressed = false
	disable_lunch_button.button_pressed = true
	lunch_time_label.visible = false


func _on_confirm_pressed():
	# 保存设置到全局数据
	fc.playerData.open_time = current_open_time
	fc.playerData.close_time = current_close_time
	fc.playerData.lunch_break_enabled = is_lunch_break_enabled
	
