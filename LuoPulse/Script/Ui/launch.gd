## Launch 启动界面
##
## 可以切换到这里的场景:
## 		- 无
## 从这里可以前往: 
## 		- MainMenu 游戏主页面


extends Control


func _ready() -> void:
	load_config()
	load_sympathy_song()
	load_album_song()
	pass


func load_config() -> void:
	# 加载用户数据文件夹的 config.json
	
	pass


func load_sympathy_song() -> void:
	# 加载共鸣主线歌曲 歌曲放置在一个文件夹内, 后缀名 .lpz
	# 将每个 .lpz 文件的路径记录到 Global.sympath_song_path_list 中
	# 统计歌曲数目, 保存到 Global.sympathy_song_num 中
	pass


func load_album_song() -> void:
	# 加载专辑主线歌曲
	# 暂时不制作
	pass
