## SettingsMenu 设置页面
##
## 遍历 Global.SETTINGS 中定义的设置分组, 动态生成 SettingsGroup 组件
## INFO: 欲修改设置项，请前往Global.SETTINGS

extends Control


@onready var settings_list: VBoxContainer = $MarginContainer/ScrollContainer/VBoxContainer


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


func _on_back_pressed() -> void:
	$"..".back_to_previous_scene()
