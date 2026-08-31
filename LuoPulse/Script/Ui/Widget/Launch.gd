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
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	load_config()
	_setup_animations()
	load_sympathy_song()
	_play_intro_sequence()
	pass
	

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
		"main_line_unlocked": 1,	# 主线中已经解锁的曲目数量
		"crystal": 0,	# 水晶数
		"story_fragments_unlocked": []	# 已解锁的故事碎片id
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
	Global.user_name = data["username"]
	Global.main_line_unlocked = data["main_line_unlocked"]
	Global.crystal = data["crystal"]
	Global.story_fragments_unlocked = data["story_fragments_unlocked"]
	pass


## 加载游戏配置: config.json
## 保存在 OS.get_user_data_dir()，若不存在则创建默认数据
func _load_game_config() -> void:
	# 路径指向用户数据文件夹/config.json
	var config_path: String= OS.get_user_data_dir().path_join("config.json")
	# 默认数据
	var default_data: Dictionary = {
		"version": "0.0.0.1",
		"volume_song": 90,
		"volume_note": 70,
		"volume_ui": 60,
		"offset": 0,
		"speed": 10
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
	Global.config_version 	= data["version"]
	Global.volume_song 		= data["volume_song"]
	Global.volume_note 		= data["volume_note"]
	Global.volume_ui 		= data["volume_ui"]
	Global.chart_offset 	= data["offset"]
	Global.note_flow_speed 	= data["speed"]
	pass


## 设置动画
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


func _play_intro_sequence() -> void:
	# 淡入第一段文字
	animation_player.play("fade_in_text1")
	await animation_player.animation_finished
	await get_tree().create_timer(2.0).timeout

	# 淡出第一段文字
	animation_player.play("fade_out_text1")
	await animation_player.animation_finished
	await get_tree().create_timer(0.5).timeout

	# 淡入第二段文字
	animation_player.play("fade_in_text2")
	await animation_player.animation_finished
	await get_tree().create_timer(2.0).timeout

	# 淡出第二段文字
	animation_player.play("fade_out_text2")
	await animation_player.animation_finished

	# 通过 SceneManager 切换到主菜单（带淡入淡出效果）
	$"..".start_scene_by_path("res://Scene/Ui/Menu/MainMenu.tscn")
	pass


## 将字典写入 JSON 文件
func _write_json_file(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		pass
	pass


## 加载共鸣曲目
func load_sympathy_song() -> void:
	_copy_lpz_to_customized_playlist()
	_record_sympath_song_paths()
	_count_sympath_songs()
	pass


## 将 Asset/SongPackage 中的 .lpz 文件复制到 user://CustomizedPlaylist/
func _copy_lpz_to_customized_playlist() -> void:
	var source_dir: String = "res://Asset/SongPackage"	# 源文件路径
	var target_dir: String = _get_customized_playlist_dir()	# 复制目标路径

	# 创建目标文件夹 (如果不存在)	
	DirAccess.make_dir_recursive_absolute(target_dir)

	# 所有 .lpz 文件的文件名
	var lpz_file_names: Array[String] = _list_lpz_files(source_dir)
	for file_name: String in lpz_file_names:
		var source_path := source_dir.path_join(file_name)
		var target_path := target_dir.path_join(file_name)
		# 如果文件已经存在 (已经复制) 则跳过
		if FileAccess.file_exists(target_path):
			continue
		# 进行复制
		_copy_binary_file(source_path, target_path)
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


## 以二进制方式复制单个文件
func _copy_binary_file(source: String, target: String) -> void:
	var reader: FileAccess = FileAccess.open(source, FileAccess.READ)
	if reader == null:
		push_error("无法读取源文件: %s" % source)
		return

	var data: PackedByteArray = reader.get_buffer(reader.get_length())
	reader.close()

	var writer: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if writer == null:
		push_error("无法写入目标文件: %s" % target)
		return
	writer.store_buffer(data)
	writer.close()
	pass


func load_album_song() -> void:
	# 加载专辑主线歌曲
	# 暂时不制作
	pass
