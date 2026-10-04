## HeartLine 心电图折线
##
## heart 谱面效果的视觉载体: 沿一条经典心电图 (P-QRS-T) 折线从左向右"画"出去,
## 画满整屏后停留片刻, 再清空重画一趟 —— 就这样一趟接一趟地跳动。
## 停机不是立刻断掉: 等当前这一趟画完才清空, 所以"停止"永远落在折线的末端。
##
## 相位取自 Global.master_time —— 与音符判定用的是同一个时钟, 暂停 / 继续倒计时
## 期间它会一起冻结, 不会在暂停面板后面继续跳。
##
## 对外接口 (EffectManager 是当前唯一的主人):
##   beat = true  (set_beat(true))  —— 开始跳动, 从最左边重新起笔
##   beat = false (set_beat(false)) —— 等本趟画完再清空停机
##   reset_now()                    —— 立即清空停机 (重开游戏时用)


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

@export_group("节奏")
## 一趟画完整屏的时长 (秒)
@export_range(0.1, 20.0, 0.1) var sweep_duration: float = 3.0

## 两趟之间的停留时长 (秒): 停留期间保留画好的整条波形
@export_range(0.0, 20.0, 0.1) var rest_duration: float = 0.4

## 整屏画几次心跳
@export_range(1, 32, 1) var beat_count: int = 6:
	set(value):
		beat_count = value
		_rebuild_points()
		pass

@export_group("状态")
## 是否持续跳动 —— true 时一趟接一趟地画; false 时等本趟画完就清空停机 (什么都不显示)
@export var beat: bool = false:
	set(value):
		# INFO: 同值早退 —— 两个 heart 效果重叠时 EffectManager 会重复置 true,
		#       不早退的话心电图会从半途重新起笔
		if beat == value:
			return
		beat = value
		if beat:
			_is_running = true
			_sweep_start_ms = Global.master_time
			queue_redraw()
			pass
		pass


## 折线全部采样点 (屏幕坐标)
var _points: PackedVector2Array = PackedVector2Array()

## 本帧实际要画的点 —— 复用同一个数组, 避免每帧新建
var _visible: PackedVector2Array = PackedVector2Array()

## 本趟画到哪 (0~1)
var _progress: float = 0.0

## 本趟的相位起点 (取 Global.master_time)
var _sweep_start_ms: float = 0.0

## 是否正在跑 —— beat 置 false 后仍会跑到本趟结束
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
	# 重开游戏时 master_time 会跳回负数, 相位必须重新锚定, 否则要等很久才会再画
	if now < _sweep_start_ms:
		_sweep_start_ms = now
		pass

	var sweep: float = maxf(sweep_duration, 0.001) * 1000.0

	# 本趟画完且不再重复 —— 清空停机 (什么都不显示)
	if not beat and now - _sweep_start_ms >= sweep:
		_is_running = false
		_progress = 0.0
		queue_redraw()
		return

	# 一趟 + 停留跑满, 开新一趟
	if now - _sweep_start_ms >= sweep + maxf(rest_duration, 0.0) * 1000.0:
		_sweep_start_ms = now
		pass

	_progress = clampf((now - _sweep_start_ms) / sweep, 0.0, 1.0)
	queue_redraw()
	pass


func _draw() -> void:
	if _progress <= 0.0 or _points.size() < 2:
		return

	var visible_x: float = size.x * _progress

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
## 设置 beat —— 与直接写 beat 属性等价, 给外部调用用
func set_beat(value: bool) -> void:
	beat = value
	pass


## 立即清空停机 (重开游戏 / 退出时由 EffectManager 调用)
func reset_now() -> void:
	beat = false
	_is_running = false
	_progress = 0.0
	queue_redraw()
	pass


# ---------- 折线 ----------
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
