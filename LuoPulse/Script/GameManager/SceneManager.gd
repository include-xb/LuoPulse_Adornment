extends CanvasLayer


@onready var color_rect: ColorRect = $ColorRect
@onready var texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	color_rect.self_modulate.a = 0
	color_rect.visible = false
	texture_rect.visible = false
	texture_rect.modulate.a = 0
	pass


# 切换场景时使用的淡入淡出效果
func change_scene(path: String) -> void:
	color_rect.visible = true
	var tween: Tween = get_tree().create_tween()
	
	tween.stop()
	tween.tween_property(color_rect, "self_modulate:a", 1, 0.25)
	tween.play()
	await tween.finished
	
	get_tree().change_scene_to_file(path)
	
	tween.stop()
	tween.tween_property(color_rect, "self_modulate:a", 0, 0.25)
	tween.play()
	await tween.finished
	
	# 防止 ColorRect 遮挡其他节点
	color_rect.visible = false
	pass


func change_scene_with_img(path: String, img: ImageTexture) -> void:
	texture_rect.visible = true
	texture_rect.texture = img

	# 淡入图像 (1秒)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(texture_rect, "modulate:a", 1, 1)
	await tween.finished
	
	# 停留 1 秒
	await get_tree().create_timer(1.2).timeout
	
	# 切换场景
	get_tree().change_scene_to_file(path)

	# 淡出图像 (1秒)
	tween = get_tree().create_tween()
	tween.tween_property(texture_rect, "modulate:a", 0, 1)
	await tween.finished
	
	# 防止 TextureRect 遮挡其他节点
	texture_rect.visible = false
	pass
