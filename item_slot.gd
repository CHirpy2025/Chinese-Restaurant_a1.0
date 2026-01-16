# ItemSlot.gd
extends Control

@onready var icon = $Icon
@onready var count_label = $CountLabel

var item_data: ItemData

# 当槽位被点击时，发出这个信号
signal selected(item_data: ItemData)

func _ready():
	# 监听自身的输入事件
	gui_input.connect(_on_gui_input)

# 用于设置槽位显示的内容
func setup(data: ItemData, count: int):
	item_data = data
	icon.texture = data.item_texture
	count_label.text = str(count)

# 处理鼠标点击
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(item_data)
