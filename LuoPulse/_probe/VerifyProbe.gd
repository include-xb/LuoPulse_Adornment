## 独立验证探针: 判定反馈标签的屏幕落点 (review 用, 用完删除)
extends Node


var gp: Control = null


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var packed: PackedScene = load("res://Scene/Core/Gameplay.tscn")
	gp = packed.instantiate()
	gp.is_test = true
	add_child(gp)

	for _i in range(5):
		await get_tree().process_frame
		pass

	var root_vp: Vector2 = get_viewport().get_visible_rect().size
	var ui: Control = gp.get_node("UI")
	var tr: TextureRect = gp.get_node("UI/TextureRect")
	var sv: SubViewport = gp._subviewport

	print("=== VERIFY START ===")
	print("V1 root visible_rect=", root_vp)
	print("V2 UI rect pos=", ui.position, " size=", ui.size, " global_rect=", ui.get_global_rect())
	print("V3 TextureRect pos=", tr.position, " size=", tr.size, " global_rect=", tr.get_global_rect())
	print("V4 TextureRect expand_mode=", tr.expand_mode, " stretch_mode=", tr.stretch_mode,
		" texture=", tr.texture, " tex_size=", tr.texture.get_size() if tr.texture else "null")
	print("V5 SubViewport size=", sv.size, " scale=", gp._subviewport_scale())

	# 判定线在世界 (world_x, 0, 0); 相机把它投到 SubViewport 内部像素
	var world_x: float = gp._get_column_world_x(2)
	var vp: Vector2 = gp._camera.unproject_position(Vector3(world_x, 0.0, 0.0))
	var r: Rect2 = tr.get_global_rect()
	# 纹理 (0..1024) 铺满 TextureRect 的映射
	var correct_screen: Vector2 = Vector2(
		r.position.x + (vp.x / float(sv.size.x)) * r.size.x,
		r.position.y + (vp.y / float(sv.size.y)) * r.size.y
	)
	print("V6 unproject(vp-space)=", vp, " ratio=", Vector2(vp.x / float(sv.size.x), vp.y / float(sv.size.y)))
	print("V7 正确屏幕落点 =", correct_screen)
	print("V8 代码给出 _get_judgment_line_y(2)=", gp._get_judgment_line_y(2))

	# 触发一次反馈
	gp.show_judgment_feedback(-40, "harmonious", 2)
	var lbl: RichTextLabel = gp._feedback_labels[0]
	var container: Control = gp._judgment_container
	await get_tree().process_frame
	print("V9 container rect=", container.get_global_rect())
	print("V10 label pos=", lbl.position, " size=", lbl.size,
		" global_rect=", lbl.get_global_rect())
	print("V11 label parses to '", lbl.get_parsed_text().replace("\n", " | "), "'")
	print("V12 label bottom = ", lbl.get_global_rect().end.y,
		" window height = ", root_vp.y,
		" offscreen(下) = ", lbl.get_global_rect().position.y > root_vp.y)
	print("V13 label intersect window = ", lbl.get_global_rect().intersects(Rect2(Vector2.ZERO, root_vp)))

	# 再加一个巨大的视觉标记, 便于截图对比
	var mark: ColorRect = ColorRect.new()
	mark.color = Color(1, 0, 0, 1)
	mark.size = Vector2(400, 24)
	mark.position = Vector2(0, correct_screen.y - 12.0)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gp.get_node("UI").add_child(mark)
	print("V14 已放置红色标记于 y=", mark.position.y)
	print("=== VERIFY END ===")
	pass
