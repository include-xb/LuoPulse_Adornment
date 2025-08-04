extends CanvasLayer


@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	color_rect.self_modulate.a = 0
	color_rect.visible = false
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
