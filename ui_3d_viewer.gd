extends SubViewportContainer

# 导出变量，方便在编辑器里把你的3D场景拖进去
@export_category("Content Settings")
@export var target_scene: PackedScene  # 这里拖入你做好的那个 Node3D 场景
@export var view_size: float = 24.0    # 摄像机视野大小（类似缩放）

# 导出变量，微调相机位置
@export_category("Camera Settings")
@export var camera_distance: float = 100.0 # 相机距离，正交视角下只影响裁剪不影响大小
@export var camera_offset: Vector2 = Vector2.ZERO # 如果场景中心不在(0,0)，用这个微调

@onready var sub_viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D
@onready var container_node: Node3D = $SubViewport/bg # 或者是你指定的挂载点

func _ready() -> void:
	setup_view()
	load_scene()
	



	
	

func setup_view() -> void:
	# 配置相机为正交视图
	if camera:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = view_size
		
		# 设置相机位置：正面看向原点 (Z轴正方向看向负方向)
		# 加上偏移量以对齐你的 GridMap 中心
		camera.position = Vector3(camera_offset.x, camera_offset.y, camera_distance)
		camera.rotation_degrees = Vector3.ZERO # 确保是绝对正视，无旋转




func set_newWall(old,new):#替换墙
	await container_node.replace_tile_by_name(old, new)
	await get_tree().create_timer(1.0).timeout

func set_newDoor(which):#替换墙
	container_node.replace_door(which)




func load_scene() -> void:
	if target_scene:
		# 实例化你的场景
		var scene_instance = target_scene.instantiate()
		
		# 清理旧内容（如果有）
		for child in container_node.get_children():
			child.queue_free()
			
		# 添加新场景
		container_node.add_child(scene_instance)
	else:
		pass
		#push_warning("3D Viewer: 没有设置 Target Scene！")

# 提供一个公共方法，允许你在运行时动态更改显示的物品
func change_scene(new_scene: PackedScene) -> void:
	target_scene = new_scene
	load_scene()
