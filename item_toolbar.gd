extends Window

@onready var main_panel = $title # 引用你的主背景面板

func _ready():
	# 1. 初始设置为全透明背景
	transparent = true
	transparent_bg = true
	
	# 2. 强制让窗口居中于主显示器
	center_window_on_screen()
	
	# 3. 设置穿透区域 (初始设置一次)
	update_passthrough()
	
	# 连接面板大小改变信号（如果你的UI大小会动态变化）
	main_panel.resized.connect(update_passthrough)

func center_window_on_screen():
	var screen_id = DisplayServer.window_get_current_screen()
	var screen_pos = DisplayServer.screen_get_position(screen_id)
	var screen_size = DisplayServer.screen_get_size(screen_id)
	
	# 计算居中位置
	var center_pos = screen_pos + (screen_size / 2) - (size / 2)
	position = center_pos

func update_passthrough():
	# 等待一帧以确保 UI 布局已更新
	await get_tree().process_frame
	
	# 获取 UI 面板在窗口内的矩形区域
	var rect = main_panel.get_rect()
	
	# 转换为多边形点数组
	var polygon = PackedVector2Array([
		Vector2(rect.position.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.end.y),
		Vector2(rect.position.x, rect.end.y)
	])
	
	# 设置该窗口的点击穿透区域
	# 注意：这里直接设置 Window 属性，而不是调用 DisplayServer
	mouse_passthrough_polygon = polygon


func _input(event):
	# 监听与主场景相同的快捷键
	if event.is_action_pressed("ui_up"): # 比如你的空格键
		# get_parent() 就是 Main 节点
		# 我们直接调用 Main 里的 toggle_ui()，复用逻辑
		get_parent().toggle_ui()
		# 阻止事件继续传播（可选，防止触发 UI 内部按钮的默认行为）
		get_viewport().set_input_as_handled()




func show_with_animation():
	var tween = create_tween()
	main_panel.modulate = Color.TRANSPARENT  # 初始透明
	tween.tween_property(main_panel, "modulate", Color.WHITE, 0.3)
	await tween.finished


func hide_with_animation():
	var tween = create_tween()
	# 缩小效果
	tween.tween_property(main_panel, "modulate", Color.TRANSPARENT, 0.2)
	await tween.finished
	queue_free()
