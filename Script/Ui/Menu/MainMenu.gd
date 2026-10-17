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


## 头像 / 卡片头像槽位用的圆形遮罩 shader
const AVATAR_SHADER: Shader = preload("res://Shader/circular_mask.gdshader")

## 卡片里每个头像槽位的尺寸
const AVATAR_SLOT_SIZE: Vector2 = Vector2(96, 96)

## 选中的头像槽位灰度 (0 = 原色)
const AVATAR_SLOT_LIT: float = 0.0

## 未选中的头像槽位灰度 (1 = 全灰)
## INFO: 头像素材还没做 (见 Global.AVATAR_PATHS), 现在每个槽位都是同一张图 ——
##       只能靠灰度把"当前选中的那个"区分出来
const AVATAR_SLOT_DIM: float = 0.7


# ---------- 主页卡片节点 ----------
## 头像下方那对标签里的数值 (共鸣值)
@export var level_value: Label

## 点头像打开卡片 —— 头像本体没有交互, 把外层这个 Panel 当整块热区
@export var avatar_panel: Panel

## 卡片叠加层 (显隐总开关)
@export var profile_panel: Control

## 卡片外那层遮罩 (点它关闭)
@export var profile_mask: ColorRect

## 卡片本体 (弹出动效用它的 scale)
@export var profile_card: Panel 

## 卡片上的头像 (与主菜单头像各持一份材质副本, 灰度互不干扰)
@export var profile_avatar: TextureRect

## 卡片上的昵称
@export var profile_name: Label

## ---- 信息态 ----
@export var info_view: VBoxContainer
@export var sympathy_value: Label
@export var crystal_value: Label
@export var song_value: Label
@export var fragment_value: Label
@export var edit_button: Button

## ---- 编辑态 ----
## 编辑态左上角的 "<"。它挂在卡片上而不是编辑态容器里 —— 只有这样才钉得住左上角,
## 而且它在两态间切显隐时不会把卡片内容顶下去
@export var back_button: Button
@export var edit_view: VBoxContainer
@export var name_edit: LineEdit
@export var confirm_button: Button
@export var avatar_picker: GridContainer


## 主页卡片是否正在显示
var _is_profile_panel_visible: bool = false

## 卡片显隐的那个补间 —— 重开/重关时要把还没跑完的上一趟杀掉
var _profile_tween: Tween = null

## 编辑态里待确定的头像序号 (点了"确定"才写进 Global)
var _pending_avatar_index: int = 0


# ---------- 节点重载函数 ----------
func _ready() -> void:
	_setup_profile_card()
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
	# 共鸣值: 已解锁曲数 / 共鸣主线曲数
	level_value.text = "%d%%" % Global.get_main_line_progress_percent()
	avatar.texture = Global.get_avatar_texture(Global.avatar_index)
	avatar.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())

	# 卡片开着的时候一并刷新 —— 从选歌/结算返回时场景是复用的, _ready 不会再执行,
	# 少了这一处就会出现"进度变了但卡片还是旧数" (与 _refresh_background 同一个理由)
	if _is_profile_panel_visible:
		_refresh_profile_card()
		pass
	pass


# ---------- 主页卡片 ----------
## 建卡片的动态部分: 头像材质 / 头像选择器 / 信号; 并把卡片收起来
## INFO: 材质与槽位都在代码里建, 而不是写在场景里 —— 槽位数量跟着
##       Global.AVATAR_PATHS 走 (素材加了不用改场景), 材质则必须每处一份独立实例,
##       否则"选中彩色 / 未选灰"会互相污染 (与 InputProcesser 复制粒子材质同理)
func _setup_profile_card() -> void:
	profile_avatar.material = _make_avatar_material(AVATAR_SLOT_LIT)

	for index: int in Global.AVATAR_PATHS.size():
		avatar_picker.add_child(_make_avatar_slot(index))
		pass
	
	profile_panel.visible = false
	profile_panel.modulate.a = 0.0
	_leave_edit_view()
	pass


## 造一份头像用的圆形遮罩材质 (每个用到处各持一份, 灰度互不影响)
func _make_avatar_material(gray_scale: float) -> ShaderMaterial:
	var _material: ShaderMaterial = ShaderMaterial.new()
	_material.shader = AVATAR_SHADER
	_material.set_shader_parameter("gray_scale", gray_scale)
	return _material


## 造一个头像槽位 (圆形裁剪的 Panel + 图片), 点它选中对应头像
func _make_avatar_slot(index: int) -> Panel:
	var slot: Panel = Panel.new()
	slot.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	slot.custom_minimum_size = AVATAR_SLOT_SIZE

	var picture: TextureRect = TextureRect.new()
	picture.name = "Picture"
	picture.material = _make_avatar_material(AVATAR_SLOT_DIM)
	picture.texture = Global.get_avatar_texture(index)
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	slot.add_child(picture)

	slot.gui_input.connect(_on_avatar_slot_gui_input.bind(index))
	return slot


## 打开主页卡片 (固定落在信息态)
## INFO: 显隐照抄暂停面板 / 选歌设置面板那套 (visible + modulate:a + scale)
func _show_profile_panel() -> void:
	if _is_profile_panel_visible:
		return
	_is_profile_panel_visible = true

	_leave_edit_view()
	_refresh_profile_card()

	profile_panel.visible = true
	profile_panel.modulate.a = 0.0
	
	edit_view.visible = false
	info_view.visible = true

	profile_card.pivot_offset = profile_card.size * 0.5
	profile_card.scale = Vector2(0.85, 0.85)
	
	# 卡片淡入
	_kill_profile_tween()
	_profile_tween = create_tween()
	_profile_tween.set_trans(Tween.TRANS_CUBIC)
	_profile_tween.set_ease(Tween.EASE_OUT)
	_profile_tween.tween_property(profile_panel, "modulate:a", 1.0, 0.3)
	_profile_tween.parallel().tween_property(profile_card, "scale", Vector2.ONE, 0.3)
	pass


## 收起主页卡片
## INFO: 淡出的那 0.2 秒里遮罩仍然"实心" —— 点击会被它吃掉, 所以刚关掉就立刻点回头像
##       是点不通的 (要等淡出跑完)。这是刻意的: 淡出期间若让遮罩让开, 点击就会穿透到
##       它后面的菜单按钮上, 那反而是误触切场景
func _hide_profile_panel() -> void:
	if not _is_profile_panel_visible:
		return
	_is_profile_panel_visible = false
	
	_kill_profile_tween()
	_profile_tween = create_tween()
	_profile_tween.set_trans(Tween.TRANS_CUBIC)
	_profile_tween.set_ease(Tween.EASE_IN)
	_profile_tween.tween_property(profile_panel, "modulate:a", 0.0, 0.2)
	# INFO: 这里用 tween_callback 而不是 await —— 淡出途中又被点开时, 上面那句
	#       _kill_profile_tween 会把这趟补间掐掉, 回调就不会触发, 也就不会把刚打开的
	#       卡片又收回去 (原先用 await 时, 被掐掉的那趟协程醒来照样收面板)
	_profile_tween.tween_callback(_on_profile_hide_done)
	pass


## 淡出跑完: 真正把卡片收起来
func _on_profile_hide_done() -> void:
	profile_panel.visible = false
	profile_card.scale = Vector2.ONE
	_leave_edit_view()
	pass


## 掐掉还没跑完的显隐补间
func _kill_profile_tween() -> void:
	if _profile_tween != null and _profile_tween.is_valid():
		_profile_tween.kill()
		pass
	_profile_tween = null
	pass


## 刷新卡片上的数值
## INFO: 歌曲与碎片的分母都取实际数据 —— 与选歌页进度条、背景灰度、笔记页同源,
##       避免"显示 /17 但实际只有 3 首能玩"的错位
func _refresh_profile_card() -> void:
	profile_avatar.texture = Global.get_avatar_texture(Global.avatar_index)
	profile_name.text = Global.user_name
	sympathy_value.text = "%d%%" % Global.get_main_line_progress_percent()
	crystal_value.text = "◇ %d" % Global.crystal
	song_value.text = "%d/%d" % [ Global.main_line_unlocked, Global.sympath_song_num ]
	fragment_value.text = "%d/%d" % [
		Global.story_fragments_unlocked.size(),
		Global.get_story_fragment_total(),
	]
	pass


## 切到编辑态: 输入框与"待确定的头像"都用当前值播种
## INFO: 没点"确定"之前不动 Global —— 所以 "<" 退出就等于取消
func _enter_edit_view() -> void:
	_pending_avatar_index = Global.avatar_index
	name_edit.text = Global.user_name
	_refresh_avatar_slots()
	profile_avatar.texture = Global.get_avatar_texture(_pending_avatar_index)

	edit_view.visible = true
	info_view.visible = false
	pass


## 回信息态 (同时也是"取消": 编辑态里没落盘的东西在这里丢掉)
func _leave_edit_view() -> void:
	info_view.visible = true
	edit_view.visible = false
	pass


## 头像槽位高亮: 待选中的那个原色, 其余灰度
func _refresh_avatar_slots() -> void:
	for index: int in avatar_picker.get_child_count():
		var slot: Panel = avatar_picker.get_child(index)
		var picture: TextureRect = slot.get_node_or_null("Picture")
		if picture == null or picture.material == null:
			continue
		picture.material.set_shader_parameter(
			"gray_scale",
			AVATAR_SLOT_LIT if index == _pending_avatar_index else AVATAR_SLOT_DIM
		)
		pass
	pass


## 是不是一次"左键按下"
func _is_left_click(event: InputEvent) -> bool:
	if event is not InputEventMouseButton:
		return false
	var button_event: InputEventMouseButton = event
	return button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT


## 能否离开主菜单 —— 安卓返回手势会问这里 (见 SceneManager._can_leave_current_scene)
## 卡片开着时先收卡片 (编辑态先回信息态), 而不是直接切场景
func can_leave() -> bool:
	if not _is_profile_panel_visible:
		return true

	if edit_view.visible:
		_leave_edit_view()
	else:
		_hide_profile_panel()
		pass
	return false


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


## 点头像: 开卡片; 卡片开着时再点一次就关
## INFO: 头像本体 (TextureRect) 不接事件, 热区是外面那个 Panel —— 子节点消费掉点击后
##       仍会向父级冒泡, 所以接在 AvatarPanel 上就能收到
func _on_avatar_panel_gui_input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return

	Global.play_ui_click_audio()
	if _is_profile_panel_visible:
		_hide_profile_panel()
	else:
		_show_profile_panel()
		pass
	pass


## 点卡片外的遮罩: 关卡片
## INFO: 遮罩与卡片是兄弟节点 —— 点卡片时事件被卡片那层消费, 压根到不了遮罩,
##       所以不需要 accept_event() 那套
func _on_profile_mask_gui_input(event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	_hide_profile_panel()
	pass


## 点某个头像槽位: 只改待确定的序号与高亮, 不落盘
func _on_avatar_slot_gui_input(event: InputEvent, index: int) -> void:
	if not _is_left_click(event):
		return

	Global.play_ui_click_audio()
	_pending_avatar_index = index
	_refresh_avatar_slots()
	# 卡片上那张头像跟着动, 当场看到效果 (但仍然要按"确定"才算数)
	profile_avatar.texture = Global.get_avatar_texture(index)
	pass


## 卡片上的"编辑"
func _on_edit_pressed() -> void:
	Global.play_ui_click_audio()
	_enter_edit_view()
	pass


## 编辑态左上角的 "<" —— 回信息态 (等于取消)
func _on_edit_back_pressed() -> void:
	Global.play_ui_click_audio()
	_on_confirm_pressed()
	pass


## "确定": 校验通过才写入并落盘, 不通过就弹提示并留在编辑态
## INFO: 昵称与头像是同一个"确定" —— 所以 "<" 返回等于两样都不改
func _on_confirm_pressed() -> void:
	Global.play_ui_click_audio()

	var candidate: String = name_edit.text.strip_edges()
	if candidate.is_empty():
		Global.display_notice("用户名不能为空")
		return

	if not Global.is_user_name_valid(candidate):
		Global.display_notice("用户名不得长于%d字符" % Global.USER_NAME_MAX_LENGTH)
		return

	Global.user_name = candidate
	Global.avatar_index = _pending_avatar_index
	Global.save_user_data()

	_init_data()
	_refresh_profile_card()
	_leave_edit_view()
	pass
