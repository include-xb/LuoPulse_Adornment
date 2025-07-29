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


func _ready():
	# 设置音符开始时间
	time_manager.start()
	pass

func _physics_process(delta: float) -> void:
	# 音符下落
	self.position.y -= Global.speed * delta
	pass
