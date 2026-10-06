## HeartVignette heart 特效的屏幕边缘血色光晕
##
## 整屏覆盖一层"边缘浓、往中心淡出"的血色。强度由三部分合成后写给 shader:
##   - 底子: EffectManager 每帧写 (效果的整体淡入淡出 × heart_vignette_base)
##   - 闪动: 打中一个音符时 flash_once() 踩出来的一记, 按 FLASH_DECAY_MS 衰减
##   - 压暗: 漏掉一个音符时 dim_once() 把底子压暗, 按 MISS_DIM_RECOVER_MS 恢复
##     (压暗只作用于底子, 不影响闪动 —— miss 依旧不给任何"命中感"的东西)
##
## 相位一律取自 Global.master_time —— 暂停 / 继续倒计时期间会跟着一起冻结。
## 外观参数 (血色 / 带子的宽窄 / 最浓多少) 都在 Shader/heart_vignette.gdshader 里,
## 这里只管强度, 以及让四周带子等宽所需的宽高比。

extends ColorRect


class_name HeartVignette


## 光晕用的 shader
const VIGNETTE_SHADER: Shader = preload("res://Shader/heart_vignette.gdshader")

## 一次性闪动的衰减尺度 (毫秒; 越大余辉越长)
const FLASH_DECAY_MS: float = 260.0

## 一次性闪动衰减到这个值以下就收工 (免得永远每帧写 shader)
const FLASH_END_THRESHOLD: float = 0.01

## 漏键压暗底子的最深程度 (0 = 不压, 1 = 底子全灭)
const MISS_DIM_DEPTH: float = 0.8

## 压暗的恢复时长尺度 (毫秒; 越大暗得越久)
const MISS_DIM_RECOVER_MS: float = 220.0


## 光晕材质 (自己建一份, 不与别的节点共享)
var _material: ShaderMaterial = null

## 心电图节拍算出来的强度 (由 EffectManager 每帧写入)
var _base_intensity: float = 0.0

## 一次性闪动的强度 (0 ~ 1)
var _flash: float = 0.0

## 本次一次性闪动的起始 master_time (毫秒)
var _flash_start_ms: float = 0.0

## 是否正在跑一次性闪动 (两条都停了才关 _process)
var _flash_active: bool = false

## 底子被压暗的程度 (0 ~ 1; 由 dim_once 触发, 按 MISS_DIM_RECOVER_MS 恢复)
var _dim: float = 0.0

## 本次压暗的起始 master_time (毫秒)
var _dim_start_ms: float = 0.0

## 是否正在跑压暗 (两条都停了才关 _process)
var _dim_active: bool = false


# ---------- 节点重载函数 ----------
func _ready() -> void:
	# 纯视觉覆盖层, 不能挡住底下的触屏 (与 HeartLine / Pulse 一致)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_material = ShaderMaterial.new()
	_material.shader = VIGNETTE_SHADER
	material = _material

	# 宽高比按实际控件尺寸算, 窗口 / 分辨率一变就要重算
	resized.connect(_update_aspect)
	_update_aspect()

	# 平时不跑 _process —— 只有一次性闪动在跑的时候才需要每帧推进
	set_process(false)
	set_intensity(0.0)
	pass


func _process(_delta: float) -> void:
	var now: float = Global.master_time

	if _flash_active:
		var flash_elapsed: float = now - _flash_start_ms
		# 时钟倒流 (重开 / 切歌) 时这一记已经过期, 直接收掉
		if flash_elapsed < 0.0:
			_end_flash()
		else:
			_flash = exp(-flash_elapsed / FLASH_DECAY_MS)
			if _flash < FLASH_END_THRESHOLD:
				_end_flash()
				pass
			pass
		pass

	if _dim_active:
		var dim_elapsed: float = now - _dim_start_ms
		if dim_elapsed < 0.0:
			_end_dim()
		else:
			_dim = exp(-dim_elapsed / MISS_DIM_RECOVER_MS)
			if _dim < FLASH_END_THRESHOLD:
				_end_dim()
				pass
			pass
		pass

	_push_intensity()
	pass


# ---------- 对外接口 ----------
## 设置心电图节拍算出来的强度 (0 ~ 1); 由 EffectManager 每帧写入
func set_intensity(value: float) -> void:
	_base_intensity = clampf(value, 0.0, 1.0)
	_push_intensity()
	pass


## 漏掉一个音符: 底子暗一下 (由 EffectManager 调用)
## INFO: 已经在恢复中也照常重置 —— 连丢时每次都压到底, 读起来就是"一路在挫"
func dim_once() -> void:
	_dim = 1.0
	_dim_start_ms = Global.master_time
	_dim_active = true
	_update_process_state()
	_push_intensity()
	pass


## 手动触发一次闪动 —— 一次性, 与心电图的节拍无关
## INFO: 给"某个事件想单独闪一下屏幕边缘"预留的接口 (例如将来的谱面事件 / 剧情节点),
##       从别处调 Gameplay.heart_vignette.flash_once() 即可。
##       它与心电图那一路是**相加**的, 所以特效开着的时候也能靠它再加一记。
## @param strength: 这一记的最强倍数 (1.0 = 满强度); <= 0 直接忽略
func flash_once(strength: float = 1.0) -> void:
	if strength <= 0.0:
		# INFO: 不能拿 0 强度去"闪" —— 那会把正在衰减的那一记直接掐掉
		return

	_flash_start_ms = Global.master_time
	_flash_active = true
	_flash = clampf(strength, 0.0, 1.0)
	_update_process_state()
	_push_intensity()
	pass


# ---------- 内部 ----------
## 把"底子 (漏键时被压暗) + 一次性闪动"写给 shader
## INFO: 压暗只作用于底子 —— 命中那一记闪动照旧是满的
func _push_intensity() -> void:
	if _material == null:
		return
	var dimmed: float = _base_intensity * (1.0 - MISS_DIM_DEPTH * _dim)
	_material.set_shader_parameter("intensity", clampf(dimmed + _flash, 0.0, 1.0))
	pass


## 收掉一次性闪动
func _end_flash() -> void:
	_flash = 0.0
	_flash_active = false
	_update_process_state()
	pass


## 收掉压暗
func _end_dim() -> void:
	_dim = 0.0
	_dim_active = false
	_update_process_state()
	pass


## 闪动与压暗两条都停了, 才把 _process 关掉
func _update_process_state() -> void:
	set_process(_flash_active or _dim_active)
	pass


## 把当前控件的宽高比写给 shader, 让四周的带子像素宽度一致
func _update_aspect() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	pass
