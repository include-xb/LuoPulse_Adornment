## InputProcesser.gd 输入处理器
## 每个 Column 节点挂载一个实例, 处理该轨道的触屏/按键输入判定


extends Node3D


@export var column: int = 0

@onready var single_track: MeshInstance3D = $SingleTrack

# 轨道材质副本 (每列独立, 用于触屏高亮)
var _track_material: ShaderMaterial = null

# 触屏高亮强度 (shader uniform)
var _highlight: float = 0.0
const HIGHLIGHT_FADE: float = 8.0

# 当前触摸计数 (支持多点触控)
var _touch_count: int = 0

# 是否正在长按 (hold)
var is_holding: bool = false

# 当前正在持有的 hold 音符
var current_hold_note: MeshInstance3D = null

# 当前帧触摸时间 (由 Gameplay 传入)
var _touch_time: float = -999999.0


func _ready() -> void:
	var src: ShaderMaterial = single_track.get_active_material(0)
	_track_material = src.duplicate()
	single_track.material_override = _track_material
	pass


func _process(delta: float) -> void:
	if _touch_count > 0:
		_highlight = 1.0
		_track_material.set_shader_parameter("highlight", _highlight)
		pass
	elif _highlight > 0.0:
		_highlight = maxf(0.0, _highlight - HIGHLIGHT_FADE * delta)
		_track_material.set_shader_parameter("highlight", _highlight)
		pass

	if is_holding and not is_instance_valid(current_hold_note):
		is_holding = false
		current_hold_note = null
		pass
	pass


func on_touch_pressed(master_time: float) -> void:
	_touch_time = master_time
	_touch_count += 1

	_highlight = 1.0
	_track_material.set_shader_parameter("highlight", _highlight)

	if _touch_count > 1:
		return

	press_judge(master_time)
	pass


func on_touch_released(master_time: float) -> void:
	_touch_time = master_time
	_touch_count = maxi(0, _touch_count - 1)

	if _touch_count > 0:
		return

	if is_holding:
		if is_instance_valid(current_hold_note) and current_hold_note.has_method("on_released"):
			current_hold_note.on_released(master_time)
			pass
		is_holding = false
		current_hold_note = null
		pass
	pass


func press_judge(master_time: float) -> void:
	if is_holding:
		if not is_instance_valid(current_hold_note):
			is_holding = false
			current_hold_note = null
			pass
		else:
			return
		pass

	# 获取当前轨道判定区间内的所有有效音符
	var column_notes: Array = _get_column_notes()

	if column_notes.is_empty():
		return

	# 找到距判定线最近的音符 (时间偏移绝对值最小)
	var best_note = null
	var best_offset: float = INF

	for note in column_notes:
		if not is_instance_valid(note):
			continue
		if note.has_method("is_judgable") and not note.is_judgable():
			continue
		var offset: float = abs(master_time - float(note.get("time")))
		if offset < best_offset and offset <= float(Global.LOST_TIME):
			best_offset = offset
			best_note = note
			pass
		pass

	if best_note == null:
		return

	var note_type: String = best_note.get("type")

	match note_type:
		"tap", "heart":
			if best_note.has_method("judge"):
				best_note.judge(master_time)
				pass
			pass
		"drag":
			if best_note.has_method("judge"):
				best_note.judge(master_time)
				pass
			pass
		"release":
			# 红键: 触摸即判定为 Lost
			if best_note.has_method("lose"):
				best_note.lose(master_time)
				pass
			pass
		"hold":
			if best_note.has_method("is_head_judgable") and best_note.is_head_judgable():
				best_note.judge_head(master_time)
				is_holding = true
				current_hold_note = best_note
				pass
			elif best_note.has_method("is_head_judgable") and not best_note.is_head_judgable():
				# 头部已判定, 开始 hold
				is_holding = true
				current_hold_note = best_note
				if best_note.has_method("on_hold_start"):
					best_note.on_hold_start(master_time)
					pass
				pass
			pass
		pass

	pass


func _get_column_notes() -> Array:
	var result: Array = []
	for note in Global.judging_area:
		if not is_instance_valid(note):
			continue
		var note_column: int = note.get("column")
		if note_column == column:
			result.append(note)
			pass
		pass
	return result
