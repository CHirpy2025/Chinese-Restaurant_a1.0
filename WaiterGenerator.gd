# waiter_generator.gd
extends Node

# 技能枚举 (可选，但推荐使用，避免硬编码字符串)
enum SkillType {
	UPSELL,      # 点单引导
	CRISIS,      # 危机处理
	RETENTION    # 顾客维系
}

# 技能名称映射
const SKILL_NAMES = {
	SkillType.UPSELL: "点单引导",
	SkillType.CRISIS: "危机处理",
	SkillType.RETENTION: "顾客维系"
}

signal waiter_hired(waiter_data: WaiterData)
signal waiter_fired(waiter_id: String)

# 服务员数据池
var all_waiters: Array[WaiterData] = []
var hired_waiters: Dictionary = {}  # {station_id: WaiterData}

# 服务员彩蛋名字
var easter_egg_names = {
	"狄恩": {"gender": "male", "bonus": {"speed": 25, "charm": 10, "affinity": 5}},
	"艾瑞斯": {"gender": "male", "bonus": {"speed": 5, "charm": 25, "affinity": 10}},
	"9527": {"gender": "male", "bonus": {"speed": 5, "charm": 10, "affinity": 25}},
	"哈基米": {"gender": "female", "bonus": {"speed": 10, "charm": 25, "affinity": 5}},
	"电子女鹅": {"gender": "female", "bonus": {"speed": 5, "charm": 10, "affinity": 25}},
	"绝绝紫": {"gender": "female", "bonus": {"speed": 25, "charm": 5, "affinity": 10}},
}

func _ready():
	# 可以在这里初始化，但通常由外部调用
	pass

# 生成招聘服务员
func generate_recruitment_waiters(count: int = 10) -> Array[WaiterData]:
	all_waiters.clear()
	
	for i in range(count):
		var waiter = _generate_random_waiter()
		all_waiters.append(waiter)
	
	return all_waiters

# 生成随机服务员
func _generate_random_waiter() -> WaiterData:
	var waiter = WaiterData.new()
	waiter.id = "waiter_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
	
	# 决定是否是彩蛋角色
	var is_easter_egg = randf() < 0.1
	
	if is_easter_egg:
		_generate_easter_egg_waiter(waiter)
	else:
		_generate_normal_waiter(waiter)
	
	# 生成技能
	_generate_waiter_skills(waiter)
	
	# 设置头像
	waiter.avatar_path = "res://pic/npc/fuwuyuan/waiter_type1_" + ("man" if waiter.gender == "male" else "woman") + ".png"
	return waiter

# 生成普通服务员
func _generate_normal_waiter(waiter: WaiterData):
	waiter.gender = "male" if randf() < 0.5 else "female"
	waiter.is_easter_egg = false
	
	# 使用你已经设置好的全局名字生成器
	waiter.name = NameGenerator._generate_random_name(waiter.gender)
	
	# 基础属性
	waiter.speed = randi_range(20, 65)
	waiter.charm = randi_range(20, 65)
	waiter.affinity = randi_range(20, 65)
	
	# 根据属性和技能确定月薪
	waiter.salary = _calculate_salary(waiter.speed, waiter.charm, waiter.affinity, waiter.skills)

# 生成彩蛋服务员
func _generate_easter_egg_waiter(waiter: WaiterData):
	var easter_names = easter_egg_names.keys()
	var selected_name = easter_names[randi() % easter_names.size()]
	var easter_data = easter_egg_names[selected_name]
	
	waiter.name = selected_name
	waiter.gender = easter_data.gender
	waiter.is_easter_egg = true
	
	# 基础属性（更高）
	
	# 应用彩蛋加成
	var base_speed = randi_range(30, 50)
	var base_charm = randi_range(30, 50)
	var base_affinity = randi_range(30, 50)
	
	waiter.speed = min(base_speed + easter_data.bonus.get("speed", 0), 99)
	waiter.charm = min(base_charm + easter_data.bonus.get("charm", 0), 99)
	waiter.affinity = min(base_affinity + easter_data.bonus.get("affinity", 0), 99)
	
	# 生成技能
	_generate_waiter_skills(waiter)
	
	# 根据属性和技能确定月薪
	waiter.salary = _calculate_salary(waiter.speed, waiter.charm, waiter.affinity, waiter.skills)


# 生成服务员技能
func _generate_waiter_skills(waiter: WaiterData):
	var skill_points = 10 # 总共10个技能点
	var skills = {
		SkillType.UPSELL: 0,
		SkillType.CRISIS: 0,
		SkillType.RETENTION: 0
	}
	var skill_names = skills.keys()
	
	for i in range(skill_points):
		var random_skill = skill_names.pick_random()
		# 每个技能最高5级
		if skills[random_skill] < 5:
			skills[random_skill] += 1
		else:
			# 如果某个技能满了，就重新抽，确保10点都加完
			i -= 1
			
	waiter.skills = skills
	
	# 彩蛋角色有更高概率获得高级技能
	if waiter.is_easter_egg:
		for skill_name in skills.keys():
			if randf() < 0.5: # 50%概率提升一个技能
				skills[skill_name] = min(skills[skill_name] + randi_range(1, 2), 5)
		waiter.skills = skills


# 计算月薪
func _calculate_salary(speed: int, charm: int, affinity: int, skills: Dictionary) -> int:
	var base_salary = 100
	var skill_total_level = skills.get(SkillType.UPSELL, 0) + skills.get(SkillType.CRISIS, 0) + skills.get(SkillType.RETENTION, 0)
	return base_salary + (speed * 50) + (charm * 60) + (affinity * 40) + (skill_total_level * 300)


# 雇佣服务员
func hire_waiter(waiter: WaiterData):
	waiter.is_hired = true
	waiter_hired.emit(waiter)
	waiter.salary_day = fc.playerData.game_day # 招聘那天就是发薪日
	fc.playerData.waiters.append(waiter) # 记录存档 (假设你已在 playerData 中创建了 waiterData 数组)

# 解雇服务员
func fire_waiter(waiter: WaiterData):
	var id=fc.playerData.waiters.find(waiter)
	fc.playerData.waiters.remove_at(id)#记录存档

		
		

# 获取岗位上的服务员
func get_waiter_at_station(station_id: String) -> WaiterData:
	return hired_waiters.get(station_id, null)

# 任命服务员到岗位
func assign_waiter_to_station(waiter: WaiterData, station_id: String):
	# 先从原岗位移除
	if waiter.work_station != "":
		hired_waiters.erase(waiter.work_station)
	
	# 任命到新岗位
	waiter.work_station = station_id
	hired_waiters[station_id] = waiter
