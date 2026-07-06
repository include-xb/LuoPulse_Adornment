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



extends Control


@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_setup_animations()
	load_sympathy_song()
	_play_intro_sequence()


func _setup_animations() -> void:
	var lib := AnimationLibrary.new()

	# 淡入 Text1
	var fade_in_text1 := Animation.new()
	fade_in_text1.length = 1.0
	fade_in_text1.add_track(Animation.TYPE_VALUE)
	fade_in_text1.track_set_path(0, "Text1:modulate:a")
	fade_in_text1.track_insert_key(0, 0.0, 0.0)
	fade_in_text1.track_insert_key(0, 1.0, 1.0)
	lib.add_animation("fade_in_text1", fade_in_text1)

	# 淡出 Text1
	var fade_out_text1 := Animation.new()
	fade_out_text1.length = 1.0
	fade_out_text1.add_track(Animation.TYPE_VALUE)
	fade_out_text1.track_set_path(0, "Text1:modulate:a")
	fade_out_text1.track_insert_key(0, 0.0, 1.0)
	fade_out_text1.track_insert_key(0, 1.0, 0.0)
	lib.add_animation("fade_out_text1", fade_out_text1)

	# 淡入 Text2
	var fade_in_text2 := Animation.new()
	fade_in_text2.length = 1.0
	fade_in_text2.add_track(Animation.TYPE_VALUE)
	fade_in_text2.track_set_path(0, "Text2:modulate:a")
	fade_in_text2.track_insert_key(0, 0.0, 0.0)
	fade_in_text2.track_insert_key(0, 1.0, 1.0)
	lib.add_animation("fade_in_text2", fade_in_text2)

	# 淡出 Text2
	var fade_out_text2 := Animation.new()
	fade_out_text2.length = 1.0
	fade_out_text2.add_track(Animation.TYPE_VALUE)
	fade_out_text2.track_set_path(0, "Text2:modulate:a")
	fade_out_text2.track_insert_key(0, 0.0, 1.0)
	fade_out_text2.track_insert_key(0, 1.0, 0.0)
	lib.add_animation("fade_out_text2", fade_out_text2)

	animation_player.add_animation_library("", lib)


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
	SceneManager.change_scene("res://Scene/Ui/Menu/MainMenu.tscn")


func load_config() -> void:
	# 加载用户数据文件夹的 config.json
	
	pass


func load_sympathy_song() -> void:
	_copy_lpz_to_customized_playlist()
	_record_sympath_song_paths()
	_count_sympath_songs()


## 将 Asset/SongPackage 中的 .lpz 文件复制到 user://CustomizedPlaylist/
func _copy_lpz_to_customized_playlist() -> void:
	var source_dir := "res://Asset/SongPackage"
	var target_dir := _get_customized_playlist_dir()

	DirAccess.make_dir_recursive_absolute(target_dir)

	var lpz_names := _list_lpz_files(source_dir)
	for file_name in lpz_names:
		var source_path := source_dir.path_join(file_name)
		var target_path := target_dir.path_join(file_name)
		if FileAccess.file_exists(target_path):
			continue
		_copy_binary_file(source_path, target_path)


## 将每个 .lpz 文件的完整路径记录到 Global.sympath_song_path_list
func _record_sympath_song_paths() -> void:
	var target_dir := _get_customized_playlist_dir()
	var lpz_file_names := _list_lpz_files(target_dir)
	var paths: Array[String] = []
	for fname in lpz_file_names:
		paths.append(target_dir.path_join(fname))
	Global.sympath_song_path_list = paths


## 统计歌曲数目, 保存到 Global.sympathy_song_num
func _count_sympath_songs() -> void:
	Global.sympath_song_num = Global.sympath_song_path_list.size()


## 获取 CustomizedPlaylist 目录的绝对路径 (user://CustomizedPlaylist/)
func _get_customized_playlist_dir() -> String:
	return OS.get_user_data_dir().path_join("CustomizedPlaylist")


## 列出指定目录下所有 .lpz 文件名 (不含路径前缀)
func _list_lpz_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("无法打开目录: %s" % dir_path)
		return files

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "lpz":
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	return files


## 以二进制方式复制单个文件
func _copy_binary_file(source: String, target: String) -> void:
	var reader := FileAccess.open(source, FileAccess.READ)
	if reader == null:
		push_error("无法读取源文件: %s" % source)
		return

	var data := reader.get_buffer(reader.get_length())
	reader.close()

	var writer := FileAccess.open(target, FileAccess.WRITE)
	if writer == null:
		push_error("无法写入目标文件: %s" % target)
		return
	writer.store_buffer(data)
	writer.close()


func load_album_song() -> void:
	# 加载专辑主线歌曲
	# 暂时不制作
	pass
