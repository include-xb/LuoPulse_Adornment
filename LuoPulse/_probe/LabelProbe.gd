## 临时探针 4: 反馈标签的两行内容高度 vs 64px 盒子 (review 用, 用完删除)
extends Node


func _ready() -> void:
	print("=== PROBE4 START ===")
	var lbl: RichTextLabel = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.scroll_active = false
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.add_theme_font_size_override("normal_font_size", 32)
	lbl.custom_minimum_size = Vector2(180.0, 64.0)
	lbl.size = Vector2(180.0, 64.0)
	add_child(lbl)
	await get_tree().process_frame

	lbl.text = "[center][color=#4db8ff]▲ EARLY[/color]\n[color=#6bca6b]和一[/color][/center]"
	await get_tree().process_frame
	print("S1 lines=", lbl.get_line_count(), " content_height=", lbl.get_content_height(),
		" box_height=", lbl.size.y, " fit_content=", lbl.fit_content)

	var f: Font = lbl.get_theme_font("normal_font")
	print("S2 font=", f, " size=", lbl.get_theme_font_size("normal_font_size"),
		" height=", f.get_height(lbl.get_theme_font_size("normal_font_size")))

	lbl.text = "[center][color=#6bca6b]◇ 和一[/color][/center]"
	await get_tree().process_frame
	print("S3 single line content_height=", lbl.get_content_height())

	lbl.custom_minimum_size = Vector2.ZERO
	lbl.size = Vector2(180.0, 64.0)
	lbl.text = "[center][color=#4db8ff]▲ EARLY[/color]\n[color=#6bca6b]和一[/color][/center]"
	await get_tree().process_frame
	print("S4 after custom_min=0 content_height=", lbl.get_content_height())
	print("=== PROBE4 END ===")
	get_tree().quit()
	pass
