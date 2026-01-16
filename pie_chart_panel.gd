extends Control
class_name PieChartPanel

# ========================================================
# 配置与颜色定义
# ========================================================

# 性别颜色
const SEX_COLORS = {
	"男性": Color.AQUA,
	"女性": Color.PALE_VIOLET_RED
}

# 年龄颜色 (使用色谱区分)
const AGE_COLORS = {
	"儿童": Color.SPRING_GREEN,
	"少年": Color.CYAN,
	"青年": Color.SKY_BLUE,
	"中年": Color.ORANGE,
	"老年": Color.RED
}

# 布局配置
@export var pie_radius: int = 100         # 饼图半径 (稍微调小一点给文字留空间)
@export var pie_gap: int = 180           # 饼图之间的间距 (加大间距防止引出线文字重叠)
@export var label_line_offset: int = 15  # 引出线第一段延伸长度
@export var label_horizontal_offset: int = 35 # 引出线第二段水平延伸长度

# 内部数据缓存
var chart_data_type: Dictionary = {}
var chart_data_sex: Dictionary = {}
var chart_data_age: Dictionary = {}

# 字体引用 (用于 draw_string)
var label_font: Font = load("res://XiangcuiDengcusong.ttf")



# ========================================================
# 核心刷新逻辑
# ========================================================

func update_charts():
	# 1. 从玩家数据中获取统计
	chart_data_type = fc.playerData.total_guest_type_num.duplicate()
	chart_data_sex = fc.playerData.total_guest_sex_num.duplicate()
	chart_data_age = fc.playerData.total_guest_age_num.duplicate()
	
	# 触发重绘
	queue_redraw()

# ========================================================
# 绘图循环 (Godot 核心)
# ========================================================
# ========================================================
# 绘图循环 (Godot 核心) - 修改为2上1下布局
# ========================================================

func _draw():
	# 计算三个饼图的中心坐标
	# 上排 Y 坐标：屏幕高度的 30% 处
	var upper_y = size.y * 0.3
	# 下排 Y 坐标：屏幕高度的 70% 处
	var lower_y = size.y * 0.85
	
	# 上排左图 X 坐标：屏幕宽度的 25% 处
	var left_x = size.x * 0.25
	# 上排右图 X 坐标：屏幕宽度的 75% 处
	var right_x = size.x * 0.75
	# 下排中间图 X 坐标：屏幕宽度的 50% 处
	var bottom_x = size.x * 0.5
	
	# 绘制三个饼图
	# 1. 客人类型 (左上)
	_draw_single_pie_chart(0, Vector2(left_x, upper_y), chart_data_type, fc.playerData.TYPE_COLORS, "客人类型")
	
	# 2. 性别分布 (右上)
	_draw_single_pie_chart(1, Vector2(right_x, upper_y), chart_data_sex, SEX_COLORS, "性别分布")
	
	#// 3. 年龄分布 (下中)
	_draw_single_pie_chart(2, Vector2(bottom_x, lower_y), chart_data_age, AGE_COLORS, "年龄分布")

# ========================================================
# 单个饼图绘制逻辑 (带引出线和标签)
# ========================================================

@warning_ignore("unused_parameter")
func _draw_single_pie_chart(index: int, center: Vector2, data: Dictionary, color_map: Dictionary, chart_name: String):
	# 1. 计算总数
	var total = 0
	for val in data.values():
		total += val
	
	# 2. 绘制饼图
	if total == 0:
		# 如果没人，画个灰色的空圆
		draw_circle(center, pie_radius, Color(0.2, 0.2, 0.2, 0.3))
		# 画个提示文字
		if label_font:
			var text_pos = center - Vector2(80, -16)
			draw_string(label_font, text_pos, chart_name+"暂无数据", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.BLACK)
		return
	
	var current_angle = 0.0 # 起始角度
	
	for key in data:
		var count = data[key]
		var percentage = float(count) / float(total)
		var slice_angle = percentage * 360.0 # 扇形角度
		
		# 获取颜色
		var color = color_map.get(key, Color.WHITE)
		
		# 绘制扇形
		_draw_pie_slice(center, pie_radius, current_angle, current_angle + slice_angle, color)
		
		# 如果占比太低（比如小于2%），为了防止文字挤在一起，可以选择不画
		# 这里设定阈值：角度小于 5 度不画标签
		if slice_angle >= 5.0:
			# 计算扇形中心角度
			var mid_angle = current_angle + (slice_angle / 2.0)
			
			# 绘制引出线和标签
			_draw_slice_label(center, pie_radius, mid_angle, key, count, percentage)
			
		# 更新下一扇区的起始角度
		current_angle += slice_angle

# ========================================================
# 绘制引出线和文字标签
# ========================================================

@warning_ignore("unused_parameter")
func _draw_slice_label(center: Vector2, radius: float, angle_deg: float, label_text: String, count: int, percent: float):
	# 1. 角度转弧度
	var rad = deg_to_rad(angle_deg)
	
	# 2. 计算线条的三个点
	# 起点：圆周上
	var p_start = center + Vector2(cos(rad), sin(rad)) * radius
	
	# 拐点：向外延伸
	var p_break = center + Vector2(cos(rad), sin(rad)) * (radius + float(label_line_offset))
	
	# 终点：向左或向右水平延伸
	# 逻辑：角度在右侧 (-90度 ~ 90度) 向右延伸，否则向左
	var is_right_side = (angle_deg >= -90 and angle_deg <= 90)
	
	var p_end_x = p_break.x + (label_horizontal_offset if is_right_side else -label_horizontal_offset)
	var p_end = Vector2(p_end_x, p_break.y)
	
	# 3. 绘制引出线 (黑色细线)
	draw_line(p_start, p_break, Color(0, 0, 0, 0.7), 1.5)
	draw_line(p_break, p_end, Color(0, 0, 0, 0.7), 1.5)
	
	# 4. 绘制文字
	if label_font:
		var text_str = "%s\n：%d" % [label_text, count]
		
		# 文字偏移量
		var offset = 5 if is_right_side else -5
		var text_pos = p_end + Vector2(offset, -10) # 稍微向上偏移让线条连在文字中间
		
		# 右侧文字左对齐，左侧文字右对齐
		var align = HORIZONTAL_ALIGNMENT_LEFT if is_right_side else HORIZONTAL_ALIGNMENT_RIGHT

		# 绘制
		draw_string(label_font, text_pos, text_str, align, -1, 22, Color.BLACK)

# ========================================================
# 绘制扇形 (使用多边形逼近)
# ========================================================

func _draw_pie_slice(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color):
	var points = PackedVector2Array()
	points.append(center) # 圆心
	
	# 生成圆周上的点
	# 使用 30 段逼近圆弧
	var step = (end_angle - start_angle) / 30.0
	for i in range(31):
		var ang = deg_to_rad(start_angle + i * step)
		var x = center.x + cos(ang) * radius
		var y = center.y + sin(ang) * radius
		points.append(Vector2(x, y))
	
	draw_colored_polygon(points, color)

# ========================================================
# 窗口大小改变时重绘
# ========================================================

func _on_resized():
	queue_redraw()
