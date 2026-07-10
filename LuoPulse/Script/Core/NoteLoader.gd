## NodeLoader 音符加载器


extends Node


class_name NoteLoader


var note_type: Dictionary = {
	"tap": preload("res://Scene/Core/NoteTemplate/Tap.tscn"),
	#"drag": preload("res://Scene/Core/NoteTemplate/Drag.tscn"),
	#"release": preload("res://Scene/Core/NoteTemplate/Release.tscn"),
	"hold": preload("res://Scene/Core/NoteTemplate/Hold.tscn"),
	#"heart": preload("res://Scene/Core/NoteTemplate/Heart.tscn"),
}



var note_template: MeshInstance3D = null


## 加载音符
## type: 音符类型 tap/drag/release/hold/heart
## time: 音符到达判定线的时间
## duration: 音符持续时间
## column: 音符所在列
func load_note(type: String, time: int, duration: int, column: int, track: Node3D):
	# 实例化音符模板
	note_template = note_type[type].instantiate()
	
	# 设置音符时间
	note_template.time = time # 此处的时间单位为毫秒
	
	# 设置音符持续时间
	note_template.duration = duration
	
	# 设置音符所在列
	note_template.column = column
	# note_template.position.x = column - 2.5
	
	note_template.position.z = 0.0 - (float(Global.start_duration) / 1000.0) * Global.note_speed
	
	if type == "hold":
		var length_should_be: float = float(duration) / 1000.0 * Global.note_speed
		var length_current_be: float = note_template.get_mesh().size.y
		if length_current_be > 0.0:
			note_template.scale.z = length_should_be / length_current_be
			pass
		note_template.position.z -= length_should_be / 2.0
		pass
	
	# 获取对应的轨道节点
	# 获取该轨道节点的 NotePool 节点
	# 将音符添加到 NotePool 节点下
	track.get_node("Column" + str(column) + "/NotePool").add_child(note_template)
	pass
