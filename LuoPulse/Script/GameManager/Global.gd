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

# 共鸣判定区间: [-60, 60]
const SYMPATHY_TIME: int = 60

# 同步判定区间: [-120, -60) and (60, 120]
const SYNCED_TIME: int = 120

# 连接判定区间: [-180, -120) and (120, 180]
const CONNECTED_TIME: int = 180



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

# 当前歌曲的索引
var current_song_index: int = 0

# 最后一次解锁的歌曲索引
var current_unlocked_song_index: int = 0

# 四类判定等级
var harmonious: int = 0
var sympathetic: int = 0
var aware: int = 0
var lost: int = 0

# 连击数
var combo: int = 0

# 准度
var accuracy: float = 0.0

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



# 计算当前主线进度 -> 得到当前灰度
func get_current_gray_scale() -> float:
	var progress: float = float(current_unlocked_song_index) / float(sympath_song_num)
	var gray_scale: float = 1.0 - progress
	return gray_scale


func play_ui_click_audio() -> void:
	ui_click.play()
	pass


## ============================================================
## LPZ 文件读取
## ============================================================

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
