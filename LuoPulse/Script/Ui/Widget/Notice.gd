extends RichTextLabel


var timer: float = 0


func _ready() -> void:
	self.modulate.a = 0
	born()
	pass


func _process(delta: float) -> void:
	timer += delta
	if timer >= Global.NOTICE_LIFETIME:
		die()
		pass
	pass


func born() -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 1, 0.2)
	await tween.finished
	pass


func die() -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.4)
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.4)
	tween.parallel().tween_property(self, "custom_minimum_size:y", 0, 0.4)
	await tween.finished
	self.queue_free()
	pass
