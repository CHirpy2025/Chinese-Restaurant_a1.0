# cooking_control_panel.gd
extends Control

# 节点引用
@onready var gradient_background = $gradient_background
@onready var areas_container = $AreasContainer
@onready var slider = $SliderContainer/CookingSlider
@onready var area1 = $AreasContainer/Area1
@onready var area2 = $AreasContainer/Area2
@onready var area3 = $AreasContainer/Area3
@onready var area4 = $AreasContainer/Area4
@onready var timeshow = $NinePatchRect4/time # 用于显示计算出的时间

# 区域配置
const AREA_COUNT = 4
const AREA_NAMES = ["生", "偏生", "熟", "过熟"]

# --- 烹饪时间计算参数 ---
# 【关键】base_cook_time 现在是 0% (生区域0%) 的时间，而不是完美熟度的时间
@export var base_cook_time: float = 10.0  # 基准时间：在“生”区域0%需要10秒

# 每个区域每1%变化对应的时间（秒）
# [生区域, 偏生区域, 熟区域, 过熟区域]
@export var time_rate_per_area: Array[float] = [0.05, 0.08, 0.10, 0.15]

# --- 内部状态变量 ---
var area_rects = []
var area_labels = []
var is_dragging = false
var current_area = 0
var current_percentage = 0
var initial_area: int = 0
var initial_percentage: int = 0

signal cooking_changed()


func _ready():
	area_rects = [area1, area2, area3, area4]
	setup_ui()
	connect_slider_signals()

# --- 【核心修改】初始化函数 ---
# 当切换菜品时，外部调用此函数来设置初始状态
func initialize_cooking(saved_time: float, start_area: int, start_percentage: int):
	# 1. 计算从0%到保存状态所花费的时间
	var time_from_zero = 0.0

	
	var target_level = start_area * 100 + start_percentage

	for level in range(0, target_level):
		@warning_ignore("integer_division")
		var area_for_this_level = int(level / 100)
		time_from_zero += time_rate_per_area[area_for_this_level]
			
	# 2. 【关键】反向推导出该菜品的 base_cook_time (0%的时间)
	base_cook_time = saved_time - time_from_zero

	# 3. 设置初始状态变量
	initial_area = clamp(start_area, 0, AREA_COUNT - 1)
	initial_percentage = clamp(start_percentage, 0, 99)
	
	# 4. 设置滑块到初始位置，这会自动触发UI更新
	slider.value = initial_area * 100 + initial_percentage
	
	#print("烹饪系统初始化: 菜品基准时间(0%%)=%.2f, 初始区域=%s, 初始化百分比=%d%%" % [
		#base_cook_time, AREA_NAMES[initial_area], initial_percentage
	#])

# 设置UI
func setup_ui():
	setup_gradient_background()
	setup_areas()
	setup_slider()
	# 初始化时更新一次显示
	update_result()
	
func setup_gradient_background():
	gradient_background.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	gradient_background.stretch_mode = TextureRect.STRETCH_SCALE

func setup_areas():
	for i in range(area_rects.size()):
		var area = area_rects[i]
		area.color = Color.TRANSPARENT
		area.add_theme_constant_override("border_width", 1)
		area.add_theme_color_override("border_color", Color(1, 1, 1, 0.3))
		area.mouse_filter = Control.MOUSE_FILTER_PASS

func setup_slider():
	slider.min_value = 0
	slider.max_value = AREA_COUNT * 100
	slider.step = 1
	slider.add_theme_constant_override("separation", 10)

func connect_slider_signals():
	slider.value_changed.connect(_on_slider_value_changed)
	slider.drag_ended.connect(_on_slider_drag_ended)

@warning_ignore("unused_parameter")
func _on_slider_value_changed(value: float):
	update_result()
	if is_dragging:
		var area = int(value / 100)
		if area != current_area:
			play_area_change_sound(area)

func play_area_change_sound(area: int):
	match area:
		0: fc.play_se_fx("clear")
		1: fc.play_se_fx("clear")
		2: fc.play_se_fx("clear")
		3: fc.play_se_fx("clear")

@warning_ignore("unused_parameter")
func _on_slider_drag_ended(value_changed: bool):
	pass

# 更新结果
func update_result():
	var value = slider.value
	current_area = int(value / 100)
	current_percentage = int(fmod(value, 100))
	current_area = clamp(current_area, 0, AREA_COUNT - 1)
	
	#var area_name = AREA_NAMES[current_area]
	highlight_current_area()
	update_cooking_time()
	
	cooking_changed.emit()

# --- 【核心修改】时间计算函数 ---
# 从0%开始，累加到当前状态的总时间
func calculate_cooking_time() -> float:
	var total_time = base_cook_time # 从0%的时间开始
	var current_level = current_area * 100 + current_percentage
	
	# 从0%计算到当前百分比点
	for level in range(0, current_level):
		@warning_ignore("integer_division")
		var area_for_this_level = int(level / 100)
		total_time += time_rate_per_area[area_for_this_level]
	
	if total_time<1:
		total_time=1
	return total_time

# 更新时间显示
func update_cooking_time():
	var calculated_time = calculate_cooking_time()
		
	if timeshow:
		var time_int = int(round(calculated_time))
		timeshow.text = "%d" % time_int

# 高亮当前区域
func highlight_current_area():
	for i in range(area_rects.size()):
		var area = area_rects[i]
		if i == current_area:
			area.add_theme_constant_override("border_width", 3)
			area.add_theme_color_override("border_color", Color.YELLOW)
		else:
			area.color = Color.TRANSPARENT
			area.add_theme_constant_override("border_width", 1)
			area.add_theme_color_override("border_color", Color(1, 1, 1, 0.3))

# 设置滚动条值（外部调用）
func set_cooking_level(area: int, percentage: int):
	area = clamp(area, 0, AREA_COUNT - 1)
	percentage = clamp(percentage, 0, 99)
	slider.value = area * 100 + percentage

# 获取当前烹饪状态
func get_cooking_status() -> Dictionary:
	return {
		"area": current_area,
		"percentage": current_percentage,
		"calculated_time": calculate_cooking_time()
	}

# 重置到初始状态
func reset():
	slider.value = initial_area * 100 + initial_percentage
	update_result()
