## 临时探针 3: 驱动真实判定流程 (review 用, 用完删除)
extends Node


func _ready() -> void:
	print("=== PROBE3 START ===")

	# 各改动脚本能否真正加载 (真·解析检查, 不走 validate_script 的隔离包裹)
	for path: String in [
		"res://Script/Core/HitFeedback.gd",
		"res://Script/Core/HitSoundFactory.gd",
		"res://Script/Core/NoteTemplate/NoteBase.gd",
		"res://Script/Core/NoteTemplate/Hold.gd",
		"res://Script/Core/NoteTemplate/Tap.gd",
		"res://Script/Core/NoteTemplate/Drag.gd",
		"res://Script/Core/NoteTemplate/Heart.gd",
		"res://Script/Core/NoteTemplate/Release.gd",
		"res://Script/Core/Gameplay.gd",
		"res://Script/Core/InputProcesser.gd",
	]:
		var scr: GDScript = load(path)
		var methods: PackedStringArray = []
		for m: Dictionary in scr.get_script_method_list():
			methods.append(m["name"])
			pass
		print("R1 ", path.get_file(), " can_instantiate=", scr.can_instantiate(),
			" has_play_hit_sound=", methods.has("play_hit_sound"),
			" has_flash_background=", methods.has("flash_background"),
			" has_emit_particles=", methods.has("emit_particles"))
		pass

	var packed: PackedScene = load("res://Scene/Core/Gameplay.tscn")
	var gp: Control = packed.instantiate()
	gp.is_test = true
	add_child(gp)

	# 等待第一个音符进入判定窗
	var waited: float = 0.0
	while Global.judging_area.size() == 0 and waited < 12.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		pass
	print("R2 waited=", waited, "s judging_area=", Global.judging_area.size(),
		" rendering_area=", Global.rendering_area.size(), " master_time=", gp.master_time)
	if Global.judging_area.size() == 0:
		print("R2b 没能等到音符, 中止")
		get_tree().quit()
		return
		pass

	var note: Node = Global.judging_area[0]
	print("R3 note type=", note.type, " column=", note.column, " time=", note.time,
		" root_node=", note.root_node, " is_note_base=", note is NoteBase)

	# --- 完美命中 ---
	note.judge(float(note.time))
	await get_tree().create_timer(0.05).timeout
	print("R4 after perfect hit: combo=", Global.combo, " combo_label.visible=", gp._combo_label.visible,
		" text='", gp._combo_label.text, "' scale=", gp._combo_label.scale,
		" pivot=", gp._combo_label.pivot_offset)
	var playing: int = 0
	for p: AudioStreamPlayer in gp._hit_sound_players:
		if p.playing:
			playing += 1
			pass
		pass
	print("R5 hit sound players playing=", playing, " vol=", gp._hit_sound_players[0].volume_linear)
	print("R6 background flash=", gp._background_flash)

	# --- 超时漏键的反馈文本 (time_offset == 0 且 lost) ---
	gp.show_judgment_feedback(0, "lost", 1)
	var lbl: RichTextLabel = gp._feedback_labels[gp._feedback_index - 1]
	print("R7 timeout-miss label parsed='", lbl.get_parsed_text(), "' pos=", lbl.position)
	gp.show_judgment_feedback(-60, "harmonious", 1)
	lbl = gp._feedback_labels[gp._feedback_index - 1]
	print("R8 early label parsed='", lbl.get_parsed_text(), "'")
	gp.show_judgment_feedback(150, "lost", 1)
	lbl = gp._feedback_labels[gp._feedback_index - 1]
	print("R9 late label parsed='", lbl.get_parsed_text(), "'")

	# --- 连击中断 ---
	Global.combo = 0
	gp._on_combo_changed()
	print("R10 combo-break: visible=", gp._combo_label.visible, " text='", gp._combo_label.text, "'")
	await get_tree().create_timer(0.6).timeout
	print("R11 after break hold: visible=", gp._combo_label.visible)

	# --- 里程碑震动 ---
	Global.combo = 50
	gp._on_combo_changed()
	print("R12 milestone: shake origin_captured=", gp._has_view_rect_origin,
		" origin=", gp._view_rect_origin, " pos_now=", gp._view_rect.position,
		" tween_valid=", gp._shake_tween != null and gp._shake_tween.is_valid())
	await get_tree().create_timer(0.4).timeout
	print("R13 after shake: pos=", gp._view_rect.position, " origin=", gp._view_rect_origin,
		" combo_label scale=", gp._combo_label.scale, " color=", gp._combo_label.get_theme_color("font_color"))

	# --- 一次真实判定后各列轨道高亮/粒子状态 ---
	for i: int in range(gp.input_processers.size()):
		var col: Node3D = gp.input_processers[i]
		print("R14 col", i + 1, " highlight=", col._highlight, " judging_highlight=", col._judging_highlight,
			" amount=", col.gpu_particles_3d.amount, " albedo=", col._particle_material.albedo_color)
		pass

	print("=== PROBE3 END ===")
	get_tree().quit()
	pass
