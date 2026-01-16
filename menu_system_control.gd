# menu_system_control.gd
extends Control

@onready var item_container: VBoxContainer = $ScrollContainer/ItemContainer

const DISH_TITLE_SCENE = preload("res://sc/dish_title.tscn")
const DISH_SHOW_SCENE = preload("res://sc/dishes_show.tscn")

# --- 新增：每行显示的菜品数量 ---
@export var dishes_per_row: int = 3

func _ready():
	pass

# --- 核心菜单生成函数 (修改版) ---
# menu_system_control.gd 中的修改
func load_menu():
	clear_menu()

	if not fc or not fc.playerData or not fc.playerData.MYdisheslist:
		print("错误：无法获取玩家菜单列表 (fc.playerData.MYdisheslist)")
		return
		
	var menu_ids = fc.playerData.MYdisheslist
	var dishes_by_category: Dictionary = {}
	
	# 按新分类整理菜品
	for dish_id in menu_ids:
		var full_info = fc.playerData.Total_dishes_list[dish_id]
		if full_info.is_empty():
			print("警告：菜单中的菜品ID ", dish_id, " 在总数据中找不到，已跳过。")
			continue
		
		# 使用新的分类字段
		var category = fc.dish_data_manager.get_dish_category(dish_id)
		

		
		
		if not dishes_by_category.has(category):
			dishes_by_category[category] = []
		dishes_by_category[category].append(full_info)

	# 按新分类顺序生成UI
	var all_categories: Array[String] = fc.dish_data_manager.get_all_categories()
	for category in all_categories:
		if dishes_by_category.has(category) and dishes_by_category[category].size() > 0:
			# 1. 添加分类标题

			
			add_category_title(category)
			
			
			# 2. 创建一个GridContainer来存放该分类的所有菜品
			var dish_grid = GridContainer.new()
			dish_grid.columns = dishes_per_row
			dish_grid.add_theme_constant_override("h_separation", 30)
			dish_grid.add_theme_constant_override("v_separation", 30)
			
			# 确保网格不会被垂直拉伸
			dish_grid.size_flags_vertical = Control.SIZE_FILL
			
			item_container.add_child(dish_grid)
			
			# 3. 遍历该分类的菜品，并将它们添加到GridContainer中
			for dish_data in dishes_by_category[category]:
				add_dish_item(dish_data, dish_grid)


# --- UI生成辅助函数 ---
func add_category_title(title_text: String):

	
	var title_instance = DISH_TITLE_SCENE.instantiate()
	title_instance.get_node("show").text = title_text
	#item_container.add_child(new_sp1)
	item_container.add_child(title_instance)
	#item_container.add_child(new_sp2)
	# 确保标题不会被垂直拉伸
	title_instance.size_flags_vertical = Control.SIZE_FILL

	
	
# 增加一个parent_node参数，让菜品可以被添加到任何容器
func add_dish_item(dish_data: Dictionary, parent_node: Node):
	var dish_instance = DISH_SHOW_SCENE.instantiate()
	
	
	if dish_instance.has_method("setup"):
		dish_instance.setup(dish_data["ID"])
	else:
		print("警告: dishes_show.tscn 的根节点缺少 setup() 方法。")
		
	# 将菜品实例添加到传入的父节点中
	parent_node.add_child(dish_instance)

func clear_menu():
	for child in item_container.get_children():
		child.queue_free()
