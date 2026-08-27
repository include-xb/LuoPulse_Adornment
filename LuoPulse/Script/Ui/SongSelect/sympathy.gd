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

# 背景
@onready var background: TextureRect = $Background
@onready var cover: TextureRect = $Control/Cover
@onready var left: Button = $Select/Left

# 开始 (选中)
@onready var start: Button = $Select/Start

# 右切
@onready var right: Button = $Select/Right

# 展开/回退 动画
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 预览音频
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

# 下方进度条
@onready var progress_bar: ProgressBar = $ProgressBar

# 水晶数
@onready var amount: Label = $HBoxContainer/Currency/HBoxContainer/Amount

# 设置菜单
@onready var setting_panel: PanelContainer = $SettingPanel

# 自动播放按钮
@onready var autoplay_button: Button = $SettingPanel/CenterContainer/VBoxContainer/Body/AutoplayButton

# PV 播放按钮
@onready var pv_button: Button = $SettingPanel/CenterContainer/VBoxContainer/Body/PVButton



## 歌曲信息
# 标题
@onready var title: Label = $Control/VBoxContainer/Title

# P 主
@onready var producer: Label = $Control/VBoxContainer/Producer

# 谱师
@onready var creator: Label = $Control/VBoxContainer/Creator

# 演唱
@onready var vocalist: Label = $Control/VBoxContainer/Vocalist


func _ready() -> void:
	Global.game_mode = Global.GameMode.Sympathy
	setting_panel.visible = false
	setting_panel.modulate.a = 0.0
	# 页面背景色彩变化并非线性, 而是 U 形变化
	# background.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	# cover.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	
	# 界面数值显示
	amount.text = str(Global.crystal)
	
	animation_player.play("unfold")
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
func refresh_progress_bar()-> void:
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
	$"..".start_scene_by_path("res://Scene/Core/Gameplay.tscn", {}, "img", cover.texture)
	pass # Replace with function body.


func _on_setting_pressed() -> void:
	setting_panel.visible = true
	setting_panel.modulate.a = 0.0
	
	autoplay_button.text = "自动播放     " + ("开" if Global.is_autoplay else "关")
	pv_button.text = "播放 PV        " + ("开" if Global.is_pvplay else "关")

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(setting_panel, "modulate:a", 1.0, 0.3)

	var scale_tween: Tween = create_tween()
	scale_tween.set_trans(Tween.TRANS_CUBIC)
	scale_tween.set_ease(Tween.EASE_OUT)
	setting_panel.pivot_offset = setting_panel.size * 0.5
	setting_panel.scale = Vector2(0.85, 0.85)
	scale_tween.tween_property(setting_panel, "scale", Vector2.ONE, 0.3)
	pass


func _on_ok_button_pressed() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(setting_panel, "modulate:a", 0.0, 0.2)
	await tween.finished
	setting_panel.visible = false
	setting_panel.scale = Vector2.ONE
	pass


func _on_autoplay_button_pressed() -> void:
	Global.is_autoplay = !Global.is_autoplay
	autoplay_button.text = "自动播放     " + ("开" if Global.is_autoplay else "关")
	pass


func _on_pv_button_pressed() -> void:
	Global.is_pvplay = !Global.is_pvplay
	pv_button.text = "播放 PV        " + ("开" if Global.is_pvplay else "关")
	pass
