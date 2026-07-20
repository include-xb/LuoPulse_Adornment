extends MeshInstance3D


# 对 Gameplay 节点的引用 (由 NoteLoader 注入)
var gameplay: Node2D = null

var type: String = "hold"

var index: int = 0

# 从谱面加载所得的音符到达判定线的时间 (毫秒)
var time: int = 0

# 持续时间 (毫秒)
var duration: int = 0

# 轨道 (1-based)
var column: int = 0

# 头部是否已被判定
var is_head_judged: bool = false

# 是否已被彻底移除
var is_removed: bool = false

# 是否正在被摁住
var is_holding: bool = false

# hold 是否已结算 (计分完成)
var is_hold_completed: bool = false

# hold 是否被提前中断 (玩家松手)
var is_hold_interrupted: bool = false

# 中断时的可见长度 (用于中断后向后滚动的视觉效果)
var _interrupted_visible_length: float = 0.0

# 头部判定时的准度值
var a: float = 0.0

# 判定区间状态跟踪
var _was_in_judging_area: bool = false

# 预计算的 hold 基础长度
var _hold_length: float = 0.0

# 预计算的 mesh 原始高度
var _mesh_base_height: float = 0.0


func _ready() -> void:
	_mesh_base_height = get_mesh().size.y
	# 预计算 hold 全长 (世界单位)
	_hold_length = Global.note_speed * float(duration) / 1000.0
	pass


func _process(delta: float) -> void:
	if gameplay == null:
		return

	var mt: float = gameplay.master_time

	if not is_head_judged:
		# 头部下落
		var head_z: float = Global.note_speed * (mt - float(time)) / 1000.0
		position.z = head_z - _hold_length / 2.0
		scale.z = _hold_length / _mesh_base_height
		pass
	elif is_hold_interrupted:
		# 提前松手: body 整体向后滚动, 不再保持在判定线
		var head_z: float = Global.note_speed * (mt - float(time)) / 1000.0
		position.z = head_z - _interrupted_visible_length / 2.0
		if _mesh_base_height > 0.0:
			scale.z = _interrupted_visible_length / _mesh_base_height
			pass
		pass
	else:
		# 正常按住: 头部固定在判定线 (z=0), 尾部逐渐收拢
		var tail_z: float = Global.note_speed * (mt - float(time) - float(duration)) / 1000.0
		tail_z = minf(tail_z, 0.0)

		var visible_length: float = -tail_z

		if visible_length <= 0.0:
			# hold 完全消耗, 进行结算
			if not is_hold_completed:
				_complete_hold()
				pass
			if not is_removed:
				_explode()
				pass
			return
			pass

		position.z = tail_z / 2.0
		scale.z = visible_length / _mesh_base_height
		pass

	# 自动播放
	if Global.is_autoplay:
		autoplay(mt)
		pass

	# 判定区间管理 (仅在头部未判定时)
	if not is_head_judged:
		var time_offset: float = mt - float(time)
		var in_judging_area: bool = time_offset >= float(Global.START_JUDGE_TIME) and time_offset <= float(Global.END_JUDGE_TIME)

		if in_judging_area and not _was_in_judging_area:
			Global.judging_area.append(self)
			pass

		if not in_judging_area and _was_in_judging_area:
			# 头部错过判定窗口 → 丢失
			_lose()
			pass

		_was_in_judging_area = in_judging_area

		if time_offset > float(Global.END_JUDGE_TIME) and not is_removed:
			_lose()
			pass
		pass
	else:
		# 头部已判定, 从判定区间移除 (不再接受新的判定)
		if _was_in_judging_area:
			_remove_from_judging()
			_was_in_judging_area = false
			pass
		pass

	# hold 完成后自动移除
	if is_hold_interrupted:
		if mt >= float(time) + float(duration) + 1500.0:
			if not is_removed:
				_explode()
				pass
			pass
		pass
	elif is_head_judged and mt >= float(time) + float(duration) + float(Global.END_JUDGE_TIME):
		if not is_hold_completed:
			_complete_hold()
			pass
		if not is_removed:
			_explode()
			pass
		pass

	pass


func is_head_judgable() -> bool:
	return not is_head_judged and not is_removed


func is_judgable() -> bool:
	return is_head_judgable()


func judge_head(master_time: float) -> void:
	if is_head_judged or is_removed:
		return

	var time_offset: int = int(master_time - float(time))
	var abs_offset: int = abs(time_offset)

	if abs_offset <= Global.HARMONIOUS_TIME:
		a = 1.0
		pass
	elif abs_offset <= Global.SYMPATHETIC_TIME:
		a = 0.7
		pass
	elif abs_offset <= Global.AWARE_TIME:
		a = 0.5
		pass
	else:
		a = 0.0
		pass

	is_head_judged = true
	pass


func on_hold_start(master_time: float) -> void:
	is_holding = true
	pass


func on_released(master_time: float) -> void:
	if not is_hold_completed:
		is_hold_interrupted = true
		var tail_z: float = Global.note_speed * (master_time - float(time) - float(duration)) / 1000.0
		_interrupted_visible_length = maxf(0.0, -tail_z)
		_complete_hold()
		pass
	is_holding = false
	# 释放后不再追踪该 hold
	pass


func _complete_hold() -> void:
	if is_hold_completed:
		return

	if is_hold_interrupted:
		Global.lost += 1
		a = 0.0
		Global.combo = 0
		pass
	else:
		if a >= 1.0:
			Global.harmonious += 1
			pass
		elif a >= 0.7:
			Global.sympathetic += 1
			pass
		elif a >= 0.5:
			Global.aware += 1
			pass
		else:
			Global.lost += 1
			pass
		Global.combo += 1
		pass

	is_hold_completed = true
	Global.total_judged += 1
	var n: int = Global.total_judged
	Global.accuracy = (Global.accuracy * float(n - 1) + a) / float(n)
	_remove_from_judging()
	pass


func _lose() -> void:
	if is_removed:
		return

	is_removed = true
	Global.lost += 1
	a = 0.0

	Global.total_judged += 1
	var n: int = Global.total_judged
	Global.accuracy = (Global.accuracy * float(n - 1) + a) / float(n)

	_remove_from_judging()
	_explode()
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


func _explode() -> void:
	is_removed = true
	_remove_from_judging()
	queue_free()
	pass


# 自动播放
func autoplay(master_time: float) -> void:
	if not is_head_judged and master_time >= float(time):
		judge_head(master_time)
		is_holding = true
		pass
	if is_head_judged and not is_holding and master_time >= float(time):
		is_holding = true
		pass
	if is_holding and master_time >= float(time) + float(duration):
		is_holding = false
		pass
	pass
