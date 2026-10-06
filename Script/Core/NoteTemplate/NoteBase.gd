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

## 本列 InputProcesser 的引用 (只为读"本轨是否被按住", 惰性解析一次)
var _processor: Node = null

## 是否已经尝试解析过 _processor
var _is_processor_resolved: bool = false

## 多压提示亮度增量 (0.0 ~ 1.0, 在原色基础上向白色混合)
const MULTI_TAP_BRIGHTEN: float = 0.4


# ---------- 节点重载函数 ----------
func _ready() -> void:
	if is_mulit_tap:
		_apply_multi_tap_color()
		pass
	var mt: float = root_node.master_time
	position.z = Global.note_speed * (mt - float(time)) / 1000.0
	pass


@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	#if gameplay == null:
		#return

	var mt: float = root_node.master_time

	# 音符定位: z = speed * (master_time - time) / 1000
	# 使得在 master_time == time 时, 音符刚好到达 z=0 (判定线)
	# INFO 不再使用上面的方式下落音符, 而是改回旧版使用 delta 计算每帧位移
	# 优点: 与 _physics_process 高度一致, 下落时更加流畅.
	# 缺点: 长时间 delta 的累加会造成浮点数的误差被放大, 但是由于音符被创建到判定只有 3 秒时间, 这段时间内的浮点数误差可以忽略
	# var correct_pos = Global.note_speed * (mt - float(time)) / 1000.0
	# 位移按 delta 累加, 与 master_time 无关, 所以必须自己判断能否推进:
	# 暂停 / 继续倒计时期间 master_time 冻结, 这里若照常累加, 音符会在暂停面板后面继续下落
	if root_node.is_gaming:
		position.z += Global.note_speed * delta
		pass
	# if abs(position.z - correct_pos) >= 0.01:
	# 	# position.z = correct_pos
	# 	pass

	# 自动播放
	if Global.is_autoplay:
		_autoplay(mt)
		pass

	# 判定区间管理
	var time_offset: float = mt - float(time)
	var in_judging_area: bool = time_offset >= float(Global.start_judge_time) and time_offset <= float(Global.end_judge_time)

	if in_judging_area and not _was_in_judging_area and not is_removed:
		is_added = true
		Global.judging_area.append(self)
		pass

	if not in_judging_area and _was_in_judging_area and not is_removed:
		# INFO: 判定窗口会被 heart 特效整体收窄。收窄的瞬间, 还没越过判定线的音符会
		#       "被动"离开判定区 —— 那不是漏键 (它本该有机会走进收紧后的区间),
		#       只把它从判定区摘掉即可, 窗口放宽或它自己走进来时还会重新入区;
		#       只有越过判定线之后离开, 才算丢失
		if time_offset > 0.0:
			_on_miss(mt)
		else:
			_remove_from_judging()
			pass
		pass

	_was_in_judging_area = in_judging_area

	if time_offset > float(Global.end_judge_time) and not is_removed:
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

	if abs_offset <= Global.harmonious_time:
		Global.harmonious += 1
		a = 1.0
		level = "harmonious"
		pass
	elif abs_offset <= Global.sympathetic_time:
		Global.sympathetic += 1
		a = 0.7
		level = "sympathetic"
		pass
	elif abs_offset <= Global.aware_time:
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


## 离开判定区间且未被判定时的处理 (子类可覆写)
## INFO: 红键也不再例外 —— 它必须由玩家在判定线处松手结算, 一直按住不放或从头没按
##       都会走到这里, 与其它音符一样算 Lost
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
	# heart 特效期间: 漏掉一个音符, 心电图往回退半步
	_notify_note_miss()
	# 非 hold 音符漏键只原地消失: 不放粒子, 也不点亮判定线上的矩形
	# (它的反馈只剩上面那句灰色"丢失"飘字)
	queue_free()
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
		# 判定线上点亮矩形; 打到"丢失"档的点击同样不给 (与上面同一条原则)
		_burst_feedback()
		# heart 特效期间的反馈: 玩家打中一个音符, 屏幕边缘闪一下 + 心电图往前画一段
		_notify_note_hit(HitFeedback.flash_of(level))
	else:
		# 打到"丢失"档的点击算漏键 (与"丢失档不给命中反馈"同一条原则)
		_notify_note_miss()
		pass

	queue_free()
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


## 本列当前是否被玩家按住 (判据由 InputProcesser.is_pressed() 提供)
## 用途: 释放键看它决定是否"接管", 黄键在进入判定区时看它决定成败
## INFO: 自动播放没有真实触摸, 一律算作按住
func _is_column_held() -> bool:
	if Global.is_autoplay:
		return true

	if not _is_processor_resolved:
		_is_processor_resolved = true
		if root_node and root_node.has_method("get_input_processor"):
			_processor = root_node.get_input_processor(column - 1)
			pass
		pass

	if _processor == null or not is_instance_valid(_processor):
		return false
	if not _processor.has_method("is_pressed"):
		return false
	return _processor.is_pressed()


## 命中时的 heart 特效反馈 (屏幕边缘闪动 + 心电图往前画一段; 只在特效期间可见)
## @param strength: 闪动强度 (0 ~ 1), 沿用判定等级那一张表 —— "丢失"档是 0, 漏键天然不触发
func _notify_note_hit(strength: float = 1.0) -> void:
	if strength <= 0.0:
		return
	if root_node and root_node.has_method("on_note_hit"):
		root_node.on_note_hit(strength)
		pass
	pass


## 漏掉时的 heart 特效反馈 (心电图往回退半步 + 边缘血色底子暗一下; 只在特效期间可见)
func _notify_note_miss() -> void:
	if root_node and root_node.has_method("on_note_miss"):
		root_node.on_note_miss()
		pass
	pass


# ---------- 清除 ----------
## 只把音符从判定区摘掉, 保留它在渲染区 —— 判定窗口被 heart 特效收窄时用
## INFO: 不能用 _remove_from_judging_and_rendering() —— 那会连 rendering_area 一起摘掉,
##       而 Gameplay.reset_speed() 是靠 rendering_area 给长键重算长度的
func _remove_from_judging() -> void:
	var idx: int = Global.judging_area.find(self)
	if idx >= 0:
		Global.judging_area.remove_at(idx)
		pass
	pass


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


## 命中反馈: 请本列在判定线上点亮一次"迅速变大变淡的矩形"
## INFO: 粒子的位置会跟着"判定发生在哪一帧"走 (早击时音符还没落到判定线, 粒子就打在了轨道后方),
##       矩形恒定锚在判定线上, 与轨道闪光是同一个视觉焦点
## INFO: 本列那个共用的粒子发射器现在只服务长键 (见 Hold.gd), 非 hold 音符不再碰它
func _burst_feedback() -> void:
	var column_node: Node = get_node_or_null("../..")
	if column_node and column_node.has_method("show_hit_burst"):
		column_node.show_hit_burst(get_note_color())
		pass
	pass
