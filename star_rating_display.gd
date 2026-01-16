extends Control

# --- 节点引用 ---
@onready var star_container = $StarContainer
@onready var star_textures = [
	$StarContainer/Star1,
	$StarContainer/Star2,
	$StarContainer/Star3,
	$StarContainer/Star4,
	$StarContainer/Star5
]

# --- 图片资源 ---
@export var full_star_texture: Texture2D  # lv 图片
@export var half_star_texture: Texture2D  # halflv 图片
@export var empty_star_texture: Texture2D # nolv 图片

# --- 配置 ---
@export var star_spacing: int = 0  # 星星之间的间距
@export var star_size: Vector2 = Vector2(40, 40)  # 每个星星的大小

func _ready():
	setup_stars()


func setup_stars():
	# 设置HBoxContainer属性
	star_container.add_theme_constant_override("separation", star_spacing)
	
	# 设置每个星星的属性
	for i in range(star_textures.size()):
		var star = star_textures[i]
		star.custom_minimum_size = star_size
		star.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# 初始显示空星
		star.texture = empty_star_texture

# --- 核心函数：设置星级 ---
func set_rating(rating: float):
	# 限制范围在0-5之间
	rating = clamp(rating, 0.0, 5.0)
	
	for i in range(5):
		var star = star_textures[i]
		var star_position = i + 1  # 当前星星的位置（1-5）
		
		if rating >= star_position:
			# 满星
			star.texture = full_star_texture
		elif rating >= star_position - 0.5:
			# 半星
			star.texture = half_star_texture
		else:
			# 空星
			star.texture = empty_star_texture
	


# --- 便捷函数 ---
func set_0_star(): set_rating(0.0)
func set_1_star(): set_rating(1.0)
func set_1_5_star(): set_rating(1.5)
func set_2_star(): set_rating(2.0)
func set_2_5_star(): set_rating(2.5)
func set_3_star(): set_rating(3.0)
func set_3_5_star(): set_rating(3.5)
func set_4_star(): set_rating(4.0)
func set_4_5_star(): set_rating(4.5)
func set_5_star(): set_rating(5.0)

# --- 动画效果（可选） ---
func animate_rating(new_rating: float, duration: float = 0.5):
	var current_rating = get_current_rating()
	var tween = create_tween()
	
	# 从当前值动画到新值
	tween.tween_method(
		func(value): set_rating(value),
		current_rating,
		new_rating,
		duration
	)
	
	

# --- 获取当前星级 ---
func get_current_rating() -> float:
	var rating = 0.0
	for i in range(5):
		var star = star_textures[i]
		if star.texture == full_star_texture:
			rating += 1.0
		elif star.texture == half_star_texture:
			rating += 0.5
	return rating
