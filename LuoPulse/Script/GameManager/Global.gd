extends Node


## 常量
const VERSION: String = "0.0.1"

const COLUMN_NUM: int = 4


## 变量

# 音符速度
var note_speed: float = 200.0

# 游戏模式
enum GameMode {
	None,
	Album,
	Sympathy,
} 
var game_mode: GameMode = GameMode.None

# 共鸣模式歌曲列表
var sympath_song_list: Array[String] = [ ]

# 专辑模式歌曲列表
var album_song_list: Array[String] = [ ]

# 当前歌曲
var current_song: String = ""

# 当前歌曲的索引
var current_song_index: int = 0

# 判定等级
var sympathized: int = 0
var linked: int = 0
var lost: int = 0

# 连击数
var combo: int = 0
