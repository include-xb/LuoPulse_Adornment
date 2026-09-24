## HitFeedback 命中反馈参数表
##
## 判定等级 → 粒子数量 / 轨道与判定线高亮强度。
##
## 颜色不在这里配置: 粒子颜色一律取音符自身的颜色 (NoteBase / Hold 的 get_note_color),
## 这样黄键、红键、心键炸出来的粒子才会和音符本体一致。
##
## 单独成文件是因为 NoteBase 与 Hold 各自独立实现 (Hold 不继承 NoteBase),
## 但两者必须共用同一套参数, 否则长键与普通音符的打击反馈会不一致。


class_name HitFeedback


## 判定等级 → 粒子数量 (和一级最饱满, 漏键最稀疏)
const AMOUNTS: Dictionary = {
	"harmonious": 34,
	"sympathetic": 24,
	"aware": 16,
	"lost": 8,
}

## 判定等级 → 轨道与判定线的高亮强度
## 漏键为 0: 不点亮轨道, 否则等于在奖励失误
const FLASH: Dictionary = {
	"harmonious": 1.0,
	"sympathetic": 0.8,
	"aware": 0.55,
	"lost": 0.0,
}

## 取不到音符颜色时的兜底配色
const FALLBACK_COLOR: Color = Color(0.4, 0.8, 1.0, 1.0)

## 兜底粒子数量
const FALLBACK_AMOUNT: int = 24


## 取判定等级对应的粒子数量
static func amount_of(level: String) -> int:
	return int(AMOUNTS.get(level, FALLBACK_AMOUNT))


## 取判定等级对应的轨道/判定线高亮强度
static func flash_of(level: String) -> float:
	return float(FLASH.get(level, 1.0))


## 由单次准度值反推判定等级
## (长键结算时只有准度 a, 没有时间偏移, 用它还原等级以复用同一套参数)
static func level_from_accuracy(accuracy: float) -> String:
	if accuracy >= 1.0:
		return "harmonious"
	if accuracy >= 0.7:
		return "sympathetic"
	if accuracy >= 0.5:
		return "aware"
	return "lost"
