extends Control
class_name CustomerChart

# UI 设置
@export var top_padding_percent: float = 0.30  # 顶部留白
@export var bottom_padding: int = 30           # 底部文字区域
@export var bar_width: int = 20                # 柱子宽度
@export var bar_gap: int = 40                 # 柱子间距

# 定义固定的营业时间段
const BUSINESS_HOURS = ["10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "00", "01"]
var stats
@onready var legend_container = $LegendContainer 


	
	

func update_chart():
	# 清理旧图表
	for child in get_children():
		if child != legend_container:
			child.queue_free()
	
	_create_legend()
	
	
	
	# ==========================================
	# 1. 计算全场最大人数 (遍历固定的时间轴)
	# ==========================================
	
	var max_people_in_an_hour = 0
	for h in BUSINESS_HOURS:
		if stats.has(h):
			var hour_data = stats[h]
			var total_people = 0
			for type_count in hour_data.values():
				total_people += type_count 
			if total_people > max_people_in_an_hour:
				max_people_in_an_hour = total_people
	
	# 如果全天没人，默认给个最大值防止除以0，且允许画空轴
	if max_people_in_an_hour == 0: max_people_in_an_hour = 10 
	
	# ==========================================
	# 2. 计算比例尺
	# ==========================================
	
	var total_height = size.y
	var available_draw_height = total_height - (total_height * top_padding_percent) - bottom_padding
	var pixels_per_person = available_draw_height / float(max_people_in_an_hour)
	
	# ==========================================
	# 3. 开始绘制 (遍历固定时间轴)
	# ==========================================
	
	var base_line_y = total_height - bottom_padding
	
	# 计算整体宽度
	var total_chart_width = BUSINESS_HOURS.size() * (bar_width + bar_gap) - bar_gap
	var start_x = (size.x - total_chart_width) / 2
	if start_x < 10: start_x = 10
	
	for i in range(BUSINESS_HOURS.size()):
		var h = BUSINESS_HOURS[i]
		var hour_data = stats.get(h, {}) # 如果没数据，返回空字典
		
		#// 计算当前小时的总人数
		var current_total_people = 0
		for val in hour_data.values():
			current_total_people += val
			
		#// 当前柱子的总像素高度
		var current_bar_height_pixels = current_total_people * pixels_per_person
		
		#// 遍历所有类型，从下往上堆叠
		var current_draw_y_offset = 0 
		
		for type in fc.playerData.CUSTOMER_TYPES:
			var people_count = hour_data.get(type, 0)
			
			if people_count > 0:
				var block_height = people_count * pixels_per_person
				
				#// 计算位置
				var pos_x = start_x + i * (bar_width + bar_gap)
				var pos_y = base_line_y - current_draw_y_offset - block_height
				var block_size = Vector2(bar_width, block_height)
				
				#// 获取颜色
				var color = fc.playerData.TYPE_COLORS.get(type, Color.WHITE)
				
				#// 【新增】绘制带黑色描边的柱子块
				_draw_bordered_rect(Vector2(pos_x, pos_y), block_size, color)
				
				current_draw_y_offset += block_height
		
		#// 添加时间标签
		var label = Label.new()
		label.text = h
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color",Color("333333ff"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.position = Vector2(start_x + i * (bar_width + bar_gap), base_line_y + 5)
		label.set_custom_minimum_size(Vector2(bar_width, bottom_padding - 5))
		add_child(label)


#// 【新增辅助函数】绘制带黑色描边的矩形
func _draw_bordered_rect(pos: Vector2, size: Vector2, color: Color):
	#// 1. 绘制黑色背景作为描边 (宽高各增加2像素，位置左上偏移1像素)
	var border_rect = ColorRect.new()
	border_rect.color = Color.BLACK
	border_rect.position = pos - Vector2(1, 1)
	border_rect.size = size + Vector2(2, 2)
	add_child(border_rect)
	
	#// 2. 绘制彩色前景
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
