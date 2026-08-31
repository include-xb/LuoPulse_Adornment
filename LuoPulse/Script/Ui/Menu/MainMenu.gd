## MainMenu 游戏主页面
##
## 可以切换到这里的场景:
## 		- Launch 启动界面
## 		- Sympathy 共鸣主线
## 		- Album 专辑主线
## 		- AboutMenu 关于界面
## 从这里可以前往: 
## 		- SettingMenu 设置页面
## 		- Sympathy 共鸣主线
## 		- Album 专辑主线
## 		- AboutMenu 关于界面


extends Control

## 主页背景
@onready var background: TextureRect = $Background

## 用户名
@onready var username: Label = $Profile/VBoxContainer/InfoPanel/Username

## 水晶值
@onready var amount: Label = $Currency/HBoxContainer/Amount


func _ready() -> void:
	# 主页面背景色彩变化并非线性, 而是 U 形变化
	# background.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	# 界面上的数值显示
	username.text = Global.user_name
	amount.text = str(Global.crystal)
	pass


## 每次重新进入场景树时刷新显示
## SceneManager 通过 remove_child / add_child 复用场景节点, _ready 只在首次进入时执行一次
func _enter_tree() -> void:
	if not is_node_ready():
		return
	username.text = Global.user_name
	amount.text = str(Global.crystal)
	pass


func _on_sympathy_pressed() -> void:
	Global.play_ui_click_audio()
	$"..".start_scene_by_path("res://Scene/Ui/SongSelect/Sympathy.tscn")


func _on_album_pressed() -> void:
	Global.play_ui_click_audio()
	$"..".start_scene_by_path("res://Scene/Ui/SongSelect/Album.tscn")


func _on_note_pressed() -> void:
	Global.play_ui_click_audio()
	$"..".start_scene_by_path("res://Scene/Ui/Menu/Notebook.tscn")


func _on_setting_pressed() -> void:
	Global.play_ui_click_audio()
	$"..".start_scene_by_path("res://Scene/Ui/Menu/SettingsMenu.tscn")
