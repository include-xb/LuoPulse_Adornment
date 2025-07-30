extends Node


## 常量

# 版本号
const VERSION: String = "0.0.1"

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
const START_JUDGE_TIME: int = -180

# 结束判定时间 (单位: 毫秒)
const END_JUDGE_TIME: int = 180

# 共鸣判定区间: [-60, 60]
const SYMPATHY_TIME: int = 60

# 同步判定区间: [-120, -60) and (60, 120]
const SYNCED_TIME: int = 120

# 连接判定区间: [-180, -120) and (120, 180]
const CONNECTED_TIME: int = 180



## 变量

# 音符速度
var note_speed: float = 200.0

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
var sympath_song_num: int = 0

# 专辑主线歌曲路径列表
var album_song_path_list: Array[String] = [ ]

# 专辑主线歌曲数
var album_song_num: int = 0

# 当前歌曲
var current_song: String = ""

# 当前歌曲的索引
var current_song_index: int = 0

# 四类判定等级
var sympathized: int = 0
var synced: int = 0
var connected: int = 0
var lost: int = 0

# 连击数
var combo: int = 0

# 准度
var accuracy: float = 0.0
