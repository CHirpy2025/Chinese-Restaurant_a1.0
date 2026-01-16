extends Control
class_name MonthlyChart

# UI 设置
@export var top_padding_percent: float = 0.30  # 顶部留白
@export var bottom_padding: int = 30           # 底部文字区域
@export var bar_width: int = 15                # 柱子宽度（天数多，可以稍微细一点）
@export var bar_gap: int = 15                 # 柱子间距

# 定义一个月最多显示的天数
var MAX_DAYS = 30

@onready var legend_container = $LegendContainer 

func _ready():
	# 模拟一些测试数据，实际使用时可以删除这部分
	# 假设当前是 game_day = 5
	update_chart()

func update_chart():
	if fc.playerData.game_month==2:
		MAX_DAYS=28
	elif fc.playerData.game_month in [1,3,5,7,8,10,12]:
		MAX_DAYS=31
	
	
	# 清理旧图表
	for child in get_children():
		if child != legend_container:
			child.queue_free()
	
	_create_legend()
	
	var stats = fc.playerData.daily_stats
	
	# ==========================================
	# 1. 计算本月单日最大人数
	# ==========================================
	
	var max_people_in_a_day = 0
	
	# 遍历 1 到 31 号
	for d in range(1, MAX_DAYS + 1):
		var day_str = str(d)
		if stats.has(day_str):
			var day_data = stats[day_str]
			var total_people = 0
			# 累加该日所有类型的人数
			for type_count in day_data.values():
				total_people += type_count 
			
			if total_people > max_people_in_a_day:
				max_people_in_a_day = total_people
	
	# 如果全月没人，默认给个最大值防止除以0
	if max_people_in_a_day == 0: max_people_in_a_day = 10 
	
	# ==========================================
	# 2. 计算比例尺
	# ==========================================
	
	var total_height = size.y
	var available_draw_height = total_height - (total_height * top_padding_percent) - bottom_padding
	var pixels_per_person = available_draw_height / float(max_people_in_a_day)
	
	# ==========================================
	# 3. 开始绘制 (遍历 1 到 31 号)
	# ==========================================
	
	var base_line_y = total_height - bottom_padding
	
	# 计算整体宽度
	var total_chart_width = MAX_DAYS * (bar_width + bar_gap) - bar_gap
	var start_x = (size.x - total_chart_width) / 2
	if start_x < 10: start_x = 10
	
	for i in range(MAX_DAYS):
		var d = i + 1 # 当前日期 1-31
		var day_str = str(d)
		var day_data = stats.get(day_str, {})
		
		# 计算当前日期的总人数
		var current_total_people = 0
		for val in day_data.values():
			current_total_people += val
			
		# 当前柱子的总像素高度
		var current_bar_height_pixels = current_total_people * pixels_per_person
		
		# 遍历所有类型，从下往上堆叠
		var current_draw_y_offset = 0 
		
		for type in fc.playerData.CUSTOMER_TYPES:
			var people_count = day_data.get(type, 0)
			
			if people_count > 0:
				var block_height = people_count * pixels_per_person
				
				# 计算位置
				var pos_x = start_x + i * (bar_width + bar_gap)
				var pos_y = base_line_y - current_draw_y_offset - block_height
				var block_size = Vector2(bar_width, block_height)
				
				# 获取颜色
				var color = fc.playerData.TYPE_COLORS.get(type, Color.WHITE)
				
				# 绘制带黑色描边的柱子块
				_draw_bordered_rect(Vector2(pos_x, pos_y), block_size, color)
				
				current_draw_y_offset += block_height
		
		# 添加日期标签 (每隔5天显示一次标签，防止重叠，或者全部显示)
		# 这里为了美观，简单全部显示，如果密可以自行加逻辑 if d % 5 == 0
		var label = Label.new()
		label.text = str(d)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color",Color("333333ff"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.position = Vector2(start_x + i * (bar_width + bar_gap), base_line_y + 5)
		label.set_custom_minimum_size(Vector2(bar_width, bottom_padding - 5))
		

		
		add_child(label)



# 绘制带黑色描边的矩形
func _draw_bordered_rect(pos: Vector2, size: Vector2, color: Color):
	# 1. 绘制黑色背景作为描边
	var border_rect = ColorRect.new()
	border_rect.color = Color.BLACK
	border_rect.position = pos - Vector2(1, 1)
	border_rect.size = size + Vector2(2, 2)
	add_child(border_rect)
	
	# 2. 绘制彩色前景
	var fill_rect = ColorRect.new()
	fill_rect.color = color
	fill_rect.position = pos
	fill_rect.size = size
	add_child(fill_rect)

func _create_legend():
	for child in legend_container.get_children():
		child.queue_free()
		
	for type in fc.playerData.CUSTOMER_TYPES:
		var item = HBoxContainer.new()
		var color_box = ColorRect.new()
		color_box.color = fc.playerData.TYPE_COLORS.get(type, Color.WHITE)
		color_box.set_custom_minimum_size(Vector2(15, 15))
		
		var label = Label.new()
		label.text = type
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color",Color("888888ff"))
		
		item.add_child(color_box)
		item.add_child(label)
		item.add_theme_constant_override("separation", 5)
		legend_container.add_child(item)


func _on_resized():
	update_chart()
