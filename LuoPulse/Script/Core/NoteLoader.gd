## NodeLoader 音符加载器


extends Node


class_name NoteLoader


@onready var tap: PackedScene = preload("res://Scene/Core/NoteTemplate/Tap.tscn")
@onready var drag: PackedScene = preload("res://Scene/Core/NoteTemplate/Drag.tscn")
@onready var release: PackedScene = preload("res://Scene/Core/NoteTemplate/Release.tscn")
@onready var hold: PackedScene = preload("res://Scene/Core/NoteTemplate/Hold.tscn")
@onready var heart: PackedScene = preload("res://Scene/Core/NoteTemplate/Heart.tscn")


var note_type: Dictionary = {
	"tap": tap,
	"drag": drag,
	"release": release,
	"hold": hold,
	"heart": heart,
}

#var column_node: Dictionary = {
	#0: $"../Track/Column1/NotePool",
	#1: $"../Track/Column2/NotePool",
	#2: $"../Track/Column3/NotePool",
	#3: $"../Track/Column4/NotePool",
#}


var note_template: Sprite2D = null


## 加载音符
## type: 音符类型 tap/drag/release/hold/heart
## time: 音符到达判定线的时间
## duration: 音符持续时间
## column: 音符所在列
func load_note(type: String, time: float, duration: float, column: int):
	# 实例化音符模板
	note_template = note_type[type].instance()
	# 设置音符时间
	note_template.time = time
	# 设置音符持续时间
	note_template.duration = duration
	# 设置音符所在列
	note_template.column = column
	# 获取对应的轨道节点
	# 获取该轨道节点的 NotePool 节点
	# 将音符添加到 NotePool 节点下
	
	pass
