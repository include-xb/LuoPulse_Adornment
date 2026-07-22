extends MeshInstance3D


# Heart (心键): 类似 tap, 判定后触发特殊效果
# 设计文档: 触发 ECG 动画背景 + 扰乱接下来 4 个音符的列映射


var gameplay: Node2D = null

var index: int = 0

var type: String = "heart"

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
		_lose()
		pass

	_was_in_judging_area = in_judging_area

	if time_offset > float(Global.END_JUDGE_TIME) and not is_removed:
		_lose()
		pass
	pass


func is_judgable() -> bool:
	return not is_removed and not is_judged


func judge(master_time: float) -> void:
	if is_removed or is_judged:
		return

	var time_offset: int = int(master_time - float(time))
	var abs_offset: int = abs(time_offset)

	if abs_offset <= Global.HARMONIOUS_TIME:
		Global.harmonious += 1
		a = 1.0
		pass
	elif abs_offset <= Global.SYMPATHETIC_TIME:
		Global.sympathetic += 1
		a = 0.7
		pass
	elif abs_offset <= Global.AWARE_TIME:
		Global.aware += 1
		a = 0.5
		pass
	else:
		Global.lost += 1
		a = 0.0
		pass

	_finish_judge()
	# TODO: 触发 ECG 动画 + 扰乱后续 4 个音符的列映射
	pass


func lose(master_time: float) -> void:
	_lose()
	pass


func _lose() -> void:
	if is_removed:
		return
	is_removed = true
	Global.lost += 1
	a = 0.0
	_update_accuracy()
	_remove_from_judging()
	explode()
	pass


func _finish_judge() -> void:
	is_judged = true
	is_removed = true
	_update_accuracy()
	_remove_from_judging()
	explode()
	pass


func _update_accuracy() -> void:
	Global.total_judged += 1
	var n: int = Global.total_judged
	Global.accuracy = (Global.accuracy * float(n - 1) + a) / float(n)
	Global.combo += 1
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
	if master_time >= float(time) and not is_judged:
		judge(master_time)
		pass
	pass
