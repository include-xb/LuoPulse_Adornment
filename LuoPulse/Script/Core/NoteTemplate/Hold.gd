extends MeshInstance3D

var type: String = "hold"

var index: int = 0

# 从谱面加载所得的音符到达判定线的时间
var time: int = 0

# 持续时间
var duration: int = 0

# 轨道
var column: int = 0

# 当前流逝的时间
var current_time: int = 0

# 开始计时的时间, 用于做差得到当前流逝的时间
var start_time: int = 0

var is_added: bool = false

var is_removed: bool = false

# 头部是否被判定
var is_head_judged: bool = false

# 是否正在被摁住
var is_holding: bool = false

# 是否刚刚摁住
var is_just_held: bool = false

# 开始摁住的时间
var start_holding_time: int = 0

# 摁住的时间
var holding_time: int = 0


func _ready() -> void:
	start_time = Time.get_ticks_msec()
	pass


func _physics_process(delta: float) -> void:
	# 下落
	self.position.z += Global.note_speed * delta
	
	# 获取当前流逝的时间
	current_time = Time.get_ticks_msec() - start_time - Global.start_duration
	
	# 自动播放
	if Global.is_autoplay:
		autoplay()
		pass

	if (not is_added) and current_time >= Global.START_JUDGE_TIME:
		is_added = true
		# 添加音符到判定区间
		Global.judging_area.append(self)
		pass
	
	if (not is_removed) and current_time >= duration + Global.END_JUDGE_TIME:
		is_removed = true

		Global.lost += 1
		# 移除音符出判定区间
		Global.judging_area.erase(self)
		queue_free()
		pass

	## 启动 hold 计时器	
	## 吸附判定线
	if is_just_held:
		start_holding_time = Time.get_ticks_msec()
		is_just_held = false

		var gap_time: int = 0 - current_time
		var gap_length: float = gap_time / 1000.0 * Global.note_speed
		var original_length: float = self.get_mesh().size.y
		var scaled_length: float = original_length + gap_length

		self.get_mesh().size.y = scaled_length
		self.position.z += gap_length / 2.0

		pass

	# 摁下时的长度缩放
	if is_holding:
		holding_time = Time.get_ticks_msec() - start_time - Global.start_duration
		var scale_factor: float = 1.0 - float(holding_time) / duration
		var original_length: float = self.get_mesh().size.y
		var scaled_length: float = original_length * scale_factor

		self.get_mesh().size.y = original_length * scale_factor
		self.position.z -= scaled_length / 2.0
		pass



	pass


func judge() -> void:
	
	pass


# 碎裂效果
func explode() -> void:
	# 碎裂效果实现
	# 释放内存
	queue_free()
	pass


# 自动播放
func autoplay() -> void:
	if not is_holding and current_time >= 0:
		is_holding = true
		pass
	if is_holding and current_time >= duration:
		is_holding = false
		pass
	pass
