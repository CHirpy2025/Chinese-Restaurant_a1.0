extends Node3D
class_name RandmapManager

# 上下文枚举
enum Context {
	BUZHI,      # 布置系统 (编辑器模式)
	GAME_SCENE, # 游戏场景 (营业模式)
	CHOICE_MAP  # 选地图模式
}

# --- 核心引用 ---
@export_group("核心引用")
@export var grid_map_node: GridMap      # 对应 Floor
@export var base_floor_node: GridMap    # 对应 Floor2

# --- 子系统引用 ---
@onready var map_system: MapSystem = $MapSystem
# 【新增】启用家具系统
@onready var furniture_system: FurnitureSystem = $FurnitureSystem 
@onready var waiter_system: WaiterSystem = $WaiterSystem # 【新增】
@onready var customer_system: CustomerSystem = $CustomerSystem # 【新增】
@onready var interaction_system: InteractionSystem = $InteractionSystem
var ordering_system: OrderingSystem
var kitchen_system: KitchenSystem
# --- 全局容器 ---
var furniture_holder: Node3D = null
var customer_holder: Node3D = null

# 当前上下文
var current_context: Context = Context.GAME_SCENE

func _ready():
	# 自动查找 GridMap，防止遗忘拖拽
	if not grid_map_node and has_node("Floor"):
		grid_map_node = $Floor
	if not base_floor_node and has_node("Floor2"):
		base_floor_node = $Floor2
		
	# 初始化容器
	_init_holders()
	
	ordering_system = preload("res://sc/ordering_system.gd").new()
	add_child(ordering_system)
	ordering_system.setup(self)
	
	kitchen_system = preload("res://sc/kitchen_system.gd").new()
	add_child(kitchen_system)
	kitchen_system.setup(self)
	
	# 如果所有子脚本都准备好了，可以在这里统一 setup
	# map_system.setup(self)

func _init_holders():
	# 创建或清理家具容器
	if has_node("FurnitureHolder"):
		furniture_holder = $FurnitureHolder
	else:
		furniture_holder = Node3D.new()
		furniture_holder.name = "FurnitureHolder"
		add_child(furniture_holder)

# 供外部调用的初始化入口
func setup_for_context(context: Context):
	current_context = context
	#print("RandmapManager 初始化模式: ", Context.keys()[context])
	
	if map_system:
		map_system.setup(self)
	
	# 【新增】初始化家具系统
	if furniture_system:
		furniture_system.setup(self)
	if waiter_system: waiter_system.setup(self) # 【新增】
	if customer_system: customer_system.setup(self) # 【新增】
	if interaction_system: interaction_system.setup(self) # 【新增】
