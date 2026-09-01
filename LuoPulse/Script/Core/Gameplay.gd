## Gameplay 游戏界面
##
## 可以切换到这里的场景:
## 		- Sympathy 共鸣主线
## 		- Album 专辑主线
## 		- FinshMenu 结算界面
## 		- CardMenu 资料卡界面
## 从这里可以前往: 
## 		- Sympathy 共鸣主线
## 		- Album 专辑主线
## 		- FinshMenu 结算界面
## 		- CardMenu 资料卡界面


extends Control


## 重要播放器, 播放音频
@onready var audio_system: AudioStreamPlayer = $"AudioSystem"

## 谱面音符加载器
@onready var note_loader: NoteLoader = $"NoteLoader"

## 进度条
@onready var progress_bar: ProgressBar = $"UI/ProgressBar"

## 背景图
@onready var background: TextureRect = $UI/Background

## PV 播放器
@onready var video_stream_player: VideoStreamPlayer = $UI/VideoStreamPlayer

## 3D 视图窗口
@onready var _subviewport: SubViewport = $UI/TextureRect/SubViewport

## 3D 场景中的摄像机
@onready var _camera: Camera3D = $UI/TextureRect/SubViewport/Node3D/Camera3D

## 轨道部分
@onready var _track: Node3D = $UI/TextureRect/SubViewport/Node3D/Track

## UI 节点
@onready var _ui: Control = $UI

## 连击数标签
@onready var _combo_label: Label = $UI/Combo

## 暂停按钮
@onready var _pause_button: Button = $"UI/PauseButton"

## 暂停界面
@onready var _pause_panel: PanelContainer = $"UI/PausePanel"

## autoplay 标签
@onready var autoplay: Label = $UI/MarginContainer/HBoxContainer/Autoplay

## username 标签
@onready var username: Label = $UI/MarginContainer/HBoxContainer/Username

## 音符流速大小标签 (-20 ~ 20)
@onready var speed_label: Label = $UI/PausePanel/CenterContainer/VBoxContainer/Speed/HBoxContainer/SpeedLabel

## 音符流速大小滑动条
@onready var speed_scroll_bar: HSlider = $UI/PausePanel/CenterContainer/VBoxContainer/Speed/HBoxContainer/SpeedScrollBar

## 第一个音符到达判定线倒计时标签
@onready var tick: Label = $UI/Tick

## 结束按钮
@onready var finish_button_mask: ColorRect = $UI/Mask


## 解析完成的谱面数据
var chart: Array = [ ]

## 主时间 (ms), 基于音频播放位置, 是判定和音符定位的唯一时钟源
var master_time: float = -3000.0

## 开始计时的时间, 与 Time.get_ticks_msec() 相减得到运行时间
var start_time: int = 0

## 总音符数
var total_notes: int = 0

## 当前加载的音符索引
var current_note_index: int = 0

## 音符时间列表
var time_list: Array = [ ]

## 音符类型列表
var type_list: Array = [ ]

## 音符持续时间列表
var duration_list: Array = [ ]

## 音符所在列列表
var column_list: Array = [ ]

## 是否正在加载
var is_loading_note: bool = true

## 音频是否开始播放
var is_audio_start: bool = false

## 音频总时长 (毫秒)
var audio_length: int = 0

# 四类判定等级
## 和一
var harmonious: int = 0
## 共鸣
var sympathetic: int = 0
## 觉醒
var aware: int = 0
## 丢失
var lost: int = 0

## 是否正在游戏
var is_gaming: bool = true

## 暂停时记录的音频播放位置 (秒)
var _pause_playback_position: float = 0.0

## 暂停时记录的 tick (用于补偿非音频阶段的暂停时间)
var _pause_frozen_tick: int = 0

## 暂停面板是否正在显示
var _is_pause_panel_visible: bool = false

## 倒计时状态
var _is_counting_down: bool = false
var _countdown_remaining: float = 0.0
const COUNTDOWN_DURATION: float = 3.0

## 显示倒计时的标签
var _countdown_label: Label = null

## 各列的 InputProcesser 引用
var input_processers: Array = [ ]

## 触屏状态追踪 (touch_index -> column)
var active_touches: Dictionary = { }

## 轨道在屏幕空间的 X 范围 (通过摄像机投影计算)
var _track_screen_min: float = 0.0
var _track_screen_max: float = 0.0

## 第一个音符到达判定线时间
var first_note_time: int = 0

## 最后一个音符到达判定线时间
var last_note_time: int = 0

## 多押提示
var mulit_tap: bool = false

## ---- 判定视觉反馈 ----
const JUDGMENT_TEXT: Dictionary = {
	"harmonious": "和一",
	"sympathetic": "共鸣",
	"aware": "觉醒",
	"lost": "丢失",
}

## 不同判定反馈词颜色
const JUDGMENT_COLORS: Dictionary = {
	"harmonious": Color("6bca6bff"),
	"sympathetic": Color("66b3ffff"),
	"aware": Color("ffd94dff"),
	"lost": Color("999999ff"),
}

## 过早点击反馈词颜色
const EARLY_COLOR: Color = Color(0.4, 0.7, 1.0, 1.0)
## 过晚点击反馈词颜色
const LATE_COLOR: Color = Color(1.0, 0.4, 0.4, 1.0)

## 显示反馈词时长
const FEEDBACK_DURATION: float = 0.2
## 显示反馈词的 Y 轴偏移
const FEEDBACK_FLOAT_Y: float = 30.0
## 显示反馈词的字体大小
const FEEDBACK_FONT_SIZE: int = 32

## 桌面键盘按键映射 (开发调试用)
const KEY_COLUMN_MAP: Dictionary = {
	KEY_D: 0,
	KEY_F: 1,
	KEY_J: 2,
	KEY_K: 3,
}

## 用于展示反馈信息标签
var _judgment_container: Control = null
## 反馈信息标签对象池
var _feedback_labels: Array[Label] = [ ]
## 反馈信息标签索引, 用于在对象池中循环复用标签的索引
var _feedback_index: int = 0
## 最多可以同时显示的反馈信息标签数量
var _max_feedback_labels: int = 8


# ---------- 测试场景 ----------
## 用于测试
var default_chart: Array = [
		{
			"type": "tap",
			"time": 1071,
			"column": 2
		},
		{
			"type": "tap",
			"time": 1071,
			"column": 4
		},
		{
			"type": "tap",
			"time": 1368,
			"column": 1
		},
		{
			"type": "tap",
			"time": 1368,
			"column": 3
		},
		{
			"type": "tap",
			"time": 1664,
			"column": 2
		},
		{
			"type": "tap",
			"time": 1664,
			"column": 4
		},
		{
			"type": "tap",
			"time": 1861,
			"column": 1
		},
		{
			"type": "tap",
			"time": 2058,
			"column": 3
		},
		{
			"type": "tap",
			"time": 2256,
			"column": 2
		},
		{
			"type": "tap",
			"time": 2453,
			"column": 4
		},
		{
			"type": "tap",
			"time": 2650,
			"column": 1
		},
		{
			"type": "tap",
			"time": 2650,
			"column": 3
		},
		{
			"type": "tap",
			"time": 2946,
			"column": 2
		},
		{
			"type": "tap",
			"time": 2946,
			"column": 4
		},
		{
			"type": "tap",
			"time": 3243,
			"column": 1
		},
		{
			"type": "tap",
			"time": 3243,
			"column": 3
		},
		{
			"type": "tap",
			"time": 3440,
			"column": 4
		},
		{
			"type": "tap",
			"time": 3637,
			"column": 4
		},
		{
			"type": "tap",
			"time": 3835,
			"column": 1
		},
		{
			"type": "tap",
			"time": 4032,
			"column": 1
		},
		{
			"type": "tap",
			"time": 4229,
			"column": 2
		},
		{
			"type": "tap",
			"time": 4229,
			"column": 4
		},
		{
			"type": "tap",
			"time": 4525,
			"column": 1
		},
		{
			"type": "tap",
			"time": 4525,
			"column": 3
		},
		{
			"type": "tap",
			"time": 4821,
			"column": 2
		},
		{
			"type": "tap",
			"time": 4821,
			"column": 4
		},
		{
			"type": "tap",
			"time": 5019,
			"column": 1
		},
		{
			"type": "tap",
			"time": 5216,
			"column": 3
		},
		{
			"type": "tap",
			"time": 5414,
			"column": 2
		},
		{
			"type": "tap",
			"time": 5611,
			"column": 4
		},
		{
			"type": "tap",
			"time": 5808,
			"column": 1
		},
		{
			"type": "tap",
			"time": 5808,
			"column": 3
		},
		{
			"type": "tap",
			"time": 6104,
			"column": 2
		},
		{
			"type": "tap",
			"time": 6104,
			"column": 4
		},
		{
			"type": "tap",
			"time": 6400,
			"column": 1
		},
		{
			"type": "tap",
			"time": 6400,
			"column": 3
		},
		{
			"type": "tap",
			"time": 6598,
			"column": 4
		},
		{
			"type": "tap",
			"time": 6795,
			"column": 4
		},
		{
			"type": "tap",
			"time": 6993,
			"column": 1
		},
		{
			"type": "tap",
			"time": 7190,
			"column": 1
		},
		{
			"type": "tap",
			"time": 7387,
			"column": 2
		},
		{
			"type": "tap",
			"time": 7387,
			"column": 4
		},
		{
			"type": "tap",
			"time": 7683,
			"column": 1
		},
		{
			"type": "tap",
			"time": 7683,
			"column": 3
		},
		{
			"type": "tap",
			"time": 7979,
			"column": 2
		},
		{
			"type": "tap",
			"time": 7979,
			"column": 4
		},
		{
			"type": "tap",
			"time": 8177,
			"column": 1
		},
		{
			"type": "tap",
			"time": 8374,
			"column": 3
		},
		{
			"type": "tap",
			"time": 8571,
			"column": 2
		},
		{
			"type": "tap",
			"time": 8769,
			"column": 4
		},
		{
			"type": "tap",
			"time": 8966,
			"column": 1
		},
		{
			"type": "tap",
			"time": 8966,
			"column": 3
		}]
## 是否处于测试模式, 若为 true, 则可以直接运行 Gameplay 场景
var is_test: bool = !true

## 测试画面
func test() -> void:
	var audio_stream: AudioStream = audio_system.stream
	audio_length = int(audio_stream.get_length() * 1000)
	print("audio_stream: " + str(audio_system.stream == null))
	chart = default_chart
	total_notes = len(chart)
	pass


# ---------- 节点重载函数 ----------
func _ready() -> void:
	_calculate_track_screen_bounds()
	_reset_judging_stats()
	_setup_judgment_feedback()
	_collect_input_processers()
	_setup_countdown_label()
	reset_speed()

	video_stream_player	.visible = true
	tick				.visible = false
	finish_button_mask	.visible = false
	_pause_panel		.visible = false
	_pause_button		.disabled = true
	autoplay			.visible = Global.is_autoplay
	_pause_panel.modulate.a = 0.0
	username.text = Global.user_name
	
	if is_test == false:
		# 从当前选择的曲包中加载谱面数据
		load_list()
		# 将谱面数据写入到各数组中
		write_in_list()
		pass
	else:
		# 测试功能
		test()
		write_in_list()
		pass
	# 获取头尾音符时间
	get_first_last_note_time()
	
	# 若第一个音符到达判定线所需时间超过 2500ms, 则显示
	if first_note_time >= 1000:
		tick.visible = true
		pass

	# 记录程序起始时间 (仅用于预加载段的计时)
	start_time = Time.get_ticks_msec()
	pass


func _process(delta: float) -> void:
	if not _is_counting_down:
		_update_master_time()
		pass

	if not is_gaming:
		if _is_counting_down:
			_countdown_tick(delta)
			pass
		return

	# 音视频启动
	if is_audio_start == false && master_time >= 0.0:
		audio_system.play()
		if video_stream_player.stream != null && Global.is_pvplay:
			video_stream_player.play()
			pass
		else:
			video_stream_player.visible = false
			pass
		is_audio_start = true
		_pause_button.disabled = false
		pass

	# 加载音符
	if is_loading_note:
		load_note_process()
		pass
	
	# 首个音符倒计时
	if tick.visible:
		tick.text = "%.2fs" % ((master_time - first_note_time) / 1000)
		if master_time >= first_note_time:
			tick.visible = false
			pass
		pass

	# 背景色彩变化
	var current_progress: float = clampf(master_time / float(audio_length), 0.0, 1.0)
	progress_bar.value = current_progress * 100.0
	video_stream_player.material.set_shader_parameter(
		"gray_scale",
		(1.0 - current_progress) * 0.6
	)
	background.material.set_shader_parameter(
		"gray_scale",
		(1.0 - current_progress) * 0.6
	)

	# 结束游戏 # NOTICE 修改为手动结束游戏
	if master_time >= last_note_time + 1000 && is_gaming:
		show_finish_btn()
		pass

	# 追踪最大连击数
	if Global.combo > Global.max_combo:
		Global.max_combo = Global.combo
		pass
		

	if Global.combo != 0:
		_combo_label.visible = true
		_combo_label.text = str(Global.combo) + " COMBO"
	else :
		_combo_label.visible = false
	pass


func _input(event: InputEvent) -> void:
	if not is_gaming:
		return
	
	# 获取当前时刻的主时间 (解决 _input 比 _process 先执行的延迟问题)
	var input_time: float = _compute_master_time()

	# 触屏事件处理
	if event is InputEventScreenTouch:
		if finish_button_mask.visible == true:
			return
		var btn_rect: Rect2 = _pause_button.get_global_rect()
		if btn_rect.has_point(event.position):
			return
		
		var col: int = _get_column_from_x(event.position.x)
		if col >= 0:
			if event.pressed:
				active_touches[event.index] = col
				_on_column_touch_pressed(col, input_time)
				pass
			else:
				if active_touches.has(event.index):
					var released_col: int = active_touches[event.index]
					active_touches.erase(event.index)
					_on_column_touch_released(released_col, input_time)
					pass
				pass
			pass
		pass

	# 桌面键盘输入 (开发调试用)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _pause_button.disabled == true:
			return
		if _is_counting_down:
			return
		
		if _is_pause_panel_visible:
			_on_continue_button_pressed()
			pass
		else:
			_on_pause_button_pressed()
			pass
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		_on_finish_button_pressed()
		pass

	if event is InputEventKey and event.pressed and not event.echo:
		var col: int = _get_column_from_key(event)
		if col >= 0:
			_on_column_touch_pressed(col, input_time)
			pass
		pass

	if event is InputEventKey and not event.echo and not event.pressed:
		var col: int = _get_column_from_key(event)
		if col >= 0:
			_on_column_touch_released(col, input_time)
			pass
		pass
	pass


# ---------- 工具函数 ----------
## 通过轨道编号获取相应的轨道 Column
func get_input_processor(column: int) -> Node3D:
	if column >= 0 and column < input_processers.size():
		return input_processers[column]
	return null


# ---------- 自动播放 ----------
## 自动播放时的轨道点击反馈 (column 为 1-based 音符列)
func flash_track_feedback(column: int) -> void:
	var processor: Node3D = get_input_processor(column - 1)
	if processor and processor.has_method("flash_track"):
		processor.flash_track()
		pass
	pass


## 自动播放 hold: 设置轨道按住状态 (column 为 1-based 音符列)
func set_track_autoplay_hold(column: int, is_active: bool) -> void:
	var processor: Node3D = get_input_processor(column - 1)
	if processor and processor.has_method("set_autoplay_hold"):
		processor.set_autoplay_hold(is_active)
		pass
	pass


# ---------- 计时器 ----------
## 更新主时间, 同步到 Global
func _update_master_time() -> void:
	master_time = _compute_master_time()
	# NOTICE: 为什么已经将 master_time 传入 Global 了, 还需要引用 root_node 获取 master_time
	Global.master_time = master_time 
	pass


## 计算主时间
func _compute_master_time() -> float:
	if is_audio_start:
		return audio_system.get_playback_position() * 1000.0 + float(Global.chart_offset)
	return float(Time.get_ticks_msec() - start_time) - float(Global.start_duration)


# ---------- 捕捉轨道点击 ----------
## 获取每个轨道的 Column 引用
func _collect_input_processers() -> void:
	for i in range(Global.COLUMN_NUM):
		var column_node: Node3D = _track.get_node("Column" + str(i + 1))
		input_processers.append(column_node)
		pass
	pass


## 计算轨道在屏幕上的边界
func _calculate_track_screen_bounds() -> void:
	var col_count: int = Global.COLUMN_NUM
	var half_width: float = float(col_count) / 2.0

	var left_point: Vector3 = Vector3(-half_width, 0.0, 0.0)
	var right_point: Vector3 = Vector3(half_width, 0.0, 0.0)

	var left_vp: Vector2 = _camera.unproject_position(left_point)
	var right_vp: Vector2 = _camera.unproject_position(right_point)

	if is_inf(left_vp.x) or is_inf(right_vp.x):
		_track_screen_min = 0.0
		_track_screen_max = get_viewport().get_visible_rect().size.x
		return

	var vp_w: float = float(_subviewport.size.x)
	var screen_w: float = get_viewport().get_visible_rect().size.x
	var _scale: float = screen_w / vp_w

	_track_screen_min = left_vp.x * _scale
	_track_screen_max = right_vp.x * _scale
	pass


## 根据点击位置的 X 坐标获取被点击的轨道编号
func _get_column_from_x(x: float) -> int:
	var col_count: int = Global.COLUMN_NUM
	var _range: float = _track_screen_max - _track_screen_min
	if _range <= 0.0:
		_range = get_viewport().get_visible_rect().size.x
	var normalized: float = (x - _track_screen_min) / _range
	var col: int = int(normalized * float(col_count))
	if col >= 0 and col < col_count:
		return col
	return -1


## 根据键盘按键获取被点击的轨道编号
func _get_column_from_key(event: InputEventKey) -> int:
	if KEY_COLUMN_MAP.has(event.keycode):
		return KEY_COLUMN_MAP[event.keycode]
	return -1


## 这个函数在干嘛?
func _get_column_screen_x(column: int) -> float:
	var col_count: int = Global.COLUMN_NUM
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var track_width: float = _track_screen_max - _track_screen_min
	if track_width <= 0.0:
		track_width = viewport_width * 0.5
		_track_screen_min = (viewport_width - track_width) * 0.5
		pass
	var col_norm: float = (float(column) - 0.5) / float(col_count)
	return _track_screen_min + col_norm * track_width


## 获取判定线在屏幕上的 Y 坐标
func _get_judgment_line_y() -> float:
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	return viewport_height * 0.78


## 触屏事件: 按下
func _on_column_touch_pressed(column: int, input_time: float) -> void:
	var processor: Node3D = get_input_processor(column)
	if processor and processor.has_method("on_touch_pressed"):
		processor.on_touch_pressed(input_time)
		pass
	pass


## 触屏事件: 释放
func _on_column_touch_released(column: int, input_time: float) -> void:
	var processor: Node3D = get_input_processor(column)
	if processor and processor.has_method("on_touch_released"):
		processor.on_touch_released(input_time)
		pass
	pass


# ---------- 音符加载 ----------
## 加载音符总过程
func load_note_process() -> void:
	# 结束加载
	if current_note_index >= total_notes:
		is_loading_note = false
		return

	var note_time: float = float(time_list[current_note_index])
	var load_deadline: float = note_time - float(Global.start_duration)

	if master_time < load_deadline:
		return

	# 相同时间的音符, 一并加载
	var batch_time: float = note_time

	# 统计同时间音符数量, 决定是否为多压 (避免"向后看"漏掉组内最后一个音符)
	var batch_count: int = 0
	var probe: int = current_note_index
	while probe < total_notes and float(time_list[probe]) == batch_time:
		batch_count += 1
		probe += 1
		pass
	var is_multi: bool = batch_count >= 2

	while current_note_index < total_notes and float(time_list[current_note_index]) == batch_time:
		load_note(current_note_index, current_note_index, is_multi)
		current_note_index += 1
		pass

	# 结束加载
	if current_note_index >= total_notes:
		is_loading_note = false
		pass
	pass


## 从当前选择的曲包中加载谱面数据
func load_list() -> void:
	var path: String = Global.sympath_song_path_list[Global.current_song_index]
	var lpz: Dictionary = Global._read_lpz(path)

	background.texture = lpz["cover"]
	audio_system.stream = lpz["audio"]
	audio_length = int(lpz["audio"].get_length() * 1000)
	chart = lpz["chart"].get("HitObjects")
	video_stream_player.stream = lpz["video"]
	pass


## 将谱面数据写入到各数组中
func write_in_list() -> void:
	total_notes = len(chart)
	for i: Dictionary in chart:
		var time: int = i.get("time")
		var type: String = i.get("type")
		var column: int = i.get("column")
		var duration: int = i.get("duration", 0)
		time_list.append(time)
		type_list.append(type)
		column_list.append(column)
		duration_list.append(duration)
		pass
	pass


## 获取头尾音符时间
func get_first_last_note_time() -> void:
	first_note_time = time_list[0]
	last_note_time = time_list[-1]
	pass


## 重置各类判定数据
func _reset_judging_stats() -> void:
	Global.harmonious = 0
	Global.sympathetic = 0
	Global.aware = 0
	Global.lost = 0
	Global.total_judged = 0
	Global.combo = 0
	Global.accuracy = 0.0
	Global.max_combo = 0
	Global.judging_area = [ ]
	Global.rendering_area = [ ]
	_feedback_index = 0
	pass


## 重新封装 load_note 方法，方便外部调用
func load_note(note_index: int, index: int, is_mulit_tap: bool = false) -> void:
	note_loader.load_note(
		type_list[note_index],
		time_list[note_index],
		duration_list[note_index],
		column_list[note_index],
		index,
		_track,
		self, 
		is_mulit_tap
	)
	pass


# ---------- 判定反馈 ----------
## 初始化判定反馈
func _setup_judgment_feedback() -> void:
	_judgment_container = Control.new()
	_judgment_container.anchor_left = 0.0
	_judgment_container.anchor_right = 1.0
	_judgment_container.anchor_top = 0.0
	_judgment_container.anchor_bottom = 1.0
	_judgment_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_judgment_container)

	# 初始化反馈信息标签
	for _i in range(_max_feedback_labels):
		var lbl: Label = Label.new()
		lbl.add_theme_font_size_override("font_size", FEEDBACK_FONT_SIZE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.visible = false
		lbl.modulate.a = 0.0
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_judgment_container.add_child(lbl)
		_feedback_labels.append(lbl)
		pass
	pass


## 展示判定反馈信息标签
func show_judgment_feedback(time_offset: int, judgment_level: String, column: int) -> void:
	var lbl: Label = _feedback_labels[_feedback_index]
	_feedback_index = (_feedback_index + 1) % _max_feedback_labels

	# 终止旧动画
	var old_tween: Tween = null
	if lbl.has_meta("_feedback_tween"):
		old_tween = lbl.get_meta("_feedback_tween")
		if old_tween and old_tween.is_valid():
			old_tween.kill()
			pass
		pass

	# 判断文字
	var jtext: String = JUDGMENT_TEXT.get(judgment_level, "丢失")
	var jcolor: Color = JUDGMENT_COLORS.get(judgment_level, Color.GRAY)

	var early_late_text: String = ""
	var text_color: Color = jcolor

	if judgment_level != "lost":
		if time_offset < 0:
			early_late_text = "▲ EARLY"
			text_color = jcolor
			pass
		elif time_offset > 0:
			early_late_text = "▼ LATE"
			text_color = jcolor
			pass
		pass

	var display_text: String = jtext
	if early_late_text != "":
		display_text = early_late_text + "\n" + jtext
		pass

	lbl.text = display_text
	lbl.add_theme_color_override("font_color", text_color)

	var screen_x: float = _get_column_screen_x(column)
	lbl.position = Vector2(screen_x - 60.0, _get_judgment_line_y())
	lbl.size = Vector2(120, 50)
	lbl.visible = true
	lbl.modulate.a = 1.0

	var tween: Tween = create_tween()
	lbl.set_meta("_feedback_tween", tween)
	tween.set_parallel(true)
	if time_offset > 0:
		tween.tween_property(lbl, "position:y", lbl.position.y + FEEDBACK_FLOAT_Y, FEEDBACK_DURATION)
		pass
	elif time_offset < 0:
		tween.tween_property(lbl, "position:y", lbl.position.y - FEEDBACK_FLOAT_Y, FEEDBACK_DURATION)
		pass
	else:
		lbl.text = "◇ " + jtext
		pass
	tween.tween_property(lbl, "modulate:a", 0.0, FEEDBACK_DURATION).set_ease(Tween.EASE_IN).set_delay(0.15)
	pass


# ---------- 结束游戏 ----------
## 显示结束按钮
func show_finish_btn() -> void:
	finish_button_mask.visible = true
	pass


## 结束
func _on_finish_button_pressed() -> void:
	Global.play_ui_click_audio()
	if not is_gaming:
		return
	is_gaming = false

	var acc: float = Global.accuracy
	var grade_info: Dictionary = Global.get_grade(acc)
	var crystal_earned: int = Global.get_crystal_reward(acc)

	# 存储结果到 Global
	Global.gameplay_result = {
		"accuracy": acc,
		"grade": grade_info["grade"],
		"grade_color": grade_info["color"],
		"harmonious": Global.harmonious,
		"sympathetic": Global.sympathetic,
		"aware": Global.aware,
		"lost": Global.lost,
		"max_combo": Global.max_combo,
		"total_notes": total_notes,
		"crystal_earned": crystal_earned,
	}

	Global.current_unlocked_song_index = maxi(Global.current_unlocked_song_index, Global.current_song_index + 1)

	# 同步本地计数
	harmonious = Global.harmonious
	sympathetic = Global.sympathetic
	aware = Global.aware
	lost = Global.lost

	var scene_manager: Node = get_parent()
	if scene_manager and scene_manager.has_method("start_scene_by_path"):
		scene_manager.start_scene_by_path("res://Scene/Ui/Menu/FinishMenu.tscn")
		pass
	pass


# ---------- 暂停菜单 ----------
## 展示暂停菜单
func _show_pause_panel() -> void:
	if _is_pause_panel_visible:
		return
	_is_pause_panel_visible = true
	_pause_panel.visible = true
	_pause_panel.modulate.a = 0.0
	
	speed_label.text = str(Global.note_flow_speed)
	speed_scroll_bar.value = Global.note_flow_speed
	
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_pause_panel, "modulate:a", 1.0, 0.3)

	var scale_tween: Tween = create_tween()
	scale_tween.set_trans(Tween.TRANS_CUBIC)
	scale_tween.set_ease(Tween.EASE_OUT)
	_pause_panel.pivot_offset = _pause_panel.size * 0.5
	_pause_panel.scale = Vector2(0.85, 0.85)
	scale_tween.tween_property(_pause_panel, "scale", Vector2.ONE, 0.3)
	pass


## 隐藏暂停菜单
func _hide_pause_panel() -> void:
	if not _is_pause_panel_visible:
		return
	_is_pause_panel_visible = false

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_pause_panel, "modulate:a", 0.0, 0.2)
	await tween.finished
	_pause_panel.visible = false
	_pause_panel.scale = Vector2.ONE
	pass


## 按下暂停按钮
func _on_pause_button_pressed() -> void:
	Global.play_ui_click_audio()
	if _is_pause_panel_visible or not is_gaming or _is_counting_down:
		return

	var pause_time: float = _compute_master_time()
	for col in active_touches.values():
		_on_column_touch_released(col, pause_time)
	active_touches.clear()

	is_gaming = false
	_pause_playback_position = audio_system.get_playback_position()
	_pause_frozen_tick = Time.get_ticks_msec()
	audio_system.stream_paused = true
	if video_stream_player.stream != null:
		video_stream_player.paused = true
		pass
	_show_pause_panel()
	pass


## 按下继续按钮
func _on_continue_button_pressed() -> void:
	if not _is_pause_panel_visible:
		return
	_hide_pause_panel()
	_start_countdown()
	pass


## 按下重试按钮
func _on_retry_button_pressed() -> void:
	if not _is_pause_panel_visible:
		return
	_restart_game()
	pass


## 按下退出按钮
func _on_exit_button_pressed() -> void:
	if not _is_pause_panel_visible:
		return

	audio_system.stop()
	video_stream_player.stop()
	is_gaming = false
	var scene_manager: Node = get_parent()
	if scene_manager and scene_manager.has_method("back_to_previous_scene"):
		scene_manager.back_to_previous_scene()
		pass
	pass


# ---------- 继续游戏 倒计时 ----------
## 设置暂停后继续的倒计时标签
func _setup_countdown_label() -> void:
	_countdown_label = Label.new()
	_countdown_label.visible = false
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.anchor_left = 0.5
	_countdown_label.anchor_right = 0.5
	_countdown_label.anchor_top = 0.5
	_countdown_label.anchor_bottom = 0.5
	_countdown_label.offset_left = -150.0
	_countdown_label.offset_top = -50.0
	_countdown_label.offset_right = 150.0
	_countdown_label.offset_bottom = 50.0
	_countdown_label.add_theme_font_size_override("font_size", 80)
	_countdown_label.add_theme_color_override("font_color", Color(0.784, 0.784, 0.784, 1.0))
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_countdown_label)
	pass


## 启动继续按钮按后的倒计时
func _start_countdown() -> void:
	_is_counting_down = true
	_countdown_remaining = COUNTDOWN_DURATION
	_countdown_label.visible = true
	_countdown_label.modulate.a = 0.0
	_update_countdown_display()

	var tween: Tween = create_tween()
	tween.tween_property(_countdown_label, "modulate:a", 1.0, 0.15)
	pass


## 继续按钮按后的倒计时
func _countdown_tick(delta: float) -> void:
	_countdown_remaining -= delta
	if _countdown_remaining <= 0.0:
		_on_countdown_ready()
		return

	var prev_second: int = ceili(_countdown_remaining + delta)
	var cur_second: int = ceili(_countdown_remaining)
	if prev_second != cur_second:
		_update_countdown_display()
		_pulse_countdown_label()
		pass
	pass


## 更新继续按钮按后的倒计时时间
func _update_countdown_display() -> void:
	var second: int = ceili(_countdown_remaining)
	_countdown_label.text = str(second)
	pass


## 按下继续按钮按后的倒计时标签闪烁 (缩放)
func _pulse_countdown_label() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	_countdown_label.scale = Vector2(1.3, 1.3)
	tween.tween_property(_countdown_label, "scale", Vector2.ONE, 0.3)
	pass


## 按下继续按钮按后的倒计时结束
func _on_countdown_ready() -> void:
	_countdown_label.visible = false
	_countdown_label.scale = Vector2.ONE
	_is_counting_down = false

	audio_system.stream_paused = false
	if video_stream_player.stream != null:
		video_stream_player.paused = false
		pass

	if not is_audio_start:
		var elapsed: int = Time.get_ticks_msec() - _pause_frozen_tick
		start_time += elapsed
		pass

	is_gaming = true
	pass


# ---------- 重新开始 ----------
## 重新开始游戏
func _restart_game() -> void:
	audio_system.stop()
	audio_system.stream_paused = false
	video_stream_player.stop()
	video_stream_player.paused = false

	_clear_notes()
	_reset_judging_stats()

	chart = [ ]
	time_list = [ ]
	type_list = [ ]
	duration_list = [ ]
	column_list = [ ]
	current_note_index = 0
	is_loading_note = true
	is_audio_start = false
	master_time = -3000.0
	Global.master_time = -3000.0

	if is_test == false:
		load_list()
		write_in_list()
		pass
	else:
		test()
		write_in_list()
		pass

	start_time = Time.get_ticks_msec()

	_hide_pause_panel()
	is_gaming = true
	
	# 若第一个音符到达判定线所需时间超过 2500ms, 则显示
	if first_note_time >= 2500:
		tick.visible = true
		pass
	
	pass


## 清除场景中现有的音符
func _clear_notes() -> void:
	var track: Node3D = $UI/TextureRect/SubViewport/Node3D/Track
	for i: int in range(Global.COLUMN_NUM):
		var column_node: Node3D = track.get_node("Column" + str(i + 1))
		var note_pool: Node3D = column_node.get_node("NotePool")
		for child in note_pool.get_children():
			if child is Node3D:
				child.queue_free()
				pass
			pass
		pass
	Global.judging_area = [ ]
	Global.rendering_area = [ ]

	# 重置各轨道的自动播放 hold 状态, 避免残留高亮
	for processor: Node3D in input_processers:
		if processor and processor.has_method("set_autoplay_hold"):
			processor.set_autoplay_hold(false)
			pass
		pass
	pass

# ---------- 更改音符流速 ----------
## 当音符流速滑动条被滑动时, 重新设置音符流速, 更新现有音符的位置
func _on_speed_scroll_bar_value_changed(value: float) -> void:
	Global.note_flow_speed = int(value)
	reset_speed()
	speed_label.text = str(value)
	pass


## 设置音符流速更改后，重新计算实际音符流速
func reset_speed() -> void:
	Global.note_speed = 19.0 * Global.note_flow_speed / 40.0 + 10.5
	if Global.rendering_area.size() == 0:
		return
	for note: MeshInstance3D in Global.rendering_area:
		if not is_instance_valid(note):
			continue
		if note.type != "hold":
			continue
		note._hold_length = Global.note_speed * float(note.duration) / 1000.0
		pass
	pass
