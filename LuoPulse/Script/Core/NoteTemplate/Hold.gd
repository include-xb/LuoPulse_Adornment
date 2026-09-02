extends MeshInstance3D


## 对 Gameplay 节点的引用 (由 NoteLoader 注入)
var root_node: Control

## 音符类型
var type: String = "hold"

## 音符序号
var index: int = 0

## 从谱面加载所得的音符到达判定线的时间 (毫秒)
var time: int = 0

## 持续时间 (毫秒)
var duration: int = 0

## 轨道 (1-based)
var column: int = 0

## 头部是否已被判定
var is_head_judged: bool = false

## 是否已被彻底移除
var is_removed: bool = false

## 是否正在被摁住
var is_holding: bool = false

## hold 是否已结算 (计分完成)
var is_hold_completed: bool = false

## hold 是否被提前中断 (玩家松手)
var is_hold_interrupted: bool = false

## 中断时的可见长度 (用于中断后向后滚动的视觉效果)
var _interrupted_visible_length: float = 0.0

## 松手时刻 (毫秒), 用于提前松手后从松手时刻起算下落距离, 保证松手瞬间位置连续
var _release_time: float = 0.0

## 头部判定时的准度值
var a: float = 0.0

## 判定区间状态跟踪
var _was_in_judging_area: bool = false

## 预计算的 hold 基础长度
var _hold_length: float = 0.0

## 预计算的 mesh 原始高度
var _mesh_base_height: float = 0.0

## 从 root_node 获取的 master_time
var mt: float = 0.0

## 是否为多押
var is_mulit_tap: bool = false

## 剩余未按住部分设置透明度 (0 - 1) .f
const REST_ALPHA: float = 0.6

## 多押提示亮度增量 (0.0 ~ 1.0, 在原色基础上向白色混合)
const MULTI_TAP_BRIGHTEN: float = 0.6

## 尾部松手容差 (毫秒): 允许玩家提前这么长时间松手, 仍按完全按完结算
const HOLD_RELEASE_TOLERANCE: float = 40.0


# ---------- 节点重载函数 ----------
func _ready() -> void:
	_mesh_base_height = get_mesh().size.y
	# 预计算 hold 全长 (世界单位)
	_hold_length = Global.note_speed * float(duration) / 1000.0

	if is_mulit_tap:
		var c: Color = self.material_override.get_shader_parameter("color")
		self.material_override.set_shader_parameter("color", c.lightened(MULTI_TAP_BRIGHTEN))
		pass

	pass


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	# 获取 master_time 时间
	mt = root_node.master_time
	
	if is_holding:
		pass
	
	if not is_head_judged:
		# 头部下落
		var head_z: float = Global.note_speed * (mt - float(time)) / 1000.0
		position.z = head_z - _hold_length / 2.0
		scale.z = _hold_length / _mesh_base_height
		pass
	elif is_hold_interrupted:
		# 提前松手: body 整体向后滚动, 不再保持在判定线
		# 从松手时刻起算下落距离 (而非从头部到达时刻), 保证松手瞬间位置连续, 不会突然向后跳变
		var head_z: float = Global.note_speed * (mt - _release_time) / 1000.0
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

		# 完全按住: 按满 100% 才结算移除 (不能提前, 否则松手前就被移除, 无法半透明下落)
		# 尾部容差只在 on_released 中判断 (提前 HOLD_RELEASE_TOLERANCE 内松手仍算完成)
		if mt >= float(time) + float(duration):
			if not is_hold_completed:
				_complete_hold()
				pass
			if not is_removed:
				# 完全按完
				_explode()
				pass
			return

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
			_remove_from_judging_and_rendering()
			_was_in_judging_area = false
			pass
		pass

	# hold 完成后自动移除
	# 提前松开: 继续下落 1500ms, 滚出屏幕后再移除
	if is_hold_interrupted and mt >= float(time) + float(duration) + 1500.0:
		if not is_removed:
			_explode()
			pass
		pass
	# 完全按住 (排除提前松手, 提前松手只由上方 is_hold_interrupted 分支处理)
	elif is_head_judged and not is_hold_interrupted and mt >= float(time) + float(duration) + float(Global.END_JUDGE_TIME):
		if not is_hold_completed:
			_complete_hold()
			pass
		if not is_removed:
			_explode()
			pass
		pass
	# 始终未被点击: 半透明后继续下落 1500ms, 滚出屏幕后再移除
	elif is_removed and not is_head_judged and mt >= float(time) + float(duration) + 1500.0:
		_explode()
		pass
	
	pass


# ---------- 谓词/工具函数 ----------
## 由 InputProcesser.gd 调用
## 是否处于判定区间且未被头判
func is_head_judgable() -> bool:
	return not is_head_judged and not is_removed


## 由 InputProcesser.gd 调用
## 是否处于判定区间且未被头判 (与 is_head_judgable() 函数相同)
func is_judgable() -> bool:
	return is_head_judgable()


## 设置 is_holding 为 true
@warning_ignore("unused_parameter")
func on_hold_start(master_time: float) -> void:
	is_holding = true
	pass


## 设置 hold 透明度 (0.0 ~ 1.0)
## 通过 shader 的 color 参数控制 alpha, 保留 RGB 不变
func _set_alpha(alpha: float) -> void:
	var c: Color = material_override.get_shader_parameter("color")
	c.a = alpha
	material_override.set_shader_parameter("color", c)
	pass


# ---------- 判定 ----------
## 头判
func judge_head(master_time: float) -> void:
	if is_head_judged or is_removed:
		return

	var time_offset: int = int(master_time - float(time))

	var level: String = "lost"

	if Global.is_autoplay:
		time_offset = 0
		pass

	var abs_offset: int = abs(time_offset)

	if abs_offset <= Global.HARMONIOUS_TIME:
		a = 1.0
		level = "harmonious"
		pass
	elif abs_offset <= Global.SYMPATHETIC_TIME:
		a = 0.7
		level = "sympathetic"
		pass
	elif abs_offset <= Global.AWARE_TIME:
		a = 0.5
		level = "aware"
		pass
	else:
		# 头部判定 Lost: 等同 miss, 半透明后继续下落
		a = 0.0
		_lose()
		return
	pass

	if root_node and root_node.has_method("show_judgment_feedback"):
		root_node.show_judgment_feedback(time_offset, level, column)
		pass

	is_head_judged = true
	pass


## 由 InputProcesser 节点调用
## 松开, 对音符进行判定
func on_released(master_time: float) -> void:
	if not is_hold_completed:
		if master_time >= float(time) + float(duration) - HOLD_RELEASE_TOLERANCE:
			# 已按满 (含尾部容差): 正常结算, 不判中断
			_complete_hold()
			pass
		else:
			# 未按满: 半透明后继续下落
			_set_alpha(REST_ALPHA)
			is_hold_interrupted = true
			_release_time = master_time
			var tail_z: float = Global.note_speed * (master_time - float(time) - float(duration)) / 1000.0
			_interrupted_visible_length = maxf(0.0, -tail_z)
			_complete_hold()
			pass
		pass
	is_holding = false
	# 释放后不再追踪该 hold
	pass


## 完成按住, 每帧持续调用
func _complete_hold() -> void:
	if is_hold_completed:
		return

	if is_hold_interrupted:
		Global.lost += 1
		a = 0.0
		Global.combo = 0
		
		_set_alpha(0.2)
		
		if root_node and root_node.has_method("show_judgment_feedback"):
			root_node.show_judgment_feedback(0, "lost", column)
			pass
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
	_remove_from_judging_and_rendering()
	pass


## 判定为失败
func _lose() -> void:
	if is_removed:
		return

	is_removed = true
	Global.lost += 1
	Global.combo = 0
	a = 0.0
	
	_set_alpha(REST_ALPHA)

	if root_node and root_node.has_method("show_judgment_feedback"):
		root_node.show_judgment_feedback(0, "lost", column)
		pass

	Global.total_judged += 1
	var n: int = Global.total_judged
	Global.accuracy = (Global.accuracy * float(n - 1) + a) / float(n)

	_remove_from_judging_and_rendering()
	# 不立即释放: 半透明后继续下落, 滚出屏幕后在 _process 中移除
	pass


# ---------- 清除 ----------
## 清理对象池中的引用
func _remove_from_judging_and_rendering() -> void:
	var idx: int = Global.judging_area.find(self)
	if idx >= 0:
		Global.judging_area.remove_at(idx)
		pass
	idx = Global.rendering_area.find(self)
	if idx >= 0:
		Global.rendering_area.remove_at(idx)
		pass
	pass


## 从场景中移除
func _explode() -> void:
	is_removed = true
	_remove_from_judging_and_rendering()
	_set_autoplay_hold(false)
	queue_free()
	pass


# ---------- 自动播放 ----------
## 自动播放
func autoplay(master_time: float) -> void:
	if not is_head_judged and master_time >= float(time):
		judge_head(master_time)
		is_holding = true
		_set_autoplay_hold(true)
		pass
	if is_head_judged and not is_holding and master_time >= float(time):
		is_holding = true
		_set_autoplay_hold(true)
		pass
	if is_holding and master_time >= float(time) + float(duration):
		is_holding = false
		_set_autoplay_hold(false)
		pass
	pass


## 自动播放 hold 的轨道持续高亮转发
func _set_autoplay_hold(is_active: bool) -> void:
	if root_node and root_node.has_method("set_track_autoplay_hold"):
		root_node.set_track_autoplay_hold(column, is_active)
		pass
	pass
