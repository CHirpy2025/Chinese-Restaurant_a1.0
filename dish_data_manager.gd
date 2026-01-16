# dish_data_manager.gd
extends Node

# ========================================================
# 【新增】程序化生成配置 (复制到脚本最顶部)
# ========================================================

# 1. 菜系枚举 (直接复制过来，保证独立运行)
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

# 2. 菜系前缀配置 (包含你想要的高级食材风格)
const CUISINE_PREFIX_CONFIG = {
	CuisineType.SHANDONG: ["鲁味", "孔府", "九转", "奶汤", "葱烧", "酱爆", "黑松露"],
	CuisineType.SICHUAN:  ["麻辣", "川香", "宫保", "水煮", "干煸", "怪味", "红油", "鱼香", "黑松露"],
	CuisineType.GUANGDONG:  ["粤鲜", "清蒸", "老火", "白切", "广式", "烧味", "啫啫", "黑松露"],
	CuisineType.FUJIAN:       ["闽式", "红糟", "沙茶", "佛跳", "海味", "醉糟"],
	CuisineType.JIANGSU:      ["苏帮", "淮扬", "松鼠", "水晶", "国宴", "蜜汁"],
	CuisineType.ZHEJIANG:     ["浙味", "西湖", "龙井", "东坡", "南国", "泥烤"],
	CuisineType.HUNAN:        ["湘辣", "剁椒", "腊味", "发丝", "臭鳜", "烟熏"],
	CuisineType.ANHUI:        ["徽派", "红烧", "烩", "焗", "蒸", "炖"],
	
	# 外国菜系 (加入黑松露等高级前缀)
	CuisineType.FRENCH:       ["法式", "奶油", "红酒", "香煎", "黑松露", "鹅肝", "蜗牛", "鱼子酱"],
	CuisineType.MEXICAN:      ["墨式", "玉米", "辣椒", "仙人掌", "塔可", "牛油果", "莎莎酱"],
	CuisineType.ITALIAN:      ["意式", "番茄", "罗勒", "芝士", "黑松露", "披萨", "千层", "黑醋"],
	CuisineType.TURKISH:       ["土风", "旋转", "炭烤", "茄子", "羊肉", "开心果", "酸奶"]
}

# 3. 高级食材前缀池 (等级高时额外抽取)
const FANCY_INGREDIENT_PREFIXES = [
	"黑松露", "鹅肝", "鱼翅", "燕窝", "鲍鱼", "鱼子酱", "松茸", "和牛", "伊比利亚火腿", "藏红花"
]

# ========================================================
# 4. 前缀 -> 标签映射表 (新增，用于生成时融合标签)
# ========================================================
const PREFIX_TO_TAGS = {
	# --- 高级食材前缀 ---
	"黑松露": ["昂贵", "高级", "滋补"],
	"鹅肝":   ["昂贵", "高级", "软口"],
	"鱼翅":   ["昂贵", "高级", "滋补"],
	"燕窝":   ["昂贵", "高级", "滋补", "甜口"],
	"鲍鱼":   ["昂贵", "高级"],
	"鱼子酱": ["昂贵", "高级"],
	"松茸":   ["昂贵", "高级"],
	"和牛":   ["昂贵", "高级", "劲嚼"],
	"伊比利亚火腿": ["昂贵", "高级", "劲嚼"],
	"藏红花": ["昂贵", "高级", "滋补"],
	
	# --- 川菜系前缀 ---
	"麻辣": ["辣", "重口味", "热食"],
	"川香": ["辣", "香口", "热食"],
	"宫保": ["辣", "下饭", "热食"],
	"水煮": ["辣", "重口味", "汤类"],
	"干煸": ["香口", "劲嚼", "热食"],
	"怪味": ["辣", "创新菜", "下酒"],
	"红油": ["辣", "重口味", "凉菜"],
	"鱼香": ["辣", "酸甜", "下饭"],
	
	# --- 鲁菜系前缀 ---
	"鲁味": ["重口味", "下饭", "热食"],
	"孔府": ["传统经典", "商务", "摆盘风"],
	"九转": ["甜口", "精致", "创新菜"],
	"奶汤": ["软口", "汤类", "滋补"],
	"葱烧": ["香口", "下饭"],
	"酱爆": ["香口", "重口味"],
	
	# --- 粤菜系前缀 ---
	"粤鲜": ["清淡健康", "鲜味", "软口"],
	"清蒸": ["清淡健康", "汤类", "保留原味"],
	"老火": ["清淡健康", "汤类", "滋补", "耗时"],
	"白切": ["清淡健康", "软口", "凉菜"],
	"广式": ["清淡健康", "传统经典"],
	"烧味": ["香口", "传统经典"],
	"啫啫": ["软口", "汤类"],
	
	# --- 外国菜系前缀 ---
	"法式": ["摆盘风", "精致", "商务"],
	"奶油": ["香口", "软口"],
	"红酒": ["下酒", "商务", "热食"],
	"香煎": ["热食", "香口"],
	"蜗牛": ["劲嚼", "下酒", "特色"],
	"披萨": ["多人分享", "主食", "热食"],
	"芝士": ["香口", "软口", "浓香"],
	"千层": ["精致", "摆盘风"],
	"黑醋": ["酸甜", "下酒"],
	
	# --- 其他常见前缀 (兜底) ---
	"红烧": ["重口味", "下饭", "热食"],
	"清炒": ["清淡健康", "热食"],
	"凉拌": ["凉菜", "清淡健康"],
	"特色": ["地方特色", "家常"],
	"苏帮": ["清淡健康", "甜口", "精致"],
	"淮扬": ["清淡健康", "精致", "汤类"],
	"松鼠": ["甜口", "精致", "创新菜"],
	"水晶": ["精致", "凉菜", "软口"],
	"国宴": ["商务", "摆盘风", "高级"],
	"蜜汁": ["甜口", "软口"],
	"西湖": ["清淡健康", "鲜味"],
	"龙井": ["清淡健康", "茶香", "汤类"],
	"东坡": ["传统经典", "软口", "下饭"],
	"南国": ["甜口", "软口"],
	"泥烤": ["热食", "传统经典"],
	"湘辣": ["辣", "重口味", "热食"],
	"剁椒": ["辣", "重口味", "下饭"],
	"腊味": ["传统经典", "劲嚼", "热食"],
	"发丝": ["精致", "创新菜"],
	"臭鳜": ["地方特色", "重口味"],
	"烟熏": ["重口味", "特色"],
	"徽派": ["传统经典", "重口味"],
	"炖": ["软口", "热食"],
	"焗": ["热食", "创新菜"],
	"烩": ["传统经典", "重口味", "热食","汤类"],
	"蒸": ["传统经典", "热食"],
	"红糟": ["酒香", "软口"],
	"沙茶": ["香口", "下饭"],
	"佛跳": ["软口", "汤类", "滋补"],
	"海味": ["鲜味", "高级"],
	"醉糟": ["下酒", "软口"],
	"墨式": ["辣", "重口味", "热食"],
	"玉米": ["甜口", "家常"],
	"辣椒": ["辣", "热食"],
	"仙人掌": ["创新菜", "特色"],
	"塔可": ["主食", "多人分享", "热食"],
	"牛油果": ["软口", "健康"],
	"莎莎酱": ["辣", "酸口", "下饭"],
	"番茄": [ "传统经典", "家常"],
	"罗勒": ["香口", "清新"],
	"土风": ["重口味", "特色"],
	"旋转": ["创新菜", "摆盘风"],
	"炭烤": ["热食", "劲嚼"],
	"茄子": ["软口", "家常"],
	"羊肉": ["重口味", "热食"],
	"开心果": ["甜口", "坚果"],
	"酸奶": ["软口", "冷食"]
}

const PREFIX_MODIFIERS = {
	# --- 高级食材 (大幅涨价) ---
	"黑松露":   {"price_mult": 2.5, "time_mult": 1.0},  # 极其昂贵
	"鹅肝":     {"price_mult": 2.0, "time_mult": 1.0},
	"鱼翅":     {"price_mult": 2.0, "time_mult": 1.0},
	"燕窝":     {"price_mult": 1.8, "time_mult": 1.0},
	"鲍鱼":     {"price_mult": 2.2, "time_mult": 1.0},
	"鱼子酱":   {"price_mult": 2.5, "time_mult": 1.0},
	"松茸":     {"price_mult": 1.8, "time_mult": 1.0},
	"和牛":     {"price_mult": 2.5, "time_mult": 1.0},
	"伊比利亚火腿": {"price_mult": 2.0, "time_mult": 1.0},
	"藏红花":   {"price_mult": 2.0, "time_mult": 1.0},
	
	# --- 耗时手法 (时间大幅增加，成本略增) ---
	"老火":     {"price_mult": 1.3, "time_mult": 2.5},  # 老火汤，非常耗时
	"红烧":     {"price_mult": 1.1, "time_mult": 1.5},
	"炖":       {"price_mult": 1.1, "time_mult": 1.5},
	"焗":       {"price_mult": 1.1, "time_mult": 1.3},
	"炭烤":     {"price_mult": 1.2, "time_mult": 1.5},
	"砂锅":     {"price_mult": 1.2, "time_mult": 1.4},
	
	# --- 快速手法 (时间减少) ---
	"清炒":     {"price_mult": 0.9, "time_mult": 0.7},
	"凉拌":     {"price_mult": 0.8, "time_mult": 0.5},
	"白切":     {"price_mult": 0.9, "time_mult": 0.6},
	"水煮":     {"price_mult": 0.9, "time_mult": 0.8},
	
	# --- 精致/商务/国宴 (高价，略微耗时) ---
	"国宴":     {"price_mult": 1.8, "time_mult": 1.2},
	"商务":     {"price_mult": 1.3, "time_mult": 1.1},
	"精致":     {"price_mult": 1.2, "time_mult": 1.1},
	"摆盘风":   {"price_mult": 1.3, "time_mult": 1.1},
	"法式":     {"price_mult": 1.5, "time_mult": 1.1},
	"意式":     {"price_mult": 1.3, "time_mult": 1.0},
	"苏帮":     {"price_mult": 1.2, "time_mult": 1.1},
	"淮扬":     {"price_mult": 1.2, "time_mult": 1.1},
	
	# --- 普通家常 (略便宜) ---
	"家常":     {"price_mult": 0.9, "time_mult": 1.0},
	"清淡健康": {"price_mult": 0.95, "time_mult": 0.9}
}

# 后缀数值修正系数
const SUFFIX_MODIFIERS = {
	"王":   {"price_mult": 1.5, "time_mult": 1.1},
	"至尊": {"price_mult": 1.8, "time_mult": 1.2},
	"特制": {"price_mult": 1.3, "time_mult": 1.1},
	"秘制": {"price_mult": 1.5, "time_mult": 1.0}
}







# --- 数据缓存 ---
# 保持原始的数组格式，不做任何转换！
var csv_data_array: Array = [] 
# 对 fc.playerData.Total_dishes_list 的直接引用
var unlocked_dishes_list: Dictionary = {}

# --- 新的菜品分类 ---
# 修改后
const DISH_CATEGORIES: Array[String] = ["主菜", "主食", "小吃", "饮料", "酒水"]
var chef_manager
func _ready():
	chef_manager = preload("res://sc/chef_manager.gd").new()
	add_child(chef_manager)
	
	load_all_base_data()

# --- 数据加载函数 ---
func load_all_base_data():
	# 1. 使用你的函数加载CSV，保持为数组格式
	csv_data_array = fc.load_csv_to_rows("dishesData")
	#print("DishManager: 菜品总纲(CSV)加载完成，共 ", csv_data_array.size(), " 条。")
	
	# 2. 获取玩家已解锁菜品列表的引用
	if fc and fc.playerData and fc.playerData.Total_dishes_list:
		unlocked_dishes_list = fc.playerData.Total_dishes_list
	else:
		#print("DishManager: 警告，无法找到 fc.playerData.Total_dishes_list，已创建空字典。")
		fc.playerData.Total_dishes_list = {}
		unlocked_dishes_list = fc.playerData.Total_dishes_list
	

# --- 【核心】解锁菜品函数（修改版）---
func unlock_dish(dish_id: int):
	# 1. 检查是否已解锁
	if unlocked_dishes_list.has(str(dish_id)):
		#print("DishManager: 菜品ID '", dish_id, "' 已经解锁。")
		return

	# 2. 在CSV数组中进行线性搜索，找到对应ID的菜品数据
	var base_info: Dictionary = {}
	for row in csv_data_array:
		if row.get("ID") == dish_id:
			base_info = row
			break # 找到了就退出循环

	# 3. 检查是否在CSV中找到了这个菜品
	if base_info.is_empty():
		printerr("DishManager: 错误，无法在菜品总纲(CSV)中找到ID '", dish_id, "'。解锁失败。")
		return
	
	# 4. 处理熟度区域
	var area_id = 0
	for i in 4:
		var list = ["生", "偏生", "熟", "过熟"]
		if list[i] == base_info["shudu"]:
			area_id = i
			break

	# 5. 处理标签（从CSV中的tags字段解析）
	var tags = []
	if base_info.has("tags") and base_info["tags"] != "":
		var tag_array = base_info["tags"].split(",")
		for tag in tag_array:
			tags.append(tag.strip_edges())

	var unique_id = ""
	unique_id = "other_" + str(base_info.get("ID"))

	# 6. 构建新的数据结构
	unlocked_dishes_list[unique_id] = {
		# 基础信息
		"ID": unique_id,
		"name": base_info.get("name", "未知"),
		"category": base_info.get("type"),  # 新增分类字段
		"base_id": base_info.get("ID"),
		# 经营相关
		"price": base_info.get("base_price", 0),
		"base_price": base_info.get("base", 0),
		"stock": 0,  # 备货数量
		"need_stock": 0,#进货数量
		"chef": 0,
		"time": base_info.get("base_time", 0),
		
		# 烹饪相关
		"shudu": area_id,
		"shudu_value": base_info.get("shudu_value", 0),
		
		# 标签相关
		#"tags": tags,  # 基础标签
		"is_signature": false,  # 是否招牌
		"daily_sales": 0,  # 当日销量
		"total_sales": 0,  # 总销量
		"is_hot_selling": false  # 是否热销
	}
	
	#print("DishManager: 成功解锁菜品 '", base_info.get("name", "未知"), "' (ID: ", dish_id, ")，分类: ", unlocked_dishes_list[str(dish_id)]["category"])
	fc.playerData.Total_dishes_list = unlocked_dishes_list

# --- 【新增】按分类获取菜品 ---
func get_dishes_by_category(category: String) -> Array:
	var dishes = []
	for dish_id_str in fc.playerData.Total_dishes_list:
		var dish=fc.playerData.Total_dishes_list[dish_id_str]
		if dish["category"]==category:
			if category=="主菜":
				if dish["is_locked"]==false:
					dishes.append(dish_id_str)
			else:
				dishes.append(dish_id_str)
			
	return dishes


# --- 【新增】获取菜品分类 ---
func get_dish_category(dish_id) -> String:
	if fc.playerData.Total_dishes_list.has(dish_id):
		return fc.playerData.Total_dishes_list[dish_id].get("category", "主菜")
	return "主菜"

# --- 【新增】获取所有菜品分类 ---
func get_all_categories() -> Array[String]:
	return DISH_CATEGORIES.duplicate()

# --- 【修改】根据ID从CSV数组中获取菜品的完整信息 ---
func get_dish_full_info(dish_id) -> Dictionary:
	return fc.playerData.Total_dishes_list[dish_id]



# 【修改】获取菜品运行时数据
func get_dish_runtime_data(dish_id) -> Dictionary:
	if unlocked_dishes_list.has(dish_id):
		return unlocked_dishes_list[dish_id]
	return {}

# --- 【新增】更新菜品运行时数据 ---
# 【修改】更新菜品运行时数据
func update_dish_runtime_data(dish_id: String, key: String, value):
	if unlocked_dishes_list.has(dish_id):
		unlocked_dishes_list[dish_id][key] = value

# --- 【新增】增加销量 ---
func add_sales(dish_id, quantity: int = 1):
	if unlocked_dishes_list.has(str(dish_id)):
		var dish_data = unlocked_dishes_list[str(dish_id)]
		dish_data["daily_sales"] = dish_data.get("daily_sales", 0) + quantity
		dish_data["total_sales"] = dish_data.get("total_sales", 0) + quantity
		
		# 通知标签管理器更新热销状态
		if fc and fc.tag_manager:
			fc.tag_manager.update_hot_selling_status()

# --- 【新增】重置每日销量 ---
func reset_daily_sales():
	for dish_id_str in unlocked_dishes_list:
		unlocked_dishes_list[dish_id_str]["daily_sales"] = 0

# --- 【新增】搜索菜品（按分类和标签）---
func search_dishes(category: String = "", search_tags: Array = []) -> Array:
	var matching_dishes = []
	
	for dish_id_str in unlocked_dishes_list:
		var dish_data = unlocked_dishes_list[dish_id_str]
		var dish_id = int(dish_id_str)
		
		# 检查分类匹配
		if category != "" and dish_data.get("category") != category:
			continue
		
		# 检查标签匹配
		if search_tags.size() > 0:
			var dish_tags = fc.tag_manager.get_dish_tags(dish_id) if fc and fc.tag_manager else []
			var all_tags_match = true
			
			for search_tag in search_tags:
				if search_tag not in dish_tags:
					all_tags_match = false
					break
			
			if not all_tags_match:
				continue
		
		matching_dishes.append(dish_id)
	
	return matching_dishes

# --- 【新增】获取菜品价格 ---
func get_dish_price(dish_id) -> int:
	if unlocked_dishes_list.has(str(dish_id)):
		return unlocked_dishes_list[str(dish_id)].get("price", 0)
	return 0

# --- 【新增】获取菜品备货数量 ---
# 【修改】获取库存
func get_dish_stock(dish_id) -> int:
	if unlocked_dishes_list.has(dish_id):
		return int(unlocked_dishes_list[dish_id].get("stock"))
	return 0

# --- 【新增】设置菜品备货数量 ---
func set_dish_stock(dish_id, stock: int):
	if unlocked_dishes_list.has(str(dish_id)):
		if stock>999:
			stock=999
		unlocked_dishes_list[str(dish_id)]["stock"] = stock


# --- 【新增】减少菜品备货 ---
# 【修改】减少库存
func reduce_dish_stock(dish_id: String, quantity: int = 1) -> bool:
	if unlocked_dishes_list.has(dish_id):
		var current_stock = int(unlocked_dishes_list[dish_id].get("stock", 0))
		var new_stock = max(0, current_stock - quantity)
		unlocked_dishes_list[dish_id]["stock"] = new_stock
		
		# 返回是否刚刚售罄
		if current_stock > 0 and new_stock == 0:
			return true 
	return false

# --- 【修改】获取已解锁菜品列表 ---
func get_unlocked_dishes_list() -> Dictionary:
	return unlocked_dishes_list

# --- 【新增】获取菜品烹饪时间 ---
func get_dish_cooking_time(dish_id) -> float:
	if unlocked_dishes_list.has(str(dish_id)):
		return unlocked_dishes_list[str(dish_id)].get("time", 0.0)
	return 0.0

# --- 【新增】获取菜品熟度设置 ---
func get_dish_cooking_level(dish_id) -> int:
	if unlocked_dishes_list.has(str(dish_id)):
		return unlocked_dishes_list[str(dish_id)].get("shudu", 2)
	return 2

# --- 【新增】获取菜品熟度值 ---
func get_dish_cooking_value(dish_id) -> float:
	if unlocked_dishes_list.has(str(dish_id)):
		return unlocked_dishes_list[str(dish_id)].get("shudu_value", 75.0)
	return 75.0

func check_cai_data(type,id):
	var data = fc.load_csv_to_rows("dishesData")
	var check
	for i in data:
		if i["ID"]==int(id):
			check=i[type]
			break
	return check


# dish_data_manager.gd

# dish_data_manager.gd
# chef_level: int (1-10，该菜系的技能等级)
# is_unlocked: bool (true=招聘直接变菜, false=升级生成需解锁的菜谱)
func generate_procedural_dish(chef_skill_cuisine_type: int, chef_innovation: int, chef_level: int, is_unlocked: bool = false) -> String:
	# 1. 随机基底菜谱
	var base_recipe_id = _get_random_base_dish_id()
	if base_recipe_id == 0: return ""
	
	
	
	var base_data = fc.get_row_from_csv_data("dishesData","ID",base_recipe_id)
	var base_name = base_data.get("name", "未知菜")
	
	# 2. 【修正】获取前缀 (支持黑松露等高级食材)
	var prefix_list = CUISINE_PREFIX_CONFIG.get(chef_skill_cuisine_type, ["特色"])
	var selected_prefix = ""
	
	# --- 前缀选择逻辑 ---
	# 规则：
	# 等级 1-3: 100% 从该菜系的常规前缀中选 (如 "川香")
	# 等级 4-6: 混合选择
	# 等级 7-10: 20% 概率出现 "全局高级食材前缀" (如 "黑松露红烧肉")
	
	var fancy_trigger = (chef_level >= 7) and (randf() < 0.2)
	
	if fancy_trigger:
		# 从全局的高级食材池里随机取一个 (无论什么菜系，都可能做成法式黑松露风)
		selected_prefix = FANCY_INGREDIENT_PREFIXES[randi() % FANCY_INGREDIENT_PREFIXES.size()]
	else:
		# 从该菜系的特定配置里随机取一个
		if prefix_list.size() > 0:
			selected_prefix = prefix_list[randi() % prefix_list.size()]
		else:
			selected_prefix = "特色" # 容错

	# 3. 生成新名字 (前缀 + 基底)
	var new_name = selected_prefix + base_name
	
	# 10% 概率加史诗后缀
	var generated_suffix = ""
	if randf() < 0.1:
		var suffixes = ["王", "至尊", "特制", "秘制"]
		generated_suffix = suffixes[randi() % suffixes.size()]
		new_name += generated_suffix

	# 4. 【新增】计算数值修正系数
	var final_price_mult = 1.0
	var final_time_mult = 1.0

	# 4.1 应用前缀系数
	if PREFIX_MODIFIERS.has(selected_prefix):
		final_price_mult *= PREFIX_MODIFIERS[selected_prefix].price_mult
		final_time_mult *= PREFIX_MODIFIERS[selected_prefix].time_mult
		
	# 4.2 应用后缀系数
	if generated_suffix != "" and SUFFIX_MODIFIERS.has(generated_suffix):
		final_price_mult *= SUFFIX_MODIFIERS[generated_suffix].price_mult
		final_time_mult *= SUFFIX_MODIFIERS[generated_suffix].time_mult

	# 4.3 计算最终价格和时间 (向下取整)
	var base_price = base_data.get("base_price", 0)
	var base_time = base_data.get("base_time", 30)
	
	var final_price = int(float(base_price) * final_price_mult)
	var final_time = int(float(base_time) * final_time_mult)
	
	# 确保时间和价格不会太小或为负
	final_price = max(10, final_price) # 最低售价10
	final_time = max(10, final_time)   # 最快10秒

	# 5. 计算创意点消耗 (逻辑保持不变)
	var cost_multiplier = 1.0 + ((100.0 - float(chef_innovation)) / 100.0)
	var unlock_cost = int(1000 * cost_multiplier)


	# 5. 【修正】判断存入哪个列表
	var target_list_dict = {}
	var unique_id = ""
	
	if is_unlocked:
		# --- 招聘逻辑 ---
		# 数据存入 Total_dishes_list，且标记为 is_locked = false
		target_list_dict = fc.playerData.Total_dishes_list
		# 【修复】加上毫秒和随机数，防止循环生成时 ID 冲突
		unique_id = "unlocked_" + str(Time.get_ticks_msec()) + "_" + str(randi()) 
	else:
		# --- 升级逻辑 ---
		# 数据存入 LockedRecipes (需玩家手动解锁)
		if not fc.playerData.has("locked_recipes"):
			fc.playerData.locked_recipes = {} # 确保字典存在
		target_list_dict = fc.playerData.locked_recipes
		# 【修复】加上毫秒和随机数
		unique_id = "locked_" + str(Time.get_ticks_msec()) + "_" + str(randi())



		# --- 标签与评分 ---
	# ==========================================
	# 【关键修复】标签融合逻辑
	# ==========================================
	var final_tags = []
	# 1. 继承基底菜谱的标签
	var base_tags = base_data.get("tags", "")
	if typeof(base_tags) == TYPE_STRING and base_tags != "":
		# 处理 CSV 读出来的字符串格式 "辣,下饭"
		var tag_arr = base_tags.split(",")
		for t in tag_arr:
			final_tags.append(t.strip_edges())
	elif typeof(base_tags) == TYPE_ARRAY:
		# 兼容数组格式
		final_tags.append_array(base_tags)
		
	# 2. 【新增】根据前缀融合标签
	if PREFIX_TO_TAGS.has(selected_prefix):
		var prefix_tags = PREFIX_TO_TAGS[selected_prefix]
		for tag in prefix_tags:
			if not final_tags.has(tag): # 去重
				final_tags.append(tag)
	
	# 3. 添加菜系标签 (如 "川菜")
	# 这里简单映射一下，或者直接从配置里拿名字
	var cuisine_name_str = "特色菜"
	# 你可以在这里加个字典把枚举转中文，或者简单点：
	if chef_manager:
		cuisine_name_str = chef_manager.CUISINE_NAMES.get(chef_skill_cuisine_type, "特色菜")
	else:
		# 兜底：如果你没有 chef_manager 引用，这里需要简单映射
		# 比如通过字符串判断 ...
		pass
		
	if not final_tags.has(cuisine_name_str):
		final_tags.append(cuisine_name_str)
		
	# 4. 限制标签总数 (最多6个)
	if final_tags.size() > 6:
		final_tags.resize(6)
		
	var shudu=0
	var checklist=["生","偏生","熟","过熟"]
	for i in 4:
		if checklist[i]==base_data.get("shudu"):
			shudu=i
			break
	

	# 6. 构建数据结构
	var new_dish_data = {
		"ID": unique_id,
		"base_id": base_recipe_id, # 记录来源
		
		# --- 信息层 ---
		"name": new_name,
		"category": base_data.get("category", "主菜"),
		
		# --- 经营数据 ---
		"price": int(final_price*1.4),
		"base_price": int(final_price),
		"stock": 0,
		"need_stock": 0,
		"chef": 0,
		"time": int(final_time),
		
		# -菜品当前时间数据
		"shudu": shudu,#分为0，1，2，3，4
		"shudu_value": base_data.get("shudu_value", 75.0),#范围1-100
		
		# --- 菜品原始时间数据 ---
		"base_shudu": shudu,#分为0，1，2，3，4
		"base_shudu_value": base_data.get("shudu_value", 75.0),#范围1-100
		
		
		"tags": final_tags,
		
		"is_signature": false,
		"is_hot_selling": false,
		"daily_sales": 0,
		"total_sales": 0,
		
		# --- 融合属性 ---
		"fusion_source": chef_skill_cuisine_type, # 记录来源菜系 (int)
		"unlock_cost": unlock_cost,
		"generated_by": "chef",
		
		# --- 【关键】状态标记 ---
		"is_locked": not is_unlocked
	}

	# 7. 存入字典
	target_list_dict[unique_id] = new_dish_data
	
	var state_str = "菜品" if is_unlocked else "菜谱(待解锁)"
	print("DishManager: 生成%s: %s (创意点: %d)" % [state_str, new_name, unlock_cost])
	
	return unique_id


# ========================================================
# 【新增】解锁菜谱功能 (UI面板调用)
# ========================================================
func unlock_dish_from_locked(recipe_id: String) -> bool:
	# 1. 检查 LockedRecipes 中是否有这个菜谱
	if not fc.playerData.has("locked_recipes"):
		print("警告：没有锁定菜谱列表")
		return false
		
	if not fc.playerData.locked_recipes.has(recipe_id):
		print("警告：菜谱 ID 不存在")
		return false
	
	var recipe_data = fc.playerData.locked_recipes[recipe_id]
	
	# 2. 检查创意点是否足够
	var cost = recipe_data.get("unlock_cost", 0)
	if fc.playerData.innovation_points < cost:
		print("创意点不足")
		return false
	
	# 3. 扣除创意点
	fc.playerData.innovation_points -= cost
	
	# 4. 将数据从 LockedRecipes 移动到 Total_dishes_list
	var unlocked_data = recipe_data.duplicate(true)
	unlocked_data["is_locked"] = false
	unlocked_data["ID"] = "dish_" + str(Time.get_unix_time_from_system()) # 给个新ID正式成为菜
	# 初始化一些经营数据
	unlocked_data["stock"] = 0
	unlocked_data["daily_sales"] = 0
	
	# 存入主列表
	fc.playerData.Total_dishes_list[unlocked_data["ID"]] = unlocked_data
	
	# 从锁定列表中删除
	fc.playerData.locked_recipes.erase(recipe_id)
	
	print("DishManager: 解锁成功！解锁菜: ", unlocked_data["name"])
	return true


# ========================================================
# 【新增】获取锁定菜谱列表 (供UI显示)
# ========================================================
func get_locked_recipes_list() -> Dictionary:
	if fc.playerData.has("locked_recipes"):
		return fc.playerData.locked_recipes
	return {}


# ========================================================
# 【辅助】修改随机获取基底ID的函数 (仅抽取主菜)
# ========================================================
func _get_random_base_dish_id() -> int:
	# 确保数组已加载
	if csv_data_array.is_empty():
		csv_data_array = fc.load_csv_to_rows("dishesData")
		
	if csv_data_array.is_empty(): return 0
	
	# 【关键修改】筛选出所有“主菜”类型的基底菜谱
	var main_dish_candidates = []
	for row in csv_data_array:
		# 注意：csv_data_array 是原始 CSV 数据，分类字段通常叫 "type"
		if row.get("type", "") == "主菜":
			main_dish_candidates.append(row)
	
	# 如果筛选后是空的（比如CSV里没填主菜），报错并返回0
	if main_dish_candidates.is_empty():
		printerr("DishManager: 错误，CSV中未找到“主菜”类型的菜谱，无法生成菜谱。")
		return 0
	
	# 从筛选后的列表中随机取一个
	var random_row = main_dish_candidates[randi() % main_dish_candidates.size()]
	var id_val = random_row.get("ID", 0)
	
	# 确保返回整数
	if typeof(id_val) == TYPE_STRING:
		if id_val.is_valid_int():
			return id_val.to_int()
		return 0
		
	return int(id_val)
