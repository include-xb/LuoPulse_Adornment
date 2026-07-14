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



# 解析完成的谱面数据
var chart: Array = [ ]

# 当前时间
var current_time: int = 0

# 开始计时的时间, 与 Time.get_ticks_msec() 相减得到 current_time
var start_time: int = 0

# 总音符数
var total_notes: int = 0

# 当前音符
var current_note: Sprite2D = null

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
	# 连接音频播放器的 finished 信号: 播放完毕即游戏结束
	audio_system.connect("finished", game_finished)
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
	# 启动计时器
	start_time = Time.get_ticks_msec()
	pass


# 测试画面崩溃
# 为啥会崩溃呐 <- 全局变量当成了函数内的局部变量 INFO: 已解决
func test() -> void:
	var audio_stream: AudioStream = audio_system.stream
	audio_length = int(audio_stream.get_length() * 1000)
	print("audio_stream: " + str(audio_system.stream == null))
	chart = default_chart
	total_notes = len(chart)
	pass


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	# 获取流逝时间
	if is_gaming:
		current_time = Time.get_ticks_msec() - start_time
		pass
	
	# 加载音符
	if is_audio_start == false && current_time >= 3000:
		audio_system.play()
		if video_stream_player.stream != null: 
			video_stream_player.play()
			pass
		is_audio_start = true
		pass
	
	if is_loading_note:
		load_note_process()
		## 当正在加载音符时, 代码不会向下执行
		#return
		pass
	
	# 背景色彩变化
	var current_progress: float = float(current_time) / float(audio_length)
	progress_bar.value = current_progress * 100
	video_stream_player.material.set_shader_parameter(
		"gray_scale", 
		(1.0 - current_progress) * 0.6 # 此处乘 0.6 是最终背景色彩恢复情况, 1.0 为最终色彩恢复至原图
	)
	background.material.set_shader_parameter(
		"gray_scale", 
		(1.0 - current_progress) * 0.6 # 此处乘 0.6 是最终背景色彩恢复情况, 1.0 为最终色彩恢复至原图
	)
	# print("进度: " + str(current_progress))
	# print("video 灰度" + str(video_stream_player.material.get_shader_parameter("gray_scale")))
	
	# 结束游戏
	if current_time >= audio_length && is_gaming:
		game_finished()
		pass
	
	pass


# 加载音符总过程
func load_note_process() -> void:
	if current_note_index >= total_notes:
		# 加载完毕
		is_loading_note = false
		return
	
	if current_time >= time_list[current_note_index]:
		# 加载音符
		load_note(current_note_index, current_note_index)
		print("正在加载第 %d 个音符" % current_note_index)
		# 检查接下来是否有相同时间的音符
		for i in range(Global.COLUMN_NUM - 1):
			# 获取下一个音符的索引
			var next_note_index: int = current_note_index + 1
			# 如果下一个音符索引超出范围，则退出循环
			if next_note_index >= total_notes:
				is_loading_note = false
				break
			# 如果下一个音符的时间与当前音符相同，则加载下一个音符
			if time_list[current_note_index] == time_list[next_note_index]:
				load_note(next_note_index, current_note_index + 1)
				print("正在加载第 %d 个音符" % (current_note_index + 1))
				# 更新当前音符索引
				current_note_index += 1
				pass
			pass
		
		# 更新当前音符索引
		current_note_index += 1
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
	# print(chart)
	pass


# 将谱面数据写入到各数组中
func write_in_list() -> void:
	# INFO: 没有 duration 元素则默认为 0
	
	total_notes = len(chart)
	for i: Dictionary in chart:
		var time: int = i.get("time")
		var type: String = i.get("type")
		var column: int = i.get("column")
		var duration: int = i.get("duration", 0.0)
		
		time_list.append(time)
		type_list.append(type)
		column_list.append(column)
		duration_list.append(duration)
		pass
	
	pass


# 游戏结束
func game_finished() -> void:
	is_gaming = false
	# 转到结算场景
	pass
