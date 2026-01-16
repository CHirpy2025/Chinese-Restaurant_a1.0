extends Node

# review_manager.gd
class_name ReviewManager

# ReviewManager.gd
# 新增：年龄性别权重表
class AgeGenderWeights:
	#"""
	#不同年龄性别对五个维度的权重偏好
	#权重总和为1.0
	#"""
	#
	static func get_weights(gender: String, age_group: int) -> Dictionary:
		#"""
		#获取权重配置
		#gender: "男", "女"
		#age_group: 1-5 (儿童,少年,青年,中年,老年)
		#"""
		var weight_tables = {
			"女": {
				1: {"taste": 0.30, "variety": 0.15, "price": 0.15, "service": 0.20, "environment": 0.20},  # 儿童
				2: {"taste": 0.25, "variety": 0.20, "price": 0.15, "service": 0.20, "environment": 0.20},  # 少年
				3: {"taste": 0.20, "variety": 0.20, "price": 0.15, "service": 0.25, "environment": 0.20},  # 青年
				4: {"taste": 0.25, "variety": 0.15, "price": 0.20, "service": 0.20, "environment": 0.20},  # 中年
				5: {"taste": 0.30, "variety": 0.10, "price": 0.25, "service": 0.20, "environment": 0.15}   # 老年
			},
			"男": {
				1: {"taste": 0.35, "variety": 0.15, "price": 0.10, "service": 0.15, "environment": 0.25},  # 儿童
				2: {"taste": 0.30, "variety": 0.20, "price": 0.15, "service": 0.15, "environment": 0.20},  # 少年
				3: {"taste": 0.25, "variety": 0.20, "price": 0.20, "service": 0.15, "environment": 0.20},  # 青年
				4: {"taste": 0.30, "variety": 0.15, "price": 0.25, "service": 0.10, "environment": 0.20},  # 中年
				5: {"taste": 0.35, "variety": 0.10, "price": 0.30, "service": 0.10, "environment": 0.15}   # 老年
			}
		}
		
		# 默认权重（中性）
		var default_weights = {"taste": 0.25, "variety": 0.20, "price": 0.20, "service": 0.20, "environment": 0.15}
		
		if weight_tables.has(gender) and weight_tables[gender].has(age_group):
			return weight_tables[gender][age_group]
		
		return default_weights
	
	static func get_group_average_weights(customer: CustomerData) -> Dictionary:
		#"""
		#计算一组客人的平均权重
		#customer.sex_age_list 格式: [["男", 1], ["女", 3], ...]
		#"""
		if not customer.sex_age_list or customer.sex_age_list.is_empty():
			# 默认权重
			return {"taste": 0.25, "variety": 0.20, "price": 0.20, "service": 0.20, "environment": 0.15}
		
		var total_weights = {"taste": 0.0, "variety": 0.0, "price": 0.0, "service": 0.0, "environment": 0.0}
		var member_count = 0
		
		for member_info in customer.sex_age_list:
			if member_info.size() >= 2:
				var gender = member_info[0]
				var age_group = member_info[1]
				
				var weights = get_weights(gender, age_group)
				
				# 累加权重
				for key in total_weights:
					total_weights[key] += weights.get(key, 0.0)
				
				member_count += 1
		
		# 计算平均值
		if member_count > 0:
			for key in total_weights:
				total_weights[key] /= member_count
		
		return total_weights

# 评价等级枚举 (5级制)
enum Level { 
	VERY_BAD = 1, # 非常差
	BAD = 2,      # 差
	NORMAL = 3,   # 一般
	GOOD = 4,     # 好
	VERY_GOOD = 5 # 非常好
}

# ========================================================
# 1. 环境评价 (装修风格)
# ========================================================
static func calculate_environment_review(customer: CustomerData, restaurant_styles: Dictionary, min_toilet_cleanliness: float):
	# --- 1. 计算【风格匹配度】得分 ---
	var style_score_diff = 0
	var focus_point = ""
	var max_impact = 0
	
	var preferences = {}
	var basedata = fc.get_row_from_csv_data("guestData", "type", customer.type)
	if basedata:
		for key in ["yanhuoqi", "shishangdu", "wenhuagan", "shushidu", "dutexing", "simixing"]:
			var key_cn = {"yanhuoqi":"烟火气","shishangdu":"时尚度","wenhuagan":"文化感","shushidu":"舒适度","dutexing":"独特性","simixing":"私密性"}[key]
			var req = basedata.get(key, 0)
			var shop_val = restaurant_styles.get(key_cn, 0)
			if req > 20:
				var diff = shop_val - req
				style_score_diff += diff
				if abs(diff) > max_impact:
					max_impact = abs(diff)
					focus_point = key_cn

	# 初始风格等级
	var style_level = Level.NORMAL
	var style_text = "装修风格中规中矩。"
	
	if style_score_diff >= 50:
		style_level = Level.VERY_GOOD
		style_text = "天哪！这里的%s简直完美契合我的品味！" % focus_point
	elif style_score_diff >= 20:
		style_level = Level.GOOD
		style_text = "店里的%s氛围很棒，坐着很舒服。" % focus_point
	elif style_score_diff <= -50:
		style_level = Level.VERY_BAD
		style_text = "装修风格太糟糕了，完全没有我想要的%s。" % focus_point
	elif style_score_diff <= -20:
		style_level = Level.BAD
		style_text = "装修感觉差点意思，尤其是缺乏%s。" % focus_point

	# --- 2. 计算【卫生/肮脏】影响 ---
	var dirty_val = fc.playerData.dirty
	var dirty_level = Level.VERY_GOOD # 默认干净是最高级
	var dirty_text = ""
	
	if dirty_val >= 150:
		dirty_level = Level.VERY_BAD
		dirty_text = "但店里简直脏得要命，到处是油腻感！"
		customer.satisfaction -= 40 # 肮脏直接重扣满意度
	elif dirty_val >= 100:
		dirty_level = Level.BAD
		dirty_text = "不过店里看起来有点脏，卫生细节很差。"
		customer.satisfaction -= 15 # 轻微扣除

	# --- 3. 【新增】厕所卫生专项评分 ---
	var toilet_level = Level.VERY_GOOD
	var toilet_text = ""
	
	if min_toilet_cleanliness < 20:
		toilet_level = Level.VERY_BAD
		toilet_text = "而且厕所脏得让人作呕，我一秒钟都不想多待！"
		customer.satisfaction -= 50
	elif min_toilet_cleanliness < 50:
		toilet_level = Level.BAD
		toilet_text = "但是厕所不太卫生，感觉很久没打扫了。"
		customer.satisfaction -= 15
	
	# --- 4. 【最终合成】短板效应 ---
	# 最终等级是 风格、全店肮脏、厕所卫生 三者的最小值
	# 只要有一个是 VERY_BAD，环境总评就是 VERY_BAD
	var final_level = min(style_level, min(dirty_level, toilet_level))
	
	# 合成最终文本
	var final_text = style_text # 初始为风格描述
	if dirty_level <= Level.BAD:
		final_text += dirty_text
	if toilet_text != "":
		final_text += toilet_text
		
	# 存储到结果
	if not customer.review_result: customer.review_result = {}
	customer.review_result["environment"] = {
		"level": final_level,
		"text": final_text
	}

# ========================================================
# 2. 价格评价 (性价比)
# ========================================================
static func calculate_order_reviews(customer: CustomerData, order_result):
	if not customer.review_result: customer.review_result = {}
	
	# --- 2.1 价格评价 ---
	var budget = float(customer.total_xiaofei)
	var cost = float(order_result.total_cost)
	var ratio = cost / budget if budget > 0 else 1.0
	
	var p_res = {"level": Level.NORMAL, "text": "价格还算公道，在预算范围内。"}
	
	# 预算越低越好，但太低(比如只点了白饭)可能会在Variety里扣分，这里只看钱包痛不痛
	if ratio <= 0.5:
		p_res.level = Level.VERY_GOOD
		p_res.text = "这也太便宜了！简直是做慈善，性价比爆表！"
	elif ratio <= 0.8:
		p_res.level = Level.GOOD
		p_res.text = "这顿饭比我预想的便宜，很划算。"
	elif ratio >= 1.4:
		p_res.level = Level.VERY_BAD
		p_res.text = "这就是抢钱！价格完全超出了我的承受能力！"
	elif ratio >= 1.1:
		p_res.level = Level.BAD
		p_res.text = "钱包大出血，比预算贵了不少..."
		
	customer.review_result["price"] = p_res
	
	# --- 2.2 菜品丰富度评价 ---
	var temp = customer.get("review_temp_data")
	var matched = temp.get("matched_tags", [])
	var missing = temp.get("missing_tags", [])
	var bad_variety = temp.get("bad_variety", false) # 是否因为单一被惩罚

	var v_res = {"level": Level.NORMAL, "text": "菜单种类还行，基本的都有。"}
	
	if matched.size() >= 2:
		v_res.level = Level.VERY_GOOD
		v_res.text = "菜单太丰富了！竟然同时有%s和%s，都是我的最爱！" % [matched[0], matched[1]]
	elif matched.size() == 1:
		v_res.level = Level.GOOD
		v_res.text = "不错，有我喜欢的%s，我很开心。" % matched[0]
	elif bad_variety: # OrderSystem 传来的严重单一标志
		v_res.level = Level.VERY_BAD
		v_res.text = "菜单极其单调，根本没东西可点！"
	elif missing.size() >= 1:
		v_res.level = Level.BAD
		v_res.text = "翻遍菜单也没找到想要的%s，有点失望。" % missing[0]
		
	customer.review_result["variety"] = v_res

# ========================================================
# 3. 服务评价 (服务员能力)
# ========================================================
static func calculate_service_review(customer: CustomerData, waiter_data):
	if not customer.review_result: customer.review_result = {}
	
	var s_res = {"level": Level.NORMAL, "text": "服务态度一般，没什么存在感。"}
	
	if waiter_data:
		var charm = waiter_data.charm # 0-100
		var retention_lv = waiter_data.skills.get("RETENTION", 0) # 0-10
		
		# 综合分：最高约 100 + 100 = 200
		var score = charm + (retention_lv * 10)
		
		if score >= 150:
			s_res.level = Level.VERY_GOOD
			s_res.text = "服务员%s是天使吗？这种帝王般的待遇太难得了！" % waiter_data.name
		elif score >= 110:
			s_res.level = Level.GOOD
			s_res.text = "服务员%s很贴心，随叫随到，态度很好。" % waiter_data.name
		elif score <= 30:
			s_res.level = Level.VERY_BAD
			s_res.text = "那个叫%s的服务员极其粗鲁！简直是在赶客！" % waiter_data.name
		elif score <= 60:
			s_res.level = Level.BAD
			s_res.text = "服务员%s板着个脸，叫半天都没反应。" % waiter_data.name
	else:
		s_res.level = Level.BAD
		s_res.text = "全程没看到服务员，感觉被冷落了。"
		
	customer.review_result["service"] = s_res

# ========================================================
# 4. 味道评价 (菜品质量)
# ========================================================
static func calculate_taste_review(customer: CustomerData):
	if not customer.review_result: customer.review_result = {}
	
	var temp = customer.get("review_temp_data")
	# 我们的新算法下，avg_quality 范围是 10 - 200
	var avg_quality = temp.get("avg_dish_quality", 85.0) 
	
	var t_res = {"level": Level.NORMAL, "text": "还行吧，味道中规中矩，能填饱肚子。"}
	
	if avg_quality >= 166:
		t_res.level = Level.VERY_GOOD
		t_res.text = "太好吃了！这就是传说中的神级料理吗？感觉灵魂都升华了！"
		customer.satisfaction += 50 # 满意度大增
	elif avg_quality >= 126:
		t_res.level = Level.GOOD
		t_res.text = "味道很赞，厨师对火候和调味的把控非常到位。"
		customer.satisfaction += 25
	elif avg_quality <= 50:
		t_res.level = Level.VERY_BAD
		t_res.text = "这做的什么东西？或者是生的或者是焦的，完全无法下咽！"
		customer.satisfaction -= 60 # 满意度暴跌
	elif avg_quality <= 85:
		t_res.level = Level.BAD
		t_res.text = "味道欠佳，感觉厨师今天心不在焉，水平很一般。"
		customer.satisfaction -= 20
	else:
		# 86 - 125 属于 NORMAL
		t_res.level = Level.NORMAL
		# 满意度不加不减
		
	customer.review_result["taste"] = t_res

# ========================================================
# 5. 综合打分计算 (核心算法 - 优化拉开差距版)
# ========================================================
# ReviewManager.gd
# 修改：calculate_final_score 函数
static func calculate_final_score(customer: CustomerData) -> int:
	# 【新增】检查是否为未进店客人
	if not customer.review_result:
		return calculate_no_table_score(customer)
	
	# 【新增】获取群体平均权重
	var group_weights = AgeGenderWeights.get_group_average_weights(customer)
	
	# 【新增】计算加权维度评分
	var weighted_total = 0.0
	var dimension_scores = {}
	
	# 1. 将等级转换为分数
	for dimension in ["taste", "variety", "price", "service", "environment"]:
		var review_item = customer.review_result.get(dimension, {})
		var level = review_item.get("level", Level.NORMAL)
		
		# 等级转分数
		var points = 0
		match level:
			Level.VERY_GOOD: points = 90
			Level.GOOD: points = 70
			Level.NORMAL: points = 50
			Level.BAD: points = 30
			Level.VERY_BAD: points = 10
		
		dimension_scores[dimension] = points
	
	# 2. 应用权重计算加权总分（满分450）
	for dimension in dimension_scores:
		var weight = group_weights.get(dimension, 0.2)  # 默认权重0.2
		weighted_total += dimension_scores[dimension] * weight
		

	# 3. 满意度修正（0-50分）
	var satisfaction_bonus = clamp(customer.satisfaction / 4.0, 0, 50)
	weighted_total += satisfaction_bonus
	
	
	var satisfaction_points = customer.satisfaction * 2.0
	# 4. 【新增】个人特质差异随机波动
	# 同一类型的客人也会有细微差异
	randomize()
	var personal_variance = 0.0
	
	# 根据客人的性别年龄构成增加随机性
	var gender_age_factor = 0.0
	for member_info in customer.sex_age_list:
		if member_info.size() >= 2:
			var gender = member_info[0]
			var age = member_info[1]
			
			# 不同人群的波动范围不同
			if gender == "女" and age >= 3:  # 成年女性
				gender_age_factor += randf_range(-5.0, 5.0)
			elif gender == "男" and age >= 4:  # 中年以上男性
				gender_age_factor += randf_range(-8.0, 8.0)
			else:  # 其他
				gender_age_factor += randf_range(-3.0, 3.0)
	
	# 人数越多，波动越趋于平均
	if customer.sex_age_list and customer.sex_age_list.size() > 0:
		gender_age_factor /= customer.sex_age_list.size()
	
	personal_variance = gender_age_factor
	
	# 5. 基础随机波动（保持一定意外性）
	var mood_swing = randi_range(-10, 10)
	
	# 6. 综合计算
	var final_score = weighted_total + personal_variance + mood_swing
	
	# 【新增】群体规模调整：人数越多，评分越稳定
	var group_size = customer.group_size
	var size_stability_factor = 1.0 - (0.05 * (group_size - 1))  # 每多一人，波动减少5%
	final_score = 250 + (final_score - 250) * clamp(size_stability_factor, 0.7, 1.0)
	
	# 确保在合理范围内
	return clampi(int(final_score), 1, 500)

# ReviewManager.gd
# 新增：处理未进店客人的评分
static func calculate_no_table_score(customer: CustomerData) -> int:
	var env_level = customer.review_result.get("environment", {"level": Level.NORMAL}).level
	var score = 10 + (env_level * 5) - (customer.pressure / 10.0)
	return clampi(int(score), 1, 50)
	
# ReviewManager.gd
# 新增：温度对满意度的影响
static func apply_temperature_effects(customer: CustomerData, order_result = null):
	var original_satisfaction = customer.satisfaction
	
	# 1. 空调温度影响
	var ac_temp = fc.playerData.get("ac_temp")
	if ac_temp != 26:
		# 每偏差1度减少0.5%满意度
		var temp_diff = abs(ac_temp - 26)
		var ac_penalty = original_satisfaction * (temp_diff * 0.005)
		customer.satisfaction -= ac_penalty
		
		# 记录影响
		if not customer.review_temp_data:
			customer.review_temp_data = {}
		customer.review_temp_data["ac_penalty"] = ac_penalty
	
	# 2. 天气温度影响（如果有订单）
	if order_result and order_result.selected_dishes:
		var weather_info = fc.weather_system.get_current_date_and_weather()
		if weather_info and weather_info.has("temperature"):
			var outdoor_temp = weather_info["temperature"]
			
			# 检查是否有热食或冷食
			var has_hot_dish = false
			var has_cold_dish = false
			
			for dish_id in order_result.selected_dishes:
				var dish_info = fc.dish_data_manager.get_dish_full_info(dish_id)
				var tags = dish_info.get("tags", [])
				
				if "热食" in tags or "汤类" in tags:
					has_hot_dish = true
				if "冷食" in tags or "凉菜" in tags:
					has_cold_dish = true
			
			# 温度影响
			var weather_effect = 0.0
			
			if outdoor_temp < 16:  # 寒冷天气
				if has_hot_dish:
					weather_effect = original_satisfaction * 0.10  # +10%
				else:
					weather_effect = -original_satisfaction * 0.15  # -15%
					
			elif outdoor_temp > 28:  # 炎热天气
				if has_cold_dish:
					weather_effect = original_satisfaction * 0.08   # +8%
				else:
					weather_effect = -original_satisfaction * 0.12  # -12%
			
			customer.satisfaction += weather_effect
			
			# 记录影响
			if not customer.review_temp_data:
				customer.review_temp_data = {}
			customer.review_temp_data["weather_effect"] = weather_effect
			customer.review_temp_data["outdoor_temp"] = outdoor_temp

# --- 2. 时间评价 (新增) ---
# 由 OrderingSystem 在上菜时调用
static func calculate_wait_time_review(customer: CustomerData, wait_seconds: float):
	if not customer.review_result: customer.review_result = {}
	
	var res = {"level": Level.NORMAL, "text": "上菜速度还可以。"}
	
	# 评价标准：每道菜平均等待时间 (假设每道菜 > 20秒算慢)
	var dish_count = customer.get_meta("order_result").selected_dishes.size()
	var time_per_dish = wait_seconds / max(1, dish_count)
	
	if wait_seconds < 15: # 极速
		res.level = Level.VERY_GOOD
		res.text = "上菜神速！我还没刷完手机就端上来了。"
		customer.satisfaction += 30
	elif time_per_dish < 20: # 快速
		res.level = Level.GOOD
		res.text = "上菜挺快的，服务效率很高。"
		customer.satisfaction += 15
	elif wait_seconds > 60 or time_per_dish > 40: # 极慢
		res.level = Level.VERY_BAD
		res.text = "等了半天都不上菜，我的肚子都叫得全店都能听见了！"
		customer.satisfaction -= 50
	elif wait_seconds > 40: # 较慢
		res.level = Level.BAD
		res.text = "这菜做得也太慢了，等到花儿都谢了。"
		customer.satisfaction -= 25
		
	customer.review_result["wait_time"] = res
