# tag_manager.gd
extends Node

# 标签分类
enum TagCategory {
	BASE,       # 基础标签（地域、口味等）
	DYNAMIC,    # 动态标签（招牌、热销等）
	FEATURE,     # 特性标签（份量、场合等）
	AREA     # 地域）	
}

# 预定义标签
# tag_manager.gd

const PREDEFINED_TAGS = {
	# --- 基础标签 (原有) ---
	"清淡健康": TagCategory.BASE,
	"重口味": TagCategory.BASE,
	"多人分享": TagCategory.FEATURE,
	"单人份": TagCategory.FEATURE,
	"传统经典": TagCategory.BASE,
	"地方特色": TagCategory.BASE,
	"家常": TagCategory.BASE,
	"商务": TagCategory.FEATURE,
	"创新菜": TagCategory.BASE,
	"下酒": TagCategory.FEATURE,
	"搭饮": TagCategory.FEATURE,
	"软口": TagCategory.BASE,
	"劲嚼": TagCategory.BASE,
	"摆盘风": TagCategory.BASE,
	"下饭": TagCategory.BASE,
	"热食": TagCategory.BASE,
	"冷食": TagCategory.BASE,
	"汤类": TagCategory.BASE,
	"凉菜": TagCategory.BASE,
	"特色": TagCategory.BASE,

	# --- 特性标签 (你在文件中新增的) ---
	"昂贵": TagCategory.FEATURE,
	"高级": TagCategory.FEATURE,
	"滋补": TagCategory.FEATURE,
	"甜口": TagCategory.FEATURE,

	# --- 【新增】补齐缺失的标签 ---
	# 口味类
	"辣": TagCategory.BASE,
	"香口": TagCategory.BASE,
	"酸甜": TagCategory.BASE,
	"酒香": TagCategory.BASE, # 香气
	"茶香": TagCategory.BASE, # 香气
	"浓香": TagCategory.BASE, # 香气
	"清新": TagCategory.BASE, # 香气
	"保留原味": TagCategory.BASE,
	"鲜味": TagCategory.BASE,
	
	# 品质/食材类
	"精致": TagCategory.FEATURE,
	"坚果": TagCategory.FEATURE,
	"健康": TagCategory.FEATURE,
	"鲜艳": TagCategory.FEATURE,

	# 地域标签
	"川菜": TagCategory.AREA,
	"湘菜": TagCategory.AREA,
	"粤菜": TagCategory.AREA,
	"鲁菜": TagCategory.AREA,
	"苏菜": TagCategory.AREA,
	"浙菜": TagCategory.AREA,
	"闽菜": TagCategory.AREA,
	"徽菜": TagCategory.AREA,
	
	# 动态标签
	"本店招牌": TagCategory.DYNAMIC,
	"热销": TagCategory.DYNAMIC
}


# 热销阈值（可配置）
var hot_selling_threshold = 10  # 每日销量超过10自动标记为热销

# 获取菜品的所有标签
# tag_manager.gd

func get_dish_tags(dish_id) -> Array:
	if not fc.playerData.Total_dishes_list.has(str(dish_id)):
		return []
	
	var dish_data = fc.playerData.Total_dishes_list[str(dish_id)]
	var tags = []
	
	# 【关键修复】优先读取运行时数据中已保存的 tags
	# (针对自生成的菜谱，tags 已经在生成时计算好并存在 Total_dishes_list 里了)
	if dish_data.has("tags"):
		var runtime_tags = dish_data["tags"]
		if typeof(runtime_tags) == TYPE_ARRAY:
			tags.append_array(runtime_tags)
		elif typeof(runtime_tags) == TYPE_STRING:
			# 兼容旧数据或特殊情况(字符串格式)
			for t in runtime_tags.split(","):
				tags.append(t.strip_edges())

	# 【降级逻辑】如果运行时数据里没有 tags (可能是旧数据或空数据)，才回退去读 CSV
	# (针对默认菜谱，它们还在用 CSV 的数据结构)
	if tags.is_empty():
		var data = fc.get_row_from_csv_data("dishesData","ID",int(dish_id))
		if data:
			for k in range(1,7):
				if data["tag"+str(k)]!="":
					tags.append(data["tag"+str(k)])
	
	# --- 下面是动态标签处理 (保持不变) ---
	
	# 动态标签 (招牌、热销)
	if dish_data.get("is_signature", false):
		tags.append("本店招牌")
	
	if dish_data.get("is_hot_selling", false):
		tags.append("热销")
	
	return tags


# 在 tag_manager.gd 中添加这个函数

# 查询标签属于哪个分类
func get_tag_category(tag: String) -> TagCategory:
	return PREDEFINED_TAGS.get(tag, TagCategory.BASE)  # 默认返回 BASE


# 添加标签到菜品
func add_tag_to_dish(dish_id, tag):
	if not PREDEFINED_TAGS.has(tag):
		print("警告：未知标签 '", tag, "'")
		return
	
	if not fc.playerData.Total_dishes_list.has(str(dish_id)):
		print("警告：菜品ID ", dish_id, " 不存在")
		return
	
	var dish_data = fc.playerData.Total_dishes_list[str(dish_id)]
	
	# 处理动态标签
	if tag == "本店招牌":
		dish_data["is_signature"] = true
	elif tag == "热销":
		dish_data["is_hot_selling"] = true
	else:
		# 基础标签
		if not dish_data.has("tags"):
			dish_data["tags"] = []
		
		if tag not in dish_data["tags"]:
			dish_data["tags"].append(tag)

# 移除菜品标签
func remove_tag_from_dish(dish_id, tag: String):
	if not fc.playerData.Total_dishes_list.has(str(dish_id)):
		return
	
	var dish_data = fc.playerData.Total_dishes_list[str(dish_id)]
	
	# 处理动态标签
	if tag == "本店招牌":
		dish_data["is_signature"] = false
	elif tag == "热销":
		dish_data["is_hot_selling"] = false
	else:
		# 基础标签
		if dish_data.has("tags") and tag in dish_data["tags"]:
			dish_data["tags"].erase(tag)

# 更新热销状态
func update_hot_selling_status():
	for dish_id_str in fc.playerData.Total_dishes_list:
		var dish_data = fc.playerData.Total_dishes_list[dish_id_str]
		var daily_sales = dish_data.get("daily_sales", 0)
		
		# 检查是否达到热销阈值
		var was_hot_selling = dish_data.get("is_hot_selling", false)
		var should_be_hot_selling = daily_sales >= hot_selling_threshold
		
		if was_hot_selling != should_be_hot_selling:
			dish_data["is_hot_selling"] = should_be_hot_selling
			#print("菜品 ", dish_data.get("name", "未知"), " 热销状态更新: ", should_be_hot_selling)

# 重置每日销量
func reset_daily_sales():
	for dish_id_str in fc.playerData.Total_dishes_list:
		var dish_data = fc.playerData.Total_dishes_list[dish_id_str]
		dish_data["daily_sales"] = 0

# 增加销量
func add_sales(dish_id, quantity: int = 1):
	if not fc.playerData.Total_dishes_list.has(str(dish_id)):
		return
	
	var dish_data = fc.playerData.Total_dishes_list[str(dish_id)]
	dish_data["daily_sales"] = dish_data.get("daily_sales", 0) + quantity
	dish_data["total_sales"] = dish_data.get("total_sales", 0) + quantity
	
	# 检查是否需要更新热销状态
	update_hot_selling_status()

# 设置热销阈值
func set_hot_selling_threshold(threshold: int):
	hot_selling_threshold = threshold
	update_hot_selling_status()
