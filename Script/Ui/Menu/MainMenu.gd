## MainMenu 游戏主页面
##
## 可以切换到这里的场景:
## 		- Launch 启动界面
## 		- Sympathy 共鸣主线
## 		- Album 专辑主线
## 		- AboutMenu 关于界面
## 从这里可以前往: 
## 		- SettingMenu 设置页面
## 		- Sympathy 共鸣主线
## 		- Album 专辑主线
## 		- AboutMenu 关于界面


extends Control


## 主页背景
@export var background: TextureRect # = $Background

## 用户名
@export var username: Label # = $Profile/VBoxContainer/InfoPanel/Username

## 水晶值
@export var amount: Label # = $Currency/HBoxContainer/Amount

## 头像
@export var avatar: TextureRect


# ---------- 节点重载函数 ----------
func _ready() -> void:
	_refresh_background()
	# 界面上的数值显示
	_init_data()
	pass


## 每次重新进入场景树时刷新显示
## SceneManager 通过 remove_child / add_child 复用场景节点, _ready 只在首次进入时执行一次
func _enter_tree() -> void:
	if not is_node_ready():
		return
	# 从选歌 / 结算返回时把背景音乐恢复回来
	# (首次进入时不走这里, 那时背景音乐本来就是满音量)
	Global.fade_in_bgm()

	_refresh_background()
	_init_data()
	pass


# ---------- 私有函数 ----------
## 刷新背景灰度 —— 主菜单背景随主线解锁进度做 U 形变化 (见 Global.get_progress_gray_scale)
## INFO: 光靠 _ready 不够 —— 解锁新歌后返回主菜单时场景是复用的, _ready 不会再执行,
##       只有 _enter_tree 会, 少了这一处就会出现"进度变了但背景还是旧色"
func _refresh_background() -> void:
	if background == null or background.material == null:
		return
	background.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	pass


func _init_data() -> void:
	username.text = Global.user_name
	amount.text = str(Global.crystal)
	avatar.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	pass


# ---------- 按钮信号绑定 ----------
## 共鸣 (主线)
func _on_sympathy_pressed() -> void:
	Global.play_ui_click_audio()
	$"..".start_scene_by_path("res://Scene/Ui/SongSelect/Sympathy.tscn")


## 断章
func _on_album_pressed() -> void:
	Global.play_ui_click_audio()
	$"..".start_scene_by_path("res://Scene/Ui/SongSelect/Album.tscn")


## 笔记
func _on_note_pressed() -> void:
	Global.play_ui_click_audio()
	$"..".start_scene_by_path("res://Scene/Ui/Menu/Notebook.tscn")


## 设置
func _on_setting_pressed() -> void:
	Global.play_ui_click_audio()
	$"..".start_scene_by_path("res://Scene/Ui/Menu/SettingsMenu.tscn")
