## Notebook 笔记本场景
##
## 布局按 LPDocument/ui-mockup/index.html 的笔记部分重做: 纸面底色 + 墨色文字
## 两个标签页 (资料卡 / 故事碎片), 左侧索引列表, 右侧内容区
##
## 资料卡: 侧栏曲目仍来自全部曲包 (.lpz) 的 chart.lp General.Title,
## cards.json 只记录 { "曲名": 资料卡序号 n }; 正文直接读
## res://Asset/NoteBook/cards/card_n.bbcode 并写进 RichTextLabel。
## 未解锁的条目只显示 ??? 且点不动; 点已解锁的条目会把全屏背景换成该曲的曲绘封面 (cover.png)
## 故事碎片: 侧栏标题/解锁顺序仍看 fragments.json,
## 正文直接读 res://Asset/NoteBook/fragments/fragment_n.bbcode。
## 解锁进度看 Global.story_fragments_unlocked 里记的碎片序号。
## INFO: 索引表/碎片表缺失时侧栏退回"暂无数据"; 单个 .bbcode 缺失时正文给出提示。
##
## 从 Sympathy 的"笔记"按钮进来时, 上个场景会通过 SceneManager 传参
## { "song_index": 曲目下标 }; 本场景按该下标取出曲名, 再查 cards.json 得资料卡序号 n。


extends Control


# ---------- 节点引用 ----------
## 资料卡标签栏
@export var cards_tab: Button # = $TabBar/CardsTab

## 故事碎片标签栏
@export var fragments_tab: Button # = $TabBar/FragmentsTab

## 资料卡下划线
@export var cards_underline: ColorRect # = $TabBar/CardsTab/Underline

## 故事碎片下划线
@export var fragments_underline: ColorRect # = $TabBar/FragmentsTab/Underline

## 左侧索引列表 (两个标签共用, 切换时清空重建)
@export var sidebar: VBoxContainer # = $Layout/Sidebar/Scroll/SidebarList

## 右侧内容 (RichTextLabel, 显示 BBCode)
@export var content_label: RichTextLabel # = $Layout/Main/Scroll/Content/Paper/PaperMargin/ContentLabel

## 全屏背景上的曲绘, 跟随侧栏选中项切换
@export var cover: TextureRect # = $Cover

## 用于暗色过度背景
@export var color_rect: ColorRect # = $ColorRect

## 切换背景图时的黑场过渡时长 (单向, 秒)
## 一次完整过渡是 压黑 → 换图 → 淡回来, 所以实际耗时是它的两倍
@export var cover_fade_duration: float = 0.25


## 侧栏每一行的最小高度 (够到移动端触摸区的最低要求)
const SIDEBAR_ROW_HEIGHT: float = 44.0

## 曲包所在目录名 (位于 OS.get_user_data_dir() 下)
const PLAYLIST_DIR_NAME: String = "CustomizedPlaylist"

## 曲包扩展名
const SONG_PACKAGE_EXTENSION: String = "lpz"

## 资料卡索引表: { "曲名": 资料卡序号 n }
const CARDS_JSON_PATH: String = "res://Asset/NoteBook/cards.json"

## 资料卡正文目录: card_n.bbcode
const CARDS_DIR: String = "res://Asset/NoteBook/cards"

## 故事碎片表: 侧栏标题与解锁顺序
const FRAGMENTS_JSON_PATH: String = "res://Asset/NoteBook/fragments.json"

## 故事碎片正文目录: fragment_n.bbcode
const FRAGMENTS_DIR: String = "res://Asset/NoteBook/fragments"

## 未解锁条目的占位 (资料卡与故事碎片共用)
const LOCKED_PLACEHOLDER: String = "???"


## 当前状态(资料卡/故事碎片)
var current_tab: String = "cards"

## 选中的标签索引
var selected_card_index: int = -1

## 资料卡列表: 每项 { "path": String, "general": Dictionary, "card_no": int },
## 与侧栏条目一一对应。card_no 是 cards.json 里的资料卡序号 n, -1 表示没有索引
var _songs: Array[Dictionary] = [ ]

## 故事碎片索引表: { "序号": "标题" }, 进故事碎片页时读一次缓存下来
## 正文和日期不在索引表里, 由 fragments/fragment_n.bbcode 提供
var _fragments: Dictionary = { }

## color_rect 原本的透明度 —— 黑场过渡结束要回到这个值, 而不是回到透明
## INFO: 在 _ready 里从节点上读一次, 不硬编码, 这样在场景里改透明度, 过渡终值就跟着变
var _color_rect_base_alpha: float = 0.0

## 正在进行中的黑场过渡
var _cover_tween: Tween = null

## 当前背景图的来源: 曲目下标, 或 -1 表示默认背景 (Global.normal_background)
## 用它避免"重复点同一首"时白白重读一次 png、以及白闪一下黑场
var _cover_source_index: int = -1

## 本次进入是否还没设置过背景图 —— 是的话第一次换图直接生效, 不播过渡
## INFO: 进本场景时 SceneManager 已经做过一次整屏淡入, 曲绘再淡入一次就是重复的,
##       所以首次换图藏在那次淡入底下直接完成即可
## INFO: 本场景每次进入都是新实例 (SceneManager 离开时会把旧实例 queue_free),
##       所以这个字段每次进入都会重置回 true, 不需要额外复位
var _is_first_cover_set: bool = true


# ---------- 节点重载函数 ----------
## 进入时把背景音乐淡回来 (选歌页为了试听会把背景音乐淡掉)
## INFO: 用 _ready 而不是像 MainMenu 那样用 _enter_tree —— 本场景每次都是新实例
##       (SceneManager 离开时会把旧实例 queue_free), _ready 每次进入都会执行, 不需要
##       用 _enter_tree 去兜"场景被复用、_ready 不再跑"的情况。
##       反过来 _enter_tree 会踩坑: 它早于自动加载的 _ready 传播, 那时 Global 的
##       @onready bgm_player 还是 null, 单独把本场景当主场景运行会直接报错
func _ready() -> void:
	# 先记下 color_rect 本来的透明度, 必须在任何过渡发生之前读
	_color_rect_base_alpha = color_rect.color.a
	Global.fade_in_bgm()
	switch_tab("cards", _read_requested_song_index())
	pass


## 读上个场景通过 SceneManager 传进来的曲目下标 (键 "song_index";
## 旧键 "card_index" 保留兼容)。它只是曲目列表下标, 不是 cards.json 里的资料卡序号。
## 单独运行本场景调试时父节点不是 SceneManager, 没有 get_args, 用 has_method 挡一下
func _read_requested_song_index() -> int:
	var parent_node: Node = get_parent()
	if parent_node == null or not parent_node.has_method("get_args"):
		return -1

	var args: Dictionary = parent_node.get_args()
	var raw: Variant = args.get("song_index", args.get("card_index", -1))
	if raw is int or raw is float:
		return int(raw)
	return -1

# ---------- 信号绑定 ----------
## 返回按钮
func _on_back_pressed() -> void:
	Global.play_ui_click_audio()
	if Global.notebook_return_scene == "results":
		$"..".start_scene_by_path("res://Scene/Ui/SongSelect/Sympathy.tscn")
	else:
		$"..".back_to_previous_scene()
	Global.notebook_return_scene = "home"
	pass


# ---------- 标签页 ----------
## 资料卡
func _on_cards_tab_pressed() -> void:
	Global.play_ui_click_audio()
	switch_tab("cards")
	pass


## 故事碎片
func _on_fragments_tab_pressed() -> void:
	Global.play_ui_click_audio()
	switch_tab("fragments")
	pass


## 切换标签页: 清空侧栏后重建列表
## 两个标签按钮和侧栏条目都用主题 (Genrial) 里的默认 Button 样式, 不覆盖字色字号;
## 选中态只靠下划线的显隐表示
## @param song_index: 资料卡要优先展示的曲目下标, -1 表示不指定
func switch_tab(tab: String, song_index: int = -1) -> void:
	current_tab = tab
	var is_cards: bool = tab == "cards"

	cards_underline.visible = is_cards
	fragments_underline.visible = not is_cards
	
	_show_normal_background()
	
	# 清左侧
	# INFO: 必须先 remove_child 再 queue_free —— queue_free 是延迟到帧末执行的,
	#       若只调 queue_free, 紧接着重建列表时这些旧条目还挂在 sidebar 下,
	#       子节点数会翻倍, 按行号取条目的地方就会错位
	for child: Node in sidebar.get_children():
		sidebar.remove_child(child)
		child.queue_free()
		pass

	if is_cards:
		_build_card_list(song_index)
		pass
	else:
		_build_fragment_list()
		pass
	pass


# ---------- 侧栏列表 ----------
## 下标 index 的曲目是否未解锁
## 判定与 Sympathy.if_locked() 同一套 —— 解锁的是前 main_line_unlocked 首,
## 也就是把"已解锁曲目数"这个计数直接当成"开头几首可用"来用
func _is_song_locked(index: int) -> bool:
	return index >= Global.main_line_unlocked


## 序号为 fragment_id 的故事碎片是否未解锁
## Global.story_fragments_unlocked 里装的是已解锁的碎片序号
## INFO: 元素是数字还是字符串取决于 json 里怎么写, 统一转成字符串比对
func _is_fragment_locked(fragment_id: String) -> bool:
	for unlocked_id: Variant in Global.story_fragments_unlocked:
		if str(unlocked_id) == fragment_id:
			return false
		pass
	return true


## 资料卡侧栏: 列出全部曲包, 未解锁的只显示 ???
## @param requested_song_index: 要优先展示的曲目下标, -1 表示不指定
func _build_card_list(requested_song_index: int = -1) -> void:
	_songs = _load_song_cards()
	if _songs.is_empty():
		_show_empty_hint()
		return

	for i: int in _songs.size():
		var btn: Button = _make_sidebar_button()
		if _is_song_locked(i):
			btn.text = LOCKED_PLACEHOLDER
			btn.disabled = true
			pass
		else:
			btn.text = _song_title(_songs[i])
			pass
		btn.pressed.connect(_on_card_selected.bind(i))
		sidebar.add_child(btn)
		pass

	# 优先选中上个场景指定的那一首, 没指定 (或它没解锁) 就退回第一首已解锁的
	# INFO: 指定的下标越界 (曲包被删过) 或那一首未解锁时都不能直接用 ——
	#       否则会把未解锁曲目的资料漏出来
	var target_index: int = requested_song_index
	if target_index < 0 or target_index >= _songs.size() or _is_song_locked(target_index):
		target_index = -1
		for i: int in _songs.size():
			if not _is_song_locked(i):
				target_index = i
				break
			pass
		pass

	# INFO: 一首都没解锁时不能沿用正文里上一篇的残留内容
	if target_index >= 0:
		_on_card_selected(target_index)
	else:
		content_label.text = "[center]（尚未解锁任何曲目）[/center]"
	pass


## 故事碎片侧栏: 按序号列出全部碎片, 未解锁的只显示 ???
func _build_fragment_list() -> void:
	_fragments = _get_fragment_data()
	if _fragments.is_empty():
		_show_empty_hint()
		return

	var ids: Array[String] = _sorted_fragment_ids(_fragments)
	for fragment_id: String in ids:
		var btn: Button = _make_sidebar_button()
		if _is_fragment_locked(fragment_id):
			btn.text = LOCKED_PLACEHOLDER
			btn.disabled = true
			pass
		else:
			btn.text = _fragment_title(fragment_id)
			pass
		btn.pressed.connect(_on_fragment_selected.bind(fragment_id))
		sidebar.add_child(btn)
		pass

	# 自动选中第一条已解锁的
	# INFO: 一条都没解锁时不能沿用正文里上一篇的残留内容
	var first_unlocked_id: String = ""
	for fragment_id: String in ids:
		if not _is_fragment_locked(fragment_id):
			first_unlocked_id = fragment_id
			break
		pass
	if first_unlocked_id.is_empty():
		content_label.text = "[center]（尚未解锁任何故事碎片）[/center]"
		pass
	else:
		_on_fragment_selected(first_unlocked_id)
		pass
	pass


## 建一个侧栏条目
## 不设 flat, 也不覆盖字色字号 —— 外观完全交给主题 (Genrial) 里的 Button 定义
func _make_sidebar_button() -> Button:
	var btn: Button = Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 35)
	btn.custom_minimum_size = Vector2(0, SIDEBAR_ROW_HEIGHT)
	# mouse_filter 用 PASS 而不是默认的 STOP: 条目铺满整列, STOP 会把触摸拖拽
	# 整个吃掉, 侧栏条目一多就滚不动了 (正文那个 RichTextLabel 也是同样的处理)。
	# 用 PASS 而非 IGNORE: 条目自己还要收点击, IGNORE 会让它点不动
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	# 点击音效单独接一条, 不写进 _on_card_selected / _on_fragment_selected ——
	# 那两个函数在"进入场景自动选中"和"从 Sympathy 的笔记按钮进来"时也会被调用,
	# 写在那里会让玩家什么都没点也响一声
	btn.pressed.connect(Global.play_ui_click_audio)
	return btn


## 数据文件缺失时不留空白
func _show_empty_hint() -> void:
	content_label.text = "[center]（暂无数据）[/center]"
	pass


# ---------- 选中 ----------
func _on_card_selected(index: int) -> void:
	if index < 0 or index >= _songs.size():
		return

	selected_card_index = index
	var song: Dictionary = _songs[index]

	# 曲绘切到这一首 —— 同一首重复点就什么都不做, 免得白闪一下黑场
	# 曲绘的实际读取交给 _fade_to_cover 在黑场中间做 (见那里的说明)
	if _cover_source_index != index:
		_cover_source_index = index
		_fade_to_cover(_read_song_cover.bind(song["path"]))
		pass

	var card_no: int = int(song.get("card_no", -1))
	if card_no <= 0:
		content_label.text = "[center]（这首曲目还没有资料卡）[/center]"
		return

	var card_text: String = _read_bbcode_file(_card_file_path(card_no))
	if card_text.is_empty():
		content_label.text = "[center]（资料卡 #%d 缺失）[/center]" % card_no
		return

	content_label.text = card_text
	pass


func _on_fragment_selected(fragment_id: String) -> void:
	var fragment_no: int = fragment_id.to_int()
	if fragment_no <= 0:
		content_label.text = "[center]（故事碎片序号无效）[/center]"
		return

	var fragment_text: String = _read_bbcode_file(_fragment_file_path(fragment_no))
	if fragment_text.is_empty():
		content_label.text = "[center]（故事碎片 #%d 缺失）[/center]" % fragment_no
		return

	content_label.text = fragment_text
	pass


# ---------- 背景图切换 ----------
## 背景图切回默认图 (切到故事碎片页时用)
func _show_normal_background() -> void:
	if _cover_source_index == -1:
		return
	_cover_source_index = -1
	_fade_to_cover(_read_normal_background)
	pass


## 黑场过渡: 把 color_rect 压到全黑 → 黑透了才取图并换上 → 淡回它原本的透明度
## @param texture_provider: 无参、返回 Texture2D 的可调用对象, 在黑场中间才被调用
## INFO: 取图要放在黑场中间的回调里, 不能在过渡开始前先取好 ——
##       从 .lpz 里解一张曲绘要几十上百毫秒, 放在变黑之前玩家会先卡一下才看到变黑;
##       挪到黑幕底下就完全看不见了
## INFO: 终值是 _color_rect_base_alpha 而不是 0 —— color_rect 是常驻的压暗层,
##       场景里给了它一个非 0 的透明度, 过渡完必须回到那个值
func _fade_to_cover(texture_provider: Callable) -> void:
	# 本次进入的第一次换图直接生效: SceneManager 已经在做整屏淡入了, 不必再来一次
	if _is_first_cover_set:
		_is_first_cover_set = false
		_apply_cover_texture(texture_provider)
		return

	# 时长为 0 就退化成直接换图, 不做黑场
	if cover_fade_duration <= 0.0:
		_apply_cover_texture(texture_provider)
		return

	# 先掐掉正在进行的过渡, 否则两条 tween 会抢 color_rect 的 alpha。
	# 连点侧栏时上一轮可能还没黑完, 这时从当前透明度接着走, 画面是连着的
	if _cover_tween and _cover_tween.is_valid():
		_cover_tween.kill()
		pass

	_cover_tween = create_tween()
	_cover_tween.set_trans(Tween.TRANS_CUBIC)
	_cover_tween.set_ease(Tween.EASE_OUT)
	_cover_tween.tween_property(color_rect, "color:a", 1.0, cover_fade_duration)
	# 黑透了才换图, 这一下突变玩家看不到
	_cover_tween.tween_callback(_apply_cover_texture.bind(texture_provider))
	_cover_tween.tween_property(color_rect, "color:a", _color_rect_base_alpha, cover_fade_duration)
	pass


## tween_callback 的目标: 取出图并换上。取到的图是 null 就保持原样, 不清空背景
func _apply_cover_texture(texture_provider: Callable) -> void:
	var texture: Texture2D = texture_provider.call()
	if texture:
		cover.texture = texture
		pass
	pass


## 默认背景图 (已在 Global 里 preload 好, 不用现读)
func _read_normal_background() -> Texture2D:
	return Global.normal_background


## 读出某一首曲包的曲绘 (供黑场过渡在途中调用)
func _read_song_cover(lpz_path: String) -> Texture2D:
	return Global._read_cover_from_lpz(lpz_path)


# ---------- 资料卡 / 碎片文件 ----------
## 资料卡序号 n 对应的 .bbcode 路径
func _card_file_path(card_no: int) -> String:
	return CARDS_DIR.path_join("card_%d.bbcode" % card_no)


## 故事碎片序号 n 对应的 .bbcode 路径
func _fragment_file_path(fragment_no: int) -> String:
	return FRAGMENTS_DIR.path_join("fragment_%d.bbcode" % fragment_no)


## 读一个纯文本 .bbcode 文件; 文件缺失 / 打不开时返回空字符串
func _read_bbcode_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_error("找不到文本文件: %s" % path)
		return ""

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开文本文件: %s" % path)
		return ""

	var text: String = file.get_as_text()
	file.close()
	return text


# ---------- 数据文件读取 ----------
## 读一个"以字符串为键的 JSON 对象"文件 (资料卡索引表与故事碎片表都是这个形状)
## 文件缺失 / 打不开 / 解析结果不是对象, 一律返回空字典, 调用方据此退回占位文字
## @param path: res:// 路径
## @param label: 出错时打印用的中文名, 便于一眼看出是哪个表出了问题
func _read_json_object(path: String, label: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { }

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开%s: %s" % [label, path])
		return { }
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("%s解析失败 (应为 JSON 对象): %s" % [label, path])
	return { }


# ---------- 曲包数据 ----------
## 读取全部曲包, 抽出每首的 chart.General, 并配上同名曲目的资料卡序号
## 每个曲包只读 chart.lp —— 它在包里是压缩过的几 KB, 不碰同包的音频与视频
func _load_song_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = [ ]
	var paths: Array[String] = _get_song_packages()
	# 索引表整表读一次就够, 不要在循环里按曲名反复读同一个文件
	var card_indices: Dictionary = _get_card_indices()
	var missing_titles: Array[String] = [ ]
	for i: int in paths.size():
		var chart: Dictionary = Global._read_chart_from_lpz(paths[i])
		var general: Dictionary = chart.get("General", { })
		var title: String = _raw_title(general)
		var card_no: int = _card_no_for_title(card_indices, general)
		# 曲名写错一个字 (全角空格、标点差异) 资料卡就会静默找不到, 攒起来一次报全
		if not title.is_empty() and card_no <= 0:
			missing_titles.append(title)
			pass
		cards.append({
			"path": paths[i],
			"general": general,
			"card_no": card_no,
		})
		pass
	print("资料卡曲包读取完成, 共 %d 首" % cards.size())
	if not missing_titles.is_empty():
		print("以下曲名在%s里没有序号, 请核对键名: %s" % [
			CARDS_JSON_PATH,
			", ".join(missing_titles),
		])
	return cards


## 读资料卡索引表 (曲名 -> 资料卡序号 n)
func _get_card_indices() -> Dictionary:
	return _read_json_object(CARDS_JSON_PATH, "资料卡索引表")


## 曲包里的原始曲名 (chart.General 的 Title), 取不到就是空字符串
## INFO: 与 _song_title() 的区别是这里不做文件名兜底 —— 文件名是服务器链接末段的
##       数字 ID (1.lpz / 3.lpz), 只配用来显示, 拿来当 cards.json 的键毫无意义
func _raw_title(general: Dictionary) -> String:
	return str(general.get("Title", ""))


## 取曲名对应的资料卡序号 n
## INFO: 键是曲名而不是"第几首" —— 下标来自未排序的目录枚举, 曲包一增删就整体错位,
##       曲名是曲目的固有属性, 不受目录顺序影响
## 曲名为空、表里没有这个曲名、值不是有效序号时返回 -1
func _card_no_for_title(card_indices: Dictionary, general: Dictionary) -> int:
	var title: String = _raw_title(general)
	if title.is_empty():
		return -1

	var raw: Variant = card_indices.get(title, -1)
	if raw is int or raw is float:
		return int(raw)
	if raw is String and (raw as String).is_valid_int():
		return int(raw)
	return -1


## 侧栏显示用的曲名: 优先曲包里的 Title, 没有就退回文件名
func _song_title(song: Dictionary) -> String:
	var general: Dictionary = song["general"]
	var title: String = str(general.get("Title", ""))
	if title.is_empty():
		return (song["path"] as String).get_file().get_basename()
	return title


## 取全部曲包路径
## 正常流程下 Launch 启动时已扫描并排好序, 直接用它的结果 —— 单独运行本场景调试时
## (Global.sympath_song_path_list 还是空的) 才回退到现场扫描目录
## INFO: 排序规则必须与 Launch 完全一致 (Global.sort_song_package_paths) ——
##       Global.main_line_unlocked 是"已解锁几首"的计数, 靠下标去套,
##       两个场景对"第 i 首"的认定一旦错开, 结果就是锁错歌。
func _get_song_packages() -> Array[String]:
	if not Global.sympath_song_path_list.is_empty():
		return Global.sympath_song_path_list.duplicate()
	return Global.sort_song_package_paths(_scan_song_package_dir())


## 扫描曲包目录下的 .lpz 文件
func _scan_song_package_dir() -> Array[String]:
	var paths: Array[String] = [ ]
	var dir_path: String = OS.get_user_data_dir().path_join(PLAYLIST_DIR_NAME)
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("无法打开曲包目录: %s" % dir_path)
		return paths

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == SONG_PACKAGE_EXTENSION:
			paths.append(dir_path.path_join(file_name))
			pass
		file_name = dir.get_next()
		pass
	dir.list_dir_end()
	return paths


# ---------- 故事碎片数据 ----------
## 读故事碎片索引表 (侧栏标题与解锁顺序; 正文由 fragment_n.bbcode 提供)
## 结构是 { "序号": "标题" }
## 文件缺失或格式不对都返回空字典, 侧栏退回"暂无数据"
func _get_fragment_data() -> Dictionary:
	return _read_json_object(FRAGMENTS_JSON_PATH, "故事碎片索引表")


## 取碎片序号的显示顺序
## INFO: 不能直接对键做字符串排序 —— 那样 "10" 会排到 "2" 前面, 得按数值比
func _sorted_fragment_ids(fragments: Dictionary) -> Array[String]:
	var ids: Array[String] = [ ]
	for key: Variant in fragments:
		ids.append(str(key))
		pass
	ids.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	return ids


## 侧栏显示用的碎片标题
func _fragment_title(fragment_id: String) -> String:
	var title: Variant = _fragments.get(fragment_id, LOCKED_PLACEHOLDER)
	if title is String:
		return title
	if title is Dictionary:
		# 兼容旧的 { "title": ... } 结构
		return str((title as Dictionary).get("title", LOCKED_PLACEHOLDER))
	return LOCKED_PLACEHOLDER


# ---------- 内容里的链接 ----------
func _on_content_meta_clicked(meta: Variant) -> void:
	if meta == "close":
		_on_back_pressed()
	pass
