extends Control

# --- 可配置参数 ---
@export var min_stock: int = 0
@export var max_stock: int = 999
@export var initial_stock: int = 0
@export var step_amount: int = 1 # 每次点击或按住时增加/减少的数量

# --- 节点引用 ---
@onready var stock_show = $now
@onready var stock_need = $need
@onready var sub_bt = $sub
@onready var add_bt = $add

# --- 内部变量 ---
var current_stock: int = 0
var need_stock: int = 0

# 定义按键状态枚举
enum HoldState {
	NONE,      # 无操作
	ADDING,    # 正在按加
	SUBTRACTING # 正在按减
}

var current_hold_state: HoldState = HoldState.NONE

# 按住连点用的计时器
var hold_timer: Timer = null
const HOLD_INTERVAL: float = 0.08 # 连点速度(秒)，数值越小越快

# --- 信号 ---
signal stock_changed(new_stock: int)


func _ready():
	# 1. 初始化库存
	set_stock(0,0)
	
	# 2. 创建并配置计时器
	hold_timer = Timer.new()
	hold_timer.wait_time = HOLD_INTERVAL
	hold_timer.autostart = false # 不自动开始
	hold_timer.one_shot = false # 循环执行
	add_child(hold_timer)
	
	# 连接计时器超时信号
	hold_timer.timeout.connect(_on_hold_tick)
	
	# 3. 绑定按钮信号
	add_bt.button_down.connect(_on_add_down.bind())
	add_bt.button_up.connect(_on_any_button_up.bind())
	
	sub_bt.button_down.connect(_on_sub_down.bind())
	sub_bt.button_up.connect(_on_any_button_up.bind())


# --- 核心逻辑：设置库存 ---
func set_stock(now:int,need: int):
	current_stock = now
	need_stock = clamp(need, min_stock, max_stock)
	update_ui()
	stock_changed.emit(need_stock)


# --- 核心逻辑：更新UI显示 ---
func update_ui():
	# 1. 更新文字显示
	stock_need.text = "/"+str(need_stock)
	
	# 2. 可选：达到上限时禁用加号按钮，达到下限时禁用减号按钮 (提升体验)
	if add_bt:
		add_bt.disabled = (need_stock >= max_stock)
	if sub_bt:
		sub_bt.disabled = (need_stock <= min_stock)


# --- 核心逻辑：改变库存 ---
func _change_stock(amount: int):
	fc.play_se_fx("up")
	set_stock(current_stock,need_stock + amount)


# --- 按钮事件处理 ---

# 【通用】任意按钮抬起 -> 重置状态并停止计时
func _on_any_button_up():
	current_hold_state = HoldState.NONE
	hold_timer.stop()
	update_ui() # 确保抬起时按钮状态正确更新（比如松开减号时，如果到0了，减号按钮变灰）

# 【加号】按下
func _on_add_down():
	# 防御性代码：如果已经满了，不处理
	if need_stock >= max_stock:
		return
	
	# 【关键修改】强制重置为增加状态，清除其他状态
	current_hold_state = HoldState.ADDING
	
	_change_stock(step_amount) # 立即加一次
	hold_timer.start() # 启动计时器

# 【减号】按下
func _on_sub_down():
	# 防御性代码：如果已经空了，不处理
	if need_stock <= min_stock:
		return
	
	# 【关键修改】强制重置为减少状态，清除其他状态
	current_hold_state = HoldState.SUBTRACTING
	
	_change_stock(-step_amount) # 立即减一次
	hold_timer.start() # 启动计时器


# --- 计时器回调：处理连点逻辑 ---
func _on_hold_tick():
	match current_hold_state:
		HoldState.ADDING:
			# 如果满了，自动停止
			if need_stock >= max_stock:
				current_hold_state = HoldState.NONE
				hold_timer.stop()
				update_ui()
				return
			
			_change_stock(step_amount)
			
		HoldState.SUBTRACTING:
			# 如果空了，自动停止
			if need_stock <= min_stock:
				current_hold_state = HoldState.NONE
				hold_timer.stop()
				update_ui()
				return
			
			_change_stock(-step_amount)
			
		HoldState.NONE:
			# 理论上不会跑到这里，但如果跑到了，停止计时器以防万一
			hold_timer.stop()
