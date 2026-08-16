extends NoteBase


# Release (红键): 不可触摸, 触摸即判定为 Lost


var type: String = "release"


# 被触摸 → Lost
func lose(master_time: float) -> void:
	if is_removed or is_judged:
		return

	is_judged = true
	is_removed = true
	Global.lost += 1
	Global.combo = 0
	a = 0.0

	if gameplay and gameplay.has_method("show_judgment_feedback"):
		gameplay.show_judgment_feedback(0, "lost", column)
		pass

	_update_accuracy()
	_remove_from_judging()
	explode()
	pass


# 离开判定区间未被触碰 → 自动通过 (不触发丢失)
func _on_miss(master_time: float) -> void:
	_pass_through()
	pass


# 自动播放: Release 不触摸, 安全通过
func _autoplay(master_time: float) -> void:
	if master_time >= float(time) and not is_removed:
		_pass_through()
		pass
	pass


func _pass_through() -> void:
	if is_removed:
		return
	is_removed = true
	_remove_from_judging()
	explode()
	pass
