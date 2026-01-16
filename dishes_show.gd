# dish_show.gd
extends Control

# 假设你的场景里有这些节点
@onready var texture_rect: TextureRect = $show/pic

# 【核心函数】用于接收并显示数据
func setup(base_id: String):
	# 1. 设置名字
	$NinePatchRect/name.text = fc.playerData.Total_dishes_list[base_id]["name"]
	# 2. 设置价格
	$show2/price.text = "¥ %d" % int(fc.playerData.Total_dishes_list[base_id]["price"])
	
	$NinePatchRect/num.text="x %d" % int(fc.playerData.Total_dishes_list[base_id]["stock"])
	
	# 3. 设置图片 (你需要一个根据image_id加载图片的逻辑)
	
	var image_path = "res://pic/cai/" + str(int(fc.playerData.Total_dishes_list[base_id]["base_id"])) + ".png" # 假设图片路径是这样
	if ResourceLoader.exists(image_path):
		$show/pic.texture = load(image_path)
