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



extends Node2D

@onready var audio_system: AudioStreamPlayer = $"AudioSystem"

@onready var note_loader: NoteLoader = $"NoteLoader"

@onready var progress_bar: ProgressBar = $"UI/ProgressBar"

@onready var background: TextureRect = $UI/Background

@onready var video_stream_player: VideoStreamPlayer = $UI/VideoStreamPlayer

@onready var _subviewport: SubViewport = $SubViewport

@onready var _camera: Camera3D = $SubViewport/Node3D/Camera3D

@onready var _ui: Control = $UI

@onready var _combo_label: Label = $UI/Combo



# 解析完成的谱面数据
var chart: Array = [ ]

# 主时间 (ms), 基于音频播放位置, 是判定和音符定位的唯一时钟源
var master_time: float = -3000.0

# 开始计时的时间, 与 Time.get_ticks_msec() 相减得到运行时间
var start_time: int = 0

# 总音符数
var total_notes: int = 0

# 当前加载的音符索引
var current_note_index: int = 0

# 音符时间列表
var time_list: Array = []

# 音符类型列表
var type_list: Array = []

# 音符持续时间列表
var duration_list: Array = []

# 音符所在列列表
var column_list: Array = []

# 是否正在加载
var is_loading_note: bool = true

# 音频是否开始播放
var is_audio_start: bool = false

# 音频总时长 (毫秒)
var audio_length: int = 0

# 四类判定等级
var harmonious: int = 0
var sympathetic: int = 0
var aware: int = 0
var lost: int = 0

# 是否正在游戏
var is_gaming: bool = true

# 各列的 InputProcesser 引用
var input_processers: Array = []

# 触屏状态追踪 (touch_index -> column)
var active_touches: Dictionary = {}

# 轨道在屏幕空间的 X 范围 (通过摄像机投影计算)
var _track_screen_min: float = 0.0
var _track_screen_max: float = 0.0

# ---- 判定视觉反馈 ----

const JUDGMENT_TEXT: Dictionary = {
	"harmonious": "和一",
	"sympathetic": "共鸣",
	"aware": "觉醒",
	"lost": "丢失",
}

const JUDGMENT_COLORS: Dictionary = {
	"harmonious": Color(1.0, 0.85, 0.3, 1.0),
	"sympathetic": Color(0.5, 0.9, 0.5, 1.0),
	"aware": Color(0.4, 0.7, 1.0, 1.0),
	"lost": Color(0.6, 0.6, 0.6, 1.0),
}

const EARLY_COLOR: Color = Color(0.4, 0.7, 1.0, 1.0)
const LATE_COLOR: Color = Color(1.0, 0.4, 0.4, 1.0)

const FEEDBACK_DURATION: float = 0.5
const FEEDBACK_FLOAT_Y: float = -30.0
const FEEDBACK_FONT_SIZE: int = 24
const FEEDBACK_EARLY_LATE_FONT_SIZE: int = 18

var _judgment_container: Control = null
var _feedback_labels: Array[Label] = []
var _feedback_index: int = 0
var _max_feedback_labels: int = 16

# 用于测试
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
var is_test: bool = false


func _ready() -> void:
	_calculate_track_screen_bounds()
	_reset_judging_stats()
	_setup_judgment_feedback()

	audio_system.connect("finished", game_finished)

	_collect_input_processers()

	if is_test == false:
		# 从当前选择的曲包中加载谱面数据
		load_list()
		# 将谱面数据写入到各数组中
		write_in_list()
		pass
	else:
		test()
		write_in_list()
		pass

	# 记录程序起始时间 (仅用于预加载段的计时)
	start_time = Time.get_ticks_msec()
	pass


func _collect_input_processers() -> void:
	var track: Node3D = $SubViewport/Node3D/Track
	for i in range(Global.COLUMN_NUM):
		var column_node: Node3D = track.get_node("Column" + str(i + 1))
		input_processers.append(column_node)
		pass
	pass


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
	var scale: float = screen_w / vp_w

	_track_screen_min = left_vp.x * scale
	_track_screen_max = right_vp.x * scale
	pass


func get_input_processor(column: int) -> Node3D:
	if column >= 0 and column < input_processers.size():
		return input_processers[column]
	return null


# 测试画面
func test() -> void:
	var audio_stream: AudioStream = audio_system.stream
	audio_length = int(audio_stream.get_length() * 1000)
	print("audio_stream: " + str(audio_system.stream == null))
	chart = default_chart
	total_notes = len(chart)
	pass


func _process(delta: float) -> void:
	_update_master_time()

	if not is_gaming:
		return

	# 音频启动
	if is_audio_start == false && master_time >= 0.0:
		audio_system.play()
		if video_stream_player.stream != null:
			video_stream_player.play()
			pass
		is_audio_start = true
		pass

	# 加载音符
	if is_loading_note:
		load_note_process()
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

	# 结束游戏
	if master_time >= audio_length && is_gaming:
		game_finished()
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


func _update_master_time() -> void:
	master_time = _compute_master_time()
	Global.master_time = master_time
	pass


func _compute_master_time() -> float:
	if is_audio_start:
		return audio_system.get_playback_position() * 1000.0 + float(Global.chart_offset)
	return float(Time.get_ticks_msec() - start_time) - float(Global.start_duration)


func _input(event: InputEvent) -> void:
	if not is_gaming:
		return

	# 获取当前时刻的主时间 (解决 _input 比 _process 先执行的延迟问题)
	var input_time: float = _compute_master_time()

	if event is InputEventScreenTouch:
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

	# 桌面键盘输入 (开发调试用)
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


func _get_column_from_x(x: float) -> int:
	var col_count: int = Global.COLUMN_NUM
	var range: float = _track_screen_max - _track_screen_min
	if range <= 0.0:
		range = get_viewport().get_visible_rect().size.x
	var normalized: float = (x - _track_screen_min) / range
	var col: int = int(normalized * float(col_count))
	if col >= 0 and col < col_count:
		return col
	return -1


func _get_column_from_key(event: InputEventKey) -> int:
	var key_map: Dictionary = {
		KEY_D: 0,
		KEY_F: 1,
		KEY_J: 2,
		KEY_K: 3,
	}
	if key_map.has(event.keycode):
		return key_map[event.keycode]
	return -1


func _on_column_touch_pressed(column: int, input_time: float) -> void:
	var processor: Node3D = get_input_processor(column)
	if processor and processor.has_method("on_touch_pressed"):
		processor.on_touch_pressed(input_time)
		pass
	pass


func _on_column_touch_released(column: int, input_time: float) -> void:
	var processor: Node3D = get_input_processor(column)
	if processor and processor.has_method("on_touch_released"):
		processor.on_touch_released(input_time)
		pass
	pass


# 加载音符总过程
func load_note_process() -> void:
	if current_note_index >= total_notes:
		is_loading_note = false
		return

	var note_time: float = float(time_list[current_note_index])
	var load_deadline: float = note_time - float(Global.start_duration)

	if master_time < load_deadline:
		return

	var batch_time: float = note_time
	while current_note_index < total_notes and float(time_list[current_note_index]) == batch_time:
		load_note(current_note_index, current_note_index)
		print("正在加载第 %d 个音符" % current_note_index)
		current_note_index += 1
		pass

	if current_note_index >= total_notes:
		is_loading_note = false
		pass
	pass


# 重新封装 load_note 方法，方便外部调用
func load_note(note_index: int, index: int) -> void:
	note_loader.load_note(
		type_list[note_index],
		time_list[note_index],
		duration_list[note_index],
		column_list[note_index],
		index,
		$SubViewport/Node3D/Track,
		self,
	)
	pass


# 从当前选择的曲包中加载谱面数据
func load_list() -> void:
	var path: String = Global.sympath_song_path_list[Global.current_song_index]
	var img: ImageTexture = Global._read_cover_from_lpz(path)
	var audio_stream: AudioStream = Global._read_audio_from_lpz(path)
	var chart_raw: Dictionary = Global._read_chart_from_lpz(path)
	var video_stream: VideoStream = Global._read_video_from_lpz(path)

	background.texture = img
	audio_system.stream = audio_stream
	audio_length = int(audio_stream.get_length() * 1000)
	chart = chart_raw.get("HitObjects")
	video_stream_player.stream = video_stream
	pass


# 将谱面数据写入到各数组中
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
	_feedback_index = 0
	pass


func _setup_judgment_feedback() -> void:
	_judgment_container = Control.new()
	_judgment_container.anchor_left = 0.0
	_judgment_container.anchor_right = 1.0
	_judgment_container.anchor_top = 0.0
	_judgment_container.anchor_bottom = 1.0
	_judgment_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_judgment_container)

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
			text_color = EARLY_COLOR
			pass
		elif time_offset > 0:
			early_late_text = "▼ LATE"
			text_color = LATE_COLOR
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
	tween.tween_property(lbl, "position:y", lbl.position.y + FEEDBACK_FLOAT_Y, FEEDBACK_DURATION)
	tween.tween_property(lbl, "modulate:a", 0.0, FEEDBACK_DURATION).set_ease(Tween.EASE_IN).set_delay(0.15)
	pass



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


func _get_judgment_line_y() -> float:
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	return viewport_height * 0.72


# 游戏结束
func game_finished() -> void:
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

	Global.crystal += crystal_earned
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
