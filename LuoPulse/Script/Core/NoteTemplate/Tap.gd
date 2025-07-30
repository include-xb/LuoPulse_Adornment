extends Sprite2D

@onready var time_manager: Node = $"TimeManager"


# 音符类型
var type: String = "tap"

# 音符到达判定线的时间 (毫秒)
var time: int = 0

# 音符持续时间 (毫秒)
var duration: int = 0

# 音符所在列数
var column: int = 0

# 当前时间
var current_time: int = 0

var start_time: int = 0

# 音符是否已经被添加到判定区间
var is_added: bool = false

# 音符是否已经被移除出判定区间
var is_removed: bool = false


func _ready():
	# 设置音符开始时间
	time_manager.start()
	start_time = Time.get_ticks_msec()
	pass


func _physics_process(delta: float) -> void:
	# 音符下落
	self.position.y += Global.speed * delta
	# 获取当前时间
	current_time = Time.get_ticks_msec() - time

	if (not is_added) and current_time >= Global.START_JUDGE_TIME:
		is_added = true
		# 添加音符到判定区间
		pass

	if (not is_removed) and current_time >= duration + Global.START_JUDGE_TIME:
		is_removed = true
		# 移除音符出判定区间
		# lost + 1
		# 释放内存
		pass
	
	if Global.is_autoplay:
		# 自动播放
		autoplay()
	
	pass


func judge() -> void:
	# 通过当前时间确定判定等级
	# 更新准度
	# 连击数加一
	# 被点击后调用碎裂函数
	pass


# 碎裂效果
func explode() -> void:
	# 碎裂效果实现
	# 释放内存
	pass



# 自动播放
func autoplay() -> void:
	pass
