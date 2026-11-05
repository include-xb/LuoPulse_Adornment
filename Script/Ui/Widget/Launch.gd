## Launch 启动界面
##
## 可以切换到这里的场景:
## 		- 无
## 从这里可以前往: 
## 		- MainMenu 游戏主页面


extends Control


## 用于淡入淡出文字
@export var animation_player: AnimationPlayer # = $AnimationPlayer

## 加载面板 (下载期间显示, 其余时间隐藏)
@export var loading_panel: Control # = $LoadingPanel

## 下载进度条
@export var download_progress_bar: ProgressBar # = $LoadingPanel/DownloadProgressBar

## 下载状态文字
@export var download_label: Label # = $LoadingPanel/DownloadLabel

## 下载时的背景图
@export var background: TextureRect

## 下载管理器
@export var downloader: Node


# @export var is_test: bool = false


## 正在下载曲包 (期间禁止切换场景)
var _is_downloading: bool = false

## 当前正在下载的文件序号 (从 0 开始) 与文件总数, 用于把单文件进度换算成总体进度
var _download_index: int = 0
var _download_total: int = 0


# ---------- 节点重载函数 ----------
func _ready() -> void:
	Engine.max_fps = 50
	load_config()
	if Global.is_auto_update_package:
		downloader.download_progress.connect(_on_download_progress)
		# 进入场景立刻检查并补齐资源, 全部结束后才进入后续流程
		await _check_and_update_song_packages()
		pass
	else:
		# 玩家关闭了"自动更新曲包", 跳过检查与下载, 直接进入后续流程
		pass
	
	load_sympathy_song()
	if Global.if_play_start_animation:
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
## 每次启动检查远端资源:
##   1. 拉取远端文件列表, 只下载本地缺失或大小不一致的文件
##   2. 每个下载完成的文件立刻用 SHA256 校验
##   3. 服务器不可用 / 鉴权失败时直接使用本地资源进入游戏
## 全部结束后才会返回, 调用方用 await 等待
func _check_and_update_song_packages() -> void:
	print("开始检查曲包更新")
	_is_downloading = true
	_download_index = 0
	_download_total = 0
	loading_panel.visible = true
	# 立刻显示 0%, 避免在拉取列表期间一直停在场景里的占位文字
	_apply_download_progress(0.0, "正在检查曲包更新")

	var remote_result: Dictionary = await downloader.fetch_remote_files()
	if not bool(remote_result.get("is_ok", false)):
		push_warning("曲包列表获取失败, 本次使用本地资源")
		await _finish_update_check("资源检查失败, 正在使用本地曲包")
		return

	var remote_files: Array = remote_result.get("files", [ ])
	print("远端曲包列表获取成功, 共 %d 个" % remote_files.size())
	# 远端已下架的曲包从本地清掉; 远端列表为空时 Downloader 会保留本地, 防止误清空
	var deleted_files: Array[String] = downloader.delete_orphan_packages(remote_files)
	if not deleted_files.is_empty():
		print("已清理 %d 个远端不存在的曲包" % deleted_files.size())
		pass

	var pending_files: Array[Dictionary] = downloader.get_pending_files(remote_files)
	_download_total = pending_files.size()

	if _download_total == 0:
		# 没有待下载的文件: 直接显示满格, 不要停留在 0%
		_apply_download_progress(1.0, "曲包已是最新")
		await _finish_update_check("曲包已是最新")
		return

	# /api/sha256 首次请求需要服务端计算全部文件哈希, 可能明显偏慢
	_apply_download_progress(0.0, "正在获取校验信息, 首次可能较慢")
	var sha_result: Dictionary = await downloader.fetch_remote_sha256()
	if not bool(sha_result.get("is_ok", false)):
		push_warning("SHA256 列表获取失败, 本次使用本地资源")
		await _finish_update_check("资源检查失败, 正在使用本地曲包")
		return

	var sha_map: Dictionary = sha_result.get("sha256", { })

	for index: int in _download_total:
		var file: Dictionary = pending_files[index]
		var file_name: String = str(file.get("name", ""))
		var expected_sha256: String = str(sha_map.get(file_name, ""))
		_download_index = index

		if expected_sha256.is_empty():
			push_error("远端未提供 SHA256, 已跳过: %s" % file_name)
		else:
			var is_success: bool = await downloader.download_file(file, expected_sha256)
			if not is_success:
				push_error("曲包下载或校验失败, 已跳过: %s" % file_name)
				pass
			pass

		# 该文件结束, 进度推进到整数刻度
		_apply_download_progress(float(index + 1) / float(_download_total))
		pass

	await _finish_update_check("曲包更新完成")
	pass


## 结束更新检查: 显示最终提示, 稍作停留后隐藏加载面板
func _finish_update_check(text: String) -> void:
	download_label.text = text
	await get_tree().create_timer(1.0).timeout
	loading_panel.visible = false
	_is_downloading = false
	pass


## 当前文件的字节进度变化 → 换算成总体进度
## 总体进度 = (已完成文件数 + 当前文件字节比例) / 本次待下载文件数
func _on_download_progress(file_ratio: float) -> void:
	if _download_total <= 0:
		return
	var overall: float = (float(_download_index) + clampf(file_ratio, 0.0, 1.0)) / float(_download_total)
	_apply_download_progress(overall)
	pass


## 应用总体进度 (0.0 ~ 1.0), 同步进度条、背景色彩与提示文字
func _apply_download_progress(ratio: float, status: String = "正在下载曲包, 请不要退出游戏") -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	download_progress_bar.value = clamped * 100.0
	background.material.set_shader_parameter("gray_scale", 1.0 - clamped)
	download_label.text = "%s (%d%%)" % [ status, int(clamped * 100.0) ]
	pass


## 覆盖进度条样式
## 全局主题里进度条的填充是纯黑噪点贴图、轨道是全透明的, 在黑色背景下完全看不见
#func _setup_download_bar_style() -> void:
	#var track: StyleBoxFlat = StyleBoxFlat.new()
	#track.bg_color = Color(1, 1, 1, 0.15)
#
	#var fill: StyleBoxFlat = StyleBoxFlat.new()
	#fill.bg_color = Color(0.952941, 0.933333, 0.866667, 1)
#
	#download_progress_bar.add_theme_stylebox_override("background", track)
	#download_progress_bar.add_theme_stylebox_override("fill", fill)
	#pass


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
## INFO: 按文件名前缀的序号排序 (1-Step-on-your-heart.lpz → 第 1 首), 见 Global.sort_song_package_paths
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
	# 按序号前缀排序后赋值到 Global
	Global.sympath_song_path_list = Global.sort_song_package_paths(paths)
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
		"username": "源小白",	# 用户名
		"is_first_open": true,
		"main_line_unlocked": 1,	# 主线中已经解锁的曲目数量
		"crystal": 25,	# 水晶数
		"story_fragments_unlocked": ["1"], 	# 已解锁的故事碎片id
		"avatar_index": 0,	# 当前选用的头像序号
		"max_accuracy": { },	# 每首歌的历史最高准度 (键: 歌曲标题)
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
	# INFO: 老存档里没有这个键, 上面的合并循环会让它落回 default_data 里的 0
	Global.avatar_index 			= data["avatar_index"]
	# INFO: 老存档没有 max_accuracy, 合并循环会落回空字典; 这里再防一手损坏的非字典值
	Global.song_max_accuracy 		= data["max_accuracy"] if data["max_accuracy"] is Dictionary else { }
	pass


## 加载游戏配置: config.json
## 保存在 OS.get_user_data_dir()，若不存在则创建默认数据
func _load_game_config() -> void:
	# 路径指向用户数据文件夹/config.json
	var config_path: String = OS.get_user_data_dir().path_join("config.json")
	# 默认数据
	var default_data: Dictionary = {
		"version": "0.0.0.1",
		"volume_song": 45,
		"volume_note": 30,
		"volume_ui": 60,
		"volume_bg": 40,
		"offset": 0,
		"speed": 10,
		"if_play_start_animation": true,
		"is_auto_update_package": true
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
	Global.is_auto_update_package 	= data["is_auto_update_package"]

	# 背景音乐在 Global._ready() 里就已经开始播放了, 那时读到的还是 volume_bg 的默认值;
	# 配置加载完之后立刻刷一次, 让启动时的音量就是玩家实际设定的值
	Global.apply_bgm_volume()
	pass


# ---------- 加载曲目 ----------
## 加载共鸣曲目 (扫描 CustomizedPlaylist 目录, 曲包由 _check_and_update_song_packages 检查/下载)
func load_sympathy_song() -> void:
	_record_sympath_song_paths()
	_count_sympath_songs()
	pass


func load_album_song() -> void:
	# 加载专辑主线歌曲
	# 暂时不制作
	pass


# ---------- 开始动画 ----------
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
