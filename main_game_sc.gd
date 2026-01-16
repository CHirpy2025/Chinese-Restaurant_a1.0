# main_game_sc.gd
extends Node3D

# --- 核心节点引用 ---
@onready var camera = $Camera3D
@onready var world_env = $WorldEnvironment
@onready var sun_light = $DirectionalLight3D
@onready var bg = $bg
@onready var maplight = $maplight as OmniLight3D
@onready var map_holder = $MapHolder

# --- 【关键】Randmap 管理器引用 ---
@onready var randmap_manager: RandmapManager = $MapHolder/Randmap
@onready var time_system: TimeSystem = $time_system

# --- 窗口穿透标记点 ---
@onready var marker_tl = $MarkerTL
@onready var marker_tr = $MarkerTR
@onready var marker_br = $MarkerBR
@onready var marker_bl = $MarkerBL

# --- 日夜循环配置 ---
var day_sun_color = Color("fdfcdc")
var day_sun_energy = 1.0
var day_ambient_color = Color("e8e4d9")
var day_ambient_energy = 0.6

var night_sun_color = Color("cad2ef")
var night_sun_energy = 0.1
var night_ambient_color = Color("a6e0fd")
var night_ambient_energy = 0.3

var maplight_day_color = Color("ffffff")
var maplight_day_energy = 0.0
var maplight_night_color = Color("ffd1af")
var maplight_night_energy = 3.0

# --- 营业状态光照配置 ---
# 关门状态光照（较暗，偏冷色调）
var closed_sun_color = Color("b0b0b0")      # 灰白色太阳光
var closed_sun_energy = 0.3               # 低能量
var closed_ambient_color = Color("808080") # 灰色环境光
var closed_ambient_energy = 0.2           # 低环境光能量

# 午休状态光照（中等亮度）
var lunch_sun_color = Color("d0d0d0")      # 稍亮的灰白色
var lunch_sun_energy = 0.5                 # 中等能量
var lunch_ambient_color = Color("a0a0a0")  # 中等灰色
var lunch_ambient_energy = 0.3             # 中等环境光

# 地图灯光在关门时的配置
var closed_maplight_color = Color("ffaa66") # 暖黄色，但较弱
var closed_maplight_energy = 1.5            # 较弱的能量
var lunch_maplight_color = Color("ffcc88") # 暖黄色
var lunch_maplight_energy = 2.0            # 中等能量

var maplight_range = 70.0
var maplight_attenuation = 0.3
var maplight_shadow_enabled = false

# --- 状态变量 ---
var is_night = false
var dragging = false
var drag_start_position = Vector2()

var ui_windows: Array[Window] = []
var is_ui_draggings: Array[bool] = []
var ui_drag_start_poses: Array[Vector2i] = []
var ui_window_start_poses: Array[Vector2i] = []

var ui_scenes: Array[PackedScene] = []
var UI_SCENE_PATH_1 = "res://sc/main_info_ui.tscn"
var UI_SCENE_PATH_2 = "res://sc/financial_situation.tscn"
var UI_SCENE_PATH_3 = "res://sc/business_info.tscn"
var UI_SCENE_PATH_4 = "res://sc/button_show_ui.tscn"

@export var AUTO_SAVE_INTERVAL: float = 60.0
var auto_save_timer: Timer

# --- 新窗口管理系统 ---
var popup_windows: Array[Window] = []  # 存储所有弹窗
var popup_scenes: Dictionary = {}      # 存储预加载的场景
# 预定义的弹窗场景路径
var POPUP_SCENE_PATHS = {
	"caibao": "res://sc/caibao_ui.tscn",
	"tongji": "res://sc/tongji_ui.tscn",
	"sys": "res://sc/management_ui.tscn",
	"paihang": "res://sc/paihang_ui.tscn",
	# 添加更多场景路径
}

# --- 时间系统相关 ---
var main_info_ui_window: Window
var msgshow = null
var button_ui = null
var info_ui = null
@onready var bird_system: BirdSystem = $BirdSystem

# =================================================================
# 1. 初始化
# =================================================================

func _ready():
	if fc.now_play_mu==false:
		if fc.playerData.BGMmusic!="":
			fc.now_play_mu=true
			fc.play_mu(fc.playerData.BGMmusic)
	
	
	
	fc.playerData.from_main_game = true

	# 基础窗口设置
	get_window().transparent_bg = true
	get_window().borderless = true
	get_window().always_on_top = true
	get_window().unfocusable = true
	
	move_window_to_bottom_right_sync()
	# 初始化鸟群系统
	if bird_system:
		bird_system.setup()
	
	# 初始化bg
	for i in bg.get_children():
		if i is Sprite3D:
			i.visible = false
	
	var wall = fc.get_row_from_csv_data("walldoorData", "ID", fc.playerData.wall_id)
	var door = fc.get_row_from_csv_data("walldoorData", "ID", fc.playerData.door_id)

	for i in bg.get_children():
		if i is Sprite3D:
			if i.name == door["show"]:
				i.visible = true
				if check_pic():
					var img = Image.load_from_file("user://logo_0.png")
					var loaded_texture = ImageTexture.create_from_image(img)
					i.get_node("Sprite3D").texture = loaded_texture
				else:
					i.get_node("Sprite3D").texture = load("res://pic/ui/logo2.png")
				i.get_node("title").text = fc.playerData.name
				break
	
	bg.replace_tile_by_name(wall["show"], wall["show"])
	
	# 初始化时间系统
	if time_system:
		time_system.setup(self, fc.playerData)
		
		# --- 连接信号 ---
		# 1. 基础时间更新（用于显示 UI 上的时间文字）
		time_system.time_changed.connect(_on_time_changed)
		
		# 2. 状态机核心信号（处理光照、音乐、清场逻辑）
		if time_system.has_signal("business_state_changed"):
			time_system.business_state_changed.connect(_on_business_state_changed)
		
		# 3. 日期切换（用于存档或跨天结算）
		time_system.day_changed.connect(_on_day_changed)
		
		## 4. 开关门动作信号（用于处理服务员 AI 开关、招牌灯开关）
		#time_system.business_state_changed.connect(_on_business_opened)
		#time_system.business_state_changed.connect(_on_business_closed)

	# ========================================================
	# 【核心修复】拆解后的加载序列
	# ========================================================
	if randmap_manager:
		# A. 初始化管理器（营业模式上下文）
		randmap_manager.setup_for_context(RandmapManager.Context.GAME_SCENE)
		
		# B. 加载地形
		if randmap_manager.map_system:
			var data = fc.get_row_from_csv_data("walldoorData", "ID", fc.playerData.floor_id)
			randmap_manager.map_system.load_map() # 加载存档形状
			randmap_manager.map_system.replace_map_tiles_with(data["zhuan_id"]) # 应用皮肤

		# C. 适配相机（必须在地形加载后）
		await get_tree().process_frame
		_setup_camera_for_map()
		
		# D. 【关键等待】确保相机和 GridMap 位置已锁定
		await get_tree().process_frame
		
		# E. 加载家具
		if randmap_manager.furniture_system:
			randmap_manager.furniture_system.load_furniture_from_global()
		
		# F. 加载人员
		if randmap_manager.waiter_system:
			randmap_manager.waiter_system.load_waiters_from_global()
		
		#if randmap_manager.customer_system:
			## 加载存档中的客人状态
			#randmap_manager.customer_system.load_customer_states()

		# 在_ready函数中添加
		if randmap_manager.interaction_system:
			randmap_manager.interaction_system.setup(randmap_manager)

	# --------------------------------------------------------
	# ========================================================
	# 【核心修复】强制重建寻路数据 (空白格子地图)
	# ========================================================
	# 如果不执行这一步，MapSystem 里的 empty_floor_cells 是空的，服务生哪都去不了
	if randmap_manager.map_system and randmap_manager.furniture_system:
		randmap_manager.map_system.rebuild_empty_cells_map(randmap_manager.furniture_system)

	# 初始化环境状态
	if _time_string_to_minutes(fc.playerData.now_time) >= _time_string_to_minutes("18:30"):
		is_night = true
		apply_night_state()
	else:
		is_night = false
		apply_day_state()

	# 修正物体旋转（针对 2.5D 视角）
	await get_tree().process_frame
	_correct_all_rotations()
	
	update_mouse_passthrough()
	
	# UI 窗口初始化
	await setup_all_ui_windows()

	# 启动时间与自动保存
	check_stock()
	
	get_window().close_requested.connect(_on_window_close_requested)
	_init_popup_system()
	
	check_deployment_status()
	# 启动时间系统

	# 根据当前营业状态设置初始光照
	await get_tree().process_frame  # 等待一帧确保所有系统初始化完成
	_set_initial_lighting_by_business_state()

# 添加初始光照设置函数
func _set_initial_lighting_by_business_state():
	if not time_system:
		return
	
	var current_state = time_system.current_business_state
	match current_state:
		TimeSystem.BusinessState.OPEN:
			restore_normal_business_lighting()
		TimeSystem.BusinessState.CLOSED:
			apply_closed_state()
		TimeSystem.BusinessState.LUNCH_BREAK:
			apply_lunch_state()
	
# =================================================================
# 2. 时间系统信号处理
# =================================================================

@warning_ignore("unused_parameter")
# 修改 main_game_sc.gd 中的 _on_time_changed 函数
func _on_time_changed(current_time: String):
	# 更新UI显示
	_update_time_display()
	
	# 每10分钟自动保存
	
	# 检查光照切换
	_check_day_night_transition()
	
	# 【新增】每分钟检查并派遣等待的客人
	if fc.playerData.is_open:  # 仅在营业状态下
		try_dispatch_waiting_customers()
	
	# 【原有】尝试生成新客人
	if fc.playerData.is_open:  # 仅在营业状态下
		try_spawn_customer()

# 【新增】尝试派遣等待中的客人
func try_dispatch_waiting_customers():
	if not randmap_manager or not randmap_manager.customer_system:
		return
	
	# 调用客人系统的派遣函数
	randmap_manager.customer_system.process_customer_greeting()

# 尝试生成客人
# 在 main_game_sc.gd 中找到并修改 try_spawn_customer 函数
# 在 main_game_sc.gd 中修改 try_spawn_customer 函数的尾部逻辑

func try_spawn_customer():
	if not fc.playerData.is_open or time_system.current_business_state == TimeSystem.BusinessState.CLOSING:
		return
	
	# 1. 冷却检查
	if time_system.current_game_minutes == fc.playerData.last_spawn_minute:
		return 
	
	# 2. 获取当前评分
	var current_rating = fc.playerData.ratings_data["global"]["average"]
	
	# 3. 计算生成概率
	var probability = fc.calculate_time_segment_spawn_rate(
		time_system.current_game_minutes, 
		current_rating
	)
	
	# 4. 概率判定生成
	if randf() < probability:
		# 5. 计算类型权重
		var type_weights = fc.calculate_customer_type_weights()
		
		if type_weights.size() > 0:
			var types = []
			var weights = []
			for item in type_weights:
				types.append(item["type"])
				weights.append(item["weight"])
			
			# 6. 抽取类型
			var selected_customer_type = fc.weighted_random_choice(types, weights)
			
			# ============================================================
			# 【新增】外卖逻辑拦截
			# ============================================================
			if selected_customer_type == "外卖":
				_process_takeaway_order()
				# 更新冷却时间
				fc.playerData.last_spawn_minute = time_system.current_game_minutes
				return # 外卖处理完毕，不执行下面的堂食逻辑
			
			# ============================================================
			# 【原有】堂食逻辑
			# ============================================================
			var customer_details = fc.customer_check(selected_customer_type)
			
			if not customer_details.is_empty():
				if randmap_manager and randmap_manager.customer_system:
					randmap_manager.customer_system.spawn_customer_if_needed(customer_details)
					print("生成客人: 类型=%s, 人数=%d, 预算=%d" % [customer_details["类型"], customer_details["人数"], customer_details["预算"]])
					fc.playerData.last_spawn_minute = time_system.current_game_minutes


# 在 main_game_sc.gd 中添加处理外卖订单的函数
func _process_takeaway_order():
	# 1. 检查是否有外卖柜台
	if not randmap_manager or not randmap_manager.furniture_system:
		return
		
	var counters = randmap_manager.furniture_system.get_all_furniture_by_limit("外卖柜台")
	if counters.is_empty():
		# 虽然刷出了外卖类型，但没柜台，忽略本次生成
		return
	
	# 2. 生成外卖菜单
	if not randmap_manager.ordering_system:
		return
		
	var takeaway_dishes = randmap_manager.ordering_system.make_takeaway_menu()
	
	if takeaway_dishes.is_empty():
		# 没菜可卖，忽略
		return
		
	# 3. 发送给厨房
	# 默认使用第一个外卖柜台
	var counter_node = counters[0]["node_ref"]
	randmap_manager.kitchen_system.receive_takeaway_order(takeaway_dishes, counter_node)
	
	print("生成外卖订单，菜品数: ", takeaway_dishes.size())


func _on_day_changed(new_day: int, new_month: int, new_year: int):
	add_msg(["通知","新的一天开始了"])
	fc.playerData.game_day = new_day
	fc.playerData.game_month = new_month
	fc.playerData.game_year = new_year
# ============================================================
	# 【新增】广告效果每日自然衰减
	# ============================================================
	var daily_decay = 2.0 # 每天衰减 5 点，你可以根据游戏节奏调整
	fc.playerData.ads_effect = max(50.0, fc.playerData.ads_effect - daily_decay)

func _on_business_opened():
	add_msg(["通知","饭店开门营业啦！"])
	# ============================================================
	# 【核心修改】锁定当前经营周期的归属日
	# ============================================================
	# 每次开店，更新 current_business_day_id 为当前游戏日期
	# 这意味着从这一刻起发生的所有经济行为，都归到这一天
	fc.playerData.current_business_day_id = fc.playerData.game_day
	
	# ============================================================
	# 【核心修改】计算并扣除电费 (只在这个时刻扣)
	# ============================================================
	var elec_cost = fc.playerData.calculate_daily_electricity_cost()
	fc.playerData.pay_dian += elec_cost # 计入当天成本
	fc.playerData.money -= elec_cost # 扣钱
# ============================================================
	# 【核心修改】计算并扣除初始采购费 (进一次货)
	# ============================================================
	# 这里的逻辑是：开店时，把所有库存不足的菜品补满到设定值（例如10份）
	# 然后计算总成本
	var proc_cost = _calculate_initial_procurement_cost() # 这是一个新辅助函数，见下文
	if proc_cost > 0:
		fc.playerData.pay_caigou += proc_cost # 计入当天成本
		fc.playerData.money -= proc_cost # 扣钱
		add_msg(["通知", "开市采购已完成，花费： %s (计入第 %d 天账单)" % [fc.format_money(proc_cost), fc.playerData.current_business_day_id]])
		
	
	
	if fc.playerData.dirty >= 120:
		add_msg(["通知", "店里已经很脏了，建议打烊进行大扫除。"])
	Audio.clean_up()
	fc.play_se_fx("opendoor")
	if bird_system:
		bird_system.set_system_active(true)
	
	check_stock()
	
	
	# 开店时，服务员切换为工作状态
	if randmap_manager and randmap_manager.waiter_system:
		randmap_manager.waiter_system.set_all_waiters_working()
	
	button_ui.change_state(true)
	
	# 恢复正常光照
	restore_normal_business_lighting()
	
	# 【新增】立即更新服务生外观
	if randmap_manager and randmap_manager.waiter_system:
		randmap_manager.waiter_system.update_waiter_appearance(true)
	
	fc.save_game(fc.save_num)
	
func _on_business_closed():
	add_msg(["通知","本日营业完全结束"])
	fc.play_se_fx("clean")
	# 【新增】先清空所有服务员的任务

	if randmap_manager and randmap_manager.customer_system:
		var cleared_waiting_count = 0
		# 倒序遍历，避免在删除时改变数组索引
		for i in range(fc.playerData.waiting_customers.size() - 1, -1, -1):
			var customer = fc.playerData.waiting_customers[i]
			if customer.status == "waiting":
				# 调用客人离开函数，并传入特殊原因，这样不会触发复杂的结账逻辑
				randmap_manager.customer_system._customer_leave(customer, "营业时间结束，不再接待")
				cleared_waiting_count += 1
		if cleared_waiting_count > 0:
			add_msg(["通知", "已送走 " + str(cleared_waiting_count) + " 桌排队的客人"])
		
	if randmap_manager and randmap_manager.waiter_system:
		randmap_manager.waiter_system.clear_all_tasks()
		randmap_manager.waiter_system.set_all_waiters_cleaning()
		randmap_manager.kitchen_system.abort_all_orders()    # 【新增】停止厨房制作
		randmap_manager.waiter_system.update_waiter_appearance(false)
	
	# ============================================================
	# 【核心修改】进行最终结算 (基于归属日)
	# ============================================================
	# 即使当前游戏日期已经变了 (例如从 2号 变到了 3号)，
	# 我们依然使用 current_business_day_id (也就是 2号) 进行结算
	var target_day = fc.playerData.current_business_day_id
	# 计算本周期的总成本
	var total_cost = fc.playerData.pay_dian + fc.playerData.pay_caigou
	# 调用结算逻辑
	_settle_daily_business_logic(
		target_day,                  # 结算给哪一天
		fc.playerData.pay_today,      # 营收
		total_cost,                   # 总成本 (电费+采购)
		fc.playerData.total_guest_now_day # 来店人数
	)
	
	#结算当前的状态
	check_new_state()
	
	# 切换到关门状态光照
	apply_closed_state()



# 修改 check_new_state 函数
func check_new_state():
	# ============================================================
	# 1. 汇总昨天的真实数据 (昨夜营收 + 今晨营收)
	# ============================================================
	# 注意：如果是跨天经营 (2号开店，3号关店)
	# pay_last_day 在午夜时暂存了 2号晚上的营收
	# pay_today 是 3号凌晨的营收
	# 两者相加才是 2号这一整天的营收
	var yesterdays_total_revenue = fc.playerData.pay_last_day + fc.playerData.pay_today
	
	# 同理，成本也需要汇总
	# 通常 pay_last_day 不包含成本，成本都在 pay_dian 里 (因为只在开店扣一次)
	# 但如果未来逻辑复杂，建议还是按下面的方式写，兼容性好
	var yesterdays_total_dian = fc.playerData.pay_dian
	var yesterdays_total_caigou = fc.playerData.pay_caigou
	var yesterdays_total_cost = yesterdays_total_dian + yesterdays_total_caigou
	
	# 计算昨日净利润
	var yesterdays_profit = yesterdays_total_revenue - yesterdays_total_cost

	# ============================================================
	# 2. 将昨天的数据存入 basedata 的顶层变量 (这就是"存进去")
	# ============================================================
	# 这样，下次开店时，UI 读取到的就是完整且准确的昨日数据
	fc.playerData.pay_last_day = yesterdays_total_revenue
	fc.playerData.pay_last_dian = yesterdays_total_dian
	fc.playerData.pay_last_caigou = yesterdays_total_caigou
	#fc.playerData.pay_last_day_profit = yesterdays_profit # 如果您有这个变量的话

	# ============================================================
	# 3. 清空今日累加器 (这就是"今天的清0")
	# ============================================================
	# 因为昨日数据已经存好并存档了，这里可以放心清空
	fc.playerData.pay_today = 0
	fc.playerData.pay_dian = 0
	fc.playerData.pay_caigou = 0

	# ============================================================
	# 4. 结算到月度/年度统计
	# ============================================================
	# 调用我们之前写好的结算函数，传入昨天的归属日
	_settle_daily_business_logic(
		fc.playerData.current_business_day_id, # 归属日 (例如 Day 2)
		yesterdays_total_revenue,      # 营收
		yesterdays_total_cost,         # 成本
		fc.playerData.total_guest_now_day # 人数
	)

	# ============================================================
	# 5. 员工与厨师升级 (只在这里执行)
	# ============================================================
	
	# 1. 服务员技能
	var skill=["点单引导","危机处理","顾客维系"]
	for i in fc.playerData.waiters:
		for k in 3:
			if i.skill_experience[k]==100:
				i.skill_experience[k]=0
				i.skills[k]+=0.5
				add_msg(["好事","服务员【%s】一直努力工作，%s能力提升了！"%[i.name,skill[k]]])
		
		if randi_range(0,4)==0:
			var linshi=randi_range(1,3)
			if linshi==1:
				i.speed+=1
				add_msg(["好事","服务员【%s】又成长了，速度提升！"%i.name])
			elif linshi==2:
				i.charm+=1
				add_msg(["好事","服务员【%s】又进步了，魅力提升！"%i.name])
			elif linshi==3:
				i.affinity+=1
				add_msg(["好事","服务员【%s】进步的很快，亲和力提升！"%i.name])
	
	# 2. 厨师能力结算逻辑
	for chef in fc.playerData.chefs:
		var cuisine_keys = chef.cuisines.keys()
		var has_skill_upgraded = false
		
		for k in range(cuisine_keys.size()):
			if chef.cuisines_experience[k] >= 100:
				chef.cuisines_experience[k] = 0
				var c_type = cuisine_keys[k]
				chef.cuisines[c_type] += 0.5
				has_skill_upgraded = true
				
				var c_name = randmap_manager.kitchen_system.get_cuisine_name(c_type)
				add_msg(["好事", "厨师【%s】勤学苦练，%s菜系等级提升到了 %.1f！" % [chef.name, c_name, chef.cuisines[c_type]]])
		
		if has_skill_upgraded and chef.cuisines.size() < 4:
			var all_cuisine_types = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
			var unknown_cuisines = []
			for t in all_cuisine_types:
				if not chef.cuisines.has(t):
					unknown_cuisines.append(t)
			
			if unknown_cuisines.size() > 0:
				var new_c_type = unknown_cuisines[randi() % unknown_cuisines.size()]
				chef.cuisines[new_c_type] = 0.5
				chef.cuisines_experience.append(0)
				var new_c_name = randmap_manager.kitchen_system.get_cuisine_name(new_c_type)
				add_msg(["好事", "厨师【%s】触类旁通，竟然领悟了新的菜系：%s！" % [chef.name, new_c_name]])

		if randi_range(0, 4) == 0:
			var attr_roll = randi_range(1, 3)
			if attr_roll == 1:
				chef.cooking_skill += 1
				add_msg(["好事", "厨师【%s】的基本功更加扎实了，厨艺提升了！" % chef.name])
			elif attr_roll == 2:
				chef.innovation_skill += 1
				add_msg(["好事", "厨师【%s】在收工时灵感迸发，创新能力提升了！" % chef.name])
			elif attr_roll == 3:
				chef.speed_skill += 1
				add_msg(["好事", "厨师【%s】干活越来越利索，烹饪速度提升了！" % chef.name])

	# ============================================================
	# 6. 存档与排名
	# ============================================================
	# 这里的利润已经在上面 yesterdays_profit 计算过了
	paihang.calculate_daily_ranking()
	fc.save_game(fc.save_num)

	


# =================================================================
# 3. 新增：辅助计算函数 (针对采购)
# ================================================================
# 辅助函数：计算开店时的初始采购成本
# 假设逻辑：补满所有菜单的库存到 10 份
func _calculate_initial_procurement_cost() -> float:
	var total_cost = 0.0
	# 遍历所有菜单
	for dish_id_str in fc.playerData.MYdisheslist:
		var target_stock=fc.playerData.Total_dishes_list[dish_id_str]["need_stock"]
		var price=fc.playerData.Total_dishes_list[dish_id_str]["price"]
		total_cost += price * target_stock
		fc.playerData.Total_dishes_list[dish_id_str]["stock"]=target_stock
			
	return total_cost


# 【新增】中途补货函数


# 修改 _on_business_state_changed 函数
func _on_business_state_changed(new_state: TimeSystem.BusinessState):
	# 更新按钮UI状态
	if button_ui:
		button_ui.change_state(fc.playerData.is_open)
	
	match new_state:
		TimeSystem.BusinessState.OPEN:
			_on_business_opened()
			
		TimeSystem.BusinessState.CLOSING:
			# 这里处理"打烊中"的视觉效果，比如关掉招牌灯，但不关大灯
			_on_business_closing() 
			
		# 将原本报错的几行统一合并到这里
		# 【修复】当进入午休或正式关门时，必须调用清理逻辑和光照切换
		TimeSystem.BusinessState.LUNCH_BREAK, TimeSystem.BusinessState.CLOSED:
			_on_business_closed() # 调用清理逻辑（包含任务清理、外观更新等）
			apply_closed_state()  # 切换光照

func _on_business_closing():
	# 1. 立即发布通知
	add_msg(["通知", "营业时间结束，正在进行打烊清场。"])
	fc.play_se_fx("close")
	# 2. 【核心修复】立即清理所有还没进店（状态为 waiting）的客人
	if randmap_manager and randmap_manager.customer_system:
		#var cleared_count = 0
		# 倒序遍历，安全删除
		for i in range(fc.playerData.waiting_customers.size() - 1, -1, -1):
			var customer = fc.playerData.waiting_customers[i]
			if customer.status == "waiting":
				# 直接调用客人离开，传入特殊原因，不计入差评，仅清理数据和节点
				randmap_manager.customer_system._customer_leave(customer, "营业结束")
				#cleared_count += 1
	
	## 4. 确保按钮状态更新
	#if button_ui:
		#button_ui.change_state(false)



# =================================================================
# 4. 环境与渲染修正
# =================================================================

func _correct_all_rotations():
	# 这个函数现在作为最后的保险
	if not randmap_manager: return
	
	await get_tree().process_frame
	
	# 修正家具
	if randmap_manager.furniture_holder:
		for item_root in randmap_manager.furniture_holder.get_children():
			for child in item_root.get_children():
				if child is Node3D:
					# 确保所有家具子节点垂直 (X=0)
					if child.rotation_degrees.x != 0:
						child.rotation_degrees.x = 0
					
					if child.has_node("pic"):
						var pic = child.get_node("pic")
						if pic.rotation_degrees.x != 0:
							pic.rotation_degrees.x = 0

	# 修正服务生
	if randmap_manager.waiter_system:
		for waiter_data in randmap_manager.waiter_system.placed_waiters_data:
			var node_ref = waiter_data.get("node_ref")
			if is_instance_valid(node_ref):
				node_ref.rotation_degrees = Vector3(0, 0, 0)

func _setup_camera_for_map():
	# 使用 RandmapManager 暴露的节点引用
	var floor_gridmap = randmap_manager.grid_map_node 
	if not floor_gridmap: return

	var used_cells = floor_gridmap.get_used_cells()
	if used_cells.is_empty(): return

	var min_bound = Vector3(1e9, 0, 1e9)
	var max_bound = Vector3(-1e9, 0, -1e9)

	for cell in used_cells:
		min_bound.x = min(min_bound.x, cell.x)
		min_bound.z = min(min_bound.z, cell.z)
		max_bound.x = max(max_bound.x, cell.x)
		max_bound.z = max(max_bound.z, cell.z)

	var map_center_cell = (min_bound + max_bound) / 2.0
	var map_center_world = floor_gridmap.to_global(floor_gridmap.map_to_local(map_center_cell))

	var map_size_x = max_bound.x - min_bound.x + 1
	var map_size_z = max_bound.z - min_bound.z + 1
	var map_size = max(map_size_x, map_size_z)

	var min_map_size = 5.0
	var max_map_size = 120.0
	var min_camera_pos = Vector3(0, 60.0, 100.0)
	var max_camera_pos = Vector3(5, 80.0, 158.0)

	var t = inverse_lerp(log(min_map_size), log(max_map_size), log(map_size))
	t = clamp(t, 0.0, 1.0)

	var final_offset = lerp(min_camera_pos, max_camera_pos, t)
	camera.global_position = map_center_world + final_offset
	camera.rotation_degrees = Vector3(lerp(-25.0, -30.0, t), 0, 0)
	camera.fov = lerp(25.0, 30.0, t)

# =================================================================
# 5. UI 与 窗口管理
# =================================================================

func _on_window_close_requested():
	close_all_popup_windows()
	get_tree().quit()

# 初始化弹窗系统
func _init_popup_system():
	popup_windows.clear()
	popup_scenes.clear()
	# 预加载所有弹窗场景
	for key in POPUP_SCENE_PATHS:
		var path = POPUP_SCENE_PATHS[key]
		if ResourceLoader.exists(path):
			popup_scenes[key] = load(path)
		else:
			print("⚠️ 弹窗场景不存在: ", key, " -> ", path)

# 打开弹窗窗口
func open_popup_window(popup_key: String) -> Window:
	# 1. 检查是否已经打开，如果打开了就聚焦它，不再创建
	for window in popup_windows:
		if is_instance_valid(window) and window.get_meta("popup_key", "") == popup_key:
			print("窗口 ", popup_key, " 已经打开，激活现有窗口")
			window.grab_focus()
			window.move_to_foreground()
			return window
	
	# 2. 检查场景资源
	if not popup_scenes.has(popup_key) or popup_scenes[popup_key] == null:
		print("❌ 未找到弹窗场景资源: ", popup_key)
		return null
	
	# 3. 创建新窗口 (Window 节点)
	var popup_window = Window.new()
	popup_window.name = "PopupWindow_" + popup_key
	popup_window.title = "Menu"
	
	# 设置窗口属性：确保它是独立的
	popup_window.size = Vector2i(1280, 960)
	popup_window.borderless = true
	popup_window.transparent = true
	popup_window.always_on_top = true
	popup_window.unfocusable = false 
	popup_window.exclusive = false # 关键：不要设为独占，否则其他窗口会失去响应
	popup_window.transient = false # 关键：不要设为临时，让它独立于主窗口
	
	# 标记 Key
	popup_window.set_meta("popup_key", popup_key)
	
	# 4. 添加到根节点 (成为主窗口的兄弟节点，互不干扰)
	get_tree().root.add_child(popup_window)
	
	# 5. 实例化内容
	var scene_instance = popup_scenes[popup_key].instantiate()
	popup_window.add_child(scene_instance)
	
	# 6. 居中设置 (计算正确的位置)
	_center_popup_window(popup_window)
	
	# 7. 记录并显示
	popup_windows.append(popup_window)
	popup_window.close_requested.connect(_on_popup_window_closed.bind(popup_window))
	
	popup_window.show()
	popup_window.grab_focus()
	
	return popup_window

# 居中显示弹窗窗口
func _center_popup_window(window: Window):
	# 获取当前主窗口所在的屏幕ID
	var main_window_id = get_window().get_window_id()
	var screen_id = DisplayServer.window_get_current_screen(main_window_id)
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
	
	# 确保新窗口也在同一个屏幕上
	window.current_screen = screen_id
	
	# 计算居中坐标
	var center_x = screen_rect.position.x + (screen_rect.size.x - window.size.x) / 2
	var center_y = screen_rect.position.y + (screen_rect.size.y - window.size.y) / 2
	
	# 应用位置
	window.position = Vector2i(center_x, center_y)

# 关闭单个弹窗
func _close_popup_window(window: Window):
	if is_instance_valid(window):
		popup_windows.erase(window)
		window.queue_free()

# 信号回调
func _on_popup_window_closed(window: Window):
	_close_popup_window(window)

# 关闭所有弹窗 (ESC键或退出时调用)
func close_all_popup_windows():
	# 倒序遍历删除，防止数组索引错误
	for i in range(popup_windows.size() - 1, -1, -1):
		_close_popup_window(popup_windows[i])
	popup_windows.clear()

# 关闭弹窗窗口
func close_popup_window(popup_key: String):
	for i in range(popup_windows.size() - 1, -1, -1):
		var window = popup_windows[i]
		if window.get_meta("popup_key") == popup_key:
			_close_popup_window(window)
			break

# 检查弹窗是否已打开
func is_popup_open(popup_key: String) -> bool:
	for window in popup_windows:
		if window.get_meta("popup_key") == popup_key:
			return true
	return false

# 获取指定弹窗的窗口实例
func get_popup_window(popup_key: String) -> Window:
	for window in popup_windows:
		if window.get_meta("popup_key") == popup_key:
			return window
	return null

# 设置所有UI窗口
func setup_all_ui_windows():
	#print("开始创建所有UI窗口...")
	
	# 初始化数组
	ui_windows = []
	is_ui_draggings = []
	ui_drag_start_poses = []
	ui_window_start_poses = []
	
	# 预加载场景
	ui_scenes = []
	
	# 【修改】尝试加载四个场景
	var scene_paths = [UI_SCENE_PATH_1, UI_SCENE_PATH_2, UI_SCENE_PATH_3, UI_SCENE_PATH_4]
	
	for path in scene_paths:
		if ResourceLoader.exists(path):
			ui_scenes.append(load(path))
		else:
			print("⚠️ 场景文件不存在: ", path)
			ui_scenes.append(null)  # 添加null作为占位符
	
	# 【修改】创建四个UI窗口
	for i in range(scene_paths.size()): # 使用 scene_paths.size() 更灵活
		var success = await setup_single_ui_window(i)
		if not success:
			print("❌ 创建第", i+1, "个UI窗口失败")
			continue
	
	# 等待所有窗口初始化完成
	await get_tree().process_frame
	
	# 排列前三个窗口的位置
	arrange_ui_windows_horizontal()
	
	# 【关键新增】为第四个窗口设置特殊的位置和拖动
	if ui_windows.size() > 3:
		_arrange_special_ui_window() # 定位第四个窗口
		_setup_special_window_dragging(ui_windows[3], 3) # 设置特殊拖动
	
	#print("✅ 所有UI窗口创建完成")

# 设置单个UI窗口
func setup_single_ui_window(index: int) -> bool:
	# 检查是否有预加载的场景
	if index >= ui_scenes.size() or ui_scenes[index] == null:
		print("❌ 第", index+1, "个UI场景未预加载或为空")
		return false

	var ui_scene = ui_scenes[index]
	var ui_instance = ui_scene.instantiate()
	
	if index == 0:
		main_info_ui_window = ui_instance
	if index == 1:
		info_ui = ui_instance
	if index == 2:
		msgshow = ui_instance
	if index == 3:
		button_ui = ui_instance
	
	# 设置为无边框窗口
	ui_instance.borderless = true
	ui_instance.transparent = true
	ui_instance.always_on_top = true
	ui_instance.unfocusable = false
	ui_instance.title = "UI窗口" + str(index + 1)
	
	# 添加到场景树
	get_tree().root.add_child(ui_instance)
	
	# 等待窗口初始化
	await get_tree().process_frame
	
	# 【关键修改】第四个窗口（索引为3）不使用通用拖动设置
	if index != 3:
		_setup_window_dragging(ui_instance, index)
	
	# 添加到数组
	ui_windows.append(ui_instance)
	is_ui_draggings.append(false)
	ui_drag_start_poses.append(Vector2i())
	ui_window_start_poses.append(Vector2i())
	
	# 显示窗口
	ui_instance.show()
	
	return true

# 水平排列所有UI窗口的位置
func arrange_ui_windows_horizontal():
	# 获取屏幕信息
	var main_window = get_window()
	var screen_id = DisplayServer.window_get_current_screen(main_window.get_window_id())
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
	
	# 窗口之间的间距
	var margin_bottom = 100  # 距离底部边缘的距离（给3D窗口留出空间）
	var margin_between = 20  # 窗口之间的水平间距
	
	# 计算总宽度
	var total_width = 0
	var window_sizes = []
	
	for i in range(ui_windows.size()):
		var window_instance = ui_windows[i]
		if not window_instance:
			continue
			
		# 获取窗口大小（如果没有设置，使用默认值）
		var win_size = window_instance.size
		if win_size.x == 0 or win_size.y == 0:
			win_size = Vector2i(400, 300)  # 默认大小
		
		window_sizes.append(win_size)
		total_width += win_size.x
		
		# 如果不是最后一个窗口，加上间距
		if i < ui_windows.size() - 1:
			total_width += margin_between
	
	# 如果总宽度超过屏幕宽度，等比缩放
	if total_width > screen_rect.size.x * 0.9:
		var scale_factor = (screen_rect.size.x * 0.9) / total_width
		for i in range(window_sizes.size()):
			window_sizes[i] = Vector2i(
				int(window_sizes[i].x * scale_factor),
				window_sizes[i].y
			)
		total_width = int(total_width * scale_factor)
	
	# 计算起始X位置（水平居中）
	var start_x = screen_rect.position.x + (screen_rect.size.x - total_width) / 2
	var current_x = start_x
	
	# 设置每个窗口的位置
	for i in range(ui_windows.size()):
		var window_instance = ui_windows[i]
		if not window_instance:
			continue
			
		var win_size = window_sizes[i]
		
		# 计算垂直位置（屏幕底部，但要确保在3D窗口上方）
		var target_y = screen_rect.position.y + screen_rect.size.y - win_size.y - margin_bottom
		
		# 设置窗口位置
		window_instance.position = Vector2i(current_x, target_y)
		
		# 为下一个窗口更新X位置
		current_x += win_size.x + margin_between

## main_game_sc.gd

func _setup_window_dragging(window_instance: Window, window_index: int):
	if not window_instance: return
	
	# 尝试查找标题栏
	var title_bar = window_instance.get_node_or_null("TitleBar")
	if not title_bar:
		title_bar = window_instance.get_node_or_null("Panel/TitleBar")
	
	if title_bar:
		title_bar.gui_input.connect(_on_ui_window_input.bind(window_index))
	else:
		# 【修改】如果没有标题栏，不要创建 Overlay！
		# 而是直接找到窗口内容的根节点（通常是第一个子 Control），连接它的输入事件
		for child in window_instance.get_children():
			if child is Control:
				# 确保它是背景层，并且能接收鼠标
				if child.mouse_filter == Control.MOUSE_FILTER_IGNORE:
					child.mouse_filter = Control.MOUSE_FILTER_PASS
				
				# 连接信号 (防止重复连接)
				if not child.gui_input.is_connected(_on_ui_window_input):
					child.gui_input.connect(_on_ui_window_input.bind(window_index))
				
				# 只需要连接最外层的一个即可
				break

# UI窗口输入事件处理（支持多窗口）
func _on_ui_window_input(event: InputEvent, window_index: int):
	if window_index < 0 or window_index >= ui_windows.size():
		return
		
	var window_instance = ui_windows[window_index]
	if not window_instance:
		return
	
	_handle_drag_input_for_window(event, window_instance, window_index)

# 处理拖动输入 (带调试打印)
func _handle_drag_input_for_window(event: InputEvent, window_instance: Window, window_index: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				#print("--- 鼠标点击窗口 ", window_index, " ---")
				# 检查是否点到了滚动条或按钮
				var blocking_node = _get_interactive_control_under_mouse(window_instance)
				
				if blocking_node:
					print("🛑 拖动被阻止！鼠标在交互控件上: ", blocking_node.name, " 类型: ", blocking_node.get_class())
					return # 是交互控件，不拖动
				else:
					pass
					#print("✅ 允许拖动！鼠标下没有交互控件。")
				
				# 否则，开始拖动
				is_ui_draggings[window_index] = true
				ui_drag_start_poses[window_index] = DisplayServer.mouse_get_position()
				ui_window_start_poses[window_index] = window_instance.position
			else:
				# 鼠标松开，停止拖动
				if is_ui_draggings[window_index]:
					pass
					#print("⏹ 停止拖动窗口 ", window_index)
				is_ui_draggings[window_index] = false
	
	elif event is InputEventMouseMotion and is_ui_draggings[window_index]:
		# 移动窗口
		var current_mouse_pos = DisplayServer.mouse_get_position()
		var delta = current_mouse_pos - ui_drag_start_poses[window_index]
		window_instance.position = ui_window_start_poses[window_index] + delta

# 【核心修复】获取鼠标下的交互控件 (返回具体的节点，方便调试)
func _get_interactive_control_under_mouse(window: Window) -> Node:
	# 获取鼠标在窗口内的位置
	var mouse_pos = window.get_mouse_position()
	# print("  鼠标在窗口内位置: ", mouse_pos)
	
	# 从窗口的根节点开始检查
	for child in window.get_children():
		if child is Control and child.visible:
			# 将鼠标位置转换到子节点空间 (假设子节点全屏覆盖，通常不需要减 position，但为了保险)
			var result = _check_controls_recursive(child, mouse_pos)
			if result:
				return result
	return null

# 【新增】辅助函数：检查鼠标是否悬停在交互控件上
# 检查鼠标是否悬停在【需要独占输入】的控件上
func _is_mouse_over_interactive_control(window: Window) -> bool:
	var mouse_pos = window.get_mouse_position()
	
	# 从窗口的根节点开始检查
	for child in window.get_children():
		if child is Control and child.visible:
			# 坐标转换：鼠标在窗口内的坐标 -> 相对于子节点的坐标
			var child_local_pos = mouse_pos - child.position
			if _check_controls_recursive(child, child_local_pos):
				return true
	return false

# 递归检查函数
func _check_controls_recursive(node: Node, local_mouse_pos: Vector2) -> bool:
	if not node is Control or not node.visible:
		return false
		
	# 1. 优先检查子节点（因为子节点在父节点上层）
	# 倒序遍历，确保先检查最上层的子节点
	var children = node.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child = children[i]
		if child is Control and child.visible:
			# 计算鼠标相对于这个子节点的位置
			var child_pos = local_mouse_pos - child.position
			# 递归
			if _check_controls_recursive(child, child_pos):
				return true
	
	# 2. 如果子节点都没命中，检查当前节点自己
	# 必须鼠标在当前节点范围内
	if node.get_rect().has_point(local_mouse_pos):
		# 【核心修复】只有以下类型的控件会阻止拖动
		if node is BaseButton: return true      # 按钮、复选框等
		if node is ScrollBar: return true       # 滚动条滑块/轨道
		if node is Slider: return true          # 滑动条
		#if node is LineEdit: return true        # 输入框
		#if node is TextEdit: return true        # 文本框
		#if node is Tree: return true            # 树状列表
		#if node is ItemList: return true        # 物品列表
		#if node is RichTextLabel and node.selection_enabled: return true # 可选中的文本
		
		# 注意：Panel, VBoxContainer, Label, TextureRect 等
		# 在这里都会返回 false，因此允许拖动！
		
	return false

# =================================================================
# 6. 环境与光照系统
# =================================================================

func move_window_to_bottom_right_sync():
	var window_id = get_window().get_window_id()
	var screen_id = DisplayServer.window_get_current_screen(window_id)
	var screen_rect = DisplayServer.screen_get_usable_rect(screen_id)
	
	# 不要修改窗口大小！使用当前窗口大小
	var win_size = get_window().size
	var margin = Vector2i(20, 20)
	
	# 如果窗口大小为0（可能是初始状态），使用默认大小
	if win_size.x == 0 or win_size.y == 0:
		win_size = Vector2i(800, 600)  # 使用与项目设置一致的默认大小

	var target_pos = screen_rect.position + screen_rect.size - win_size - margin
	get_window().position = target_pos

# 更新鼠标穿透的函数
func update_mouse_passthrough():
	# 只在标记点都有效时更新穿透
	if not marker_tl or not marker_tr or not marker_br or not marker_bl:
		return
		
	var point_1 = camera.unproject_position(marker_tl.global_position)
	var point_2 = camera.unproject_position(marker_tr.global_position)
	var point_3 = camera.unproject_position(marker_br.global_position)
	var point_4 = camera.unproject_position(marker_bl.global_position)
	var polygon = PackedVector2Array([point_1, point_2, point_3, point_4])
	if polygon.size() >= 3:
		DisplayServer.window_set_mouse_passthrough(polygon)

# 配置地图灯光
func _configure_maplight():
	if not maplight:
		return
	
	# 【修改】确保maplight是OmniLight3D
	if maplight is OmniLight3D:
		# 设置OmniLight3D特定属性
		maplight.omni_range = maplight_range
		maplight.omni_attenuation = maplight_attenuation
		maplight.shadow_enabled = maplight_shadow_enabled
		
		# 默认白天状态
		maplight.light_color = maplight_day_color
		maplight.light_energy = maplight_day_energy
		maplight.visible = false

# 应用白天状态
func apply_day_state():
	sun_light.light_color = day_sun_color
	sun_light.light_energy = day_sun_energy
	world_env.environment.ambient_light_color = day_ambient_color
	world_env.environment.ambient_light_energy = day_ambient_energy
	
	# 【修改】白天时关闭地图灯光
	if maplight:
		# 确保配置正确
		if maplight is OmniLight3D:
			_configure_maplight()
		
		maplight.visible = false
		maplight.light_color = maplight_day_color
		maplight.light_energy = maplight_day_energy

# 应用夜晚状态
func apply_night_state():
	sun_light.light_color = night_sun_color
	sun_light.light_energy = night_sun_energy
	world_env.environment.ambient_light_color = night_ambient_color
	world_env.environment.ambient_light_energy = night_ambient_energy
	
	# 【修改】夜晚时开启地图灯光
	if maplight:
		# 确保配置正确
		if maplight is OmniLight3D:
			_configure_maplight()
		
		maplight.visible = true
		maplight.light_color = maplight_night_color
		maplight.light_energy = maplight_night_energy

# 切换日夜
func toggle_day_night():
	if is_night:
		transition_to_night()
	else:
		transition_to_day()

# 过渡到白天
func transition_to_day():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sun_light, "light_color", day_sun_color, 2.0)
	tween.tween_property(sun_light, "light_energy", day_sun_energy, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_color", day_ambient_color, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_energy", day_ambient_energy, 2.0)
	
	# 【修改】渐变关闭地图灯光
	if maplight:
		# 确保配置正确
		if maplight is OmniLight3D:
			_configure_maplight()
		
		tween.tween_property(maplight, "light_energy", maplight_day_energy, 2.0)
		tween.tween_property(maplight, "light_color", maplight_day_color, 2.0)
		# 在动画结束后隐藏灯光
		await get_tree().create_timer(1).timeout  # 稍微提前一点
		if not is_night:  # 确保我们仍然在白天状态
			maplight.visible = false

# 过渡到夜晚
func transition_to_night():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sun_light, "light_color", night_sun_color, 2.0)
	tween.tween_property(sun_light, "light_energy", night_sun_energy, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_color", night_ambient_color, 2.0)
	tween.tween_property(world_env.environment, "ambient_light_energy", night_ambient_energy, 2.0)
	
	# 【修改】渐变开启地图灯光
	if maplight:
		# 确保配置正确
		if maplight is OmniLight3D:
			_configure_maplight()
		
		maplight.visible = true  # 立即显示但能量从0开始
		maplight.light_energy = 0.0  # 从0开始渐变
		tween.tween_property(maplight, "light_energy", maplight_night_energy, 2.0)
		tween.tween_property(maplight, "light_color", maplight_night_color, 2.0)

# =================================================================
# 7. 输入处理
# =================================================================

func _input(event):
	if event.is_action_pressed("ui_cancel"): 
		get_tree().quit()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				drag_start_position = event.position

	if event is InputEventMouseMotion and dragging:
		var new_pos = DisplayServer.mouse_get_position() - Vector2i(drag_start_position)
		get_window().position = new_pos
		
		# 窗口移动后，需要更新鼠标穿透区域
		update_mouse_passthrough()

	# 添加快捷键支持（ESC关闭所有弹窗）
	if event.is_action_pressed("ui_cancel"):
		if not popup_windows.is_empty():
			close_all_popup_windows()
			return  # 阻止退出游戏

# =================================================================
# 8. 第四个窗口特殊处理
# =================================================================

# 定位第四个窗口到指定位置
func _arrange_special_ui_window():
	if ui_windows.size() < 4:
		print("⚠️ UI窗口数量不足，无法定位第四个窗口。")
		return
		
	var button_window = ui_windows[3]
	var leftmost_window = ui_windows[0] # 第一个窗口
	
	# 确保窗口大小有效
	var button_win_size = button_window.size
	if button_win_size.x == 0 or button_win_size.y == 0:
		button_win_size = Vector2i(400, 200) # 给一个默认大小

	# 计算目标位置：对齐第一个窗口的左上角，并在其上方
	var spacing = 10 # 窗口之间的间距
	var target_pos = Vector2i(
		leftmost_window.position.x,
		leftmost_window.position.y - button_win_size.y - spacing
	)
	
	button_window.position = target_pos

# 为第四个窗口设置特殊的拖动（通过命名节点）
func _setup_special_window_dragging(window_instance: Window, window_index: int):
	if not window_instance:
		return

	# 【关键】通过节点名获取内部的拖动区域
	# 请确保你的 button_show_ui.tscn 场景中，作为背景的 Control 节点被命名为 "DragArea"
	var drag_area = window_instance.get_node_or_null("DragArea") as Control
	
	if drag_area:
		drag_area.gui_input.connect(_on_special_ui_window_input.bind(window_index))
	else:
		pass

# 第四个窗口的输入事件处理
func _on_special_ui_window_input(event: InputEvent, window_index: int):
	# 复用原有的拖动逻辑，但只针对第四个窗口
	_handle_drag_input_for_window(event, ui_windows[window_index], window_index)

# =================================================================
# 9. 时间系统辅助函数
# =================================================================

# 修改暂停/继续函数
func toggle_time_pause():
	if time_system:
		if time_system.is_time_paused:
			time_system.resume_time()
		else:
			time_system.pause_time()
		


# 更新主界面上的时间显示
func _update_time_display():
	if not main_info_ui_window:
		return
	
	# 假设你的 main_info_ui 场景中有一个名为 "TimeLabel" 的 Label 节点
	var time_label = main_info_ui_window.time
	if time_label:
		if time_system:
			time_label.text = time_system._minutes_to_time_string(time_system.current_game_minutes)

# 检查日夜切换
func _check_day_night_transition():
	if not time_system:
		return
		
	var night_start_minutes = time_system._time_string_to_minutes("18:30")
	if time_system.current_game_minutes >= night_start_minutes and not is_night:
		is_night = true
		toggle_day_night()
	elif time_system.current_game_minutes < night_start_minutes and is_night:
		is_night = false
		toggle_day_night()

# =================================================================
# 10. 辅助函数
# =================================================================




# 获取客人生成位置
func get_customer_spawn_position() -> Vector3:
	if not bg:
		#print("❌ bg节点不存在")
		return Vector3.ZERO
	
	# 搜索bg节点下所有Sprite3D类型的子节点
	var sprite3d_nodes = []
	for child in bg.get_children():
		if child is Sprite3D and child.visible:
			sprite3d_nodes.append(child)
	
	if sprite3d_nodes.is_empty():
		return Vector3.ZERO
	
	# 如果有多个背景层，通常取第一个
	var sprite_node = sprite3d_nodes[0]
	
	# 在该Sprite3D节点下查找名为"pos"的Marker3D节点
	var pos_marker = sprite_node.get_node_or_null("pos")
	
	if not pos_marker:
		return Vector3.ZERO
	
	# 返回全局坐标
	return pos_marker.global_position

# 添加消息
func add_msg(showmsg):
	if msgshow:
		msgshow.add_new_msg(showmsg)

# 辅助函数：将 "HH:MM" 字符串转换为从00:00开始的总分钟数
func _time_string_to_minutes(time_str: String) -> int:
	var parts = time_str.split(":")
	var hour = parts[0].to_int()
	var minute = parts[1].to_int()
	return hour * 60 + minute

# 同时保留 _notification 作为备用
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 备用处理，防止信号连接失败
		_on_window_close_requested()

# 在 main_game_sc.gd 中添加这些函数

# 应用关门状态光照
func apply_closed_state():
	var tween = create_tween().set_parallel(true)
	
	# 渐变到关门状态光照
	tween.tween_property(sun_light, "light_color", closed_sun_color, 1.5)
	tween.tween_property(sun_light, "light_energy", closed_sun_energy, 1.5)
	tween.tween_property(world_env.environment, "ambient_light_color", closed_ambient_color, 1.5)
	tween.tween_property(world_env.environment, "ambient_light_energy", closed_ambient_energy, 1.5)
	
	# 调整地图灯光
	if maplight and maplight is OmniLight3D:
		_configure_maplight()
		maplight.light_color = closed_maplight_color
		maplight.light_energy = closed_maplight_energy
		maplight.visible = true  # 关门时也开启，但较弱
	
	#print("🌑 切换到关门状态光照")

# 应用午休状态光照
func apply_lunch_state():
	var tween = create_tween().set_parallel(true)
	
	# 渐变到午休状态光照
	tween.tween_property(sun_light, "light_color", lunch_sun_color, 1.5)
	tween.tween_property(sun_light, "light_energy", lunch_sun_energy, 1.5)
	tween.tween_property(world_env.environment, "ambient_light_color", lunch_ambient_color, 1.5)
	tween.tween_property(world_env.environment, "ambient_light_energy", lunch_ambient_energy, 1.5)
	
	# 调整地图灯光
	if maplight and maplight is OmniLight3D:
		_configure_maplight()
		maplight.light_color = lunch_maplight_color
		maplight.light_energy = lunch_maplight_energy
		maplight.visible = true
	
	#print("🌤️ 切换到午休状态光照")

# 恢复正常营业光照（根据当前日夜状态）
func restore_normal_business_lighting():
	var tween = create_tween().set_parallel(true)
	
	# 根据当前日夜状态恢复光照
	if is_night:
		# 恢复夜晚光照
		tween.tween_property(sun_light, "light_color", night_sun_color, 1.5)
		tween.tween_property(sun_light, "light_energy", night_sun_energy, 1.5)
		tween.tween_property(world_env.environment, "ambient_light_color", night_ambient_color, 1.5)
		tween.tween_property(world_env.environment, "ambient_light_energy", night_ambient_energy, 1.5)
		
		# 恢复夜晚地图灯光
		if maplight and maplight is OmniLight3D:
			_configure_maplight()
			maplight.light_color = maplight_night_color
			maplight.light_energy = maplight_night_energy
			maplight.visible = true
	else:
		# 恢复白天光照
		tween.tween_property(sun_light, "light_color", day_sun_color, 1.5)
		tween.tween_property(sun_light, "light_energy", day_sun_energy, 1.5)
		tween.tween_property(world_env.environment, "ambient_light_color", day_ambient_color, 1.5)
		tween.tween_property(world_env.environment, "ambient_light_energy", day_ambient_energy, 1.5)
		
		# 白天关闭地图灯光
		if maplight and maplight is OmniLight3D:
			_configure_maplight()
			maplight.visible = false
	
	#print("☀️ 恢复正常营业光照")

func force_close_restaurant():
	if not fc.playerData.is_open:
		return
	
	
	if bird_system:
		bird_system.set_system_active(false)
	fc.play_se_fx("clean")
	# 立即切换到彻底关门状态（跳过 CLOSING 状态）
	fc.playerData.is_open = false
	
	if time_system:
		time_system._set_business_state(TimeSystem.BusinessState.CLOSING, "玩家手动关门", true)
	
	if randmap_manager and randmap_manager.waiter_system:
		randmap_manager.waiter_system.clear_all_tasks()
		
	# 【关键修复】1. 先强制清场，让所有客人离开并重置桌子
	if randmap_manager and randmap_manager.customer_system:
		var cleared_count = randmap_manager.customer_system.clear_all_customers()
		if cleared_count > 0:
			add_msg(["通知", "强制关门，已送走 " + str(cleared_count) + " 桌客人，并清空了所有餐桌。"])
	
	# 【关键修复】2. 然后清理所有服务员的任务（此时客人已不存在，任务会被安全清理）
	if randmap_manager and randmap_manager.waiter_system:
		randmap_manager.waiter_system.set_all_waiters_cleaning()
		randmap_manager.waiter_system.update_waiter_appearance(false)
	
#


# 添加检查客人是否全部离店的函数
# 在 main_game_sc.gd 中
func all_customers_left() -> bool:
	if fc.playerData.waiting_customers.is_empty():
		return true
	
	# 检查是否还有任何“已经在店里”的客人
	for customer in fc.playerData.waiting_customers:
		# 状态不是 waiting 且还没离开的，都算店里有人
		if customer.status != "waiting":
			return false
	
	# 如果全是 waiting（理论上在 closing 已经被清了），则可以关门
	return true


# 手动开门函数
func manually_open_restaurant():
	# 1. 检查时间
	var current_time = fc.playerData.now_time
	if not fc.is_within_business_hours(current_time):
		add_msg(["通知", "当前时间不在营业范围内"])
		return
	
	
	# 2. 设置营业状态
	fc.playerData.is_open = true
	
	# 3. 更新时间系统状态
	if time_system:
		time_system._set_business_state(TimeSystem.BusinessState.OPEN, "玩家手动开门", true)
		
	# 4. 恢复服务员工作状态
	if randmap_manager and randmap_manager.waiter_system:
		randmap_manager.waiter_system.set_all_waiters_working()
	
	# 5. 恢复光照
	restore_normal_business_lighting()
	
	# 6. 更新按钮UI
	if button_ui:
		button_ui.change_state(true)
	
	# 7. 播放音效
	fc.play_se_fx("opendoor")
	if bird_system:
		bird_system.set_system_active(true)


# 检查自定义logo
func check_pic():
	var save_path = "user://logo_0.png"
	if not FileAccess.file_exists(save_path):
		return false
	else:
		return true

# 清理所有UI窗口并退出到主菜单
func cleanup_and_exit_to_main():
	#print("🔄 开始清理3D场景并退出到主菜单...")
	

	
	# 2. 关闭所有UI窗口
	close_all_ui_windows()
	
# 关闭所有UI窗口
func close_all_ui_windows():
	#print("🔒 关闭所有UI窗口...")
	for window in ui_windows:
		if is_instance_valid(window):
			window.queue_free()
	
	ui_windows.clear()
	is_ui_draggings.clear()
	ui_drag_start_poses.clear()
	ui_window_start_poses.clear()
	


func check_stock():
	for i in fc.playerData.MYdisheslist:
		if fc.dish_data_manager.get_dish_stock(i)==0:
			var dishname = fc.playerData.Total_dishes_list[i]["name"]
			add_msg(["通知","%s本日没有库存了，请进货。" % dishname])

	
# 在你的主场景脚本中 (例如 main_game_sc.gd) 添加以下函数

func check_deployment_status():
	var waiter_system = randmap_manager.waiter_system
	var furniture_system = randmap_manager.furniture_system

	# ------------------------------------------------
	# 第一部分：检查所有服务员，是否有人没配置到地图上
	# ------------------------------------------------
	if not fc.playerData.waiters.is_empty():
		var unplaced_waiters = []
		
		for waiter in fc.playerData.waiters:
			# 检查该服务员是否在 WaiterSystem 中已放置
			# 注意：这里假设 WaiterSystem 有 is_waiter_placed(id) 方法
			if waiter_system and waiter_system.is_waiter_placed(waiter.id):
				continue
			else:
				# 如果没有找到记录，说明未配置
				unplaced_waiters.append(waiter)
		
		if unplaced_waiters.is_empty():
			pass
			#("✅ 检查结果：所有服务员均已配置到地图上。")
		else:
			#print("❌ 警告：以下服务员未配置到地图上，无法正常工作！")
			for w in unplaced_waiters:
				# 这里使用 print 输出，你可以自行替换为 UI 提示
				add_msg(["通知","服务员【%s】未配置位置，无法正常工作！" % [w.name]])
				#print("   - 未配置员工：%s (ID: %s)" % [w.name, w.id])
	else:
		pass

	#print("------------------------------------------------")

	# ------------------------------------------------
	# 第二部分：检查所有需要配置人员的家具，是否没有配置服务员
	# ------------------------------------------------
	if furniture_system:
		var unassigned_furniture = []
		
		# 遍历所有已放置的家具
		for item in furniture_system.placed_furniture_data:
			var limit = item.get("limit", "无")
			
			# 排除不需要专职分配的类型
			# 逻辑参考：main_management.gd 中的排除项 ("传菜口", "迎客位", "无")
			if limit != "无" and limit != "传菜口" and limit != "迎客位":
				var node_ref = item.get("node_ref")
				if node_ref:
					# 检查该家具是否分配了服务员
					var assigned_id = furniture_system.get_assigned_waiter_id(node_ref)
					if assigned_id == "":
						unassigned_furniture.append(item)
		
		if unassigned_furniture.is_empty():
			pass
			#print("✅ 检查结果：所有需要人员的家具均已分配服务员。")
		else:
			#print("❌ 警告：以下家具未配置负责的服务员！")
			for item in unassigned_furniture:
				# 获取家具名称
				var item_id = item.get("ID", "")
				# 通过全局配置表读取名字
				var item_cfg = fc.get_row_from_csv_data("itemData", "ID", item_id)
				var item_name = item_cfg.get("itemtype")
				add_msg(["通知","家具【%s】未配置负责的服务员！" % [item_name]])
				
				#print("   - 未分配家具：%s (类型限制: %s)" % [item_name, limit])

		#print("❌ 错误：无法找到家具系统。")

	#print("========== 检查结束 ==========")



# ============================================================
# 【新增】日结算专用函数 (不修改原有函数，直接操作数据)
# 功能：跨月判断、记录营收/成本、记录来店人数、更新总数据
# ============================================================
# day_id: 业务归属的日期 (例如 31号)
# revenue: 营业额
# cost: 总成本
# guest_count: 来店人数


# 在 main_game_sc.gd 中修改 _settle_daily_business_logic 函数

func _settle_daily_business_logic(target_day: int, revenue: int, cost: int, guest_num: int):
	# ============================================================
	# 【修改】调用新的结算函数
	# ============================================================
	# 这个新函数会自动处理跨月逻辑，并更新所有相关字典和总数
	fc.playerData.record_daily_settlement(target_day, revenue, cost, guest_num)
	
	# ============================================================
	# 其余逻辑保持不变
	# ============================================================
	# 计算利润 (用于显示或本地存储)
	fc.playerData.pay_today_profit = revenue - cost
