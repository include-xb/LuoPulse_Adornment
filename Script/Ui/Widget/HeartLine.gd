## HeartLine 心电图折线
##
## heart 谱面效果的视觉载体: 一条经典心电图 (P-QRS-T) 折线, 从最左边起笔,
## 随玩家的打击一段段往前"画"出去 —— 打不中就不往前画, 心跳是玩家自己踩出来的。
## 画满整屏后清空, 从头再画。
##
## 相位取自 Global.master_time —— 与音符判定用的是同一个时钟, 暂停 / 继续倒计时
## 期间它会一起冻结 (笔尖那一段很短的推进动画也一起冻住)。
##
## 对外接口 (EffectManager 是当前唯一的主人):
##   beat = true  (set_beat(true))  —— 上场: 清空并从最左边起笔
##   beat = false (set_beat(false)) —— 退场: 停笔 (整体淡出由 EffectManager 写 modulate.a)
##   advance()                      —— 玩家打中一个音符, 笔尖往前画一段
##   reset_now()                    —— 立即清空 (重开游戏时用)


extends Control


class_name HeartLine


## 一段心电图的归一化模板 (x: 0~1, y: -1~1)
## INFO: 屏幕坐标 y 向下, 所以向上的波峰写负值。顺序: 基线 → P 波 → 基线 →
##       QRS 波群 → 基线 → T 波 → 基线; 首尾两点都必须落在基线上,
##       否则平铺时相邻两趟之间会多出一条竖直连线
const HEART_TEMPLATE: Array[Vector2] = [
	Vector2(0.00, 0.0),
	Vector2(0.10, 0.0),
	Vector2(0.14, -0.18),
	Vector2(0.18, 0.0),
	Vector2(0.26, 0.0),
	Vector2(0.30, 0.10),
	Vector2(0.33, -1.0),
	Vector2(0.36, 0.55),
	Vector2(0.40, 0.0),
	Vector2(0.52, 0.0),
	Vector2(0.60, -0.30),
	Vector2(0.68, 0.0),
	Vector2(0.80, 0.0),
	Vector2(1.00, 0.0),
]

## 辉光那笔相对主折线的宽度倍数
const GLOW_WIDTH_SCALE: float = 3.0

## 辉光那笔的透明度
const GLOW_ALPHA: float = 0.25

## 漏掉一个音符时笔尖往回退多少 = advance_step × 这个比例
## INFO: 半步而不是一整步 —— 一次失误不该把一次命中完全抹平, 否则准度刚好一半的
##       玩家会让心电图长期贴在零点, 特效等于没画
const REWIND_RATIO: float = 0.5


@export_group("外观")
## 折线颜色 (整体亮度由 EffectManager 写 modulate.a 控制)
@export var line_color: Color = Color(1.0, 0.35, 0.35, 1.0)

## 折线宽度 (像素)
@export_range(0.5, 12.0, 0.5) var line_width: float = 3.5

## 波形半高占控件高度的比例
@export_range(0.01, 0.5, 0.01) var amplitude_ratio: float = 0.12:
	set(value):
		amplitude_ratio = value
		_rebuild_points()
		pass

## 基线位置 (0 = 贴控件顶部, 1 = 贴底部)
@export_range(0.0, 1.0, 0.01) var baseline_ratio: float = 0.45:
	set(value):
		baseline_ratio = value
		_rebuild_points()
		pass

@export_group("推进")
## 每次打击让笔尖前进多少 (占屏宽的比例)
@export_range(0.01, 1.0, 0.01) var advance_step: float = 0.125

## 笔尖推到新位置的时长 (秒)
## INFO: 打击是瞬时的, 但笔尖要"走"过去 —— 直接跳过去会像掉帧; 0 就是瞬移。
##       密集连打时后一次推进是从前一个"目标"接着走的 (见 advance), 所以不会积压
@export_range(0.0, 0.5, 0.01) var advance_glide: float = 0.08

## 整屏画几次心跳
@export_range(1, 32, 1) var beat_count: int = 6:
	set(value):
		beat_count = value
		_rebuild_points()
		pass

@export_group("状态")
## 是否在场 —— true 时笔尖随打击往前走; false 时停笔 (什么都不显示)
@export var beat: bool = false:
	set(value):
		# INFO: 同值早退 —— 两个 heart 效果重叠时 EffectManager 会重复置 true,
		#       不早退的话心电图会从半途重新起笔
		if beat == value:
			return
		beat = value
		if beat:
			# 上场: 清空, 从最左边起笔
			_is_running = true
			_progress = 0.0
			_drawn = 0.0
			_glide_from = 0.0
			_glide_start_ms = Global.master_time
			queue_redraw()
			pass
		else:
			# 退场: 停笔 (画面上留着最后那一笔, 整体淡出由 EffectManager 的 modulate.a 负责)
			_is_running = false
			pass
		pass


## 折线全部采样点 (屏幕坐标)
var _points: PackedVector2Array = PackedVector2Array()

## 本帧实际要画的点 —— 复用同一个数组, 避免每帧新建
var _visible: PackedVector2Array = PackedVector2Array()

## 目标进度 (0~1): 每次打击推进一段, 画满就回到 0 重画
var _progress: float = 0.0

## 实际画到哪 —— 平滑地追 _progress, 不会瞬移
var _drawn: float = 0.0

## 本次推进的起点
var _glide_from: float = 0.0

## 本次推进的起始时刻 (取 Global.master_time)
var _glide_start_ms: float = 0.0

## 是否在场 (beat 为真时才画)
var _is_running: bool = false


# ---------- 节点重载函数 ----------
func _ready() -> void:
	# 纯视觉组件, 不能挡住底下的按钮 (与 Pulse 一致)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 折线按像素现算, 尺寸一变就得重建
	resized.connect(_rebuild_points)
	_rebuild_points()
	pass


func _process(_delta: float) -> void:
	if not _is_running:
		return

	var now: float = Global.master_time
	# 重开游戏时 master_time 会跳回负数, 锚点必须跟着退, 否则笔尖会僵在半路
	if now < _glide_start_ms:
		_glide_start_ms = now
		pass

	# 笔尖平滑地追到目标进度
	var glide_ms: float = maxf(advance_glide, 0.0) * 1000.0
	var t: float = 1.0
	if glide_ms > 0.0:
		t = clampf((now - _glide_start_ms) / glide_ms, 0.0, 1.0)
		pass
	_drawn = lerpf(_glide_from, _progress, _ease_out(t))

	queue_redraw()
	pass


func _draw() -> void:
	if _drawn <= 0.0 or _points.size() < 2:
		return

	var visible_x: float = size.x * _drawn

	# _points 的 x 单调递增, 所以"画到哪"就是找最后一个 x 不越界的点
	var tip: int = 0
	while tip + 1 < _points.size() and _points[tip + 1].x <= visible_x:
		tip += 1
		pass

	_visible.resize(tip + 1)
	for i: int in tip + 1:
		_visible[i] = _points[i]
		pass

	# 笔尖插值到两条采样点之间 —— 笔尖永远落在折线上, 波形末尾也不会"跳"到下一个点
	if tip + 1 < _points.size():
		var a: Vector2 = _points[tip]
		var b: Vector2 = _points[tip + 1]
		var t: float = (visible_x - a.x) / maxf(b.x - a.x, 0.001)
		_visible.append(a.lerp(b, t))
		pass

	if _visible.size() < 2:
		return

	# 两笔: 先一层粗而淡的辉光, 再画主线
	draw_polyline(_visible, Color(line_color, line_color.a * GLOW_ALPHA), line_width * GLOW_WIDTH_SCALE, true)
	draw_polyline(_visible, line_color, line_width, true)
	pass


# ---------- 对外接口 ----------
## 玩家打中一个音符: 笔尖往前画一段 (由 EffectManager 调用)
func advance() -> void:
	if not _is_running:
		return

	# 后一次从前一个"目标"接着走, 而不是从笔尖当前位置 —— 这样密集连打时
	# 几次推进不会互相拖慢, 笔尖始终平滑地往前滑
	_glide_from = _progress
	_glide_start_ms = Global.master_time

	_progress = fposmod(_progress + advance_step, 1.0)
	if _progress < advance_step:
		# 画满整屏: 清空, 从头再画
		# INFO: 这一步不做平滑 —— 否则笔尖会从右往左倒着扫回去
		_glide_from = 0.0
		_drawn = 0.0
		pass

	queue_redraw()
	pass


## 玩家漏掉一个音符: 笔尖往回退半步 (由 EffectManager 调用)
## INFO: 不能复用 advance() —— 那里靠"结果小于一个步长"判断画满一圈, 倒退也会满足
##       那个条件, 会被误判成清空、笔尖瞬间归零
func rewind() -> void:
	if not _is_running:
		return

	_glide_from = _progress
	_glide_start_ms = Global.master_time

	# 退到 0 就打住 (已经空了之后再漏也不会变成负数)
	_progress = maxf(_progress - advance_step * REWIND_RATIO, 0.0)
	queue_redraw()
	pass


## 设置 beat —— 与直接写 beat 属性等价, 给外部调用用
func set_beat(value: bool) -> void:
	beat = value
	pass


## 立即清空 (重开游戏 / 退出时由 EffectManager 调用)
func reset_now() -> void:
	beat = false
	_is_running = false
	_progress = 0.0
	_drawn = 0.0
	_glide_from = 0.0
	queue_redraw()
	pass


# ---------- 内部 ----------
## 0~1 的缓出映射 (笔尖快起慢收, 看起来像"啪"地一下画出去)
func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


## 按当前 size 把心电模板横向平铺 beat_count 次, 生成屏幕坐标的折线
func _rebuild_points() -> void:
	_points.resize(0)
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var count: int = maxi(beat_count, 1)
	var beat_width: float = size.x / float(count)
	var baseline_y: float = size.y * baseline_ratio
	var amplitude: float = size.y * amplitude_ratio

	for beat_index: int in count:
		var origin_x: float = beat_width * float(beat_index)
		for point: Vector2 in HEART_TEMPLATE:
			_points.append(Vector2(origin_x + point.x * beat_width, baseline_y + point.y * amplitude))
			pass
		pass

	queue_redraw()
	pass
