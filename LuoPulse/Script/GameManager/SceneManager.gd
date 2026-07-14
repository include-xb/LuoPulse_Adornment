#INFO: 已取消当前场景的自动加载，要在其他脚本中使用该脚本的方法，请使用 $"..".方法名

extends Node

const LAUNCH_SCENE_PATH := "res://Scene/Ui/Launch.tscn"

@onready var color_rect: ColorRect = $CanvasLayer/ColorRect
@onready var texture_rect: TextureRect = $CanvasLayer/TextureRect

var _scene_track: Array = []
var _args: Dictionary = {}
var _last_animation_name: String = "fade"
var _launch_scene: Node = null

func _ready() -> void:
	color_rect.self_modulate.a = 0
	color_rect.visible = false
	texture_rect.visible = false
	texture_rect.modulate.a = 0
	start_scene_by_path(LAUNCH_SCENE_PATH)

# ===== Public =====

## 启动场景并传递参数
## @param scene_path: 必须，场景路径
## @param animation_name: 可选，切换动画名称, 默认淡入淡出
## @param pass_args: 可选，要传递的参数字典
## @param img: 可选，图像资源, 仅在切换动画为 img 时有效
func start_scene_by_path(scene_path: String, pass_args: Dictionary = {}, animation_name: String = "fade", img: ImageTexture = null) -> void:
	if not _is_launch_scene(scene_path):
		await _play_enter_animation(animation_name, img)
		_args = pass_args
		_last_animation_name = animation_name

	_load_and_add_scene(scene_path)

	if not _is_launch_scene(scene_path):
		await _play_exit_animation(animation_name)


## 返回上一个场景
func back_to_previous_scene() -> void:
	if _scene_track.is_empty():
		return

	await _play_enter_animation(_last_animation_name)

	var old_scene: Node = _scene_track.pop_back()
	self.remove_child(old_scene)
	old_scene.queue_free()

	if not _scene_track.is_empty():
		self.add_child(_scene_track.back())

	await _play_exit_animation(_last_animation_name)


## 获取上个场景传参
## @return: 上个场景的参数字典
func get_args() -> Dictionary:
	return _args


# ===== Private =====

func _is_launch_scene(scene_path: String) -> bool:
	return scene_path == LAUNCH_SCENE_PATH


func _load_and_add_scene(scene_path: String) -> void:
	# 移除非 Launch 场景时，同时移除 Launch 场景
	if not _scene_track.is_empty():
		self.remove_child(_scene_track.back())
	elif _launch_scene:
		self.remove_child(_launch_scene)
		_launch_scene.queue_free()
		_launch_scene = null

	var scene: Node = load(scene_path).instantiate()

	if _is_launch_scene(scene_path):
		_launch_scene = scene
	else:
		_scene_track.append(scene)

	self.add_child(scene)

## 入场动效
func _play_enter_animation(animation_name: String, img: ImageTexture = null) -> void:
	match animation_name:
		"fade":
			color_rect.visible = true
			var tween: Tween = get_tree().create_tween()
			tween.tween_property(color_rect, "self_modulate:a", 1, 0.25)
			await tween.finished
		"img":
			texture_rect.visible = true
			if img:
				texture_rect.texture = img
			var tween: Tween = get_tree().create_tween()
			tween.tween_property(texture_rect, "modulate:a", 1, 1)
			await tween.finished
			await get_tree().create_timer(1.2).timeout

## 出场动效
func _play_exit_animation(animation_name: String) -> void:
	match animation_name:
		"fade":
			var tween: Tween = get_tree().create_tween()
			tween.tween_property(color_rect, "self_modulate:a", 0, 0.25)
			await tween.finished
			color_rect.visible = false
		"img":
			var tween: Tween = get_tree().create_tween()
			tween.tween_property(texture_rect, "modulate:a", 0, 1)
			await tween.finished
			texture_rect.visible = false
