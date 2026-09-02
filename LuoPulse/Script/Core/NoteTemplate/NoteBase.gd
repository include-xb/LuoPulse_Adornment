## NoteBase 音符基类
##
## 提供 tap / drag / heart / release 共用的下落、判定区间管理与判定逻辑。
## hold 音符行为差异较大, 单独实现 (见 Hold.gd)。


extends MeshInstance3D


class_name NoteBase


## 对 Gameplay 节点的引用 (由 NoteLoader 注入)
var root_node: Control;

## 音符索引
var index: int = 0

## 音符到达判定线的时间 (毫秒)
var time: int = 0

## 音符持续时间 (毫秒)
var duration: int = 0

## 音符所在列数 (1-based)
var column: int = 0

## 音符准度 (该音符的单次准度值)
var a: float = 0.0

## 音符是否已经被添加到判定区间
var is_added: bool = false

## 音符是否已经被移除 (已判定/已丢失)
var is_removed: bool = false

## 音符是否已判定 (valid hit)
var is_judged: bool = false

## 上次判定区间状态
var _was_in_judging_area: bool = false

## 是否为多压
var is_mulit_tap: bool = false

## 多压提示亮度增量 (0.0 ~ 1.0, 在原色基础上向白色混合)
const MULTI_TAP_BRIGHTEN: float = 0.6


# ---------- 节点重载函数 ----------
func _ready() -> void:
	if is_mulit_tap:
		_apply_multi_tap_color()
		pass
	pass


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	#if gameplay == null:
		#return

	var mt: float = root_node.master_time

	# 音符定位: z = speed * (master_time - time) / 1000
	# 使得在 master_time == time 时, 音符刚好到达 z=0 (判定线)
	position.z = Global.note_speed * (mt - float(time)) / 1000.0

	# 自动播放
	if Global.is_autoplay:
		_autoplay(mt)
		pass

	# 判定区间管理
	var time_offset: float = mt - float(time)
	var in_judging_area: bool = time_offset >= float(Global.START_JUDGE_TIME) and time_offset <= float(Global.END_JUDGE_TIME)

	if in_judging_area and not _was_in_judging_area and not is_removed:
		is_added = true
		Global.judging_area.append(self)
		pass

	if not in_judging_area and _was_in_judging_area and not is_removed:
		_on_miss(mt)
		pass

	_was_in_judging_area = in_judging_area

	if time_offset > float(Global.END_JUDGE_TIME) and not is_removed:
		_on_miss(mt)
		pass
	pass


# ---------- 工具函数 ----------
## 多压提示: 复制材质后在原色基础上调亮, 避免同类型音符共享材质导致互相污染 (调试用)
func _apply_multi_tap_color() -> void:
	var src: ShaderMaterial = get_active_material(0)
	if src == null:
		return
	var copied: ShaderMaterial = src.duplicate()
	material_override = copied
	var base_color: Color = copied.get_shader_parameter("original_color")
	copied.set_shader_parameter("original_color", base_color.lightened(MULTI_TAP_BRIGHTEN))
	pass


## 由 InputProcesser.gd 调用
## 是否处于判定区间且未被头判
func is_judgable() -> bool:
	return not is_removed and not is_judged


## 更新准度, 通过准度计算公式
func _update_accuracy() -> void:
	Global.total_judged += 1
	var n: int = Global.total_judged
	Global.accuracy = (Global.accuracy * float(n - 1) + a) / float(n)
	pass


# ---------- 判定 ----------
## 判定
func judge(master_time: float) -> void:
	if is_removed or is_judged:
		return

	var time_offset: int = int(master_time - float(time))

	var level: String = "lost"

	# 自动播放
	if Global.is_autoplay:
		time_offset = 0
		pass

	var abs_offset: int = abs(time_offset)

	if abs_offset <= Global.HARMONIOUS_TIME:
		Global.harmonious += 1
		a = 1.0
		level = "harmonious"
		pass
	elif abs_offset <= Global.SYMPATHETIC_TIME:
		Global.sympathetic += 1
		a = 0.7
		level = "sympathetic"
		pass
	elif abs_offset <= Global.AWARE_TIME:
		Global.aware += 1
		a = 0.5
		level = "aware"
		pass
	else:
		Global.lost += 1
		a = 0.0
		pass
	
	if level == "lost":
		Global.combo = 0
		pass
	else:
		Global.combo += 1
		pass

	if root_node and root_node.has_method("show_judgment_feedback"):
		root_node.show_judgment_feedback(time_offset, level, column)
		pass

	_finish_judge()
	pass


## 被触摸判定为 Lost (release 覆写为触摸即丢失)
func lose(master_time: float) -> void:
	_lose(master_time)
	pass


## 离开判定区间且未被判定时的处理 (子类可覆写)
func _on_miss(master_time: float) -> void:
	_lose(master_time)
	pass


## 判定为 lost
@warning_ignore("unused_parameter")
func _lose(master_time: float) -> void:
	if is_removed or is_judged:
		return

	is_removed = true
	Global.lost += 1
	Global.combo = 0
	a = 0.0

	if root_node and root_node.has_method("show_judgment_feedback"):
		root_node.show_judgment_feedback(0, "lost", column)
		pass

	_update_accuracy()
	_remove_from_judging_and_rendering()
	explode()
	pass


## 结束判定
func _finish_judge() -> void:
	is_judged = true
	is_removed = true
	_update_accuracy()
	_remove_from_judging_and_rendering()
	explode()
	pass


# ---------- 自动播放 ----------
## 自动播放命中处理 (子类可覆写)
func _autoplay(master_time: float) -> void:
	if master_time >= float(time) - 10.0 and not is_judged:
		judge(master_time)
		_flash_track_feedback()
		pass
	pass


## 自动播放时的轨道点击反馈
func _flash_track_feedback() -> void:
	if root_node and root_node.has_method("flash_track_feedback"):
		root_node.flash_track_feedback(column)
		pass
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


## 碎裂效果, 从场景中移除
func explode() -> void:
	var particle: GPUParticles3D = get_node("../../GPUParticles3D")
	particle.emitting = false
	particle.position.z = self.position.z
	particle.one_shot = true
	particle.emitting = true
	queue_free()
	pass
