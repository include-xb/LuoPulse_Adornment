## SettingsGroup 设置分组组件
##
## 根据 Global.SETTINGS 中定义的设置项, 动态生成每一行的名称与控件
## INFO: 欲修改设置项，请前往Global.SETTINGS

extends VBoxContainer


func set_up(settings_group_key: String, settings_group: Dictionary) -> void:
	$MarginContainer/VBoxContainer/Label.text = settings_group_key

	for setting_name: String in settings_group:
		var setting: Dictionary = settings_group[setting_name]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var name_label: Label = Label.new()
		name_label.text = setting_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)

		var widget: Control = _create_widget(setting)
		row.add_child(widget)

		$MarginContainer/VBoxContainer/VBoxContainer.add_child(row)


func _create_widget(setting: Dictionary) -> Control:
	var node_type: String = setting["node_type"]
	match node_type:
		"HSlider":
			return _create_slider(setting)
		"SpinBox":
			return _create_spinbox(setting)
		"LineEdit":
			return _create_lineedit(setting)
		"OptionButton":
			return _create_optionbutton(setting)
	return Control.new()


func _create_slider(setting: Dictionary) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(300, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_END

	var slider: HSlider = HSlider.new()
	slider.min_value = float(setting["min"])
	slider.max_value = float(setting["max"])
	slider.step = float(setting["step"])
	slider.value = float(Global.get(setting["key"]))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(slider)

	var value_label: Label = Label.new()
	value_label.custom_minimum_size = Vector2(80, 0)
	value_label.text = _format_value(slider.value, setting.get("suffix", ""))
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(value_label)

	slider.value_changed.connect(_on_slider_changed.bind(value_label, setting["key"], setting.get("suffix", "")))
	return box


func _create_spinbox(setting: Dictionary) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_SHRINK_END

	var spin: SpinBox = SpinBox.new()
	spin.min_value = float(setting["min"])
	spin.max_value = float(setting["max"])
	spin.step = float(setting["step"])
	spin.value = float(Global.get(setting["key"]))
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(spin)

	var suffix: String = setting.get("suffix", "")
	if suffix != "":
		var suffix_label: Label = Label.new()
		suffix_label.text = suffix
		suffix_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(suffix_label)
		pass

	spin.value_changed.connect(_on_spinbox_changed.bind(setting["key"]))
	return box


func _create_lineedit(setting: Dictionary) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(300, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_END

	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = str(Global.get(setting["key"]))
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(line_edit)

	line_edit.text_changed.connect(_on_lineedit_changed.bind(setting["key"]))
	return box


func _create_optionbutton(setting: Dictionary) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_SHRINK_END

	var option_button: OptionButton = OptionButton.new()
	var options: Array = setting.get("options", [])
	for option: String in options:
		option_button.add_item(option)
		pass
	option_button.selected = int(Global.get(setting["key"]))
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(option_button)

	option_button.item_selected.connect(_on_optionbutton_changed.bind(setting["key"]))
	return box


func _format_value(value: float, suffix: String) -> String:
	var text: String = str(int(value))
	if suffix != "":
		text += " " + suffix
	return text


func _on_slider_changed(value: float, value_label: Label, key: String, suffix: String) -> void:
	value_label.text = _format_value(value, suffix)
	_apply_setting(key, int(value))
	pass


func _on_spinbox_changed(value: float, key: String) -> void:
	_apply_setting(key, int(value))
	pass


func _on_lineedit_changed(text: String, key: String) -> void:
	_apply_setting(key, text)
	pass


func _on_optionbutton_changed(index: int, key: String) -> void:
	_apply_setting(key, index)
	pass


func _apply_setting(key: String, value: Variant) -> void:
	Global.set(key, value)
	Global.save_config()
	pass
