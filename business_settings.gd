extends Control
@onready var TimeSettingsPanel=$Panel/base/NinePatchRect/TimeSettingsPanel
@onready var shownpc=[
	$Panel/base/NinePatchRect2/npc,
	$Panel/base/NinePatchRect2/npc2
]
@onready var change_cloth_next=$Panel/base/NinePatchRect2/next
@onready var change_cloth_last=$Panel/base/NinePatchRect2/last

@onready var change_music_name=$Panel/base/music/name
@onready var change_music_next=$Panel/base/music/next
@onready var change_music_last=$Panel/base/music/last

@onready var change_cesuo_time=$Panel/base/cesuo/time
@onready var change_cesuo_next=$Panel/base/cesuo/next
@onready var change_cesuo_last=$Panel/base/cesuo/last

@onready var change_kongtiao_wendu=$Panel/base/kongtiao/wendu


@onready var securityItem=[
	$Panel/base/safe/VBoxContainer/CheckBox,
	$Panel/base/safe/VBoxContainer/CheckBox2,
	$Panel/base/safe/VBoxContainer/CheckBox3,
	$Panel/base/safe/VBoxContainer/CheckBox4,
]

@onready var mymoney=$Panel/base/NinePatchRect4/money
var safe_item_money = 50
var music_id=-99
func _ready():
	#保险费
	# 【新增】确保窗口居中
	fc._ensure_window_centered()
	
	fc.playerData.step="第9步"
	securityItem[0].text = "店铺财产保险 （每年支付￥"+fc.format_money(safe_item_money*fc.playerData.saved_map.size()*2)+")"
	
	for i in 4:
		securityItem[i].toggled.connect(change_safe.bind(i))
		change_safe(fc.playerData.safe_item[i],i)
		
	

	var check=0
	var wendu =[18,22,26,30]
	for i in 4:
		if wendu[i]==fc.playerData.ac_temp:
			check=i
			break
	change_kongtiao_wendu.value = check
	
	show_npc_cloth()
	mymoney.text = fc.format_money(fc.playerData.money)
	
	change_cloth_next.pressed.connect(change_cloth.bind(1))
	change_cloth_last.pressed.connect(change_cloth.bind(-1))
	
	change_cesuo_next.pressed.connect(change_cesuo.bind(1))
	change_cesuo_last.pressed.connect(change_cesuo.bind(-1))
	
	change_music_next.pressed.connect(change_music.bind(1))
	change_music_last.pressed.connect(change_music.bind(-1))
	
	var mu_list=[
		"welcome",
		"Bossa",
		"Modern",
		"cafe",
		"Fingertips",
		"Orchestral",
		"heku",
	]
	for i in 7:
		if mu_list[i]==fc.playerData.BGMmusic:
			music_id=i
			break
	
	
	show_music()
	
	GuiTransitions.show("yiban")
	await GuiTransitions.show_completed
	
	
func show_music():
	var listshow=[
		"欢迎来到我的餐厅",
		"桑巴热浪",
		"都市脉搏",
		"慵懒午后",
		"微风弦语",
		"闲庭絮语",
		"何苦做游戏",
	]
	var mu_list=[
		"welcome",
		"Bossa",
		"Modern",
		"cafe",
		"Fingertips",
		"Orchestral",
		"heku",
	]
	if music_id==-99:
		change_music_name.text="当前没有播放音乐"
	else:
		fc.playerData.BGMmusic = mu_list[music_id]
		change_music_name.text=listshow[music_id]
		
	if music_id!=-99:
		fc.now_play_mu=true
		fc.play_mu(fc.playerData.BGMmusic)
	else:
		fc.now_play_mu=false
		fc.stop_mu()
	
func change_music(change):
	if music_id==-99:
		music_id=0
	else:
		music_id+=change
		if music_id==7:
			music_id=-99
		elif music_id<0:
			music_id=6
	
	show_music()
	
	
	
	
	
func show_cesuo_info():
	change_cesuo_time.text = str(fc.playerData.toilet_clean_time)+" 小时"
	
	
func change_cesuo(change):
	fc.playerData.toilet_clean_time+=change

	if fc.playerData.toilet_clean_time==7:
		fc.playerData.toilet_clean_time=1
	elif fc.playerData.toilet_clean_time==0:
		fc.playerData.toilet_clean_time=6
		
	
	show_cesuo_info()
	
	
	
	
func show_npc_cloth():
	shownpc[0].texture= load("res://pic/npc/fuwuyuan/waiter_type"+str(fc.playerData.clothtype)+"_man.png")
	shownpc[1].texture= load("res://pic/npc/fuwuyuan/waiter_type"+str(fc.playerData.clothtype)+"_woman.png")
	
	
func change_cloth(change):
	fc.playerData.clothtype+=change
	if fc.playerData.clothtype==4:
		fc.playerData.clothtype=1
		
	if fc.playerData.clothtype==0:
		fc.playerData.clothtype=3
		
	show_npc_cloth()
	
	
	
func change_safe(if_toggled,num):#安保措施
	fc.playerData.safe_item[num]=if_toggled
	


func _on_yes_pressed():
	TimeSettingsPanel._on_confirm_pressed()#确认时间安排
	fc.save_game(fc.save_num)
	if fc.playerData.from_main_game==true:
		get_tree().change_scene_to_file("res://sc/main_game_sc.tscn")
	else:
		get_tree().change_scene_to_file("res://sc/ready_open.tscn")
