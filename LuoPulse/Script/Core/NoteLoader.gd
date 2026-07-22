## NodeLoader 音符加载器


extends Node


class_name NoteLoader


var note_type: Dictionary = {
	"tap": preload("res://Scene/Core/NoteTemplate/Tap.tscn"),
	"drag": preload("res://Scene/Core/NoteTemplate/Drag.tscn"),
	"release": preload("res://Scene/Core/NoteTemplate/Release.tscn"),
	"hold": preload("res://Scene/Core/NoteTemplate/Hold.tscn"),
	"heart": preload("res://Scene/Core/NoteTemplate/Heart.tscn"),
}


var note_template: MeshInstance3D = null


## 加载音符
## type: 音符类型 tap/drag/release/hold/heart
## time: 音符到达判定线的时间 (毫秒)
## duration: 音符持续时间 (毫秒)
## column: 音符所在列 (1-based)
## index: 音符在轨道上的索引 (从 0 开始)
## track: 轨道父节点
## gameplay: Gameplay 节点引用
func load_note(type: String, time: int, duration: int, column: int, index: int, track: Node3D, gameplay: Node2D):

	if not note_type.has(type):
		push_error("未知的音符类型: %s" % type)
		return

	# 实例化音符模板
	note_template = note_type[type].instantiate()

	# 注入 gameplay 引用
	note_template.set("gameplay", gameplay)

	# 设置音符属性
	note_template.index = index
	note_template.time = time
	note_template.duration = duration
	note_template.column = column

	# 初始位置: 音符将在 _physics_process 中通过 master_time 自行定位
	# 这里设置初始 z 以配合 _physics_process 的定位公式
	note_template.position.z = Global.note_speed * (-float(Global.start_duration)) / 1000.0

	if type == "hold":
		# hold 音符的 scale 和 position 偏移在 Hold.gd 的 _physics_process 中处理
		pass

	# 将音符添加到对应轨道的 NotePool 节点下
	track.get_node("Column" + str(column) + "/NotePool").add_child(note_template)
	pass
