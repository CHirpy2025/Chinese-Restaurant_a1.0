extends Control
class_name MonthlyFinanceChart

# UI 设置
@export var top_padding_percent: float = 0.20  # 顶部留白
@export var bottom_padding: int = 40           # 底部文字区域
@export var bar_width: int = 12                # 柱子宽度（两根柱子，所以要细）
@export var bar_gap: int = 6                   # 两根柱子之间的间隙
@export var month_gap: int = 30                # 两个月之间的间隙

@onready var legend_container = $LegendContainer 

func _ready():
	update_chart()

func update_chart():
	# 清理旧图表
	for child in get_children():
		if child != legend_container:
			child.queue_free()
	
	_create_legend()
	
	var revenue_stats = fc.playerData.monthly_stats_revenue
	var cost_stats = fc.playerData.monthly_stats_cost
	
	# ==========================================
	# 1. 计算全年的数值范围 (用于确定Y轴和0线位置)
	# ==========================================
	
	var max_val = 0     # 全年最大的正数
	var min_val = 0     # 全年最小的数 (可能为负，代表亏损)
	
	for m in range(1, 13):
		var month_str = str(m)
		var rev = revenue_stats.get(month_str, 0)
		var cost = cost_stats.get(month_str, 0)
		var profit = rev - cost
		
		if rev > max_val: max_val = rev
		if profit > max_val: max_val = profit
		
		if profit < min_val: min_val = profit
	
	# 如果全年没数据，给个默认范围
	if max_val == 0 and min_val == 0: 
		max_val = 1000
		
	# 增加一点顶部/底部缓冲，防止柱子顶到边
	# 比如最大值是100，我们让Y轴上限设为120
	var range_val = max_val - min_val
	if range_val == 0: range_val = max_val # 防止除以0
	
	var buffer = range_val * 0.1 # 10% 缓冲
	max_val += buffer
	min_val -= buffer
	
	# ==========================================
	# 2. 计算比例尺
	# ==========================================
	
	var total_height = size.y
	var available_draw_height = total_height - (total_height * top_padding_percent) - bottom_padding
	var pixels_per_unit = available_draw_height / float(range_val)
	
	# 计算0线(Y=0)在屏幕上的像素位置
	# 公式: 底部Y - (0 - min_val) * 比例尺
	var base_bottom_y = total_height - bottom_padding
	var zero_line_y = base_bottom_y - (0 - min_val) * pixels_per_unit
	
	# ==========================================
	# 3. 开始绘制 (1月 - 12月)
	# ==========================================
	
	# 计算整体宽度：12个月，每个月占 (bar宽 + bar宽 + 间隙 + 月份间隔)
	# 每个月占用宽度 = bar_width (营收) + bar_gap + bar_width (利润) + month_gap
	var month_width = bar_width * 2 + bar_gap + month_gap
	var total_chart_width = 12 * month_width
	var start_x = (size.x - total_chart_width) / 2
	if start_x < 10: start_x = 10
	
	for i in range(12):
		var month = i + 1
		var month_str = str(month)
		
		var rev = revenue_stats.get(month_str, 0)
		var cost = cost_stats.get(month_str, 0)
		var profit = rev - cost
		
		# 当前月份的起始X坐标
		var current_month_start_x = start_x + i * month_width
		
		# ------------------------------------------
		# 绘制营收柱 (左柱，金色)
		# ------------------------------------------
		# 高度 = 营收 * 比例尺
		# Y坐标 = 0线位置 - 高度 (向上生长)
		var rev_height = rev * pixels_per_unit
		var rev_y = zero_line_y - rev_height
		
		_draw_bordered_rect(
			Vector2(current_month_start_x, rev_y), 
			Vector2(bar_width, rev_height), 
			Color.GOLD # 营收颜色：金色
		)
		
		# ------------------------------------------
		# 绘制利润柱 (右柱，青色或红色)
		# ------------------------------------------
		var profit_height = abs(profit) * pixels_per_unit
		var profit_color = Color.CYAN # 默认盈利青色
		var profit_y = zero_line_y
		
		if profit >= 0:
			# 盈利：向上生长
			profit_y = zero_line_y - profit_height
			profit_color = Color.CYAN
		else:
			# 亏损：向下生长
			# Y坐标就是0线位置，高度向下
			profit_color = Color.RED # 亏损红色
		
		_draw_bordered_rect(
			Vector2(current_month_start_x + bar_width + bar_gap, profit_y), 
			Vector2(bar_width, profit_height), 
			profit_color
		)
		
		# ------------------------------------------
		# 绘制0线 (辅助线)
		# ------------------------------------------
		# 只在第一个月绘制一次即可，或者每根柱子都画一点点
		if i == 0:
			var line = ColorRect.new()
			line.color = Color.DARK_GRAY
			line.position = Vector2(start_x - 5, zero_line_y)
			line.size = Vector2(total_chart_width + 10, 2)
			add_child(line)

		# ------------------------------------------
		# 添加月份标签
		# ------------------------------------------
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color",Color("333333ff"))
		label.text = str(month) + "月"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(current_month_start_x, base_bottom_y + 5)
		label.set_custom_minimum_size(Vector2(month_width - month_gap, bottom_padding - 5))
		add_child(label)
		



# 绘制带黑色描边的矩形
func _draw_bordered_rect(pos: Vector2, size: Vector2, color: Color):
	# 边框
	var border = ColorRect.new()
	border.color = Color.BLACK
	border.position = pos - Vector2(1, 1)
	border.size = size + Vector2(2, 2)
	add_child(border)
	
	# 内容
	var fill = ColorRect.new()
	fill.color = color
	fill.position = pos
	fill.size = size
	add_child(fill)

func _create_legend():
	for child in legend_container.get_children():
		child.queue_free()
		
	# 营收图例
	var item1 = HBoxContainer.new()
	var c1 = ColorRect.new()
	c1.color = Color.GOLD
	c1.set_custom_minimum_size(Vector2(15, 15))
	var l1 = Label.new()
	l1.add_theme_font_size_override("font_size", 20)
	l1.add_theme_color_override("font_color",Color("888888ff"))
	l1.text = "营业额"
	item1.add_child(c1)
	item1.add_child(l1)
	legend_container.add_child(item1)
	
	# 利润图例
	var item2 = HBoxContainer.new()
	var c2 = ColorRect.new()
	c2.color = Color.DARK_GREEN
	c2.set_custom_minimum_size(Vector2(15, 15))
	var l2 = Label.new()
	l2.add_theme_font_size_override("font_size", 20)
	l2.add_theme_color_override("font_color",Color("888888ff"))
	l2.text = "利润 (盈)"
	item2.add_child(c2)
	item2.add_child(l2)
	legend_container.add_child(item2)

	# 亏损图例
	var item3 = HBoxContainer.new()
	var c3 = ColorRect.new()
	c3.color = Color.RED
	c3.set_custom_minimum_size(Vector2(15, 15))
	var l3 = Label.new()
	l3.text = "利润 (亏)"
	l3.add_theme_font_size_override("font_size", 20)
	l3.add_theme_color_override("font_color",Color("888888ff"))
	item3.add_child(c3)
	item3.add_child(l3)
	legend_container.add_child(item3)
	
	legend_container.add_theme_constant_override("separation", 15)


func _on_resized():
	update_chart()
