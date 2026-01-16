# CameraController.gd (包含偏移量的最终版)
extends Camera3D

# --- 跟随与限制配置 ---
@export var target_node_path: NodePath # 在这里拖入你的角色节点
@export var follow_offset: Vector3 = Vector3(0, 6, 12) # 【新增】相机相对于角色的偏移量
@export var follow_speed: float = 5.0 # 跟随的平滑度 (数值越大越快)
@export var min_z: float = -50.0 # Z轴的最小值（相机最终位置的Z轴）
@export var max_z: float = 50.0  # Z轴的最大值（相机最终位置的Z轴）

# --- 旋转配置 ---
@export var rotation_speed: float = 2.0 # 旋转灵敏度
@export var min_rotation_y: float = -60.0 # 向左旋转的最大角度
@export var max_rotation_y: float = 60.0  # 向右旋转的最大角度

# --- 内部变量 ---
var _is_rotating: bool = false
var _target: Node3D

func _ready():
	# 获取目标节点
	if target_node_path.is_empty():
		push_error("CameraController: Target Node Path is not set!")
		return
		
	_target = get_node(target_node_path) as Node3D
	if not _target:
		#push_error("CameraController: Target node not found at path: " + target_node_path)
		pass
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent):
	# 检测鼠标右键的按下和释放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_start_rotating()
			else:
				_stop_rotating()

	# 检测UI取消操作（例如按ESC键），用于退出旋转模式
	if event.is_action_pressed("ui_cancel"):
		if _is_rotating:
			_stop_rotating()

	# 处理鼠标移动事件
	if _is_rotating and event is InputEventMouseMotion:
		_perform_rotation(event.relative)

# --- 【核心】每一帧都执行跟随逻辑 ---
func _process(delta):
	if not _target:
		return
		
	# 只有在不旋转的时候才进行跟随，防止逻辑冲突
	if not _is_rotating:
		_perform_follow_and_limit(delta)

# --- 【修改】执行平滑跟随和Z轴限制 ---
func _perform_follow_and_limit(delta: float):
	# 1. 获取目标节点的位置
	var target_global_pos = _target.global_position
	
	# 2. 【关键】加上偏移量，得到理想的相机位置
	var ideal_camera_pos = target_global_pos + follow_offset
	
	# 3. 应用Z轴限制（限制的是相机最终位置的Z轴）
	var limited_z = clamp(ideal_camera_pos.z, min_z, max_z)
	
	# 4. 创建一个最终的目标位置，使用被限制过的Z
	var final_target_position = Vector3(ideal_camera_pos.x, ideal_camera_pos.y, limited_z)
	
	# 5. 使用 lerp (线性插值) 平滑移动相机
	global_position = global_position.lerp(final_target_position, follow_speed * delta)

# --- 旋转相关函数 ---
func _start_rotating():
	_is_rotating = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _stop_rotating():
	_is_rotating = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _perform_rotation(motion_relative: Vector2):
	var rotation_delta = motion_relative.x * rotation_speed * 0.01
	rotation.y += rotation_delta
	rotation.y = clamp(rotation.y, deg_to_rad(min_rotation_y), deg_to_rad(max_rotation_y))
