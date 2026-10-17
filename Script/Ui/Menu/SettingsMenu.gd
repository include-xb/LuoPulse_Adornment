## SettingsMenu 设置页面
##
## 遍历 Global.SETTINGS 中定义的设置分组, 动态生成 SettingsGroup 组件
## INFO: 欲修改设置项，请前往Global.SETTINGS


extends Control


@export var settings_list: VBoxContainer # = $MarginContainer/ScrollContainer/VBoxContainer

@onready var texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	if texture_rect == null or texture_rect.material == null:
		return
	texture_rect.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	_build_settings()
	pass


func _enter_tree() -> void:
	if texture_rect == null or texture_rect.material == null:
		return
	texture_rect.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	pass


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
	$"..".back_to_previous_scene()
	pass


# INFO: 这里原本有个 can_leave(), 用来在离开前校验用户名。改用户名迁到主菜单的
#       主页卡片之后, 这个页面已经没有会失效的输入, 校验也搬到了 Global.is_user_name_valid
#       —— SceneManager 对没有 can_leave 的场景直接放行 (见 _can_leave_current_scene)
