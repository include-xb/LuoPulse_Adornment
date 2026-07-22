extends MeshInstance3D


# Release (红键): 不可触摸, 触摸即判定为 Lost


var gameplay: Node2D = null

var index: int = 0

var type: String = "release"

var time: int = 0

var duration: int = 0

var column: int = 0

var a: float = 0.0

var is_added: bool = false

var is_removed: bool = false

var is_judged: bool = false

var _was_in_judging_area: bool = false


func _process(delta: float) -> void:
	if gameplay == null:
		return

	var mt: float = gameplay.master_time

	position.z = Global.note_speed * (mt - float(time)) / 1000.0

	if Global.is_autoplay:
		autoplay(mt)
		pass

	var time_offset: float = mt - float(time)
	var in_judging_area: bool = time_offset >= float(Global.START_JUDGE_TIME) and time_offset <= float(Global.END_JUDGE_TIME)

	if in_judging_area and not _was_in_judging_area and not is_removed:
		is_added = true
		Global.judging_area.append(self)
		pass

	if not in_judging_area and _was_in_judging_area and not is_removed:
		# 离开判定区间未被触碰 → 自动通过 (不触发丢失)
		_pass_through()
		pass

	_was_in_judging_area = in_judging_area

	if time_offset > float(Global.END_JUDGE_TIME) and not is_removed:
		_pass_through()
		pass
	pass


func is_judgable() -> bool:
	return not is_removed and not is_judged


func lose(master_time: float) -> void:
	# 被触摸 → Lost
	if is_removed or is_judged:
		return

	is_judged = true
	is_removed = true
	Global.lost += 1
	a = 0.0
	_update_accuracy()
	_remove_from_judging()
	explode()
	pass


func _pass_through() -> void:
	# 未被触摸安全通过
	if is_removed:
		return
	is_removed = true
	_remove_from_judging()
	explode()
	pass


func _update_accuracy() -> void:
	Global.total_judged += 1
	var n: int = Global.total_judged
	Global.accuracy = (Global.accuracy * float(n - 1) + a) / float(n)
	pass


func _remove_from_judging() -> void:
	var idx: int = Global.judging_area.find(self)
	if idx >= 0:
		Global.judging_area.remove_at(idx)
		pass
	pass


func explode() -> void:
	queue_free()
	pass


func autoplay(master_time: float) -> void:
	# 自动播放: Release 不触摸, 安全通过
	if master_time >= float(time) and not is_removed:
		_pass_through()
		pass
	pass
