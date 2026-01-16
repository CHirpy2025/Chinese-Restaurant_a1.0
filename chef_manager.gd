# chef_manager.gd
extends Node

# 菜系枚举
enum CuisineType {
	# 中餐八大菜系
	SHANDONG,     # 鲁菜
	SICHUAN,      # 川菜
	GUANGDONG,    # 粤菜
	FUJIAN,       # 闽菜
	JIANGSU,      # 苏菜
	ZHEJIANG,     # 浙菜
	HUNAN,        # 湘菜
	ANHUI,        # 徽菜
	# 外国菜系
	FRENCH,       # 法餐
	MEXICAN,      # 墨西哥菜
	ITALIAN,      # 意大利菜
	TURKISH       # 土耳其菜
}

# 菜系名称映射
const CUISINE_NAMES = {
	CuisineType.SHANDONG: "鲁菜",
	CuisineType.SICHUAN: "川菜",
	CuisineType.GUANGDONG: "粤菜",
	CuisineType.FUJIAN: "闽菜",
	CuisineType.JIANGSU: "苏菜",
	CuisineType.ZHEJIANG: "浙菜",
	CuisineType.HUNAN: "湘菜",
	CuisineType.ANHUI: "徽菜",
	CuisineType.FRENCH: "法国菜",
	CuisineType.MEXICAN: "墨西哥菜",
	CuisineType.ITALIAN: "意大利菜",
	CuisineType.TURKISH: "土耳其菜"
}

signal chef_hired(chef_data: ChefData)
signal chef_fired(chef_id: String)

# 厨师数据池
var all_chefs: Array[ChefData] = []
var hired_chefs: Dictionary = {}  # {station_id: ChefData}

# 名字池

# 彩蛋名字
var easter_egg_names = {
	"食之神": {"gender": "male", "bonus": {"cooking": 25, "speed": 15}},
	"中华大当家": {"gender": "male", "bonus": {"cooking": 20, "speed": 20}},
	"孤独七郎": {"gender": "male", "bonus": {"cooking": 15, "speed": 25}},
	"地狱大厨": {"gender": "male", "bonus": {"cooking": 15, "speed": 25}},
	"孟姜女": {"gender": "female", "bonus": {"cooking": 30, "speed": 10}},
	"豆腐西施": {"gender": "female", "bonus": {"cooking": 30, "speed": 10}},
	"蓝夕朝": {"gender": "female", "bonus": {"cooking": 20, "speed": 20}},
	"孙二娘": {"gender": "female", "bonus": {"cooking": 10, "speed": 30}},
}




func _ready():
	generate_recruitment_chefs()

# 生成招聘厨师
func generate_recruitment_chefs(count: int = 10) -> Array[ChefData]:
	all_chefs.clear()
	
	for i in range(count):
		var chef = _generate_random_chef()
		
		all_chefs.append(chef)
	
	
	return all_chefs

# 生成随机厨师
func _generate_random_chef() -> ChefData:
	var chef = ChefData.new()
	chef.id = "chef_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
	
	# 决定是否是彩蛋角色
	var is_easter_egg = randf() < 0.1
	
	if is_easter_egg:
		_generate_easter_egg_chef(chef)
	else:
		_generate_normal_chef(chef)
	
	# 生成菜系技能
	_generate_cuisine_skills(chef)
	
	# 设置头像
	chef.avatar_path = "res://pic/npc/fuwuyuan/chushi_" + ("male" if chef.gender == "male" else "female") + ".png"
	return chef

## 生成随机名字的函数


# 生成普通厨师 - 修改这里
func _generate_normal_chef(chef: ChefData):
	chef.gender = "male" if randf() < 0.6 else "female"
	chef.is_easter_egg = false
	
	# 使用新的名字生成函数
	chef.name = NameGenerator._generate_random_name(chef.gender)
	
	# 基础属性
	chef.age = randi_range(22, 55)
	
	chef.cooking_skill = randi_range(30, 80)
	chef.innovation_skill = randi_range(20, 70)
	chef.speed_skill = randi_range(25, 75)
	
	#根据状态确定月薪
	chef.salary = randi_range(40,60)*100+(chef.cooking_skill*30)+(chef.speed_skill*20)+(chef.innovation_skill*10)+(chef.cuisines.size()*50)
	


# 生成彩蛋厨师
func _generate_easter_egg_chef(chef: ChefData):
	var easter_names = easter_egg_names.keys()
	var selected_name = easter_names[randi() % easter_names.size()]
	var easter_data = easter_egg_names[selected_name]
	
	chef.name = selected_name
	chef.gender= easter_data.gender
	chef.is_easter_egg = true
	
	# 基础属性（更高）
	chef.age = 25
	chef.salary = randi_range(400, 500)*100
	chef.cooking_skill = randi_range(30, 40) + easter_data.bonus.get("cooking", 0)
	chef.innovation_skill = randi_range(60, 80) + easter_data.bonus.get("innovation", 0)
	chef.speed_skill = randi_range(30, 40) + easter_data.bonus.get("speed", 0)

# 生成菜系技能
func _generate_cuisine_skills(chef: ChefData):
	var cuisine_count = randi_range(1, 4)  # 1-4种菜系
	var available_cuisines = CuisineType.values()
	available_cuisines.shuffle()
	
	for i in range(cuisine_count):
		var cuisine = available_cuisines[i]
		var level = randi_range(2, 6)  # 2-6级基础
		chef.cuisines_experience.append(0)#一个菜系一个经验值
		
		# 彩蛋角色有更高概率获得高级技能
		if chef.is_easter_egg and randf() < 0.5:
			level = randi_range(7, 10)
		
		chef.cuisines[cuisine] = min(level, 10)

# 雇佣厨师
func hire_chef(chef: ChefData):
	chef.is_hired = true
	chef_hired.emit(chef)
	chef.salary_day = fc.playerData.game_day#招聘那天就是发薪日
	fc.playerData.chefs.append(chef)#记录存档
	

# 解雇厨师
func fire_chef(chef: ChefData):
	var id=fc.playerData.chefs.find(chef)
	fc.playerData.chefs.remove_at(id)#记录存档



# 获取岗位上的厨师
func get_chef_at_station(station_id: String) -> ChefData:
	return hired_chefs.get(station_id, null)

# 任命厨师到岗位
func assign_chef_to_station(chef: ChefData, station_id: String):
	# 先从原岗位移除
	if chef.work_station != "":
		hired_chefs.erase(chef.work_station)
	
	# 任命到新岗位
	chef.work_station = station_id
	hired_chefs[station_id] = chef
