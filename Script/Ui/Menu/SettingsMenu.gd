## SettingsMenu 设置页面
##
## 遍历 Global.SETTINGS 中定义的设置分组, 动态生成 SettingsGroup 组件
## INFO: 欲修改设置项，请前往Global.SETTINGS


extends Control


@export var settings_list: VBoxContainer # = $MarginContainer/ScrollContainer/VBoxContainer


## 用户名长度上限
const USER_NAME_MAX_LENGTH: int = 6


func _ready() -> void:
	_build_settings()


func _build_settings() -> void:
	for group_key: String in Global.SETTINGS:
		var settings_group: Dictionary = Global.SETTINGS[group_key]

		var group_widget: VBoxContainer = preload("res://Scene/Ui/Widget/SettingsGroup.tscn").instantiate()
		group_widget.set_up(group_key, settings_group)

		settings_list.add_child(group_widget)
		pass
	pass


## 返回按钮
func _on_back_pressed() -> void:
	Global.play_ui_click_audio()
	if not can_leave():
		return
	$"..".back_to_previous_scene()
	pass


## 能否离开设置页 —— 返回按钮和安卓返回手势都会问这里
## 用户名不合法时弹提示并拒绝离开
func can_leave() -> bool:
	if Global.user_name.is_empty():
		Global.display_notice("用户名不能为空")
		return false

	if Global.user_name.length() > USER_NAME_MAX_LENGTH:
		Global.display_notice("用户名不得长于6字符")
		return false

	return true
