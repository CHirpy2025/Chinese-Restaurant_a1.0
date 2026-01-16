extends Control

func _ready():
	# 确保面板在最上层
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 允许鼠标穿透
	z_index = 1000


func show_info(typename):
	$type.text=typename
