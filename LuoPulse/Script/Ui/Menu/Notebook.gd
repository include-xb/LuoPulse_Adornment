## Notebook 笔记本场景
##
## 包含两个标签页: 资料卡 和 故事碎片
## 左侧索引列表, 右侧内容显示


extends Control


@onready var tab_cards: Button = $Margin/TabBar/CardsTab
@onready var tab_fragments: Button = $Margin/TabBar/FragmentsTab
@onready var sidebar: VBoxContainer = $Margin/HSplit/Sidebar/Scroll/SidebarList
@onready var main_content: MarginContainer = $Margin/HSplit/MainContent/Scroll/Margin
@onready var content_label: RichTextLabel = $Margin/HSplit/MainContent/Scroll/Margin/ContentLabel
@onready var slip_paper: PanelContainer = $SlipOverlay/SlipPaper
@onready var slip_label: Label = $SlipOverlay/SlipPaper/Margin/SlipLabel

var current_tab: String = "cards"
var selected_card_index: int = -1
var selected_fragment_index: int = -1


func _ready() -> void:
	slip_paper.visible = false
	switch_tab("cards")


func _on_back_pressed() -> void:
	if Global.notebook_return_scene == "results":
		SceneManager.change_scene("res://Scene/Ui/SongSelect/Sympathy.tscn")
	else:
		SceneManager.change_scene("res://Scene/Ui/Menu/MainMenu.tscn")
	Global.notebook_return_scene = "home"


func _on_cards_tab_pressed() -> void:
	switch_tab("cards")


func _on_fragments_tab_pressed() -> void:
	switch_tab("fragments")


func switch_tab(tab: String) -> void:
	current_tab = tab
	tab_cards.button_pressed = (tab == "cards")
	tab_fragments.button_pressed = (tab == "fragments")

	# 清左侧
	for child in sidebar.get_children():
		child.queue_free()

	if tab == "cards":
		_build_card_list()
	else:
		_build_fragment_list()


func _build_card_list() -> void:
	var songs: Array = _get_song_data()
	for i in songs.size():
		var song: Dictionary = songs[i]
		var btn: Button = Button.new()
		if song.get("unlocked", false):
			btn.text = song["title"]
		elif i == _first_locked_index(songs):
			btn.text = song["title"]
			btn.modulate = Color(0.5, 0.5, 0.5, 1)
			btn.disabled = true
		else:
			btn.text = "???"
			btn.modulate = Color(0.6, 0.6, 0.6, 1)
			btn.disabled = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.pressed.connect(_on_card_selected.bind(i))
		sidebar.add_child(btn)

	# 自动选中第一首已解锁
	for i in songs.size():
		if songs[i].get("unlocked", false):
			_on_card_selected(i)
			break


func _build_fragment_list() -> void:
	var fragments: Array = _get_fragment_data()
	for i in fragments.size():
		var frag: Dictionary = fragments[i]
		var btn: Button = Button.new()
		if frag.get("unlocked", false):
			btn.text = frag["title"]
		else:
			btn.text = "???"
			btn.modulate = Color(0.6, 0.6, 0.6, 1)
			btn.disabled = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.pressed.connect(_on_fragment_selected.bind(i))
		sidebar.add_child(btn)

	var first_unlocked: int = -1
	for i in fragments.size():
		if fragments[i].get("unlocked", false):
			first_unlocked = i
			break
	if first_unlocked >= 0:
		_on_fragment_selected(first_unlocked)


func _on_card_selected(index: int) -> void:
	selected_card_index = index
	var songs: Array = _get_song_data()
	if index >= songs.size():
		return
	var song: Dictionary = songs[index]
	content_label.text = _format_data_card(song)


func _on_fragment_selected(index: int) -> void:
	selected_fragment_index = index
	var fragments: Array = _get_fragment_data()
	if index >= fragments.size():
		return
	var frag: Dictionary = fragments[index]
	content_label.text = _format_diary_entry(frag)


func _format_data_card(song: Dictionary) -> String:
	var bbcode: String = "[center][font_size=36]♪ %s[/font_size][/center]\n\n" % song.get("title", "???")
	bbcode += "[center]P主: %s\n" % song.get("producer", "——")
	bbcode += "歌手: %s\n" % song.get("vocalist", "——")
	bbcode += "BPM: %s\n" % str(song.get("bpm", "——"))
	bbcode += "收录专辑: %s\n" % song.get("album", "——")
	bbcode += "发布时间: %s[/center]\n\n" % song.get("release_date", "——")
	bbcode += "[center]── 创作背景 ──[/center]\n\n"
	bbcode += "%s\n\n" % song.get("background", "（待补充）")
	bbcode += "[center]── P主简介 ──[/center]\n\n"
	bbcode += "%s\n" % song.get("producer_intro", "（待补充）")

	if Global.notebook_return_scene != "home" and Global.notebook_return_song_title != "":
		bbcode += "\n\n[center][url=close]关闭[/url][/center]"
	return bbcode


func _format_diary_entry(frag: Dictionary) -> String:
	var header: String = "%s    %s    %s" % [
		frag.get("date", ""),
		frag.get("day_of_week", ""),
		frag.get("weather", "")
	]
	var bbcode: String = "[right]%s[/right]\n" % header
	bbcode += "———————————————————————\n\n"
	bbcode += frag.get("content", "")
	if frag.get("discover_time", "") != "":
		bbcode += "\n\n[right]发现于 %s[/right]" % frag["discover_time"]
	return bbcode


func _first_locked_index(songs: Array) -> int:
	for i in songs.size():
		if not songs[i].get("unlocked", false):
			return i
	return -1


func _get_song_data() -> Array:
	# 从外部 JSON 文件加载资料卡数据
	var path: String = "res://Data/song_cards.json"
	if not FileAccess.file_exists(path):
		return [ ]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json: String = file.get_as_text()
	var json_parser := JSON.new()
	var error := json_parser.parse(json)
	if error == OK:
		return json_parser.data
	return [ ]


func _get_fragment_data() -> Array:
	# 从外部 JSON 文件加载故事碎片数据
	var path: String = "res://Data/story_fragments.json"
	if not FileAccess.file_exists(path):
		return [ ]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json: String = file.get_as_text()
	var json_parser := JSON.new()
	var error := json_parser.parse(json)
	if error == OK:
		return json_parser.data
	return [ ]


func _on_content_meta_clicked(meta: Variant) -> void:
	if meta == "close":
		_on_back_pressed()


func show_slip(message: String) -> void:
	slip_label.text = message
	slip_paper.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(slip_paper, "position:y", 50.0, 0.5).from(-120.0)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)


func _on_slip_pressed() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(slip_paper, "position:y", -120.0, 0.35)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	slip_paper.visible = false
