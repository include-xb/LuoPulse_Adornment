## Album 断章 — 选专辑 / 选歌界面
##
## 双层导航: 先选专辑 → 再选单曲


extends Control


@onready var album_view: Control = $AlbumView
@onready var song_view: Control = $SongView
@onready var album_name_label: Label = $AlbumView/AlbumNameLabel
@onready var album_cover: ColorRect = $AlbumView/Display/AlbumCoverWrap/AlbumCover
@onready var song_list: VBoxContainer = $AlbumView/Display/SongListScroll/SongList
@onready var song_name_label: Label = $SongView/SongNameLabel
@onready var album_label: Label = $SongView/AlbumLabel
@onready var song_cover: ColorRect = $SongView/SongCoverWrap/SongCover
@onready var song_staff: RichTextLabel = $SongView/SongInfo/Staff
@onready var quote_label: Label = $QuoteLabel

var current_album_index: int = 0
var selected_song_index: int = 0
var in_song_view: bool = false


func _ready() -> void:
	quote_label.text = "\"原来，回忆可以从任何地方开始...\""
	_show_album_view()


func _show_album_view() -> void:
	in_song_view = false
	album_view.visible = true
	song_view.visible = false
	_refresh_album()


func _show_song_view() -> void:
	in_song_view = true
	album_view.visible = false
	song_view.visible = true
	_refresh_song_view()


func _refresh_album() -> void:
	var album: Dictionary = _get_album_at(current_album_index)
	album_name_label.text = album.get("title", "")

	for child in song_list.get_children():
		child.queue_free()

	var songs: Array = album.get("songs", [])
	for i in songs.size():
		var s: Dictionary = songs[i]
		var btn: Button = Button.new()
		btn.text = "%d. %s" % [i + 1, s.get("title", "???")]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		if i == selected_song_index:
			btn.button_pressed = true
		btn.pressed.connect(_on_song_selected.bind(i))
		song_list.add_child(btn)


func _refresh_song_view() -> void:
	var album: Dictionary = _get_album_at(current_album_index)
	var songs: Array = album.get("songs", [])
	var song: Dictionary = songs[selected_song_index] if selected_song_index < songs.size() else { }

	album_label.text = album.get("title", "")
	song_name_label.text = song.get("title", "???")
	song_staff.text = song.get("staff", "???")


func _on_song_selected(index: int) -> void:
	selected_song_index = index
	_refresh_album()


func _on_enter_song() -> void:
	var album: Dictionary = _get_album_at(current_album_index)
	var songs: Array = album.get("songs", [])
	if selected_song_index >= songs.size():
		return
	_show_song_view()


func _on_prev_album() -> void:
	if current_album_index > 0:
		current_album_index -= 1
		selected_song_index = 0
		_refresh_album()


func _on_next_album() -> void:
	var albums: Array[Dictionary] = _get_all_albums()
	if current_album_index < albums.size() - 1:
		current_album_index += 1
		selected_song_index = 0
		_refresh_album()


func _on_prev_song() -> void:
	if selected_song_index > 0:
		selected_song_index -= 1
		_refresh_song_view()


func _on_next_song() -> void:
	var album: Dictionary = _get_album_at(current_album_index)
	var songs: Array = album.get("songs", [])
	if selected_song_index < songs.size() - 1:
		selected_song_index += 1
		_refresh_song_view()


func _on_play_song() -> void:
	var album: Dictionary = _get_album_at(current_album_index)
	var songs: Array = album.get("songs", [])
	if selected_song_index >= songs.size():
		return
	var song: Dictionary = songs[selected_song_index]
	Global.current_song_title = song.get("title", "")
	Global.current_song_artist = song.get("producer", "")
	Global.current_song_bpm = ""
	Global.game_mode = Global.GameMode.Album
	SceneManager.change_scene("res://Scene/Core/Gameplay.tscn")


func _on_album_back() -> void:
	SceneManager.change_scene("res://Scene/Ui/Menu/MainMenu.tscn")


func _on_song_back() -> void:
	_show_album_view()


func _get_album_at(index: int) -> Dictionary:
	var albums: Array[Dictionary] = _get_all_albums()
	if index >= 0 and index < albums.size():
		return albums[index]
	return { }


func _get_all_albums() -> Array[Dictionary]:
	var path: String = "res://Data/sideline_albums.json"
	if not FileAccess.file_exists(path):
		return [ ]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json: String = file.get_as_text()
	var json_parser := JSON.new()
	var error := json_parser.parse(json)
	if error == OK:
		return json_parser.data
	return [ ]
