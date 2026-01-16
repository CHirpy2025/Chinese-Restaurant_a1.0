# chef_data.gd
class_name ChefData
extends RefCounted

# 厨师数据结构
var id: String = ""
var name: String = ""
var gender: String = ""                 # "male" | "female"
var is_easter_egg: bool = false
var salary: int = 0
var age: int = 0
var cooking_skill: int = 0
var innovation_skill: int = 0
var speed_skill: int = 0
var cuisines: Dictionary = {}           # {菜系名: 等级}
var avatar_path: String = ""
var is_hired: bool = false
var work_station: String = ""
var cuisines_experience = [] # {菜系：等级}
var salary_day: int = 1 # {发薪日}
var yali: int = 0#不满度

# 序列化为字典（用于保存）
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"gender": gender,
		"is_easter_egg": is_easter_egg,
		"salary": salary,
		"age": age,
		"cooking_skill": cooking_skill,
		"innovation_skill": innovation_skill,
		"speed_skill": speed_skill,
		"cuisines": cuisines,
		"avatar_path": avatar_path,
		"is_hired": is_hired,
		"work_station": work_station,
		"cuisines_experience": cuisines_experience,
		"salary_day": salary_day,
		"yali": yali
	}

# 从字典反序列化（用于加载）
func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	yali = data.get("yali", "")
	name = data.get("name", "")
	gender = data.get("gender", "")
	is_easter_egg = data.get("is_easter_egg", false)
	salary = data.get("salary", 0)
	age = data.get("age", 0)
	cooking_skill = data.get("cooking_skill", 0)
	innovation_skill = data.get("innovation_skill", 0)
	speed_skill = data.get("speed_skill", 0)
	cuisines = data.get("cuisines", {})
	avatar_path = data.get("avatar_path", "")
	is_hired = data.get("is_hired", false)
	work_station = data.get("work_station", "")
	cuisines_experience = data.get("cuisines_experience", [])
	salary_day = data.get("salary_day", 1)
