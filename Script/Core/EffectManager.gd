## EffectManager 谱面效果管理器
##
## 负责 chart.lp 的 Effects 段。目前只有一种效果:
##   change —— 轨道换位: 把整根 Column 沿 x 挪到别的槽位, duration 到期后复原。
##
## 换位挪的是 Column 节点本身; 轨道面 / 判定线 / 粒子 / 音符 (NotePool) 都是它的子节点,
## 会整体跟着走, 所以"看到的轨道在哪"与"音符在哪"永远是同一处。

extends Node

class_name EffectManager

## 换位动画的单程时长 (秒), 换位与复原都用它
@export var effect_change_time: float = 0.2

## 动画时长的下限 (秒) —— 防止导出变量被设成 0 导致除零
const MIN_CHANGE_TIME: float = 0.001

## 参与换位的轨道 (下标必须与 Gameplay.get_input_processor 一致, 由 Gameplay 注入)
var _tracks: Array = [ ]

## 各轨道的原始 x (出生槽位), 下标 = 轨道号
var _origin_x: PackedFloat32Array = PackedFloat32Array()

## 槽位坐标 (升序): _slot_x[slot] 就是从左数第 slot 个槽位的世界 x
var _slot_x: PackedFloat32Array = PackedFloat32Array()

## 校验通过的 change 效果 (按 time 升序)
var _effects: Array = [ ]

## 下一个待触发的效果在 _effects 中的下标
var _cursor: int = 0

## 当前生效的效果下标 (-1 表示没有)
var _active_index: int = -1

## 当前效果: 各轨道在触发瞬间的 x (上升段的起点)
var _from_x: PackedFloat32Array = PackedFloat32Array()

## 当前效果: 各轨道的目标 x
var _to_x: PackedFloat32Array = PackedFloat32Array()


# ---------- 对外接口 ----------
## 载入效果列表并复位 (Gameplay 在 _ready 与重开时调用)
## @param tracks: Column 节点数组, 下标必须与 Gameplay.get_input_processor 一致
## @param raw_effects: chart.lp 的 Effects 段原文 (缺失或非法时传空数组)
func setup(tracks: Array, raw_effects: Variant) -> void:
	_tracks = tracks

	# 槽位坐标只记一次: 重开时轨道可能正被效果挪着, 那时读到的不是原位
	if _origin_x.size() != _tracks.size():
		_capture_origin()
		pass

	_effects = _parse_effects(raw_effects)
	reset()
	pass


## 复位: 清空进度并把所有轨道放回原始槽位 (重开游戏时调用)
func reset() -> void:
	_cursor = 0
	_active_index = -1
	for i: int in _tracks.size():
		var track: Node3D = _tracks[i]
		if is_instance_valid(track):
			track.position.x = _origin_x[i]
			pass
		pass
	pass


## 每帧推进 (由 Gameplay 在游戏进行中调用)
## @param master_time: 主时间 (ms), 与音符判定用的是同一个时钟
func tick(master_time: float) -> void:
	if _effects.is_empty():
		return

	# 触发所有已到期的效果 —— 同一帧内可以连触发多个
	while _cursor < _effects.size() and master_time >= float(_effects[_cursor]["time"]):
		_activate(_cursor)
		_cursor += 1
		pass

	if _active_index < 0:
		return

	_apply_positions(master_time)
	pass


## 找出当前 x 离给定世界坐标最近的那根轨道 (0-based)
## INFO: 换位动画途中按下时, 这里返回的就是"此刻实际占据该位置"的那根轨道 ——
##       所以判定永远和玩家眼睛看到的一致, 不需要等动画播完
func track_index_for_world_x(world_x: float) -> int:
	if _tracks.is_empty():
		return -1

	var best_index: int = 0
	var best_distance: float = INF
	for i: int in _tracks.size():
		var track: Node3D = _tracks[i]
		if not is_instance_valid(track):
			continue
		var distance: float = absf(track.position.x - world_x)
		# 用 < 而非 <=: 两根轨道交叉重合的瞬间取小下标, 保证结果确定
		if distance < best_distance:
			best_distance = distance
			best_index = i
			pass
		pass

	return best_index


## 槽位号 → 当前占据该槽位的轨道号 (键盘 D/F/J/K 走这条)
func track_index_for_slot(slot: int) -> int:
	if slot < 0 or slot >= _slot_x.size():
		return -1
	return track_index_for_world_x(_slot_x[slot])


# ---------- 内部: 状态推进 ----------
## 触发一个效果: 记下各轨道此刻的位置, 算出各自的目标槽位
## INFO: 起点按效果自己的 time 求, 不按当前帧的 master_time ——
##       万一这一帧卡顿导致触发迟到, 起点也不会把迟到的这段算进去, 视觉上不会多跳一下
func _activate(index: int) -> void:
	var effect: Dictionary = _effects[index]
	var start: float = float(effect["time"])
	var changed: PackedInt32Array = effect["changed"]

	_from_x.resize(_tracks.size())
	_to_x.resize(_tracks.size())
	for i: int in _tracks.size():
		_from_x[i] = _track_x_at(i, start)
		# changed[slot] 存的是轨道号 (1-based), 反查本轨道该去哪个槽位
		_to_x[i] = _slot_x[changed.find(i + 1)]
		pass

	_active_index = index
	pass


## 把当前效果的位置写进各轨道
## INFO: 上升与下降两条 ramp 直接相乘叠加, 不用 if/else 分段 ——
##       duration 短于动画时长时它会自然退化成平滑的帐篷形, 不会跳变
func _apply_positions(master_time: float) -> void:
	var effect: Dictionary = _effects[_active_index]
	var start: float = float(effect["time"])
	var change: float = _change_time_ms()
	var restore_end: float = start + float(effect["duration"]) + change

	# 复原完毕: 精确归位并结束本次效果
	if master_time >= restore_end:
		_finish_active()
		return

	var up: float = clampf((master_time - start) / change, 0.0, 1.0)
	var down: float = clampf((restore_end - master_time) / change, 0.0, 1.0)

	for i: int in _tracks.size():
		var track: Node3D = _tracks[i]
		if not is_instance_valid(track):
			continue
		track.position.x = _position_at(i, up, down)
		pass
	pass


## 结束当前效果并归位
func _finish_active() -> void:
	_active_index = -1
	for i: int in _tracks.size():
		var track: Node3D = _tracks[i]
		if is_instance_valid(track):
			track.position.x = _origin_x[i]
			pass
		pass
	pass


## 第 i 根轨道在给定主时间下的 x (按当前生效的效果推算; 没有效果时就是原始 x)
## 只给"新效果接管"时取起点用
func _track_x_at(track_index: int, master_time: float) -> float:
	if _active_index < 0:
		return _origin_x[track_index]

	var effect: Dictionary = _effects[_active_index]
	var start: float = float(effect["time"])
	var change: float = _change_time_ms()
	var restore_end: float = start + float(effect["duration"]) + change
	if master_time >= restore_end:
		return _origin_x[track_index]

	var up: float = clampf((master_time - start) / change, 0.0, 1.0)
	var down: float = clampf((restore_end - master_time) / change, 0.0, 1.0)
	return _position_at(track_index, up, down)


## 第 i 根轨道在两条 ramp 进度下的 x
func _position_at(track_index: int, up: float, down: float) -> float:
	var risen: float = lerpf(_from_x[track_index], _to_x[track_index], _ease(up))
	return lerpf(risen, _origin_x[track_index], 1.0 - _ease(down))


## 单程动画时长 (毫秒)
func _change_time_ms() -> float:
	return maxf(effect_change_time, MIN_CHANGE_TIME) * 1000.0


## 0~1 的缓动映射
func _ease(progress: float) -> float:
	return smoothstep(0.0, 1.0, progress)


# ---------- 内部: 解析与校验 ----------
## 记录轨道初始位置, 并据此推出槽位坐标
func _capture_origin() -> void:
	var count: int = _tracks.size()
	_origin_x.resize(count)

	var sorted_x: Array = [ ]
	for i: int in count:
		var track: Node3D = _tracks[i]
		_origin_x[i] = track.position.x
		sorted_x.append(track.position.x)
		pass
	sorted_x.sort()

	# 槽位 = 排序后的初始 x: 第 s 个槽位就是从屏幕左边数第 s 条轨道的位置
	_slot_x.resize(count)
	for i: int in count:
		_slot_x[i] = sorted_x[i]
		pass
	pass


## 解析并校验 Effects 段; 非法项 push_error 后跳过, 不影响其余效果
func _parse_effects(raw_effects: Variant) -> Array:
	var result: Array = [ ]
	if raw_effects == null:
		return result
	if not raw_effects is Array:
		push_error("Effects 段必须是数组: %s" % str(raw_effects))
		return result

	var order: int = 0
	for raw: Variant in raw_effects:
		if not raw is Dictionary:
			push_error("效果项必须是字典: %s" % str(raw))
			continue
		# 不同谱面效果
		var type: String = str((raw as Dictionary).get("type", ""))
		match type:
			"change":
				var parsed: Dictionary = _parse_change(raw, order)
				if parsed.is_empty():
					continue
				result.append(parsed)
				order += 1
			_:
				push_error("未知的效果类型: %s" % type)
			pass
		pass

	result.sort_custom(_sort_by_time)
	return result


## 解析一条 change 效果; 非法时返回空字典
## @param order: 原文顺序, 用于 time 相同时的稳定排序
func _parse_change(raw: Dictionary, order: int) -> Dictionary:
	if not raw.has("time") or not raw.has("duration") or not raw.has("changed"):
		push_error("change 效果缺少 time / duration / changed 字段: %s" % str(raw))
		return { }

	# JSON 里的数字解析出来全是 float, 这里统一转成 int
	var time: int = int(raw.get("time"))
	var duration: int = int(raw.get("duration"))
	if time < 0 or duration < 0:
		push_error("change 效果的 time / duration 不能为负: %s" % str(raw))
		return { }

	var raw_changed: Variant = raw.get("changed")
	if not raw_changed is Array:
		push_error("change 效果的 changed 必须是数组: %s" % str(raw))
		return { }

	var count: int = _tracks.size()
	var changed: PackedInt32Array = PackedInt32Array()
	for value: Variant in raw_changed:
		changed.append(int(value))
		pass

	if changed.size() != count:
		push_error("change 效果的 changed 长度必须是 %d, 实际是 %d" % [ count, changed.size() ])
		return { }

	# 必须是 1~count 的一个排列: 有重复会让两条轨道抢同一个槽位, 另一个槽位空着
	var seen: Dictionary = { }
	for slot: int in changed:
		if slot < 1 or slot > count or seen.has(slot):
			push_error("change 效果的 changed 必须是 1~%d 的排列: %s" % [ count, str(raw_changed) ])
			return { }
		seen[slot] = true
		pass

	return {
		"type": "change",
		"time": time,
		"duration": duration,
		"changed": changed,
		"order": order,
	}


## 按 time 升序排列; time 相同时按原文顺序, 保证触发次序确定
static func _sort_by_time(a: Dictionary, b: Dictionary) -> bool:
	if int(a["time"]) != int(b["time"]):
		return int(a["time"]) < int(b["time"])
	return int(a["order"]) < int(b["order"])
