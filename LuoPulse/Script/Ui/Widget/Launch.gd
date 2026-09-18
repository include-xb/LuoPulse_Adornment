## Launch 启动界面
##
## 可以切换到这里的场景:
## 		- 无
## 从这里可以前往: 
## 		- MainMenu 游戏主页面


############################################
##				DANGER					  ##
##		  AI 产出的 shit，勿动！			  ##
############################################
## INFO 已动

extends Control


## 用于淡入淡出文字
@export var animation_player: AnimationPlayer # = $AnimationPlayer

## 加载面板 (下载期间显示, 其余时间隐藏)
@export var loading_panel: Control # = $LoadingPanel

## 下载进度条
@export var download_progress_bar: ProgressBar # = $LoadingPanel/DownloadProgressBar

## 下载状态文字
@export var download_label: Label # = $LoadingPanel/DownloadLabel


## 正在下载曲包 (期间禁止切换场景)
var _is_downloading: bool = false


# ---------- 节点重载函数 ----------
func _ready() -> void:
	Engine.max_fps = 50
	load_config()
	# 进入场景立刻开始下载缺失的曲包, 全部结束后才进入后续流程
	await _download_all_song_packages()
	load_sympathy_song()
	if Global.if_play_start_animation:
		_setup_animations()
		_play_intro_sequence()
		Global.is_first_open = false
		pass
	else:
		$"..".start_scene_by_path("res://Scene/Ui/Menu/MainMenu.tscn")
		pass
	pass


func _input(event: InputEvent) -> void:
	# 下载期间不允许切换场景, 否则下载器会随本场景一起被销毁
	if _is_downloading:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		$"..".start_scene_by_path("res://Scene/Ui/Menu/MainMenu.tscn")
		pass
	pass


# ---------- 曲包下载 ----------
## 依次下载 Global.SONG_PACKAGE_URL_LIST 中缺失的曲包, 并推进进度条
## 全部下完 (或失败跳过) 后才会返回, 调用方用 await 等待
func _download_all_song_packages() -> void:
	var url_list: Array[String] = Global.SONG_PACKAGE_URL_LIST
	var total: int = url_list.size()
	if total == 0:
		return

	_is_downloading = true
	_setup_download_bar_style()
	loading_panel.visible = true

	for index: int in total:
		var url: String = url_list[index]
		_update_download_ui(url, index, total)

		var is_success: bool = await $Downloader.download(url)
		if not is_success:
			push_error("曲包下载失败, 已跳过: %s" % url)
			pass

		# 进度条按 "已下载文件数 / 总文件数" 推进
		download_progress_bar.value = float(index + 1) / float(total) * 100.0
		pass

	loading_panel.visible = false
	_is_downloading = false
	pass


## 刷新下载状态文字 (例: 正在下载 2.lpz (1/2))
func _update_download_ui(url: String, index: int, total: int) -> void:
	download_label.text = "正在下载 %s (%d/%d)" % [ url.get_file(), index + 1, total ]
	pass


## 覆盖进度条样式
## 全局主题里进度条的填充是纯黑噪点贴图、轨道是全透明的, 在黑色背景下完全看不见
func _setup_download_bar_style() -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.15)

	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.952941, 0.933333, 0.866667, 1)

	download_progress_bar.add_theme_stylebox_override("background", track)
	download_progress_bar.add_theme_stylebox_override("fill", fill)
	pass


# ---------- 工具函数 ----------
## 将字典写入 JSON 文件
func _write_json_file(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		pass
	pass


## 将每个 .lpz 文件的完整路径记录到 Global.sympath_song_path_list
func _record_sympath_song_paths() -> void:
	# 目标文件夹
	var target_dir: String = _get_customized_playlist_dir()
	# 所有 .lpz 文件的文件名
	var lpz_file_names: Array[String] = _list_lpz_files(target_dir)
	var paths: Array[String] = [ ]
	for fname: String in lpz_file_names:
		# 记录到 paths
		paths.append(target_dir.path_join(fname))
		pass
	# 赋值到 Global
	Global.sympath_song_path_list = paths
	pass


## 统计歌曲数目, 保存到 Global.sympathy_song_num
func _count_sympath_songs() -> void:
	Global.sympath_song_num = Global.sympath_song_path_list.size()
	pass


## 获取 CustomizedPlaylist 目录的绝对路径 (user://CustomizedPlaylist/)
func _get_customized_playlist_dir() -> String:
	return OS.get_user_data_dir().path_join("CustomizedPlaylist")


## 列出指定目录下所有 .lpz 文件名 (不含路径前缀)
func _list_lpz_files(dir_path: String) -> Array[String]:
	var files: Array[String] = [ ]
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("无法打开目录: %s" % dir_path)
		return [ ]

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "lpz":
			files.append(file_name)
			pass
		file_name = dir.get_next()
		pass
	dir.list_dir_end()
	return files


# ---------- 加载配置 ----------
## 加载配置
func load_config() -> void:
	_load_user_data()
	_load_game_config()
	pass


## 加载用户数据: user.json
## 保存在 OS.get_user_data_dir()，若不存在则创建默认数据
func _load_user_data() -> void:
	# 路径指向用户数据文件夹/user.json
	var user_path: String = OS.get_user_data_dir().path_join("user.json")
	# 默认数据
	var default_data: Dictionary = {
		"username": "小白",	# 用户名
		"is_first_open": true,
		"main_line_unlocked": 1,	# 主线中已经解锁的曲目数量
		"crystal": 25,	# 水晶数
		"story_fragments_unlocked": [], 	# 已解锁的故事碎片id
	}

	var data: Dictionary = default_data.duplicate()

	# 如果用户数据不存在
	if !FileAccess.file_exists(user_path):
		print("%s 文件不存在, 创建默认数据" % user_path)
		_write_json_file(user_path, default_data)
		print("默认用户数据创建完成")
		pass

	# 打开用户数据文件/user.json
	var file: FileAccess = FileAccess.open(user_path, FileAccess.READ)
	# 如果打开失败
	if !file:
		file.close()
		push_error("无法打开用户数据文件: %s" % user_path)
		return
	
	var json_string: String = file.get_as_text()	# 读取 JSON 数据
	file.close()	# 读取完成关闭文件
	var parsed: Variant = JSON.parse_string(json_string)	# 解析 JSON 数据

	# 如果解析失败
	if parsed == null or parsed is not Dictionary:
		push_error("无法解析 JSON 数据: %s" % user_path)
		return

	# 将解析后的数据赋值给 data
	for key: String in default_data:
		if key in parsed:
			data[key] = parsed[key]
			pass
		pass
	print("用户数据解析完成")
	
	# _write_json_file(user_path, data)
	# print("重新保存用户数据")

	# 赋值到 Global
	Global.user_name 				= data["username"]
	Global.is_first_open 			= data["is_first_open"]
	Global.main_line_unlocked 		= data["main_line_unlocked"]
	Global.crystal 					= data["crystal"]
	Global.story_fragments_unlocked = data["story_fragments_unlocked"]
	pass


## 加载游戏配置: config.json
## 保存在 OS.get_user_data_dir()，若不存在则创建默认数据
func _load_game_config() -> void:
	# 路径指向用户数据文件夹/config.json
	var config_path: String = OS.get_user_data_dir().path_join("config.json")
	# 默认数据
	var default_data: Dictionary = {
		"version": "0.0.0.1",
		"volume_song": 90,
		"volume_note": 70,
		"volume_ui": 60,
		"volume_bg": 60,
		"offset": 0,
		"speed": 10,
		"if_play_start_animation": true
	}

	var data: Dictionary = default_data.duplicate()

	if !FileAccess.file_exists(config_path):
		print("%s 文件不存在, 创建默认数据" % config_path)
		_write_json_file(config_path, default_data)
		print("默认配置数据创建完成")
		pass

	# 打开用户数据文件夹/config.json
	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	# 如果打开失败
	if !file:
		file.close()
		push_error("无法打开用户数据文件: %s" % config_path)
		return
	
	var json_string: String = file.get_as_text()	# 读取 JSON 数据
	file.close()	# 读取完成关闭文件
	var parsed: Variant = JSON.parse_string(json_string)	# 解析 JSON 数据
	
	# 如果解析失败
	if parsed == null or parsed is not Dictionary:
		push_error("无法解析 JSON 数据: %s" % config_path)
		return

	# 将解析后的数据赋值给 data
	for key: String in default_data:
		if key in parsed:
			data[key] = parsed[key]
			pass
		pass
	print("配置数据解析完成")

	# _write_json_file(config_path, data)

	# 赋值到 Global
	Global.config_version 			= data["version"]
	Global.volume_song 				= data["volume_song"]
	Global.volume_note 				= data["volume_note"]
	Global.volume_bg				= data["volume_bg"]
	Global.volume_ui 				= data["volume_ui"]
	Global.chart_offset 			= data["offset"]
	Global.note_flow_speed 			= data["speed"]
	Global.if_play_start_animation 	= data["if_play_start_animation"]
	pass


# ---------- 加载曲目 ----------
## 加载共鸣曲目 (扫描 CustomizedPlaylist 目录, 曲包由 _download_all_song_packages 下载)
func load_sympathy_song() -> void:
	_record_sympath_song_paths()
	_count_sympath_songs()
	pass


func load_album_song() -> void:
	# 加载专辑主线歌曲
	# 暂时不制作
	pass


# ---------- 开始动画 ----------
## 设置开始动画
func _setup_animations() -> void:
	var lib: AnimationLibrary = AnimationLibrary.new()

	# 淡入 Text1
	var fade_in_text1: Animation = Animation.new()
	fade_in_text1.length = 1.0
	fade_in_text1.add_track(Animation.TYPE_VALUE)
	fade_in_text1.track_set_path(0, "Text1:modulate:a")
	fade_in_text1.track_insert_key(0, 0.0, 0.0)
	fade_in_text1.track_insert_key(0, 1.0, 1.0)
	lib.add_animation("fade_in_text1", fade_in_text1)

	# 淡出 Text1
	var fade_out_text1: Animation = Animation.new()
	fade_out_text1.length = 1.0
	fade_out_text1.add_track(Animation.TYPE_VALUE)
	fade_out_text1.track_set_path(0, "Text1:modulate:a")
	fade_out_text1.track_insert_key(0, 0.0, 1.0)
	fade_out_text1.track_insert_key(0, 1.0, 0.0)
	lib.add_animation("fade_out_text1", fade_out_text1)

	# 淡入 Text2
	var fade_in_text2: Animation = Animation.new()
	fade_in_text2.length = 1.0
	fade_in_text2.add_track(Animation.TYPE_VALUE)
	fade_in_text2.track_set_path(0, "Text2:modulate:a")
	fade_in_text2.track_insert_key(0, 0.0, 0.0)
	fade_in_text2.track_insert_key(0, 1.0, 1.0)
	lib.add_animation("fade_in_text2", fade_in_text2)

	# 淡出 Text2
	var fade_out_text2: Animation = Animation.new()
	fade_out_text2.length = 1.0
	fade_out_text2.add_track(Animation.TYPE_VALUE)
	fade_out_text2.track_set_path(0, "Text2:modulate:a")
	fade_out_text2.track_insert_key(0, 0.0, 1.0)
	fade_out_text2.track_insert_key(0, 1.0, 0.0)
	lib.add_animation("fade_out_text2", fade_out_text2)

	animation_player.add_animation_library("", lib)
	pass


## 播放开始动画
func _play_intro_sequence() -> void:
	# 淡入第一段文字
	animation_player.play("fade_in_text1")
	await animation_player.animation_finished
	await get_tree().create_timer(1.0).timeout

	# 淡出第一段文字
	animation_player.play("fade_out_text1")
	await animation_player.animation_finished
	await get_tree().create_timer(0.5).timeout

	# 淡入第二段文字
	animation_player.play("fade_in_text2")
	await animation_player.animation_finished
	await get_tree().create_timer(1.0).timeout

	# 淡出第二段文字
	animation_player.play("fade_out_text2")
	await animation_player.animation_finished

	# 通过 SceneManager 切换到主菜单（带淡入淡出效果）
	$"..".start_scene_by_path("res://Scene/Ui/Menu/MainMenu.tscn")
	pass
