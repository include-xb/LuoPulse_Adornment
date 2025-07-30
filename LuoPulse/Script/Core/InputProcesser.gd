## InputProcesser.gd 输入处理器


extends Node


@export var KEY: String = "D" # "F", "J", "K"

@onready var note_pool: Node2D = $NotePool


# 按键是否按下
var is_pressed: bool = false

# 按键是否松开
# var is_released: bool = false

# 按键是否长按
var is_long_pressed: bool = false


var current_note: Sprite2D = null


@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:

	if Input.is_action_just_pressed("INPUT_" + KEY):
		press_judge()
		pass
	
	if Input.is_action_pressed("INPUT_" + KEY):
		long_press_judge()
		pass
	
	if Input.is_action_just_released("INPUT_" + KEY):
		is_pressed = false
		is_long_pressed = false
		# current_note.is_long_press = false
		pass
	
	# 如果当前 current_note 不为 null:
	#	当前的 is_press, is_long_press 值传给 current_note
	pass


func press_judge() -> void:
	is_pressed = true
	print("<InputProgress.gd>点击: ", KEY)
	
	# 获取处于当前轨道判定区间的所有音符
	# 找到时间最大的音符 note
	# current_note 赋值为 note
	# 当前的 is_press, is_long_press 值传给 note
	# 调用这个音符的 judge() 方法
	pass


func long_press_judge() -> void:
	is_long_pressed = true
	print("<InputProgress.gd>长按: ", KEY)	
	pass
