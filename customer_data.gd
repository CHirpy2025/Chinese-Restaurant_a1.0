# customer_data.gd
extends Resource
class_name CustomerData

var id: String = ""
var name: String = ""
var group_size: int = 1
var arrival_time: String = ""
var status: String = "waiting"  # waiting, being_greeted, seated, eating, leaving
var node_ref: Node3D = null
var target_furniture: String = ""
var pressure: float = 0.0  # 压力值 (0-100)
var pressure_increase_rate: float = 1.0  # 压力增长速度
var max_pressure: float = 100.0  # 最大压力值
var type = ""#客人类型
var sex_age_list=[]#记录性别，年龄和所持有的金钱
var total_xiaofei=0#本桌总消费
var satisfaction=200#满意度

# 新增：详细评价数据结构
var review_result: Dictionary = {
	"environment": {"level": 0, "text": ""}, # level: 1(差), 2(中), 3(好)
	"service":     {"level": 0, "text": ""},
	"taste":       {"level": 0, "text": ""},
	"variety":     {"level": 0, "text": ""}, # 菜品类型
	"price":       {"level": 0, "text": ""}
}

# 辅助记录数据（在点餐和用餐过程中填充）
var review_temp_data: Dictionary = {
	"matched_tags": [],       # 点餐时命中的喜爱标签
	"missing_tags": [],       # 想吃但没吃到的标签
	"avg_dish_quality": 0.0,  # 吃到菜品的平均质量
	"waiter_ref": null        # 服务该客人的主要服务员数据引用
}

func _init():
	id = "customer_" + str(Time.get_unix_time_from_system())
	name = "客人_" + str(randi() % 1000)
	group_size = randi_range(1, 4)
	arrival_time = Time.get_datetime_string_from_system()



func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"group_size": group_size,
		"arrival_time": arrival_time,
		"status": status,
		"target_furniture": target_furniture
	}

func from_dict(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	group_size = data.get("group_size", 1)
	arrival_time = data.get("arrival_time", "")
	status = data.get("status", "waiting")
	target_furniture = data.get("target_furniture", "")
