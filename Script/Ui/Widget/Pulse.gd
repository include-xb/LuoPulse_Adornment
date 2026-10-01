extends Control

## 音频频谱条 —— 横向排列的细长圆角矩形, 高度跟随背景音乐跳动
##
## 数据来自 Master 总线上的 AudioEffectSpectrumAnalyzer。项目里所有 AudioStreamPlayer
## (包括 Global 常驻的 Bgm) 都没设 bus, 一律走 Master, 所以直接分析 Master 即可 ——
## 既不用新建 default_bus_layout.tres, 也不用动 project.godot 的音频设置。
## 分析器由本组件按需挂上, 场景反复进出也不会重复添加。
##
## 条的总数不由导出变量决定, 而是按父节点宽度算出来, 一路铺到填满为止;
## 导出变量只决定其中多少条"启用"—— 启用的随音乐跳动, 其余的平均分在左右两侧恒为最短。

## 频段范围 (Hz)
## INFO: 上限取 6k 是实测的结果 —— 本项目 bgm.ogg 在 8kHz 以上几乎没有能量, 12kHz
##       以上恒为 0, 把条分给那一段只会让最右侧常年不动, 白白占掉宽度
const MIN_FREQ: float = 40.0
const MAX_FREQ: float = 6000.0

## 归一化的分贝下限 —— 比这更弱的频段按 0 处理, 也就是把 -75dB ~ 0dB 拉伸成 0~1
## INFO: 不用线性幅值, 是因为音频能量分布极不均匀, 线性映射下整排条会常年贴着底,
##       只有最响的瞬间才弹一下。下限取 -75 同样是实测 —— 本项目 BGM 的频段幅值落在
##       0.0001 ~ 0.09 (约 -80dB ~ -21dB), 下限设得比 -75 高就等于把大半条刻度
##       浪费在一个永远取不到的区间里
const MIN_DB: float = -75.0

## 分析器挂在哪条总线上 —— 见文件头说明
const AUDIO_BUS: String = "Master"

@export_group("布局")
## 单条的宽度 (像素)
@export_range(1.0, 40.0, 0.5) var bar_width: float = 8.0:
	set(value):
		bar_width = value
		_rebuild_bars()
		pass

## 期望的条间距 (像素)
## INFO: 这只是用来估算"一共能放几条"的参考值。真正的间距会在条数定下来后反推,
##       好让首尾两条正好贴住父节点的左右边缘, 所以实际间距会和这个值差一点点
@export_range(0.0, 40.0, 0.5) var bar_gap: float = 6.0:
	set(value):
		bar_gap = value
		_rebuild_bars()
		pass

## 启用的条占总条数的比例 —— 启用的随音乐跳动, 其余的平均分在左右两侧恒为最短
## INFO: 总条数由父节点宽度决定, 所以这个比例折算出来是几条会随宽度而变;
##       无论多小都至少留 1 条启用的, 否则整排就全躺平了
@export_range(0.0, 1.0, 0.01) var enabled_ratio: float = 0.9:
	set(value):
		enabled_ratio = value
		_rebuild_bars()
		pass

## 圆角半径 (像素)
## INFO: 不要超过 bar_width 的一半, 否则矩形会变成胶囊
@export_range(0.0, 20.0, 0.5) var corner_radius: float = 3.0:
	set(value):
		corner_radius = value
		_rebuild_boxes()
		pass

@export_group("高度")
## 安静时的最小高度, 让条始终看得见
@export_range(0.0, 100.0, 1.0) var min_height: float = 6.0

## 音量拉满时的最大高度
@export_range(1.0, 300.0, 1.0) var max_height: float = 80.0

## 基线位置 (0 = 贴控件顶部, 1 = 贴底部), 条从基线向上生长
@export_range(0.0, 1.0, 0.01) var baseline_ratio: float = 0.5

@export_group("外观")
## 条的基色
@export var bar_color: Color = Color(0.4, 0.8, 1.0, 1.0):
	set(value):
		bar_color = value
		_rebuild_boxes()
		pass

## 从左到右的色相偏移 (度), 0 表示所有条同色
@export_range(0.0, 360.0, 1.0) var hue_shift: float = 0.0:
	set(value):
		hue_shift = value
		_rebuild_boxes()
		pass

@export_group("响应")
## 灵敏度 —— 觉得跳得太弱就调大
@export_range(0.1, 10.0, 0.1) var gain: float = 1.2

## 抬升速度 (高度/秒) —— 越大越跟手
@export_range(0.5, 60.0, 0.5) var attack_speed: float = 30.0

## 回落速度 (高度/秒) —— 越小拖尾越长
@export_range(0.1, 60.0, 0.5) var release_speed: float = 5.0

## 当前一共有多少条 —— 按父节点宽度铺满算出来的, 不是导出变量
## 初值给 0 是为了让第一次 _rebuild_bars 一定会重建 StyleBox
var _bar_count: int = 0

## 左侧未启用的条数
var _idle_left: int = 0

## 实际启用的条数 —— 由 enabled_ratio 折算而来, 至少 1 条
var _active_count: int = 1

## 每条当前的高度比例 (0~1), 做平滑用
var _levels: PackedFloat32Array = PackedFloat32Array()

## 每条预建的圆角 StyleBox —— 预建是为了避免每帧新建 N 个对象
var _boxes: Array[StyleBoxFlat] = [ ]

## Master 总线上的频谱分析器实例, 取不到时为 null (此时条静止在 min_height)
var _analyzer: AudioEffectSpectrumAnalyzerInstance = null


func _ready() -> void:
	# 纯视觉组件, 不能挡住底下的按钮
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 条数由宽度决定, 尺寸一变就得重算
	resized.connect(_rebuild_bars)
	_ensure_analyzer()
	_rebuild_bars()
	pass


## 每帧取样 + 重绘
## INFO: 用 _process 而非 _physics_process —— 这是纯视觉反馈, 跟着渲染帧走即可
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_update_levels(delta)
	queue_redraw()
	pass


func _draw() -> void:
	var baseline_y: float = size.y * baseline_ratio
	# 反推实际间距, 让第一条贴左边缘、最后一条贴右边缘
	var step: float = 0.0
	if _bar_count > 1:
		step = (size.x - bar_width) / float(_bar_count - 1)

	for i: int in _bar_count:
		var bar_height: float = lerpf(min_height, max_height, _levels[i])
		var bar_rect: Rect2 = Rect2(
			float(i) * step,
			baseline_y - bar_height,
			bar_width,
			bar_height,
		)
		draw_style_box(_boxes[i], bar_rect)
		pass
	pass


# ---------- 频谱取样 ----------
## 确保 Master 总线上有一个频谱分析器, 并把实例取到 _analyzer
## INFO: 每次进来都现找而不是缓存 —— 总线上通常只有 0~2 个效果器, 扫描很便宜,
##       而缓存会在效果器被移除后留下一个取不到数据的死引用
func _ensure_analyzer() -> void:
	var bus_index: int = AudioServer.get_bus_index(AUDIO_BUS)
	if bus_index < 0:
		push_error("找不到音频总线: %s" % AUDIO_BUS)
		return

	for i: int in AudioServer.get_bus_effect_count(bus_index):
		if AudioServer.get_bus_effect(bus_index, i) is AudioEffectSpectrumAnalyzer:
			_analyzer = AudioServer.get_bus_effect_instance(bus_index, i) as AudioEffectSpectrumAnalyzerInstance
			return
		pass

	AudioServer.add_bus_effect(bus_index, AudioEffectSpectrumAnalyzer.new())
	_analyzer = AudioServer.get_bus_effect_instance(
		bus_index,
		AudioServer.get_bus_effect_count(bus_index) - 1,
	) as AudioEffectSpectrumAnalyzerInstance
	pass


## 取样并做"快起慢落"的平滑
## INFO: 直接取瞬时值会抖得像噪声。这里上升直奔目标、下降按 release_speed 缓慢回落,
##       于是鼓点立刻弹起、余韵拖出一条尾巴, 这是频谱条好看的关键
func _update_levels(delta: float) -> void:
	if _analyzer == null:
		return

	for i: int in _bar_count:
		var target: float = _sample_band(i)
		var current: float = _levels[i]
		if target > current:
			current = minf(target, current + attack_speed * delta)
			pass
		else:
			current = maxf(target, current - release_speed * delta)
			pass
		_levels[i] = current
		pass
	pass


## 第 index 条的能量, 归一化到 0~1
## INFO: 频段按对数切分 —— 人耳感知频率本来就是对数的, 线性等宽切分会让低频全挤在
##       头几条里, 一侧一片死寂
## INFO: 频段只在中间 _active_count 条之间切分, 左右未启用的条直接返回 0, 于是它们的
##       高度停在 min_height, 而启用的那一段仍然铺满整个频段范围, 不会被挤窄
func _sample_band(index: int) -> float:
	if index < _idle_left or index >= _idle_left + _active_count:
		return 0.0

	# 这条在"启用的那些条"里排第几 (0 起)
	var band: int = index - _idle_left
	var ratio: float = MAX_FREQ / MIN_FREQ
	var from_hz: float = MIN_FREQ * pow(ratio, float(band) / float(_active_count))
	var to_hz: float = MIN_FREQ * pow(ratio, float(band + 1) / float(_active_count))

	var magnitude: Vector2 = _analyzer.get_magnitude_for_frequency_range(from_hz, to_hz)
	var level: float = (magnitude.x + magnitude.y) * 0.5
	# linear_to_db(0) 是 -inf, 垫一个够小的值兜住
	var db: float = linear_to_db(maxf(level, 0.000001))
	return clampf((db - MIN_DB) / -MIN_DB * gain, 0.0, 1.0)


# ---------- 条与样式 ----------
## 按父节点宽度算出条数, 划出中间启用段与两侧未启用段, 再重建电平数组与 StyleBox
func _rebuild_bars() -> void:
	var old_count: int = _bar_count
	# 铺满宽度能放几条: 首尾各占一条, 所以是 (宽度 + 一个间距) / 一个步长
	_bar_count = maxi(1, int(floor((size.x + bar_gap) / (bar_width + bar_gap))))
	_active_count = clampi(int(round(_bar_count * enabled_ratio)), 1, _bar_count)
	# 未启用的平均分到两侧, 除不尽时右边多一条
	_idle_left = int((_bar_count - _active_count) * 0.5)

	# 条数没变就不用重建对象 —— 拖窗口时 resized 会连着来, 每次都 new 一遍太浪费
	if _bar_count != old_count:
		_levels.resize(_bar_count)
		_rebuild_boxes()
		pass
	pass


## 重建每条预建的圆角 StyleBox
## INFO: 只重建 StyleBox 不动 _levels —— 改颜色时没必要让动画重新爬升
func _rebuild_boxes() -> void:
	_boxes.clear()
	var radius: int = int(round(corner_radius))
	for i: int in _bar_count:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = _bar_color_at(i)
		box.set_corner_radius_all(radius)
		_boxes.append(box)
		pass
	pass


## 第 index 条的颜色 —— hue_shift 为 0 时所有条同色
func _bar_color_at(index: int) -> Color:
	if is_zero_approx(hue_shift) or _bar_count <= 1:
		return bar_color
	var t: float = float(index) / float(_bar_count - 1)
	var hue: float = fmod(bar_color.h + hue_shift * t / 360.0, 1.0)
	return Color.from_hsv(hue, bar_color.s, bar_color.v, bar_color.a)
