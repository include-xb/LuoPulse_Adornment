## HeartPulse 心跳颤动
##
## heart 谱面效果期间, 每打中一个音符就让 3D 演奏区 (Gameplay 的 UI/TextureRect) 抖一下。
## 波形不是"下去再回来"的单峰, 而是阻尼弹簧: 快速下沉 → 回弹过冲 → 幅度递减,
## 再叠一个极小的左右倾斜 (每次命中左右交替), 读起来像被敲了一下而不是整块画面在滑。
## 与心电图同一条逻辑: 心跳是玩家自己踩出来的, 不打不动。
##
## 只动这一层: 它承载轨道与音符; 背景 PV 与 UI 文字不跟着抖。
## 倾斜角度很小, 触屏 X 判定不做补偿。
##
## 相位取 Global.master_time, 暂停 / 继续倒计时期间一起冻结
## 幅度由 EffectManager 在触发时写入 (heart 的整体 fade 包络), 所以特效淡入 / 淡出期间的颤动会相应变轻

class_name HeartPulse extends TextureRect


## 一次颤动向下位移的最大距离 (占控件高度的比例)
## INFO: 用比例而不是像素 —— 不同分辨率下"颤"的观感一致
@export_range(0.0, 0.08, 0.001) var dip_ratio: float = 0.014

## 颤抖时的最大倾斜角度 (度); 每次命中左右交替, 幅度随回弹一起衰减
@export_range(0.0, 0.6, 0.01) var tilt_degrees: float = 0.25

## 一次颤动的时间 (毫秒) —— 正好两个完整振荡周期, 结束时回到正中
const PULSE_END_MS: float = 320.0

## 阻尼振荡的周期 (毫秒)
const OSC_PERIOD_MS: float = 160.0

## 阻尼振荡的衰减时间常数 (毫秒; 越大余震越长)
const OSC_DECAY_MS: float = 95.0


## 当前颤动的幅度 (0 ~ 1; 触发时由 EffectManager 写入)
var _intensity: float = 0.0

## 本次颤动的起始 master_time (毫秒)
var _beat_start_ms: float = 0.0

## 颤动前的原始位置 / 旋转 (每帧在它们的基础上叠加, 收尾时精确回到原值)
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0

## 本次颤动的倾斜方向 (每次命中翻转, 避免连续命中看起来一直在同一边歪)
var _tilt_sign: float = -1.0

## 弹簧波形的第一个峰值高度 (用来归一化, 让 dip_ratio 正好是最大下沉量)
var _spring_peak: float = 1.0


# ---------- 节点重载函数 ----------
func _ready() -> void:
	_spring_peak = exp(-OSC_PERIOD_MS / (4.0 * OSC_DECAY_MS))
	resized.connect(_on_resized)
	set_process(false)
	_on_resized()
	pass


func _process(_delta: float) -> void:
	var elapsed: float = Global.master_time - _beat_start_ms
	if elapsed < 0.0 or elapsed >= PULSE_END_MS:
		stop()
		return

	var spring: float = _spring_at(elapsed)
	var dip: float = size.y * dip_ratio * _intensity * spring
	position = _base_position + Vector2(0.0, dip)
	rotation = _base_rotation + deg_to_rad(tilt_degrees * _intensity * spring * _tilt_sign)
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
		_base_rotation = rotation
		pass

	_intensity = clampf(intensity, 0.0, 1.0)
	_beat_start_ms = Global.master_time
	_tilt_sign = -_tilt_sign
	set_process(true)
	pass


## 立即回到原位 (heart 结束 / 重开时由 EffectManager 调用)
func stop() -> void:
	_intensity = 0.0
	position = _base_position
	rotation = _base_rotation
	set_process(false)
	pass


# ---------- 内部 ----------
## 归一化的阻尼弹簧: 0 → 1 (第一次下沉峰值) → 负值 (回弹过冲) → 逐渐收敛到 0
func _spring_at(elapsed: float) -> float:
	if elapsed < 0.0 or elapsed >= PULSE_END_MS:
		return 0.0
	var raw: float = exp(-elapsed / OSC_DECAY_MS) * sin(TAU * elapsed / OSC_PERIOD_MS)
	return raw / maxf(_spring_peak, 0.0001)


## 尺寸变化时: 把旋转中心放回控件中心; 空闲时同时记录新的原位
func _on_resized() -> void:
	pivot_offset = size * 0.5
	if not is_processing():
		_base_position = position
		_base_rotation = rotation
		pass
	pass
