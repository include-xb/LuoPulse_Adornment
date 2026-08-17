extends Control


@onready var NOTICE_BOX: VBoxContainer = $NoticeBox
@onready var ui_click: AudioStreamPlayer = $UiClick


## 常量

# 版本号
const VERSION: String = "0.0.1"

# 通知消息展示时间
const NOTICE_LIFETIME: int = 3

# 通知消息组件
const NOTICE_PACKED_SCENE: PackedScene = preload("res://Scene/Ui/Widget/Notice.tscn")

# 轨道数
const COLUMN_NUM: int = 4

# 轨道1对应键盘按键
const KEY_1: String = "D"

# 轨道2对应键盘按键
const KEY_2: String = "F"

# 轨道3对应键盘按键
const KEY_3: String = "J"

# 轨道4对应键盘按键
const KEY_4: String = "K"

# 按键列表
const KEY_LIST: Array[String] = [ KEY_1, KEY_2, KEY_3, KEY_4 ]

# 开始判定时间 (单位: 毫秒)
const START_JUDGE_TIME: int = -240

# 结束判定时间 (单位: 毫秒)
const END_JUDGE_TIME: int = 240

# 和一 (Harmonious) 判定区间: [-60, 60]
const HARMONIOUS_TIME: int = 60

# 共鸣 (Sympathetic) 判定区间: [-120, -60) and (60, 120]
const SYMPATHETIC_TIME: int = 120

# 觉醒 (Aware) 判定区间: [-180, -120) and (120, 180]
const AWARE_TIME: int = 180

# 丢失 (Lost) 判定区间: [-240, -180) and (180, 240]
const LOST_TIME: int = 240

# INFO: 设置项仅在此处修改，控件将会动态生成
# 设置项
# 每个设置项字段:
# 	key: Global 中的变量名 (读取/写入值)
# 	config_key: config.json 中的键名 (默认与 key 相同)
# 	node_type: 控件类型 (HSlider / SpinBox)
# 	min / max / step: 控件取值范围与步进
# 	suffix: 显示在数值后的单位
# "语言": { "key": "language", "node_type": "OptionButton", "options": ["中文", "English", "日本語"] },
# "用户名": { "key": "user_name", "node_type": "LineEdit" },
const SETTINGS: Dictionary[String, Dictionary] = {
	"音频": {
		"UI音效音量": {
			"key": "volume_ui",
			"config_key": "volume_ui",
			"node_type": "HSlider",
			"min": 0,
			"max": 100,
			"step": 1,
			"suffix": "%",
		},
		"音符打击音量": {
			"key": "volume_note",
			"config_key": "volume_note",
			"node_type": "HSlider",
			"min": 0,
			"max": 100,
			"step": 1,
			"suffix": "%",
		},
		"歌曲音量": {
			"key": "volume_song",
			"config_key": "volume_song",
			"node_type": "HSlider",
			"min": 0,
			"max": 100,
			"step": 1,
			"suffix": "%",
		},
	},
	"游戏": {
		"谱面偏移": {
			"key": "chart_offset",
			"config_key": "offset",
			"node_type": "SpinBox",
			"min": -200,
			"max": 200,
			"step": 1,
			"suffix": "ms",
		},
		"音符流速": {
			"key": "note_flow_speed",
			"config_key": "speed",
			"node_type": "SpinBox",
			"min": 1,
			"max": 20,
			"step": 1,
			"suffix": "",
		},
	},
}


## 变量

# 音符速度, 这个速度是下落的实际速度准值
var note_speed: float = 10.0

# 用户名
var user_name: String = ""

# 游戏模式
enum GameMode {
	None,
	Album,
	Sympathy,
} 
var game_mode: GameMode = GameMode.None

# 是否自动播放
var is_autoplay: bool = false

# 共鸣主线歌曲路径列表
var sympath_song_path_list: Array[String] = [ ]

# 共鸣主线歌曲数
var sympath_song_num: int = 17

# 专辑主线歌曲路径列表
var album_song_path_list: Array[String] = [ ]

# 专辑主线歌曲数
var album_song_num: int = 0

# 当前歌曲
var current_song: String = ""

# 当前歌曲标题
var current_song_title: String = ""

# 当前歌曲制作人 (P主)
var current_song_artist: String = ""

# 当前歌曲 BPM
var current_song_bpm: String = ""

# 笔记返回场景 (home / results)
var notebook_return_scene: String = "home"

# 笔记返回的歌曲标题
var notebook_return_song_title: String = ""

# 当前歌曲的索引
var current_song_index: int = 0

# 最后一次解锁的歌曲索引
var current_unlocked_song_index: int = 0

# 四类判定等级
var harmonious: int = 0
var sympathetic: int = 0
var aware: int = 0
var lost: int = 0

# 已判定音符总数 (用于计算准度)
var total_judged: int = 0

# 连击数
var combo: int = 0

# 准度
var accuracy: float = 0.0

# 当前主时间 (由 Gameplay 每帧更新, 基于音频播放位置)
var master_time: float = -3000.0

# 处在判定区间中的音符
var judging_area: Array = [ ]


# 开始前的延时，这个时间也反应着同一时间内场景中音符最大数量。
# 相当于当前时间，到当前时间+start_duration这段时间内的音符会被加载到场景中
var start_duration: int = 3000


# ---- 用户数据 (user.json) ----

# 已解锁的共鸣曲目数
var main_line_unlocked: int = 1

# 水晶数
var crystal: int = 0

# 已获得的彩蛋碎片 ID
var story_fragments_unlocked: Array = []


# ---- 游戏配置 (config.json) ----

# 游戏配置版本号
var config_version: String = "0.0.0.1"

# 歌曲播放音量
var volume_song: int = 90

# 音符打击音量
var volume_note: int = 70

# UI 音量
var volume_ui: int = 60

# 谱面偏移
var chart_offset: int = 0

# 音符流速，这个速度是将音符实际速度映射到 1-20 的区间， 方便玩家调节
var note_flow_speed: int = 10



# 最后一场游戏的结果数据
var gameplay_result: Dictionary = {
	"accuracy": 0.0,
	"grade": "",
	"grade_color": Color.GRAY,
	"harmonious": 0,
	"sympathetic": 0,
	"aware": 0,
	"lost": 0,
	"max_combo": 0,
	"total_notes": 0,
	"crystal_earned": 0,
}
# 当前最大连击 (由 Gameplay 每帧更新)
var max_combo: int = 0



func get_current_gray_scale() -> float:
	var progress: float = float(current_unlocked_song_index) / float(sympath_song_num)
	var gray_scale: float = 1.0 - progress
	return gray_scale


func play_ui_click_audio() -> void:
	ui_click.play()
	pass


## 根据准度计算评级
## 返回 Dictionary { "grade": String, "color": Color }
func get_grade(acc: float) -> Dictionary:
	if acc >= 0.95:
		return { "grade": "∞ Infinity", "color": Color.GOLDENROD }
	elif acc >= 0.85:
		return { "grade": "A", "color": Color.ORANGE }
	elif acc >= 0.70:
		return { "grade": "B", "color": Color.YELLOW }
	elif acc >= 0.50:
		return { "grade": "C", "color": Color.CORNFLOWER_BLUE }
	return { "grade": "D", "color": Color.GRAY }


## 根据准度计算水晶奖励
func get_crystal_reward(acc: float) -> int:
	var result: float = 0.0
	if acc <= 0.0:
		result = 0.0
	elif acc < 0.75:
		result = 10.0
	elif acc < 0.91:
		result = 20.0 * acc - 4.0
	elif acc < 0.95:
		result = 40.0 * acc - 22.0
	elif acc < 1.0:
		result = 60.0 * acc - 41.0
	else:
		result = 20.0
	return int(round(result))


## ============================================================
## LPZ 文件读取
## ============================================================

## 一次性从 .lpz 文件中读取所有资源 (cover/audio/chart/video)
## 相比分别调用 _read_*_from_lpz, 只打开一次 ZIP 文件, 避免重复解压
## 返回 Dictionary: { "cover": ImageTexture, "audio": AudioStream, "chart": Dictionary, "video": VideoStream }
func _read_lpz(lpz_path: String) -> Dictionary:
	var result: Dictionary = {
		"cover": null,
		"audio": null,
		"chart": { },
		"video": null,
	}

	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		push_error("无法打开 .lpz 文件: %s" % lpz_path)
		return result

	var files: Dictionary = { }
	for f in zip.get_files():
		files[f.get_file()] = f

	# 封面
	if files.has("cover.png"):
		var img := Image.new()
		if img.load_png_from_buffer(zip.read_file(files["cover.png"])) == OK:
			result["cover"] = ImageTexture.create_from_image(img)

	# 音频
	if files.has("audio.ogg"):
		var audio_stream := AudioStreamOggVorbis.load_from_buffer(zip.read_file(files["audio.ogg"]))
		if audio_stream == null:
			push_error("无法解码音频文件: audio.ogg")
		else:
			result["audio"] = audio_stream

	# 谱面
	if files.has("chart.lp"):
		var json_str := zip.read_file(files["chart.lp"]).get_string_from_utf8()
		var json := JSON.new()
		if json.parse(json_str) == OK:
			var data: Variant = json.get_data()
			if data is Dictionary:
				result["chart"] = data

	# 视频 (VideoStreamTheora 无 load_from_buffer, 需写入临时文件)
	if files.has("video.ogv"):
		var temp_dir := OS.get_user_data_dir().path_join("temp")
		if not DirAccess.dir_exists_absolute(temp_dir):
			DirAccess.make_dir_recursive_absolute(temp_dir)

		var temp_path := temp_dir.path_join("_video_temp.ogv")
		var file := FileAccess.open(temp_path, FileAccess.WRITE)
		if file == null:
			push_error("无法创建临时视频文件: %s" % temp_path)
		else:
			file.store_buffer(zip.read_file(files["video.ogv"]))
			file.close()

			var video_stream := VideoStreamTheora.new()
			video_stream.file = temp_path
			result["video"] = video_stream

	zip.close()
	return result


## 从 .lpz 文件中读取封面图片，返回 ImageTexture
func _read_cover_from_lpz(lpz_path: String) -> ImageTexture:
	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		push_error("无法打开 .lpz 文件: %s" % lpz_path)
		return null

	var cover_path := ""
	for f in zip.get_files():
		if f.get_file() == "cover.png":
			cover_path = f
			break

	if cover_path == "":
		zip.close()
		push_error("在 .lpz 中找不到 cover.png: %s" % lpz_path)
		return null

	var img_bytes := zip.read_file(cover_path)
	zip.close()

	var img := Image.new()
	var load_err := img.load_png_from_buffer(img_bytes)
	if load_err != OK:
		push_error("无法解码封面图片: %s" % cover_path)
		return null

	return ImageTexture.create_from_image(img)


## 从 .lpz 文件中读取音频，返回 AudioStream
func _read_audio_from_lpz(lpz_path: String) -> AudioStream:
	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		push_error("无法打开 .lpz 文件: %s" % lpz_path)
		return null

	var audio_path := ""
	for f in zip.get_files():
		if f.get_file() == "audio.ogg":
			audio_path = f
			break

	if audio_path == "":
		zip.close()
		push_error("在 .lpz 中找不到 audio.ogg: %s" % lpz_path)
		return null

	var audio_bytes := zip.read_file(audio_path)
	zip.close()

	var audio_stream := AudioStreamOggVorbis.load_from_buffer(audio_bytes)
	if audio_stream == null:
		push_error("无法解码音频文件: %s" % audio_path)
		return null
	return audio_stream


## 从 .lpz 文件中读取 chart.lp
func _read_chart_from_lpz(lpz_path: String) -> Dictionary:
	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		return {}

	var chart_path := ""
	for f in zip.get_files():
		if f.get_file() == "chart.lp":
			chart_path = f
			break

	if chart_path == "":
		zip.close()
		return {}

	var json_bytes := zip.read_file(chart_path)
	zip.close()

	var json_str := json_bytes.get_string_from_utf8()

	var json := JSON.new()
	var parse_err := json.parse(json_str)
	if parse_err != OK:
		push_error("无法解析 chart.lp: %s" % lpz_path)
		return {}

	var data = json.get_data()
	#if data is Dictionary and data.has("General"):
		#return data["General"]
	#return {}
	return data


## 从 .lpz 文件中读取 video.ogv
func _read_video_from_lpz(lpz_path: String) -> VideoStream:
	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		push_error("无法打开 .lpz 文件: %s" % lpz_path)
		return null

	var video_path := ""
	for f in zip.get_files():
		if f.get_file() == "video.ogv":
			video_path = f
			break

	if video_path == "":
		zip.close()
		return null

	var video_bytes := zip.read_file(video_path)
	zip.close()

	# VideoStreamTheora 没有 load_from_buffer 方法，需要先写入临时文件再加载
	var temp_dir := OS.get_user_data_dir().path_join("temp")
	if not DirAccess.dir_exists_absolute(temp_dir):
		DirAccess.make_dir_recursive_absolute(temp_dir)

	var temp_path := temp_dir.path_join("_video_temp.ogv")
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("无法创建临时视频文件: %s" % temp_path)
		return null
	file.store_buffer(video_bytes)
	file.close()

	var video_stream := VideoStreamTheora.new()
	video_stream.file = temp_path
	return video_stream



func display_notice(info: String) -> void:
	var notice: RichTextLabel = NOTICE_PACKED_SCENE.instantiate()
	notice.text = "  " + info
	NOTICE_BOX.add_child(notice)
	pass


## 将当前设置写入 config.json
## 遍历 SETTINGS, 按 config_key 组装数据, 立即保存
func save_config() -> void:
	var data: Dictionary = { "version": config_version }

	for group_key: String in SETTINGS:
		var group: Dictionary = SETTINGS[group_key]
		for setting_name: String in group:
			var setting: Dictionary = group[setting_name]
			var config_key: String = setting.get("config_key", setting["key"])
			data[config_key] = get(setting["key"])
			pass
		pass

	var path: String = OS.get_user_data_dir().path_join("config.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	pass
