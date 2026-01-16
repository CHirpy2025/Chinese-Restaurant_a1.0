# price_slider_control.gd
extends Control

# --- 可在编辑器中调整的参数 ---
@export var min_price: float = 0.0
@export var max_price: float = 200.0
@export var cost_price: float = 50.0 # 初始成本价
@export var price_step: float = 1.0

# 颜色配置
@export var default_color: Color = Color("888888")
@export var profit_color: Color = Color("2c6bab")
@export var high_profit_color: Color = Color("e95d5d")

# --- 节点引用 ---
@onready var price_slider: HSlider = $PriceSlider
@onready var cost_price_tick: ColorRect = $CostPriceTick
@onready var cost_price_label: Label = $CostPriceLabel
@onready var current_price_label: Label = $CurrentPriceLabel

# --- 内部变量 ---
var is_dragging: bool = false

# --- 信号 ---
signal price_changed(new_price: float)

func _ready():
	# 初始化滑块
	setup_slider()
	
	# 连接信号
	price_slider.value_changed.connect(_on_slider_value_changed)
	price_slider.drag_started.connect(_on_drag_started)
	#price_slider.drag_ended.connect(_on_drag_ended)
	
	# 初始化所有UI元素
	update_all_visuals()

func setup_slider():
	price_slider.min_value = min_price
	price_slider.max_value = max_price
	price_slider.step = price_step
	price_slider.value = cost_price # 默认从成本价开始

# --- 信号处理函数 ---
func _on_drag_started():
	is_dragging = true

#func _on_drag_ended(value_changed: bool):
	#is_dragging = false
	##print("拖动结束，值是否改变: ", value_changed)

func _on_slider_value_changed(value: float):
	update_current_price_label()
	update_slider_color()
	price_changed.emit(value)

# --- 核心更新函数 ---
func update_all_visuals():
	update_cost_price_indicator()
	update_current_price_label()
	update_slider_color()

# 更新成本价指示器（刻度线和标签）
func update_cost_price_indicator():
	# 确保成本价在有效范围内
	var clamped_cost_price = clamp(cost_price, min_price, max_price)
	
	# 计算成本价在滑块上的相对位置 (0.0 到 1.0)
	var ratio = (clamped_cost_price - min_price) / (max_price - min_price)
	
	# 计算实际像素位置
	var slider_width = price_slider.size.x
	var tick_x_position = price_slider.position.x + ratio * slider_width
	
	# 更新刻度线位置
	cost_price_tick.position.x = tick_x_position - cost_price_tick.size.x / 2 # 居中对齐
	
	# 更新标签位置和文字
	#cost_price_label.position.x = tick_x_position - cost_price_label.size.x / 2 # 居中对齐
	cost_price_label.text = "成本: ¥%.0f" % clamped_cost_price

# 更新当前价格标签
func update_current_price_label():
	var current_price = price_slider.value
	current_price_label.text = "¥%.0f" % current_price
	
	# 将标签定位在滑块把手的右侧
	@warning_ignore("unused_variable")
	var handle_ratio = (current_price - min_price) / (max_price - min_price)
	#var handle_x_position = price_slider.position.x + handle_ratio * price_slider.size.x
	#current_price_label.position.x = handle_x_position + 20 # 在把手右侧20像素

# 更新滑块颜色
func update_slider_color():
	var current_price = price_slider.value
	var style_box: StyleBoxFlat
	
	if current_price <= cost_price:
		style_box = _create_stylebox(default_color)
	elif current_price <= cost_price * 1.6:
		style_box = _create_stylebox(profit_color)
	else:
		style_box = _create_stylebox(high_profit_color)
		
	price_slider.add_theme_stylebox_override("grabber_area_highlight", style_box)
	
# --- 公共API函数 ---

# 设置新的成本价（这是你要求的核心函数）
func set_cost_price(new_cost_price: float):
	cost_price = clamp(new_cost_price, min_price, max_price)
	update_cost_price_indicator()
	update_slider_color() # 重新计算颜色，因为基准变了
	print("成本价已更新为: ¥%.2f" % cost_price)

# 设置当前价格
func set_current_price(new_price: float):
	price_slider.value = clamp(new_price, min_price, max_price)

# 获取当前价格
func get_current_price() -> float:
	return price_slider.value

# 获取成本价
func get_cost_price() -> float:
	return cost_price

# --- 辅助函数 ---
# 创建一个指定颜色的样式盒
func _create_stylebox(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.set_border_width_all(1)
	style.border_color = color.darkened(0.3)
	return style
