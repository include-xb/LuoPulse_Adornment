extends MeshInstance3D

var type: String = "hold"

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


func _ready() -> void:
	start_time = Time.get_ticks_msec()
	pass


func _physics_process(delta: float) -> void:
	# 下落
	self.position.z += Global.note_speed * delta
	
	# 获取当前流逝的时间
	current_time = Time.get_ticks_msec() - start_time - Global.start_duration
	
	if (not is_added) and current_time >= Global.START_JUDGE_TIME:
		is_added = true
		
		# 添加音符到判定区间
		pass
	
	if (not is_removed) and current_time >= duration + Global.END_JUDGE_TIME:
		is_removed = true
		
		# 移除音符出判定区间
		queue_free()
		pass
	
	if Global.is_autoplay:
		# 自动播放
		autoplay()
		pass

	pass


func judge() -> void:
	
	pass


# 碎裂效果
func explode() -> void:
	# 碎裂效果实现
	# 释放内存
	pass


# 自动播放
func autoplay() -> void:
	pass
