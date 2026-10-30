## HeartPulse 心跳颤动
##
## heart 谱面效果期间, 每打中一个音符就让 3D 演奏区 (Gameplay 的 UI/TextureRect)
## 向下沉一下再弹回原位 —— 与心电图同一条逻辑: 心跳是玩家自己踩出来的, 不打就不动。
## 正在颤的时候又打中了, 就掐掉当前这一下、从头重新颤 (见 beat_once)。
## 只位移这一层: 它承载轨道与音符; 背景 PV 与 UI 文字不跟着抖。
## 只改 Y 不动 X, 所以不需要为触屏判定做额外的反向补偿。
##
## 相位取 Global.master_time, 暂停 / 继续倒计时期间一起冻结。
## 幅度由 EffectManager 在触发时写入 (heart 的整体 fade 包络), 所以特效淡入 / 淡出期间的
## 颤动会相应变轻。

class_name HeartPulse extends TextureRect


## 一次颤动向下位移的最大距离 (占控件高度的比例)
## INFO: 用比例而不是像素 —— 不同分辨率下"颤"的观感一致
@export_range(0.0, 0.08, 0.001) var dip_ratio: float = 0.016

## 一次颤动的时间 (毫秒): 原位 → 最低点 → 原位
const PULSE_END_MS: float = 180.0


## 当前颤动的幅度 (0 ~ 1; 触发时由 EffectManager 写入)
var _intensity: float = 0.0

## 本次颤动的起始 master_time (毫秒)
var _beat_start_ms: float = 0.0

## 颤动前的原始位置 (每帧都在这个基础上加位移, 收尾时精确回到它)
var _base_position: Vector2 = Vector2.ZERO


# ---------- 节点重载函数 ----------
func _ready() -> void:
	_base_position = position
	set_process(false)
	pass


func _process(_delta: float) -> void:
	var elapsed: float = Global.master_time - _beat_start_ms
	if elapsed < 0.0 or elapsed >= PULSE_END_MS:
		stop()
		return

	var dip: float = size.y * dip_ratio * _intensity * _pulse_at(elapsed)
	position = _base_position + Vector2(0.0, dip)
	pass


# ---------- 对外接口 ----------
## 打中一个音符: 颤一下
## @param intensity: 颤动幅度 (0 ~ 1), 通常传 heart 当前的整体 fade
## INFO: 正在颤的时候再次命中会直接掐掉当前动画、从头重新颤 ——
##       相位按 master_time 记, 所以重开就是简单地把起点挪到现在
func beat_once(intensity: float) -> void:
	if intensity <= 0.0:
		return

	# 空闲时重新记一次原位 —— 窗口尺寸 / 布局在两次颤动之间变了也不会回错地方
	if not is_processing():
		_base_position = position
		pass

	_intensity = clampf(intensity, 0.0, 1.0)
	_beat_start_ms = Global.master_time
	set_process(true)
	pass


## 立即回到原位 (heart 结束 / 重开时由 EffectManager 调用)
func stop() -> void:
	_intensity = 0.0
	position = _base_position
	set_process(false)
	pass


# ---------- 内部 ----------
## 一次颤动内的位移包络: 单个单峰, 其余时间为 0
func _pulse_at(elapsed: float) -> float:
	return _bump(elapsed, 0.0, PULSE_END_MS)


## [start, end] 内的单峰 (0 → 1 → 0); 用 sin 让两端的速度也归零, 不会顿一下
func _bump(elapsed: float, start: float, end: float) -> float:
	if elapsed < start or elapsed > end:
		return 0.0
	var t: float = (elapsed - start) / maxf(end - start, 0.0001)
	return sin(PI * t)
