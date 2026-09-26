## Notebook 笔记本场景
##
## 布局按 LPDocument/ui-mockup/index.html 的笔记部分重做: 纸面底色 + 墨色文字
## 两个标签页 (资料卡 / 故事碎片), 左侧索引列表, 右侧内容区
##
## 资料卡的数据来自全部曲包 (.lpz): 侧栏列出每首的标题 (chart.lp 的 General.Title),
## 未解锁的条目只显示 ??? 且点不动; 点已解锁的条目会把全屏背景换成该曲的曲绘封面 (cover.png)
## 正文里"收录专辑 / 发布时间 / 创作背景 / P主简介"来自 res://Asset/NoteBook/cards.json,
## 它和故事碎片表一样是按序号索引的对象, 第 n 首取键 "n" (n 从 1 开始)
## 故事碎片的数据来自 res://Asset/NoteBook/fragments.json,
## 侧栏列出每条碎片的 title, 未解锁的只显示 ??? 且点不动;
## 解锁进度看 Global.story_fragments_unlocked 里记的碎片序号
## INFO: 两个数据文件缺失时正文显示 "（暂无数据）"
##
## 从 Sympathy 的"笔记"按钮进来时, 上个场景会通过 SceneManager 传参
## { "card_index": 曲目下标 } 指定要展示哪一首的资料卡


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

## 资料卡补充文本表: 以曲目序号 (从 1 开始) 为键的对象
## 结构与故事碎片表一样, 只是每项装的是 收录专辑 / 发布时间 / 创作背景 / P主简介
const CARDS_JSON_PATH: String = "res://Asset/NoteBook/cards.json"

## 故事碎片表: 以碎片序号为键的对象
const FRAGMENTS_JSON_PATH: String = "res://Asset/NoteBook/fragments.json"

## 文本字段缺失时的占位
const TEXT_PLACEHOLDER: String = "——"

## 未解锁条目的占位 (资料卡与故事碎片共用)
const LOCKED_PLACEHOLDER: String = "???"


## 当前状态(资料卡/故事碎片)
var current_tab: String = "cards"

## 选中的标签索引
var selected_card_index: int = -1

## 资料卡列表: 每项 { "path": String, "general": Dictionary, "note": Dictionary },
## 与侧栏条目一一对应。曲目信息与补充文本在进入资料卡时读一次缓存下来,
## 之后点侧栏只再读曲绘
var _songs: Array[Dictionary] = [ ]

## 故事碎片表: { "序号": { "title": String, "text": String, "data": Dictionary } },
## 进故事碎片页时读一次缓存下来
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
	switch_tab("cards", _read_requested_card_index())
	pass


## 读上个场景通过 SceneManager 传进来的曲目下标 (键 "card_index")
## 单独运行本场景调试时父节点不是 SceneManager, 没有 get_args, 用 has_method 挡一下
func _read_requested_card_index() -> int:
	var parent_node: Node = get_parent()
	if parent_node == null or not parent_node.has_method("get_args"):
		return -1

	var raw: Variant = parent_node.get_args().get("card_index", -1)
	if raw is int or raw is float:
		return int(raw)
	return -1


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
## @param card_index: 资料卡要优先展示的曲目下标, -1 表示不指定
func switch_tab(tab: String, card_index: int = -1) -> void:
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
		_build_card_list(card_index)
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
## @param card_index: 要优先展示的曲目下标, -1 表示不指定
func _build_card_list(card_index: int = -1) -> void:
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
	var target_index: int = card_index
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

	content_label.text = _format_data_card(_song_card_data(song))
	pass


func _on_fragment_selected(fragment_id: String) -> void:
	var fragment: Dictionary = _fragments.get(fragment_id, { })
	content_label.text = _format_diary_entry(fragment)
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


# ---------- 内容格式 ----------
func _format_data_card(song: Dictionary) -> String:
	var bbcode: String = "[center][font_size=50]& %s[/font_size][/center]\n\n" % song.get("title", "???")
	bbcode += "[center]P主: %s\n" % song.get("producer", "——")
	bbcode += "歌手: %s\n" % song.get("vocalist", "——")
	bbcode += "BPM: %s\n" % str(song.get("bpm", "——"))
	bbcode += "收录专辑: %s\n" % song.get("album", "——")
	bbcode += "发布时间: %s[/center]\n\n" % song.get("release_date", "——")
	bbcode += "[center]── 创作背景 ──[/center]\n\n"
	bbcode += "%s\n\n" % song.get("background", "(待补充)")
	bbcode += "[center]── P主简介 ──[/center]\n\n"
	bbcode += "%s\n" % song.get("producer_intro", "(待补充)")

	# if Global.notebook_return_scene != "home" and Global.notebook_return_song_title != "":
	# 	bbcode += "\n\n[center][url=close]关闭[/url][/center]"
	return bbcode


## 把一条故事碎片格式化成日记体 BBCode
## INFO: json 里日期那组字段是放在 "data" 下的 (不是 "date"), 正文在 "text"
func _format_diary_entry(fragment: Dictionary) -> String:
	var date: Dictionary = fragment.get("data", { })
	var header: String = "%s年%s月%s日    %s    %s" % [
		date.get("year", "????"),
		date.get("month", "??"),
		date.get("day", "??"),
		date.get("week", "???"),
		date.get("weather", "??"),
	]
	var bbcode: String = "[right]%s[/right]\n" % header
	bbcode += "[center]———————————————————————————————[/center]\n\n"
	bbcode += str(fragment.get("text", ""))
	return bbcode


## 把 chart.General 与资料卡补充文本合成 _format_data_card 认的键
## 曲目基本信息来自曲包, "收录专辑 / 发布时间 / 创作背景 / P主简介"来自同序号 json
## INFO: json 的键名直接沿用 _format_data_card 读取的那一套 (album / release_date /
##       background / producer_intro), 写了什么就覆盖什么, 没写的交给它的缺省值。
##       想覆盖曲名或 P主, 在 json 里写同名键 (title / producer) 即可
func _song_card_data(song: Dictionary) -> Dictionary:
	var general: Dictionary = song["general"]
	var note: Dictionary = song["note"]

	var data: Dictionary = {
		"title": _song_title(song),
		"producer": general.get("Artist", TEXT_PLACEHOLDER),
		"vocalist": general.get("Vocalist", TEXT_PLACEHOLDER),
		"bpm": general.get("BPM", TEXT_PLACEHOLDER),
	}
	for key: String in note:
		data[key] = note[key]
		pass
	return data


# ---------- 数据文件读取 ----------
## 读一个"以字符串为键的 JSON 对象"文件 (资料卡表与故事碎片表都是这个形状)
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
## 读取全部曲包, 抽出每首的 chart.General, 并配上同序号的资料卡补充文本
## 每个曲包只读 chart.lp —— 它在包里是压缩过的几 KB, 不碰同包的音频与视频
func _load_song_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = [ ]
	var paths: Array[String] = _get_song_packages()
	# 补充文本整表读一次就够, 不要在循环里按序号反复读同一个文件
	var notes: Dictionary = _get_card_data()
	for i: int in paths.size():
		var chart: Dictionary = Global._read_chart_from_lpz(paths[i])
		var general: Dictionary = chart.get("General", { })
		cards.append({
			"path": paths[i],
			"general": general,
			"note": _card_note(notes, i + 1),
		})
		pass
	print("资料卡曲包读取完成, 共 %d 首" % cards.size())
	return cards


## 读资料卡补充文本表
func _get_card_data() -> Dictionary:
	return _read_json_object(CARDS_JSON_PATH, "资料卡文本表")


## 取第 number 首 (从 1 开始) 的资料卡补充文本
## 表里没有这个序号 (或那一项不是对象) 就返回空字典, 正文退回 _format_data_card 的缺省占位文字
func _card_note(notes: Dictionary, number: int) -> Dictionary:
	var entry: Variant = notes.get(str(number), { })
	if entry is Dictionary:
		return entry
	return { }


## 侧栏显示用的曲名: 优先曲包里的 Title, 没有就退回文件名
func _song_title(song: Dictionary) -> String:
	var general: Dictionary = song["general"]
	var title: String = str(general.get("Title", ""))
	if title.is_empty():
		return (song["path"] as String).get_file().get_basename()
	return title


## 取全部曲包路径
## 正常流程下 Launch 启动时已扫描好, 直接用它的结果 —— 单独运行本场景调试时
## (Global.sympath_song_path_list 还是空的) 才回退到现场扫描目录
## INFO: 这里千万不能排序! Global.main_line_unlocked 是"已解锁几首"的计数, 靠下标去套,
##       而 Sympathy 是把同一个计数套在 Global.sympath_song_path_list 上的。
##       一旦在这里重排, 两个场景对"第 i 首"的认定就会错开, 结果就是锁错歌。
##       好处是侧栏顺序与选歌界面看到的曲目顺序天然一致。
func _get_song_packages() -> Array[String]:
	if not Global.sympath_song_path_list.is_empty():
		return Global.sympath_song_path_list.duplicate()
	return _scan_song_package_dir()


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
## 读故事碎片表
## 结构是 { "序号": { "title": String, "text": String, "data": { 年/月/日/周/天气 } } }
## 文件缺失或格式不对都返回空字典, 侧栏与正文就退回"暂无数据"
func _get_fragment_data() -> Dictionary:
	return _read_json_object(FRAGMENTS_JSON_PATH, "故事碎片表")


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
	var fragment: Dictionary = _fragments.get(fragment_id, { })
	return str(fragment.get("title", LOCKED_PLACEHOLDER))


# ---------- 内容里的链接 ----------
func _on_content_meta_clicked(meta: Variant) -> void:
	if meta == "close":
		_on_back_pressed()
	pass
