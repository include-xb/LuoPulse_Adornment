## 临时探针 2: 实例化真实 Gameplay 场景, 读取判定线投影数值 (review 用, 用完删除)
extends Node


func _ready() -> void:
	await get_tree().process_frame

	var packed: PackedScene = load("res://Scene/Core/Gameplay.tscn")
	var gp: Control = packed.instantiate()
	gp.is_test = true
	add_child(gp)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	print("=== PROBE2 START ===")
	print("Q1 window visible_rect=", get_viewport().get_visible_rect().size)
	print("Q2 subviewport size=", gp._subviewport.size)
	print("Q3 _subviewport_scale()=", gp._subviewport_scale())
	print("Q4 x_ratio=", float(get_viewport().get_visible_rect().size.x) / float(gp._subviewport.size.x),
		" y_ratio=", float(get_viewport().get_visible_rect().size.y) / float(gp._subviewport.size.y))

	for c: int in range(1, Global.COLUMN_NUM + 1):
		var world_x: float = gp._get_column_world_x(c)
		var vp: Vector2 = gp._camera.unproject_position(Vector3(world_x, 0.0, 0.0))
		print("Q5 col=", c, " world_x=", world_x, " unproject=", vp,
			" new_y=", gp._get_judgment_line_y(c),
			" y_scaled=", vp.y * (float(get_viewport().get_visible_rect().size.y) / float(gp._subviewport.size.y)))
		pass

	print("Q6 track_screen_min=", gp._track_screen_min, " max=", gp._track_screen_max)
	for c: int in range(1, Global.COLUMN_NUM + 1):
		print("Q7 col=", c, " screen_x=", gp._get_column_screen_x(c))
		pass

	# 反馈标签状态
	print("Q8 feedback label count=", gp._feedback_labels.size())
	var lbl: RichTextLabel = gp._feedback_labels[0]
	print("Q9 label font_size=", lbl.get_theme_font_size("normal_font_size"),
		" custom_min=", lbl.custom_minimum_size, " scroll_active=", lbl.scroll_active,
		" bbcode=", lbl.bbcode_enabled, " autowrap=", lbl.autowrap_mode)

	# 触发一次判定反馈, 看标签落在哪里
	gp.show_judgment_feedback(-40, "harmonious", 2)
	print("Q10 after feedback: pos=", lbl.position, " size=", lbl.size, " visible=", lbl.visible,
		" parsed='", lbl.get_parsed_text(), "'")

	# 连击标签的初始状态
	print("Q11 combo label visible=", gp._combo_label.visible, " text='", gp._combo_label.text,
		"' _last_combo=", gp._last_combo, " Global.combo=", Global.combo)

	# 打击音播放池
	print("Q12 hit pool size=", gp._hit_sound_players.size())
	if gp._hit_sound_players.size() > 0:
		print("Q13 stream=", gp._hit_sound_players[0].stream, " len=", gp._hit_sound_players[0].stream.get_length())
		pass
	gp.play_hit_sound()

	# InputProcesser 的新路径
	for i: int in range(gp.input_processers.size()):
		var col: Node3D = gp.input_processers[i]
		print("Q14 column ", i + 1, " material=", col._track_material, " judging_mat=", col._judging_material,
			" particle_mat=", col._particle_material, " particles=", col.gpu_particles_3d)
		col.flash_track(0.8)
		col.set_particle_style(Color(1, 0, 0, 1), 12)
		print("Q15 column ", i + 1, " highlight=", col._highlight, " judging_highlight=", col._judging_highlight,
			" amount=", col.gpu_particles_3d.amount)
		pass

	print("Q16 background material=", gp.background.material)
	print("=== PROBE2 END ===")
	get_tree().quit()
	pass
