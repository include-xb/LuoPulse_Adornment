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


## 背景
@onready var background: TextureRect = $Background

## 曲绘封面
@onready var cover: TextureRect = $Control/Cover

## 左切
@onready var left: Button = $Select/Left

## 开始 (选中)
@onready var start: Button = $Select/Start

## 右切
@onready var right: Button = $Select/Right

## 展开/回退 动画
@onready var animation_player: AnimationPlayer = $AnimationPlayer

## 预览音频
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

## 下方进度条
@onready var progress_bar: ProgressBar = $ProgressBar

## 显示水晶数的标签
@onready var amount: Label = $HBoxContainer/Currency/HBoxContainer/Amount

## 设置菜单
@onready var setting_panel: PanelContainer = $SettingPanel

## 自动播放按钮
@onready var autoplay_button: Button = $SettingPanel/CenterContainer/VBoxContainer/Body/AutoplayButton

## PV 播放按钮
@onready var pv_button: Button = $SettingPanel/CenterContainer/VBoxContainer/Body/PVButton

## 解锁按钮
@onready var unlock_button: Button = $MarginContainer/Option/UnlockButton


# ---------- 歌曲信息 ----------
## 标题
@onready var title: Label = $Control/VBoxContainer/Title

## P 主
@onready var producer: Label = $Control/VBoxContainer/Producer

## 谱师
@onready var creator: Label = $Control/VBoxContainer/Creator

## 演唱
@onready var vocalist: Label = $Control/VBoxContainer/Vocalist


## 当前歌曲是否未解锁
var is_locked: bool = false

## 解锁当前歌曲需要的水晶数量
var needed_crystal_num: int = 10

# ---------- 预览音频淡入淡出 ----------
## 用于音频淡入淡出
var _audio_fade_tween: Tween = null

## 开始播放预览的位置 (秒)
var start_pointer: float = 0.0

## 当前播放预览的位置 (秒)
var current_pointer: float = 0.0

## 结束播放预览的位置 (秒)
var end_pointer: float = 0.0

## 正在回拨
var is_back: bool = false

## 音频淡入时间
const AUDIO_FADE_IN_TIME: float = 1.0

## 音频淡出时间
const AUDIO_FADE_OUT_TIME: float = 1.0

## 最小音量
const AUDIO_SILENCE_DB: float = -80.0


# ---------- 节点函数重载 ----------
func _ready() -> void:
	Global.game_mode = Global.GameMode.Sympathy
	setting_panel.visible = false
	setting_panel.modulate.a = 0.0
	# 页面背景色彩变化并非线性, 而是 U 形变化
	# background.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	# cover.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	
	# 水晶数值显示
	update_crystal_num()
	
	update_if_locked()
	
	animation_player.play("unfold")
	# 监听整曲预览播到结尾的回调 (PreviewEnd == -1 / 缺省时实现整曲循环)
	audio_stream_player.finished.connect(_on_preview_finished)
	load_song_info()
	# 解锁按钮文字设置
	update_unlock_button()
	refresh_progress_bar()
	pass


# 每次重新进入场景树时刷新水晶显示
# SceneManager 通过 remove_child / add_child 复用场景节点, _ready 只在首次进入时执行一次
func _enter_tree() -> void:
	if not is_node_ready():
		return
	update_crystal_num()
	
	update_if_locked()
	update_song()
	pass


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
	
	current_pointer = audio_stream_player.get_playback_position()
	# 循环播放预览部分
	if current_pointer >= end_pointer and not is_back:
		is_back = true
		_fade_out_audio()
		audio_stream_player.play(start_pointer)
		_fade_in_audio()
		pass
	pass


# ---------- 工具函数 ----------
## 进度条跟进
func refresh_progress_bar()-> void:
	progress_bar.value = int(float(Global.current_song_index + 1) / float(Global.sympath_song_num) * 100)
	pass


## 更新当前歌曲信息 (动画 + 加载信息 + 更新按钮状态)
func update_song() -> void:
	animation_player.play_backwards("unfold")
	await animation_player.animation_finished
	load_song_info()
	update_unlock_button()
	animation_player.play("unfold")
	pass


## 更新水晶数量
func update_crystal_num() -> void:
	amount.text = str(Global.crystal)
	pass


## 当前歌曲是否未解锁
func if_locked() -> bool:
	return Global.current_song_index + 1 > Global.main_line_unlocked


## 更新解锁按钮文本
func update_unlock_button() -> void:
	unlock_button.text = ("$ 解锁 ◇-" + str(needed_crystal_num)) if is_locked else "已解锁"
	unlock_button.disabled = false if is_locked else true
	if is_locked:
		if Global.current_song_index > Global.main_line_unlocked:
			unlock_button.disabled = true
			unlock_button.tooltip_text = "必须先解锁上一个关卡"
			pass
		else:
			unlock_button.disabled = false
			unlock_button.tooltip_text = ""
			pass
	pass


## 更新当前解锁状态
func update_if_locked() -> void:
	is_locked = if_locked()
	if is_locked:
		start.disabled = true
		pass
	else:
		start.disabled = false
		pass
	pass


## 解锁
func unlock() -> void:
	is_locked = false
	start.disabled = false
	Global.main_line_unlocked += 1
	Global.save_user_data()
	pass


# ---------- 加载 ----------
## 加载曲包中的内容
func load_song_info() -> void:
	audio_stream_player.stream_paused = true
	var song_package_path: String = Global.sympath_song_path_list[Global.current_song_index]
	
	# 加载封面，更新背景和曲绘
	var song_cover: ImageTexture = Global._read_cover_from_lpz(song_package_path)
	background.texture = song_cover
	cover.texture = song_cover
	
	if is_locked:
		background.material.set_shader_parameter("gray_scale", 1.0)
		cover.material.set_shader_parameter("gray_scale", 1.0)
		pass
	else:
		background.material.set_shader_parameter("gray_scale", 0.0)
		cover.material.set_shader_parameter("gray_scale", 0.0)
		pass
	
	# 加载歌曲信息
	var song_chart: Dictionary = Global._read_chart_from_lpz(song_package_path)
	var general: Dictionary = song_chart.get("General", {})
	title.text 		= general.get("Title", "-") 	if not is_locked else "???"
	producer.text 	= general.get("Artist", "-") 	if not is_locked else "???"
	creator.text 	= general.get("Creator", "-") 	if not is_locked else "???"
	vocalist.text 	= general.get("Vocalist", "-") 	if not is_locked else "???"
	needed_crystal_num = general.get("Crystal", 10)
	
	# 加载歌曲音频
	var song_audio_stream: AudioStream = Global._read_audio_from_lpz(song_package_path)
	audio_stream_player.stream = song_audio_stream
	if is_locked:
		return
	if audio_stream_player.stream:
		start_pointer = float(general.get("Preview", 0)) / 1000
		# PreviewEnd 为 -1 / 缺省 → 预览整曲: 从 Preview 播到曲尾, 由 finished 信号触发回拨
		var preview_end_ms: float = float(general.get("PreviewEnd", -1.0))
		if preview_end_ms < 0.0:
			end_pointer = audio_stream_player.stream.get_length()
			pass
		else:
			end_pointer = preview_end_ms / 1000
			pass

		audio_stream_player.play(start_pointer)

		_fade_in_audio()
		pass
	pass


# ---------- 预览音频 ----------
## 整曲预览播到自然结尾 → 回到 Preview 处继续循环 (PreviewEnd == -1 / 缺省时)
func _on_preview_finished() -> void:
	if is_back:
		return
	is_back = true
	audio_stream_player.play(start_pointer)
	_fade_in_audio()
	pass


## 淡入音频
func _fade_in_audio() -> void:
	_kill_audio_fade()
	audio_stream_player.volume_db = AUDIO_SILENCE_DB
	_audio_fade_tween = create_tween()
	_audio_fade_tween.tween_property(
		audio_stream_player, 
		"volume_db", 
		0.0, 
		AUDIO_FADE_IN_TIME
	).set_trans(Tween.TRANS_QUART) # 三次插值曲线
	_audio_fade_tween.tween_callback(set_is_back_false) # 淡入完成后播放音频
	pass
func set_is_back_false() -> void:
	is_back = false
	pass


## 淡出音频
func _fade_out_audio() -> void:
	_kill_audio_fade()
	_audio_fade_tween = create_tween()
	_audio_fade_tween.tween_property(
		audio_stream_player, 
		"volume_db", 
		AUDIO_SILENCE_DB, 
		AUDIO_FADE_OUT_TIME
	).set_trans(Tween.TRANS_QUART) # 三次插值曲线
	_audio_fade_tween.tween_callback(audio_stream_player.stop)
	pass


## 停止当前淡入淡出动画, 为了播放新的淡入淡出动画
func _kill_audio_fade() -> void:
	if _audio_fade_tween and _audio_fade_tween.is_valid():
		_audio_fade_tween.kill()
		pass
	_audio_fade_tween = null
	pass


# ---------- 按钮信号绑定 ----------
## 返回 MainMenu
func _on_back_pressed() -> void:
	audio_stream_player.stop()
	Global.play_ui_click_audio()
	Global.game_mode = Global.GameMode.None
	$"..".back_to_previous_scene()
	pass


## 向左切歌
func _on_left_pressed() -> void:
	_fade_out_audio()
	Global.play_ui_click_audio()
	Global.current_song_index -= 1 # if Global.current_song_index > 0 else 0
	refresh_progress_bar()
	update_if_locked()
	update_song()
	pass


## 向右切歌
func _on_right_pressed() -> void:
	_fade_out_audio()
	Global.play_ui_click_audio()
	Global.current_song_index += 1 # if Global.current_song_index < Global.sympath_song_num - 1 else 0
	refresh_progress_bar()
	update_if_locked()
	update_song()
	pass


## 开始
func _on_start_pressed() -> void:
	# audio_stream_player.stop()
	_fade_out_audio()
	Global.play_ui_click_audio()
	$"..".start_scene_by_path("res://Scene/Core/Gameplay.tscn", {}, "img", cover.texture)
	pass


## 设置(选项)
func _on_setting_pressed() -> void:
	Global.play_ui_click_audio()
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


# ---------- 设置(选项)界面 ----------
## 设置(选项)界面的确认按钮
func _on_ok_button_pressed() -> void:
	Global.play_ui_click_audio()
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(setting_panel, "modulate:a", 0.0, 0.2)
	await tween.finished
	setting_panel.visible = false
	setting_panel.scale = Vector2.ONE
	pass


## 是否自动播放
func _on_autoplay_button_pressed() -> void:
	Global.play_ui_click_audio()
	Global.is_autoplay = !Global.is_autoplay
	autoplay_button.text = "自动播放     " + ("开" if Global.is_autoplay else "关")
	pass


## 是否播放 PV
func _on_pv_button_pressed() -> void:
	Global.play_ui_click_audio()
	Global.is_pvplay = !Global.is_pvplay
	pv_button.text = "播放 PV        " + ("开" if Global.is_pvplay else "关")
	pass


## 解锁按钮
func _on_unlock_button_pressed() -> void:

	if Global.crystal < needed_crystal_num:
		# 余额不足
		print("余额不足")
		Global.display_notice("◇数量不足")
		return
	else:
		print("解锁成功")
		Global.display_notice("解锁成功")
		Global.crystal -= needed_crystal_num
		update_crystal_num()
		unlock()
		pass
	update_song()
	update_unlock_button()
	pass
