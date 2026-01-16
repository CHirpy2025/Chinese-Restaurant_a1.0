# bird_system.gd
extends Node3D
class_name BirdSystem

# 鸟的场景路径
var BIRD_SCENES = [
	"res://sc/bird_1.tscn",
	"res://sc/bird_2.tscn"
]

# 鸟的数据结构
# bird_system.g
# 鸟的数据结构
class BirdData:
	var node: Node3D
	var sprite: AnimatedSprite3D
	var area: Area3D
	var target_pos: Vector3
	var is_flying: bool = false
	var is_landing: bool = false
	var auto_fly_timer: Timer  # 【新增】自动飞走计时器


# 系统变量
var active_birds: Array[BirdData] = []
var landing_positions: Array[Marker3D] = []
# 在类变量区域添加
var start_positions: Array[Marker3D] = []
var spawn_timer: Timer
var check_timer: Timer
var main_game_sc: Node3D



# 配置参数
var MAX_BIRDS = 5
var SPAWN_INTERVAL = 3.0  # 检查间隔（秒）
var BIRD_SPEED = 12
var FLY_DISTANCE = 20.0  # 飞出场景的距离

# bird_system.gd

# 将 _ready() 中的初始化代码移到 setup() 中
func _ready():
	# 只保留最基本的初始化
	pass

func setup():
	main_game_sc = get_tree().current_scene
	
	# 获取所有着陆点
	_find_landing_positions()
	
	# 【新增】获取所有起始位置
	_find_start_positions()
	
	# 创建定时器
	_setup_timers()
	
	#print("BirdSystem: 鸟群系统初始化完成，找到 ", landing_positions.size(), " 个着陆点，", start_positions.size(), " 个起始点")


# 查找所有起始位置
func _find_start_positions():
	start_positions.clear()
	
	for i in range(1, 3):  # start_pos1 到 start_pos2
		var pos_name = "start_pos" + str(i)
		var pos_node = main_game_sc.get_node_or_null(pos_name)
		if pos_node and pos_node is Marker3D:
			start_positions.append(pos_node)
			#print("BirdSystem: 找到起始点 ", pos_name, " 位置: ", pos_node.global_position)
	
	# 如果没有找到起始位置，创建默认位置
	if start_positions.is_empty():
		#print("BirdSystem: 未找到起始位置，使用默认位置")
		for i in range(2):
			var default_pos = Marker3D.new()
			default_pos.name = "default_start_pos" + str(i)
			main_game_sc.add_child(default_pos)
			
			# 设置默认位置（可以根据你的场景调整）
			if i == 0:
				default_pos.global_position = Vector3(-20, 10, -10)
			else:
				default_pos.global_position = Vector3(20, 10, -10)
			
			start_positions.append(default_pos)




# 查找所有着陆点
func _find_landing_positions():
	landing_positions.clear()
	
	for i in range(1, 6):  # pos1 到 pos5
		var pos_name = "pos" + str(i)
		var pos_node = main_game_sc.get_node_or_null(pos_name)
		if pos_node and pos_node is Marker3D:
			landing_positions.append(pos_node)
			#print("BirdSystem: 找到着陆点 ", pos_name, " 位置: ", pos_node.global_position)

# 设置定时器
func _setup_timers():
	# 检查定时器（检查是否有客人）
	check_timer = Timer.new()
	check_timer.wait_time = SPAWN_INTERVAL
	check_timer.timeout.connect(_check_and_spawn_birds)
	add_child(check_timer)
	check_timer.start()

# bird_system.gd
# bird_system.gd

# bird_system.gd
# bird_system.gd

# 修改生成鸟的调用逻辑
func _check_and_spawn_birds():
	# 检查是否在营业状态且没有客人
	if not _should_spawn_birds():
		return
	
	# 检查当前鸟的数量
	if active_birds.size() >= MAX_BIRDS:
		return
	
	# 获取可用位置
	var available_positions = _get_available_positions()
	if available_positions.size() == 0:
		return
	
	# 随机打乱位置
	available_positions.shuffle()
	
	# 随机决定生成几只鸟（1-3只）
	var spawn_count = randi() % 3 + 1
	
	# 限制生成数量
	spawn_count = min(spawn_count, available_positions.size(), MAX_BIRDS - active_birds.size())
	
	if spawn_count <= 0:
		return
	
	#print("BirdSystem: 准备生成 ", spawn_count, " 只鸟")
	
	# 【关键修复】逐个生成，每次都重新检查可用位置
	for i in range(spawn_count):
		# 每次生成前重新获取可用位置
		var current_available = _get_available_positions()
		if current_available.is_empty():
			print("BirdSystem: 没有可用位置了，停止生成")
			break
		
		# 随机选择一个位置
		var target_pos = current_available[randi() % current_available.size()]
		var bird_type = randi() % BIRD_SCENES.size()
		
		_spawn_bird(target_pos, bird_type)
		
		#print("BirdSystem: 已生成第 ", i + 1, " 只鸟，剩余可用位置: ", current_available.size() - 1)





# 判断是否应该生成鸟
func _should_spawn_birds() -> bool:
	# 检查是否在营业状态
	if not fc.playerData.is_open:
		return false
	
	# 检查是否有等待的客人
	if fc.playerData.waiting_customers.size() > 0:
		return false
	
	# 检查是否有已入座的客人
	if main_game_sc and main_game_sc.has_node("MapHolder/Randmap"):
		var randmap_manager = main_game_sc.get_node("MapHolder/Randmap")
		if randmap_manager and randmap_manager.has_node("CustomerSystem"):
			var customer_system = randmap_manager.get_node("CustomerSystem")
			if customer_system and customer_system.has_method("get_seated_customers_count"):
				var seated_count = customer_system.get_seated_customers_count()
				if seated_count > 0:
					return false
	
	return true

# bird_system.gd

# bird_system.gd

# 获取可用的着陆位置
func _get_available_positions() -> Array:
	var available = []
	
	for pos in landing_positions:
		var is_occupied = false
		
		# 【关键修复】检查所有鸟，包括正在飞行的
		for bird in active_birds:
			# 检查已经着陆的鸟
			if not bird.is_flying:
				var bird_pos = bird.node.global_position
				if bird_pos.distance_to(pos.global_position) < 1.0:
					is_occupied = true
					break
			# 【新增】检查正在飞向这个位置的鸟
			else:
				# 检查这只鸟的目标位置
				if bird.target_pos.distance_to(pos.global_position) < 1.0:
					is_occupied = true
					break
		
		if not is_occupied:
			available.append(pos)
	
	return available



# 【新增】根据鸟的场景判断鸟的类型
func _get_bird_type(bird_node: Node3D) -> int:
	var scene_path = bird_node.scene_file_path
	if "bird_1.tscn" in scene_path:
		return 0  # 鸟1
	elif "bird_2.tscn" in scene_path:
		return 1  # 鸟2
	return 0  # 默认为鸟1
# 生成一只鸟
# bird_system.gd

## bird_system.gd

# 生成一只鸟
func _spawn_bird(target_position: Marker3D, bird_type: int = 0):
	# 根据鸟的类型选择场景
	var scene_path = BIRD_SCENES[bird_type % BIRD_SCENES.size()]
	var bird_scene = load(scene_path)
	
	if not bird_scene:
		print("BirdSystem: 无法加载鸟场景: ", scene_path)
		return
	
	var bird_node = bird_scene.instantiate()
	add_child(bird_node)
	
	# 获取子节点引用
	var sprite = bird_node.get_node_or_null("AnimatedSprite3D")
	var area = bird_node.get_node_or_null("Area3D")
	
	if not sprite or not area:
		#print("BirdSystem: 鸟场景结构不正确")
		bird_node.queue_free()
		return
	
	# 创建鸟数据
	var bird_data = BirdData.new()
	bird_data.node = bird_node
	bird_data.sprite = sprite
	bird_data.area = area
	bird_data.target_pos = target_position.global_position
	
	# 【关键修改】根据鸟的类型选择固定的起始位置
	var spawn_pos = _get_fixed_start_position(bird_type)
	bird_node.global_position = spawn_pos
	
	# 设置朝向目标
	bird_node.look_at(target_position.global_position)
	bird_node.rotation_degrees.x = 0  # 保持水平
	
	# 连接鼠标进入信号
	area.mouse_entered.connect(_on_bird_hovered.bind(bird_data))
	
	# 播放飞行动画
	sprite.play("fly")
	bird_data.is_flying = true
	
	# 添加到活动列表
	active_birds.append(bird_data)
	
	#print("BirdSystem: 生成鸟类型", bird_type, "在 ", spawn_pos, " 目标位置: ", target_position.global_position)
	
	# 开始飞行
	_fly_to_position(bird_data, target_position.global_position, true)

# bird_system.gd

# 修改根据鸟类型获取固定的起始位置
func _get_fixed_start_position(bird_type: int) -> Vector3:
	if start_positions.is_empty():
		return Vector3(10, 5, 10)
	
	# 【明确对应】
	# 鸟类型0（bird_1）使用start_pos1（索引0）- 从右边来
	# 鸟类型1（bird_2）使用start_pos2（索引1）- 从左边来
	var pos_index = bird_type % start_positions.size()
	var start_pos = start_positions[pos_index]
	var pos = start_pos.global_position
	
	# 添加一些随机偏移，让每次飞行略有不同
	pos.x += randf_range(-2, 2)
	pos.y += randf_range(-1, 1)
	pos.z += randf_range(-2, 2)
	
	#print("BirdSystem: 鸟", bird_type + 1, "从起始位置", pos_index + 1, "(", pos, ")生成")
	
	return pos




# 获取场景外的随机位置
# bird_system.gd

# bird_system.gd

# 获取场景外的随机位置（简化版）
func _get_random_outside_position() -> Vector3:
	if start_positions.is_empty():
		return Vector3(10, 5, 10)
	
	# 随机选择一个起始位置
	var start_pos = start_positions[randi() % start_positions.size()]
	var pos = start_pos.global_position
	
	# 添加一些随机偏移，让每次飞行略有不同
	pos.x += randf_range(-2, 2)
	pos.y += randf_range(-1, 1)
	pos.z += randf_range(-2, 2)
	
	return pos


# bird_system.gd
# bird_system.gd

# 飞行到指定位置
func _fly_to_position(bird_data: BirdData, target: Vector3, should_land: bool = false):
	if not bird_data.node or not bird_data.sprite:
		return
	
	var start_pos = bird_data.node.global_position
	var distance = start_pos.distance_to(target)
	var duration = distance / BIRD_SPEED
	
	# 创建移动动画
	var tween = create_tween()
	tween.set_parallel(false)
	
	# 【关键修正】使用 lambda 函数正确传递参数
	tween.tween_method(func(t): _move_bird(bird_data, start_pos, target, t), 0.0, 1.0, duration)
	
	# 完成后的回调
	if should_land:
		tween.tween_callback(_on_bird_landed.bind(bird_data))
	else:
		tween.tween_callback(_on_bird_flew_away.bind(bird_data))


# bird_system.gd

# 移动鸟的插值函数
func _move_bird(bird_data: BirdData, start: Vector3, end: Vector3, t: float):
	if not bird_data.node:
		return
	
	# 使用缓动函数让移动更自然
	var eased_t = _ease_in_out_quad(t)
	var current_pos = start.lerp(end, eased_t)
	bird_data.node.global_position = current_pos
	
	# 【关键修复】保持朝向移动方向，但要检查距离
	if t > 0.01:
		var next_pos = start.lerp(end, min(t + 0.01, 1.0))
		
		# 【修复】检查当前位置和目标位置的距离，避免相同位置报错
		if current_pos.distance_to(next_pos) > 0.01:
			bird_data.node.look_at(next_pos)


# 缓动函数
func _ease_in_out_quad(t: float) -> float:
	if t < 0.5:
		return 2 * t * t
	else:
		return 1 - pow(-2 * t + 2, 2) / 2

# 鸟着陆后的处理
func _on_bird_landed(bird_data: BirdData):
	if not bird_data.sprite:
		return
	
	#print("BirdSystem: 鸟已着陆")
	bird_data.is_flying = false
	bird_data.is_landing = true
	
	# 播放站立动画（如果有）
	if bird_data.sprite.sprite_frames.has_animation("idle"):
		bird_data.sprite.play("idle")
	else:
		bird_data.sprite.stop()
	
	# 【新增】创建自动飞走计时器
	_setup_auto_fly_timer(bird_data)

# 【新增】设置自动飞走计时器
func _setup_auto_fly_timer(bird_data: BirdData):
	# 创建计时器
	bird_data.auto_fly_timer = Timer.new()
	bird_data.auto_fly_timer.wait_time = randf_range(3.0, 8.0)  # 随机3-8秒后飞走
	bird_data.auto_fly_timer.one_shot = true
	bird_data.auto_fly_timer.timeout.connect(_on_auto_fly_timeout.bind(bird_data))
	
	# 将计时器添加到鸟节点上
	bird_data.node.add_child(bird_data.auto_fly_timer)
	bird_data.auto_fly_timer.start()
	
	#print("BirdSystem: 鸟将在 ", bird_data.auto_fly_timer.wait_time, " 秒后自动飞走")
# bird_system.gd

# 【新增】自动飞走计时器到期
func _on_auto_fly_timeout(bird_data: BirdData):
	if not bird_data.node or not bird_data.sprite:
		return
	
	# 检查鸟是否还在（可能已经被玩家驱赶了）
	if not bird_data in active_birds:
		return
	
	#print("BirdSystem: 鸟停留时间到了，自动飞走")
	
	# 使用和驱赶相同的飞走逻辑
	fc.play_se_fx("bird")
	_scare_bird_away(bird_data)



# 鸟飞走后的处理
func _on_bird_flew_away(bird_data: BirdData):
	#print("BirdSystem: 鸟已飞走")
	_remove_bird(bird_data)

func _on_bird_hovered(bird_data: BirdData):
	if bird_data.is_flying:
		return
	
	#print("BirdSystem: 鼠标悬停，鸟被吓走")
		#print("BirdSystem: 还有 ", "%.1f" % bird_data.auto_fly_timer.time_left, " 秒鸟也会自己飞走")
	fc.play_se_fx("fly")
	_scare_bird_away(bird_data)

# 点击鸟的处理
# bird_system.gd


# bird_system.gd

# 吓走鸟
# bird_system.gd

# 吓走鸟
func _scare_bird_away(bird_data: BirdData):
	if not bird_data.node or not bird_data.sprite:
		return
	
	# 【新增】清理自动飞走计时器
	if bird_data.auto_fly_timer:
		bird_data.auto_fly_timer.stop()
		bird_data.auto_fly_timer.queue_free()
		bird_data.auto_fly_timer = null
	
	# 播放飞行动画
	
	bird_data.sprite.play("fly")
	bird_data.is_flying = true
	
	# 使用交叉驱赶逻辑
	var escape_pos = _get_cross_escape_position(bird_data)
	
	# 设置朝向
	bird_data.node.look_at(escape_pos)
	bird_data.node.rotation_degrees.x = 0
	
	# 飞走
	_fly_to_position(bird_data, escape_pos, false)


# 【新增】获取交叉逃离位置
func _get_cross_escape_position(bird_data: BirdData) -> Vector3:
	var bird_type = _get_bird_type(bird_data.node)
	
	# 【交叉逻辑】
	# 鸟1（类型0）逃向start_pos2（索引1）
	# 鸟2（类型1）逃向start_pos1（索引0）
	var escape_index = 1 - bird_type  # 0变1，1变0
	
	if start_positions.size() <= escape_index:
		# 如果没有足够的起始位置，使用默认位置
		return Vector3(30, 10, 0) if escape_index == 1 else Vector3(-30, 10, 0)
	
	var escape_start = start_positions[escape_index]
	var escape_pos = escape_start.global_position
	
	# 在起始位置的基础上再向外延伸
	if escape_index == 1:  # 往右边飞
		escape_pos.x += 20
	else:  # 往左边飞
		escape_pos.x -= 20
	
	escape_pos.y += randf_range(5, 10)
	escape_pos.z += randf_range(-5, 5)
	
	#print("BirdSystem: 鸟", bird_type + 1, "被驱赶，逃向位置", escape_index + 1, "(", escape_pos, ")")
	
	return escape_pos


# 【新增】根据鸟类型获取固定的逃离位置
func _get_fixed_escape_position(bird_data: BirdData) -> Vector3:
	# 根据鸟的初始位置判断它的类型
	var bird_type = 0
	if start_positions.size() >= 2:
		# 判断这只鸟更接近哪个起始位置
		var dist_to_start1 = bird_data.node.global_position.distance_to(start_positions[0].global_position)
		var dist_to_start2 = bird_data.node.global_position.distance_to(start_positions[1].global_position)
		bird_type = 0 if dist_to_start1 < dist_to_start2 else 1
	
	# 鸟类型0逃向start_pos1方向，鸟类型1逃向start_pos2方向
	var pos_index = bird_type % start_positions.size()
	var start_pos = start_positions[pos_index]
	
	# 在起始位置的基础上再向外延伸
	var escape_pos = start_pos.global_position
	escape_pos.x += (20 if pos_index == 0 else -20)  # 根据类型决定方向
	escape_pos.y += randf_range(5, 10)
	escape_pos.z += randf_range(-5, 5)
	
	return escape_pos


# 移除鸟
# 移除鸟
func _remove_bird(bird_data: BirdData):
	# 【新增】清理自动飞走计时器
	if bird_data.auto_fly_timer:
		bird_data.auto_fly_timer.stop()
		bird_data.auto_fly_timer.queue_free()
		bird_data.auto_fly_timer = null
	
	# 从活动列表中移除
	active_birds.erase(bird_data)
	
	# 删除节点
	if bird_data.node:
		bird_data.node.queue_free()

# 清理所有鸟
func clear_all_birds():
	#print("BirdSystem: 清理所有鸟，当前数量: ", active_birds.size())
	
	for bird in active_birds.duplicate():
		_remove_bird(bird)
	
	active_birds.clear()

# 获取当前鸟的数量
func get_bird_count() -> int:
	return active_birds.size()

# 暂停/恢复系统
func set_system_active(active: bool):
	if active:
		if not check_timer.is_connected("timeout", _check_and_spawn_birds):
			check_timer.timeout.connect(_check_and_spawn_birds)
		check_timer.start()
		#print("BirdSystem: 系统已激活")
	else:
		check_timer.stop()
		clear_all_birds()
		#print("BirdSystem: 系统已暂停")
