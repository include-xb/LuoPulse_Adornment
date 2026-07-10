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

@onready var background: TextureRect = $Background



func _ready() -> void:
	# 主页面背景色彩变化并非线性, 而是 U 形变化
	# background.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	pass


func _on_sympathy_pressed() -> void:
	Global.play_ui_click_audio()
	SceneManager.change_scene("res://Scene/Ui/SongSelect/Sympathy.tscn")


func _on_album_pressed() -> void:
	Global.play_ui_click_audio()
	SceneManager.change_scene("res://Script/Ui/SongSelect/Album.gd")


func _on_note_pressed() -> void:
	Global.play_ui_click_audio()
	SceneManager.change_scene("res://Scene/Ui/Menu/Notebook.tscn")


func _on_setting_pressed() -> void:
	Global.play_ui_click_audio()
	SceneManager.change_scene("res://Scene/Ui/Menu/SettingMenu.tscn")
