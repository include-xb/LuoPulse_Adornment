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

	_finish_judge(level)
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
	explode("lost")
	pass


## 结束判定
## @param level: 判定等级, 决定粒子配色/数量与轨道反馈强度
func _finish_judge(level: String) -> void:
	is_judged = true
	is_removed = true
	_update_accuracy()
	_remove_from_judging_and_rendering()

	# 漏键不点亮轨道也不发声, 否则等于在奖励失误
	_flash_track_feedback(HitFeedback.flash_of(level))
	if level != "lost":
		_play_hit_sound()
		_flash_background()
		pass

	explode(level)
	pass


# ---------- 自动播放 ----------
## 自动播放命中处理 (子类可覆写)
func _autoplay(master_time: float) -> void:
	# 命中反馈统一由 _finish_judge 触发, 这里不再重复
	if master_time >= float(time) - 10.0 and not is_judged:
		judge(master_time)
		pass
	pass


## 命中时的轨道与判定线反馈 (column 为 1-based 音符列)
## @param strength: 高亮强度 (0.0 ~ 1.0), 漏键传 0
func _flash_track_feedback(strength: float = 1.0) -> void:
	if strength <= 0.0:
		return
	if root_node and root_node.has_method("flash_track_feedback"):
		root_node.flash_track_feedback(column, strength)
		pass
	pass


## 播放打击音效 (音量接 Global.volume_note, 播放池由 Gameplay 统一管理)
func _play_hit_sound() -> void:
	if root_node and root_node.has_method("play_hit_sound"):
		root_node.play_hit_sound()
		pass
	pass


## 命中时的背景脉冲 (幅度很小, 主要反馈由连击数驱动)
func _flash_background() -> void:
	if root_node and root_node.has_method("flash_background"):
		root_node.flash_background()
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


## 取音符自身的颜色 (note_edge shader 的 original_color 参数)
## 粒子用它上色, 保证粒子颜色与音符本体一致
func get_note_color() -> Color:
	var mat: ShaderMaterial = get_active_material(0) as ShaderMaterial
	if mat == null:
		return HitFeedback.FALLBACK_COLOR

	var value: Variant = mat.get_shader_parameter("original_color")
	if value is Color:
		var note_color: Color = value
		return note_color
	return HitFeedback.FALLBACK_COLOR


## 发射一次粒子爆发 (不销毁自身, 供长键等需要继续存活的音符使用)
## @param level: 判定等级, 只决定粒子数量 (颜色取音符本体颜色)
func emit_particles(level: String = "harmonious") -> void:
	var particle: GPUParticles3D = get_node_or_null("../../GPUParticles3D")
	if particle == null:
		return

	var column_node: Node = get_node("../..")
	# 颜色取音符自身的颜色, 判定等级只体现在粒子数量上
	if column_node and column_node.has_method("set_particle_style"):
		column_node.set_particle_style(get_note_color(), HitFeedback.amount_of(level))
		pass

	particle.emitting = false
	particle.position.z = self.position.z
	particle.one_shot = true
	particle.emitting = true
	pass


## 碎裂效果: 发射粒子后销毁自身
## @param level: 判定等级, 决定粒子配色与数量
func explode(level: String = "harmonious") -> void:
	emit_particles(level)
	queue_free()
	pass


## 静默移除自身 (无粒子、无反馈)
## 用于"做对了但不该有打击反馈"的场合, 例如红键被正确忽略
func remove_silently() -> void:
	queue_free()
	pass
