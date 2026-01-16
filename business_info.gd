extends Window

var checktip=preload("res://sc/show_keren_msg.tscn")
@onready var showcheck=$Control/base/showjiaju/show



func _ready():
	await get_tree().process_frame
	check_waiter_paths()
	


	GuiTransitions.show("busuiness")
	await GuiTransitions.show_completed

func add_new_msg(showmsg):
	var obj =null
	obj=checktip.instantiate()
	if showmsg[0]=="客人":
		obj.get_node("pic").texture = load("res://pic/ui/shengqi.png")
	elif showmsg[0]=="通知":
		obj.get_node("pic").texture = load("res://pic/ui/gantanhao.png")
	elif showmsg[0]=="好事":
		obj.get_node("pic").texture = load("res://pic/ui/gantanhao.png")
	elif showmsg[0]=="警告":
		obj.get_node("pic").texture = load("res://pic/ui/konghuang.png")
	elif showmsg[0]=="坏事":
		obj.get_node("pic").texture = load("res://pic/ui/kuqi.png")
		
	obj.get_node("txt").text = showmsg[1]
		
	showcheck.add_child(obj)
	
	
# business_info.gd

# 在你需要检查的地方（例如 _ready 或 show_info）
func check_waiter_paths():
	# 1. 获取 RandmapManager
	# 注意：在 main_game_sc 中，Randmap 在 MapHolder 下
	var main_scene = get_tree().get_current_scene()
	# 保护性获取节点
	var randmap_manager = main_scene.get_node_or_null("MapHolder/Randmap")
	
	if not randmap_manager or not randmap_manager.waiter_system:
		#print("警告: 无法在 business_info 中找到 WaiterSystem")
		return

	# 2. 调用检查函数
	var the_map_check = randmap_manager.waiter_system.check_all_waiters_paths()
	
	if the_map_check.size() > 0:
		for i in the_map_check:
			var waiter_name = i[0]
			var target_identifier = i[1]
			var target_name = ""
			
			# 确保转为字符串处理
			var target_str = str(target_identifier)
			
			# 【核心修复】先判断是否为数字字符串
			if target_str.is_valid_int():
				# 如果是数字（如 "1001"），转为 int 去查表
				# 这样避免了 String vs int 的比较报错
				var csv_data = fc.get_row_from_csv_data("itemData", "ID", int(target_str))
				
				if not csv_data.is_empty():
					target_name = csv_data["itemtype"]
				else:
					target_name = target_str
			else:
				# 如果不是数字（如 "迎客位"、"传菜口"）
				# 直接使用，绝对不要去查 itemData 表，否则会报错
				target_name = target_str
			
			add_new_msg(["服务员【%s】无法走到【%s】，请调整位置" % [waiter_name, target_name],"警告"])
