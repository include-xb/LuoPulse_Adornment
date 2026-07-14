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
	
	# 页面背景色彩变化并非线性, 而是 U 形变化
	# background.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	# cover.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	
	animation_player.play("unfold")
	print(Global.sympath_song_path_list)
	load_song_info()
	refresh_progress_bar()
	pass


# 按钮的禁用与恢复
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if Global.current_song_index == 0:
		left.disabled = true
		pass
	else:
		left.disabled = false
		pass
	
	if Global.current_song_index == Global.sympath_song_num - 1:
		right.disabled = true
		pass
	else:
		right.disabled = false
		pass
	pass


# 加载曲包中的内容
func load_song_info() -> void:
	audio_stream_player.stream_paused = true
	var song_package_path: String = Global.sympath_song_path_list[Global.current_song_index]
	
	# 加载封面，更新背景和曲绘
	var song_cover: ImageTexture = Global._read_cover_from_lpz(song_package_path)
	background.texture = song_cover
	cover.texture = song_cover
	
	# 加载歌曲信息
	var song_chart: Dictionary = Global._read_chart_from_lpz(song_package_path)
	var general: Dictionary = song_chart.get("General", {})
	title.text = general.get("Title", "-")
	producer.text = general.get("Artist", "-")
	creator.text = general.get("Creator", "-")
	vocalist.text = general.get("Vocalist", "-")
	
	# 加载歌曲音频
	var song_audio_stream: AudioStream = Global._read_audio_from_lpz(song_package_path)
	audio_stream_player.stream = song_audio_stream
	if audio_stream_player.stream:
		audio_stream_player.play()
		pass
	
	pass




# 进度条跟进
func refresh_progress_bar() -> void:
	progress_bar.value = int(float(Global.current_song_index + 1) / float(Global.sympath_song_num) * 100)
	pass


# 返回 MainMenu
func _on_back_pressed() -> void:
	audio_stream_player.stop()
	Global.play_ui_click_audio()
	Global.game_mode = Global.GameMode.None
	$"..".back_to_previous_scene()
	pass # Replace with function body.


# 向左切歌
func _on_left_pressed() -> void:
	audio_stream_player.stop()
	Global.play_ui_click_audio()
	Global.current_song_index -= 1# if Global.current_song_index > 0 else 0
	refresh_progress_bar()
	
	animation_player.play_backwards("unfold")
	await animation_player.animation_finished
	load_song_info()
	animation_player.play("unfold")
	pass # Replace with function body.


# 向右切歌
func _on_right_pressed() -> void:
	audio_stream_player.stop()
	Global.play_ui_click_audio()
	Global.current_song_index += 1# if Global.current_song_index < Global.sympath_song_num - 1 else 0
	refresh_progress_bar()
	
	animation_player.play_backwards("unfold")
	await animation_player.animation_finished
	load_song_info()
	animation_player.play("unfold")
	pass # Replace with function body.


# 开始
func _on_start_pressed() -> void:
	audio_stream_player.stop()
	Global.play_ui_click_audio()
	# SceneManager.change_scene("res://Scene/Core/Gameplay.tscn")
	$"..".start_scene_by_path("res://Scene/Core/Gameplay.tscn", {}, "img", cover.texture)
	pass # Replace with function body.
