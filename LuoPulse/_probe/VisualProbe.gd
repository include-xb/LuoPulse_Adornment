## 临时探针 5: 视觉验证 64px 盒子是否裁掉第二行 (review 用, 用完删除)
extends Node


func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.25, 1.0)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# A: 与 show_judgment_feedback 完全一致的配置 (180x64, 两行)
	var a: RichTextLabel = RichTextLabel.new()
	a.bbcode_enabled = true
	a.scroll_active = false
	a.autowrap_mode = TextServer.AUTOWRAP_OFF
	a.add_theme_font_size_override("normal_font_size", 32)
	a.custom_minimum_size = Vector2(180.0, 64.0)
	a.size = Vector2(180.0, 64.0)
	a.position = Vector2(100, 100)
	a.text = "[center][color=#4db8ff]▲ EARLY[/color]\n[color=#6bca6b]和一[/color][/center]"
	add_child(a)

	# B: 对照组, 只把盒子加高到 96
	var b: RichTextLabel = RichTextLabel.new()
	b.bbcode_enabled = true
	b.scroll_active = false
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.add_theme_font_size_override("normal_font_size", 32)
	b.size = Vector2(180.0, 96.0)
	b.position = Vector2(400, 100)
	b.text = "[center][color=#4db8ff]▲ EARLY[/color]\n[color=#6bca6b]和一[/color][/center]"
	add_child(b)

	# C: 64px 盒子里放单行 (◇ 和一)
	var c: RichTextLabel = RichTextLabel.new()
	c.bbcode_enabled = true
	c.scroll_active = false
	c.autowrap_mode = TextServer.AUTOWRAP_OFF
	c.add_theme_font_size_override("normal_font_size", 32)
	c.size = Vector2(180.0, 64.0)
	c.position = Vector2(700, 100)
	c.text = "[center][color=#6bca6b]◇ 和一[/color][/center]"
	add_child(c)

	# 加一个 1px 的框标注 A 的 64px 盒子边界
	var frame: ColorRect = ColorRect.new()
	frame.color = Color(1, 1, 0, 1)
	frame.size = Vector2(180, 1)
	frame.position = Vector2(100, 164)
	add_child(frame)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://_probe/out.png")
	print("PROBE5 saved res://_probe/out.png size=", img.get_size())
	get_tree().quit()
	pass
