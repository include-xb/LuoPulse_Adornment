extends Control


const FONT_SIZE_LARGE: int = 48
const FONT_SIZE_NORMAL: int = 28
const FONT_SIZE_SMALL: int = 22
const LABEL_COLOR: Color = Color("#5A554F")

var _built: bool = false


func _ready() -> void:
	_build_results_ui()
	pass


func _build_results_ui() -> void:
	if _built:
		return
	_built = true

	var result: Dictionary = Global.gameplay_result

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.15
	vbox.anchor_bottom = 0.85
	vbox.offset_left = -300.0
	vbox.offset_right = 300.0
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# 评级
	var grade_label: Label = Label.new()
	var grade_color: Color = result.get("grade_color", Color.GRAY)
	grade_label.text = result.get("grade", "-")
	grade_label.add_theme_font_size_override("font_size", FONT_SIZE_LARGE)
	grade_label.add_theme_color_override("font_color", grade_color)
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(grade_label)

	# 准度
	var acc_label: Label = _make_label(
		"准度: %.2f%%" % (result.get("accuracy", 0.0) * 100.0),
		FONT_SIZE_NORMAL
	)
	vbox.add_child(acc_label)

	vbox.add_child(_make_spacer(8))

	# 各判定等级计数
	var judging_grid: GridContainer = GridContainer.new()
	judging_grid.columns = 2
	judging_grid.add_theme_constant_override("h_separation", 40)
	judging_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(judging_grid)

	var h: int = result.get("harmonious", 0)
	var s: int = result.get("sympathetic", 0)
	var a: int = result.get("aware", 0)
	var l: int = result.get("lost", 0)
	var total: int = result.get("total_notes", 0)

	judging_grid.add_child(_make_label("和一", FONT_SIZE_SMALL))
	judging_grid.add_child(_make_label(str(h), FONT_SIZE_SMALL))
	judging_grid.add_child(_make_label("共鸣", FONT_SIZE_SMALL))
	judging_grid.add_child(_make_label(str(s), FONT_SIZE_SMALL))
	judging_grid.add_child(_make_label("觉醒", FONT_SIZE_SMALL))
	judging_grid.add_child(_make_label(str(a), FONT_SIZE_SMALL))
	judging_grid.add_child(_make_label("丢失", FONT_SIZE_SMALL))
	judging_grid.add_child(_make_label(str(l), FONT_SIZE_SMALL))

	vbox.add_child(_make_spacer(8))

	# 最大连击
	var combo_label: Label = _make_label(
		"最大连击: " + str(result.get("max_combo", 0)),
		FONT_SIZE_NORMAL
	)
	vbox.add_child(combo_label)

	# 总音符
	var notes_label: Label = _make_label(
		"总音符: " + str(total),
		FONT_SIZE_NORMAL
	)
	vbox.add_child(notes_label)

	vbox.add_child(_make_spacer(16))

	# 水晶奖励
	var crystal_earned: int = result.get("crystal_earned", 0)
	var crystal_label: Label = _make_label(
		"水晶 +" + str(crystal_earned),
		FONT_SIZE_NORMAL
	)
	crystal_label.add_theme_color_override("font_color", Color.GOLDENROD)
	vbox.add_child(crystal_label)

	vbox.add_child(_make_spacer(24))

	# 继续按钮
	var continue_btn: Button = Button.new()
	continue_btn.text = "继续"
	continue_btn.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	continue_btn.custom_minimum_size = Vector2(200, 50)
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)
	pass


func _make_label(text: String, font_size: int) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _make_spacer(height: int) -> Control:
	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(0, height)
	return sp


func _on_continue_pressed() -> void:
	Global.play_ui_click_audio()

	var scene_manager: Node = get_parent()
	if scene_manager and scene_manager.has_method("back_to_previous_scene"):
		scene_manager.back_to_previous_scene()
		pass
	pass
