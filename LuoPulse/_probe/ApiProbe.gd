## 临时 API 探针 (review 用, 用完删除)
extends Node


func _ready() -> void:
	print("=== PROBE START ===")

	# --- 1. AudioStreamWAV 合成链路 ---
	var sfx: AudioStreamWAV = HitSoundFactory.make_hit_sound()
	print("P1 wav format=", sfx.format, " is16=", sfx.format == AudioStreamWAV.FORMAT_16_BITS,
		" mix_rate=", sfx.mix_rate, " stereo=", sfx.is_stereo(),
		" bytes=", sfx.get_data().size(), " length_s=", sfx.get_length())

	# --- 2. encode_s16 参数顺序 ---
	var b: PackedByteArray = PackedByteArray()
	b.resize(4)
	b.encode_s16(0, 258)
	print("P2 encode_s16(offset=0, value=258) -> bytes ", b[0], ",", b[1], " (little endian 期望 2,1)")

	# --- 3. RichTextLabel 主题项 ---
	var rt: RichTextLabel = RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rt.add_theme_font_size_override("normal_font_size", 32)
	rt.text = "[center][color=#ff0000]▲ EARLY[/color]\n[color=#00ff00]和一[/color][/center]"
	add_child(rt)
	await get_tree().process_frame
	print("P3 rtl normal_font_size=", rt.get_theme_font_size("normal_font_size"),
		" parsed='", rt.get_parsed_text(), "'")

	var rt2: RichTextLabel = RichTextLabel.new()
	rt2.add_theme_font_size_override("font_size", 32)
	print("P4 rtl WRONG item 'font_size' has_override=", rt2.has_theme_font_size_override("font_size"),
		" resolved normal_font_size=", rt2.get_theme_font_size("normal_font_size"))

	# --- 4. GPUParticles3D draw_pass_1 复制 + surface_get_material ---
	var p: GPUParticles3D = GPUParticles3D.new()
	var qm: QuadMesh = QuadMesh.new()
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.albedo_color = Color(0.4, 0.8, 1.0, 1.0)
	qm.material = sm
	p.draw_pass_1 = qm
	add_child(p)
	print("P5 draw_pass_1 class=", p.draw_pass_1.get_class(),
		" surface_get_material(0)=", p.draw_pass_1.surface_get_material(0),
		" surface_count=", p.draw_pass_1.get_surface_count())
	var dup_mesh: Mesh = p.draw_pass_1.duplicate() as Mesh
	p.draw_pass_1 = dup_mesh
	var raw_mat: Material = dup_mesh.surface_get_material(0)
	print("P6 dup surface_get_material(0)=", raw_mat, " is_null=", raw_mat == null)
	if raw_mat != null:
		var dup_mat: StandardMaterial3D = raw_mat.duplicate() as StandardMaterial3D
		dup_mesh.surface_set_material(0, dup_mat)
		dup_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		print("P6b dup_mat=", dup_mat, " shared_with_src=", dup_mat == sm,
			" dup albedo=", dup_mat.albedo_color, " src albedo=", sm.albedo_color)
		pass

	# --- 5. amount 运行时修改 + one_shot 重启 ---
	p.amount = 30
	p.amount = 8
	print("P7 amount set runtime -> ", p.amount)
	p.lifetime = 0.18
	p.explosiveness = 0.9
	p.one_shot = true
	p.emitting = false
	p.emitting = true
	print("P8 emitting=", p.emitting, " one_shot=", p.one_shot, " explosiveness=", p.explosiveness)

	# --- 6. AudioStreamPlayer volume_linear ---
	var ap: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(ap)
	ap.stream = sfx
	ap.volume_linear = 0.7
	print("P9 volume_linear=", ap.volume_linear, " volume_db=", ap.volume_db)
	ap.play()
	print("P10 playing=", ap.playing)

	# --- 7. shader uniform 列表 ---
	var sh: Shader = load("res://Shader/gray_scale.gdshader")
	for u: Dictionary in sh.get_shader_uniform_list(true):
		print("P11 gray_scale uniform: ", u["name"], " type=", u["type"])
		pass
	var sh2: Shader = load("res://Shader/track_edge.gdshader")
	for u: Dictionary in sh2.get_shader_uniform_list(true):
		print("P12 track_edge uniform: ", u["name"], " type=", u["type"])
		pass

	# --- 8. Tween 语义 ---
	var holder: Control = Control.new()
	add_child(holder)
	var t: Tween = create_tween()
	print("P13 fresh tween is_valid=", t.is_valid())
	t.tween_interval(0.05)
	t.tween_callback(func() -> void: print("P14 interval->callback fired"))
	await get_tree().create_timer(0.3).timeout
	print("P15 tween is_valid after finish=", t.is_valid())

	print("=== PROBE END ===")
	get_tree().quit()
	pass
