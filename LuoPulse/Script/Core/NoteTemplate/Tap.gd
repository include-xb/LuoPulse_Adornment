extends MeshInstance3D

# @onready var time_manager: Node = $"TimeManager"

# 音符索引
var index: int = 0

# 音符类型
var type: String = "tap"

# 音符到达判定线的时间 (毫秒)
var time: int = 0

# 音符持续时间 (毫秒)
var duration: int = 0

# 音符所在列数
var column: int = 0

# 当前流逝的时间
var current_time: int = 0

# 开始计时的时间, 用于做差得到当前流逝的时间
var start_time: int = 0

# 音符准度
var a: float = 0.0

# 音符是否已经被添加到判定区间
var is_added: bool = false

# 音符是否已经被移除出判定区间
var is_removed: bool = false


func _ready():
	# 设置音符开始时间
	start_time = Time.get_ticks_msec()
	pass


func _physics_process(delta: float) -> void:
	# 音符下落
	position.z += Global.note_speed * delta
	
	# 获取当前时间
	current_time = Time.get_ticks_msec() - start_time - Global.start_duration

	if Global.is_autoplay:
		# 自动播放
		autoplay()
		pass

	if (not is_added) and current_time >= Global.START_JUDGE_TIME:
		is_added = true
		# 添加音符到判定区间
		Global.judging_area.append(self)
		pass
	
	# print("current_time: " + str(current_time))
	if (not is_removed) and current_time >= duration + Global.END_JUDGE_TIME:
		is_removed = true
		# 移除音符出判定区间
		Global.judging_area.erase(self)

		# lost + 1
		Global.lost += 1
		
		# 释放内存
		queue_free()
		pass
	
	pass


func judge() -> void:
	# 通过当前时间确定判定等级
	# 共鸣
	if current_time > -60 && current_time < 60:
		Global.harmonious += 1
		a = 1.0
		pass
	# 同步
	elif (current_time >= -120 && current_time < -60) || (current_time > 60 && current_time <= 120):
		Global.sympathetic += 1
		a = 0.7
		pass
	# 连接
	elif (current_time >= -180 && current_time < -120) || (current_time > 120 && current_time <= 180):
		Global.aware += 1
		a = 0.5
		pass
	# 丢失
	else:
		Global.lost += 1
		a = 0.0
		pass
	
	# 更新准度
	Global.accuracy = (Global.accuracy * index + a) / (index + 1)
	# 连击数加一
	Global.combo += 1
	# 被点击后调用碎裂函数
	explode()
	pass


# 碎裂效果
func explode() -> void:
	# 碎裂效果实现
	
	# 释放内存
	queue_free()
	pass



# 自动播放
func autoplay() -> void:
	if current_time >= 0:
		explode()
		Global.harmonious += 1
		a = 1.0
		pass
	pass
