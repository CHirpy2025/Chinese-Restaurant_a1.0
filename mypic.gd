extends Node

@onready var file_dialog = $FileDialog
@onready var texture_rect = $TextureRect # 可选：用于预览缩放后的图片


# 导出变量，允许在检查器中设置目标尺寸
@export var target_size: Vector2i = Vector2i(240, 240) # 默认尺寸为 256x256
var save_num = 0 #存档id


signal have_pic
const SAVED_IMAGE_NAME = "logo" # 保存的文件名

func _ready():
	# 连接 FileDialog 的信号
	file_dialog.file_selected.connect(_on_file_selected)
	# 确保 FileDialog 可以选择图片
	_setup_file_dialog()

func _setup_file_dialog():
	file_dialog.clear_filters()
	file_dialog.add_filter("*.png,*.jpg,*.jpeg,*.webp,*.bmp", "Images")
	# 如果需要限制访问目录，可以设置 Access 属性
	# file_dialog.access = FileDialog.ACCESS_FILESYSTEM # 或 ACCESS_RESOURCES

# 当用户点击按钮时调用，打开文件选择对话框
func _on_SelectImageButton_pressed():
	file_dialog.popup_centered_ratio(0.8) # 弹出对话框 [[1]]

# 当 FileDialog 选择了文件时调用 [[1]]
func _on_file_selected(file_path: String):
	#print("Selected file: ", file_path)
	# 开始加载、缩放和保存流程
	_load_resize_and_save_image(file_path)

# 核心函数：加载图片，按比例缩放，保存到 user://
func _load_resize_and_save_image(file_path: String):
	# 1. 加载图片文件到 Image 对象 [[3]]
	var img = Image.load_from_file(file_path)
	#var err = img.load(file_path)
	#if err != OK:
		#print("Error loading image from path '%s': " % file_path, error_string(err))
		## 可以在这里显示错误提示给用户
		#return
#
	#print("Original image size: ", img.get_size())

	# 2. 计算缩放后的尺寸（保持宽高比）
	var original_size: Vector2i = img.get_size()
	var scaled_size: Vector2i = _calculate_scaled_size(original_size, target_size)
	#print("Target size: ", target_size)
	#print("Calculated scaled size (maintaining aspect ratio): ", scaled_size)

	# 3. 执行缩放 [[3]]
	# 注意：Image.resize 会直接修改原图对象
	# 如果需要保留原图，应先 duplicate()
	# var img_to_resize = img.duplicate()
	img.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_BILINEAR) # 使用双线性插值 [[3]]
	#print("Image resized.")

	# 4. 定义保存路径 (user:// 目录) [[4]]
	var save_path = "user://" + SAVED_IMAGE_NAME+"_"+str(save_num)+".png"
	#print("Saving resized image to: ", save_path)

	# 5. 保存缩放后的 Image [[3]]
	# 你可以根据需要选择保存格式：save_png, save_jpg, save_webp
	# PNG 无损但文件可能较大，JPG 有损但文件小
	var save_err = img.save_png(save_path) # 这里以 PNG 为例
	# var save_err = img.save_jpg(save_path, 0.9) # JPG 示例，质量 90%
	if save_err == OK:
		#print("Image resized and saved successfully!")
		# 可选：更新 TextureRect 显示缩放后的图片
		var resized_texture = ImageTexture.create_from_image(img)
		texture_rect.texture = resized_texture
		texture_rect.expand = true
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# 可以在这里触发一个信号或调用其他函数来通知操作完成
		# 例如，加载并显示保存的图片
		_load_and_display_saved_image()
		
	else:
		pass
		#print("Error saving resized image: ", error_string(save_err))
		# 可以在这里显示错误提示给用户

# 辅助函数：计算保持宽高比的缩放尺寸
# 给定原始尺寸 original 和目标限制尺寸 limit，
# 返回一个新尺寸，该尺寸 fit 在 limit 内，且宽高比与 original 相同。
func _calculate_scaled_size(original: Vector2i, limit: Vector2i) -> Vector2i:
	var original_vec: Vector2 = Vector2(original.x, original.y)
	var limit_vec: Vector2 = Vector2(limit.x, limit.y)

	# 计算缩放比例，取宽和高分别缩放后较小的那个，确保图片 fit 在限制内
	var scale_ratio: float = min(limit_vec.x / original_vec.x, limit_vec.y / original_vec.y)
	
	# 应用缩放比例并转换为整数
	var new_size: Vector2 = original_vec * scale_ratio
	# 使用 floor 或 round 取整，这里用 round 更常见
	return Vector2i(int(round(new_size.x)), int(round(new_size.y)))

# 加载并显示保存的图片
func _load_and_display_saved_image():
	var save_path = "user://" + SAVED_IMAGE_NAME+"_"+str(save_num)+".png"
	
	# 不再使用 ResourceLoader.exists 检查，直接尝试加载
	
	# 1. 创建一个新的 Image 对象
	var loaded_image = Image.new()
	
	# 2. 直接从 user:// 路径加载图片数据到 Image 对象
	var load_err = loaded_image.load(save_path)
	
	if load_err == OK:
		#print("Image file loaded successfully from: ", save_path)
		# 3. 从加载的 Image 创建 ImageTexture
		var loaded_texture = ImageTexture.create_from_image(loaded_image)
		
		emit_signal("have_pic",true)
		# 4. 将其应用到 TextureRect 上显示
		texture_rect.texture = loaded_texture
		texture_rect.expand = true
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		#print("Saved resized image loaded and displayed using Image.load().")
	else:
		pass
		# 即使文件存在，加载也可能因格式等问题失败
		#print("Failed to load image from '%s'. Error: %s" % [save_path, error_string(load_err)])
		# 可以在这里添加 UI 提示
	

# 新增函数：删除保存的图片
func delete_saved_image() -> bool:
	var save_path = "user://" + SAVED_IMAGE_NAME+"_"+str(save_num)+".png"
	#print("--- Delete Image Attempt ---")
	#print("Target full save path: ", save_path)
	#print("Resolved user directory: ", OS.get_user_data_dir())
	
	# 2. 检查文件是否真的存在
	if not FileAccess.file_exists(save_path):
		#print("File check: File DOES NOT EXIST at ", save_path)
		# 如果文件不存在，清除显示并返回 true
		texture_rect.texture = load("res://pic/ui/logo2.png")
		
		emit_signal("have_pic",false)
		#print("Operation completed: File was not present.")
		return true
	else:
		pass

	# 3. 使用 DirAccess.remove_absolute 直接通过完整路径删除文件
	# 这是 Godot 4.x 中推荐的删除文件方式，避免了 open 目录可能带来的问题
	#print("Attempting to call DirAccess.remove_absolute() on: ", save_path)
	var err = DirAccess.remove_absolute(save_path) # <--- 关键修改在这里

	if err == OK:
		#print("SUCCESS: DirAccess.remove_absolute() executed without error.")
		texture_rect.texture = load("res://pic/ui/logo2.png")
		
		emit_signal("have_pic",false)
		#print("Operation completed: File deleted.")
		return true
	else:
		#print("FAILURE: DirAccess.remove_absolute() failed with error: ", error_string(err), " (Code: ", err, ")")
		# 即使失败也清除显示
		texture_rect.texture = null
		# 可以根据需要决定失败时返回 true 还是 false
		# 如果认为文件不存在也算成功，可以检查 err == ERR_FILE_NOT_FOUND
		return false # 操作失败
	
func check_pic():
	var save_path = "user://" + SAVED_IMAGE_NAME+"_"+str(save_num)+".png"
	if not FileAccess.file_exists(save_path):
		return false
	else:
		return true
