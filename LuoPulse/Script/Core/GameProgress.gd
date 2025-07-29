extends Node2D

@onready var audio_system: AudioStreamPlayer = $"AudioSystem"

@onready var note_loader: Node = $"NoteLoader"

@onready var time_manager: Node = $"TimeManager"

@onready var progress_bar: ProgressBar = $"ProgressBar"



# 解析完成的谱面数据
var chart: Dictionary = {}

# 当前时间
var current_time: float = 0.0

# 总音符数
var total_notes: int = 0

# 当前音符
var current_note: Sprite2D = null

# 当前音符索引
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


func _ready() -> void:
	# 连接音频播放器的 finished 信号: 播放完毕即游戏结束
	audio_system.connect("finished", game_finished)
	# 从当前选择的曲包中加载谱面数据
	load_list()
	# 将谱面数据写入到各数组中
	write_in_list()
	# 启动计时器
	time_manager.start()
	pass


func _process(delta: float) -> void:
	current_time = time_manager.get_current_time()
	if is_loading_note:
		
		if current_note_index >= total_notes:
			# 加载完毕
			is_loading_note = false
			return
		
		if current_time >= time_list[current_note_index]:
			# 加载音符
			load_note(current_note_index)
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
					load_note(next_note_index)
					# 更新当前音符索引
					current_note_index += 1
					pass
				pass
			
			# 更新当前音符索引
			current_note_index += 1	
			pass
		return
		# 当正在加载音符时, 代码不会向下执行
	
	pass


# 重新封装 load_note 方法，方便外部调用
func load_note(note_index: int) -> void:
	note_loader.load_note(
		type_list[note_index],
		time_list[note_index],
		duration_list[note_index],
		column_list[note_index]
	)
	pass


# 从当前选择的曲包中加载谱面数据
func load_list() -> void:
	pass


# 将谱面数据写入到各数组中
func write_in_list() -> void:
	# INFO: 没有 duration 元素则默认为 0
	pass

# 游戏结束
func game_finished() -> void:
	# 结算
	pass
