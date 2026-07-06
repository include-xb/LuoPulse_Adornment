## Sympathy 共鸣主线
##
## 可以切换到这里的场景:
## 		- MainMenu 游戏主页面
## 		- Gameplay 游戏界面
## 		- SettingMenu 设置页面
## 		- CardMenu 资料卡界面
## 从这里可以前往: 
## 		- Gameplay 游戏界面
## 		- MainMenu 游戏主页面
## 		- SettingMenu 设置页面
## 		- CardMenu 资料卡界面


extends Control


@onready var background: TextureRect = $Background
@onready var cover: TextureRect = $Cover
@onready var left: Button = $Select/Left
@onready var start: Button = $Select/Start
@onready var right: Button = $Select/Right
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var progress_bar: ProgressBar = $ProgressBar



@onready var title: Label = $VBoxContainer/Title
@onready var producer: Label = $VBoxContainer/Producer
@onready var creator: Label = $VBoxContainer/Creator
@onready var vocalist: Label = $VBoxContainer/Vocalist



func _ready() -> void:
	Global.game_mode = Global.GameMode.Sympathy
	background.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	cover.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	
	animation_player.play("unfold")
	print(Global.sympath_song_path_list)
	load_song_info()
	refresh_progress_bar()


func load_song_info() -> void:
	audio_stream_player.stream_paused = true
	var song_package_path: String = Global.sympath_song_path_list[Global.current_song_index]
	
	# 加载封面，更新背景和曲绘
	var song_cover: ImageTexture = _read_cover_from_lpz(song_package_path)
	background.texture = song_cover
	cover.texture = song_cover
	
	# 加载歌曲信息
	var song_chart: Dictionary = _read_chart_from_lpz(song_package_path)
	var general: Dictionary = song_chart.get("General", {})
	title.text = general.get("Title", "-")
	producer.text = general.get("Artist", "-")
	creator.text = general.get("Creator", "-")
	vocalist.text = general.get("Vocalist", "-")
	
	# 加载歌曲音频
	var song_audio_stream: AudioStream = _read_audio_from_lpz(song_package_path)
	audio_stream_player.stream = song_audio_stream
	if audio_stream_player.stream:
		audio_stream_player.play()
		pass

# ============================================================
# LPZ 文件读取
# ============================================================

## 从 .lpz 文件中读取封面图片，返回 ImageTexture
func _read_cover_from_lpz(lpz_path: String) -> ImageTexture:
	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		push_error("无法打开 .lpz 文件: %s" % lpz_path)
		return null

	var cover_path := ""
	for f in zip.get_files():
		if f.get_file() == "cover.png":
			cover_path = f
			break

	if cover_path == "":
		zip.close()
		push_error("在 .lpz 中找不到 cover.png: %s" % lpz_path)
		return null

	var img_bytes := zip.read_file(cover_path)
	zip.close()

	var img := Image.new()
	var load_err := img.load_png_from_buffer(img_bytes)
	if load_err != OK:
		push_error("无法解码封面图片: %s" % cover_path)
		return null

	return ImageTexture.create_from_image(img)


## 从 .lpz 文件中读取音频，返回 AudioStream
func _read_audio_from_lpz(lpz_path: String) -> AudioStream:
	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		push_error("无法打开 .lpz 文件: %s" % lpz_path)
		return null

	var audio_path := ""
	for f in zip.get_files():
		if f.get_file() == "audio.wav":
			audio_path = f
			break

	if audio_path == "":
		zip.close()
		push_error("在 .lpz 中找不到 audio.wav: %s" % lpz_path)
		return null

	var audio_bytes := zip.read_file(audio_path)
	zip.close()

	var audio_stream := AudioStreamWAV.load_from_buffer(audio_bytes)
	if audio_stream == null:
		push_error("无法解码音频文件: %s" % audio_path)
		return null
	return audio_stream


## 从 .lpz 文件中读取 chart.lp
func _read_chart_from_lpz(lpz_path: String) -> Dictionary:
	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		return {}

	var chart_path := ""
	for f in zip.get_files():
		if f.get_file() == "chart.lp":
			chart_path = f
			break

	if chart_path == "":
		zip.close()
		return {}

	var json_bytes := zip.read_file(chart_path)
	zip.close()

	var json_str := json_bytes.get_string_from_utf8()

	var json := JSON.new()
	var parse_err := json.parse(json_str)
	if parse_err != OK:
		push_error("无法解析 chart.lp: %s" % lpz_path)
		return {}

	var data = json.get_data()
	#if data is Dictionary and data.has("General"):
		#return data["General"]
	#return {}
	return data


func refresh_progress_bar() -> void:
	progress_bar.value = int(float(Global.current_song_index + 1) / float(Global.sympath_song_num) * 100)
	pass



func _on_button_pressed() -> void:
	SceneManager.change_scene("res://Scene/Ui/Menu/MainMenu.tscn")
	pass # Replace with function body.


func _on_left_pressed() -> void:
	Global.current_song_index -= 1 if Global.current_song_index > 0 else 0
	refresh_progress_bar()
	
	animation_player.play_backwards("unfold")
	await animation_player.animation_finished
	load_song_info()
	animation_player.play("unfold")
	pass # Replace with function body.


func _on_right_pressed() -> void:
	Global.current_song_index += 1 if Global.current_song_index < Global.sympath_song_num - 1 else 0
	refresh_progress_bar()
	
	animation_player.play_backwards("unfold")
	await animation_player.animation_finished
	load_song_info()
	animation_player.play("unfold")
	pass # Replace with function body.
