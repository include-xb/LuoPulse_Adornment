extends Sprite2D


var is_long_press: bool = false

var is_judged: bool = false


func _physics_process(delta: float) -> void:
	self.position.y += Global.note_speed * delta
	
	if is_long_press and not is_judged:
		is_judged = true
		# 长度缩短
		# 累加时间
		pass
	if is_judged and not is_long_press:
		# 计算得分
		pass
	
	if Global.is_autoplay:
		# 自动播放
		autoplay()
		pass

	pass



# 自动播放
func autoplay() -> void:
	pass
