# show_guest_data.gd
extends Control

@onready var diancai_list = $showtip/list
@onready var npcshow = $npc
@onready var yali=$ProgressBar
@onready var state=$total2
#
@onready var showzhiye=$TextureRect2/AutoSizeLabel
@onready var showpic=$TextureRect
@onready var xiaofei=$total

@onready var pingjia=$show

var diancai_tip = preload("res://sc/diancai_tip.tscn")


func show_msg(customer):
	for i in npcshow.get_children():
		i.visible=false
	
	for i in diancai_list.get_children():
		i.queue_free()
		
	
	if customer.size()==0:
		return
	
	var guest = customer[0]
	var pic = fc.get_row_from_csv_data("guestData","type",guest["type"])["pic"]
	showzhiye.text = guest["type"]
	showpic.texture = load("res://pic/npc/keren/"+pic+".png")
	
	for i in guest["sex_age_list"].size():
		npcshow.get_child(i).visible=true
		var npc =guest["sex_age_list"][i]
		if npc[0]=="女":
			npcshow.get_child(i).get_node("sex").texture = load("res://pic/npc/keren/nv.png")
			
		npcshow.get_child(i).get_node("type").text = fc.get_row_from_csv_data("NpcBaseData","age",npc[1])["type"]

	
	state.text = guest["status"]
	yali.value = int(guest["satisfaction"])
	var total_money=0
	var cai_show_list=[]
	
	for i in guest["order_list"]:
		var check=false
		for k in cai_show_list:
			if k[0]==i:
				k[1]+=1
				check=true
		if check==false:
			cai_show_list.append([i,1])
	
	
	for i in cai_show_list:
		var obj = diancai_tip.instantiate()
		diancai_list.add_child(obj)
		obj.get_node("cai").text = i[0]
		obj.get_node("num").text = "x"+str(i[1])
		var showmoney = int(check_money(i[0]))*i[1]
		total_money+=showmoney
		obj.get_node("money").text = fc.format_money(showmoney)
	
	xiaofei.text = fc.format_money(total_money)
	pingjia.text=""
	pingjia.text+=guest["reviews"]["env"]["text"]
	pingjia.text+=guest["reviews"]["service"]["text"]
	pingjia.text+=guest["reviews"]["wait_time"]["text"]
	pingjia.text+=guest["reviews"]["taste"]["text"]
	pingjia.text+=guest["reviews"]["variety"]["text"]
	pingjia.text+=guest["reviews"]["price"]["text"]



func check_money(dish):
	var check
	for i in fc.playerData.Total_dishes_list:
		if fc.playerData.Total_dishes_list[str(i)].get("name")==dish:
			check=fc.playerData.Total_dishes_list[str(i)].get("price")
			break
	return check
			
