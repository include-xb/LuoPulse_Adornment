## FinishMenu 结算页面
##
## 节点结构定义在 FinishMenu.tscn 中, 本脚本只负责把 Global.gameplay_result 的数据填入对应节点


extends Control


## 等级 ∞ Infinity A B C D
@export var grade_label: Label # = $Card/Padding/VBox/Header/Grade

## 歌曲标题
@export var title_label: Label # = $Card/Padding/VBox/Header/Title

## 准度
@export var acc_label: Label # = $Card/Padding/VBox/Body/LeftGrid/AccCount

## 和一
@export var harmonious_count: Label # = $Card/Padding/VBox/Body/RightGrid/HarmoniousCount
## 共鸣
@export var sympathetic_count: Label # = $Card/Padding/VBox/Body/RightGrid/SympatheticCount
## 觉醒
@export var aware_count: Label # = $Card/Padding/VBox/Body/RightGrid/AwareCount
## 丢失
@export var lost_count: Label # = $Card/Padding/VBox/Body/RightGrid/LostCount

## 最大连击数
@export var combo_label: Label # = $Card/Padding/VBox/Body/LeftGrid/ComboCount

## 音符总数
@export var notes_label: Label # = $Card/Padding/VBox/Body/LeftGrid/NotesCount

## 获得水晶数
@export var crystal_label: Label # = $Card/Padding/VBox/Crystal

## 继续按钮
@export var continue_button: Button # = $Card/Padding/VBox/ContinueButton


## 各个数值从 0 增长到最终值的时长 (秒)
## 设为 0 则不做动画, 直接显示最终值
@export var count_up_duration: float = 0.8

## 增长动画开始前的延迟 (秒)
## SceneManager 切换场景时有 0.25 秒的淡入, 这期间本场景还看不见;
## 等它过去再开始增长, 否则动画开头一段会被淡入整个盖掉
const COUNT_UP_START_DELAY: float = 0.5

## 评级 (∞ Infinity / A / B / C / D) 淡入的时长 (秒)
## 评级在数值增长期间保持隐藏, 等增长结束后才开始淡入
## 设为 0 则不做淡入, 增长一结束就直接显示
@export var grade_fade_duration: float = 1.25

## 继续按钮淡入的时长 (秒)
## 按钮在评级淡入结束后才开始淡入
## 设为 0 则不做淡入, 评级淡入一结束就直接显示
@export var button_fade_duration: float = 0.75


# TODO 数据增加, 标签和按钮淡入时播放铅笔写字音效


func _ready() -> void:
	_show_results()
	pass


## 将 Global.gameplay_result 的数据填入结算界面, 并发放水晶奖励
func _show_results() -> void:
	var result: Dictionary = Global.gameplay_result

	_update_song_info()

	# 评级 (颜色随评级动态变化; 它是文字不是数字, 不参与增长动画)
	grade_label.text = result.get("grade", "-")
	grade_label.add_theme_color_override("font_color", result.get("grade_color", Color.GRAY))

	# 以下数值都从 0 增长到最终值, 值为 0 的不产生动画
	_count_up(acc_label, result.get("accuracy", 0.0) * 100.0, _format_percent)

	_count_up(harmonious_count, float(result.get("harmonious", 0)), _format_int)
	_count_up(sympathetic_count, float(result.get("sympathetic", 0)), _format_int)
	_count_up(aware_count, float(result.get("aware", 0)), _format_int)
	_count_up(lost_count, float(result.get("lost", 0)), _format_int)

	_count_up(combo_label, float(result.get("max_combo", 0)), _format_int)
	_count_up(notes_label, float(result.get("total_notes", 0)), _format_int)

	# 水晶: 奖励立即入账, 显示上做增长动画
	var crystal_earned: int = result.get("crystal_earned", 0)
	_count_up(crystal_label, float(crystal_earned), _format_crystal)
	Global.crystal += crystal_earned
	Global.save_user_data()

	# ---- 入场动画时序: 数值增长 → 评级淡入 → 继续按钮淡入 ----
	var grade_fade_start: float = COUNT_UP_START_DELAY + count_up_duration
	_fade_in_after(grade_label, grade_fade_start, grade_fade_duration)
	_fade_in_after(continue_button, grade_fade_start + grade_fade_duration, button_fade_duration)
	pass


# ---------- 入场动画 ----------
## 让一个标签的数值从 0 增长到目标值
## @param label: 要更新的标签
## @param target: 目标数值
## @param formatter: 把当前数值转成显示文本的函数
func _count_up(label: Label, target: float, formatter: Callable) -> void:
	# 目标为 0 或时长为 0 → 不走动画, 直接落到最终值
	if is_zero_approx(target) or count_up_duration <= 0.0:
		label.text = formatter.call(target)
		return

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(COUNT_UP_START_DELAY)
	tween.tween_method(
		func(value: float) -> void:
			label.text = formatter.call(value)
			pass,
		0.0,
		target,
		count_up_duration
	)
	pass


## 让一个控件在等待一段时间后淡入
## 用 modulate.a 而不是 visible —— 控件始终占着布局位置, 淡入时不会引起排版跳动
## @param target: 要淡入的控件
## @param delay: 开始淡入前的等待时长 (秒)
## @param duration: 淡入时长 (秒), 为 0 则等时间点到达后直接显示
func _fade_in_after(target: CanvasItem, delay: float, duration: float) -> void:
	if target == null:
		push_error("_fade_in_after: 目标控件未绑定")
		return

	target.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_interval(delay)

	if duration > 0.0:
		tween.tween_property(target, "modulate:a", 1.0, duration)
	else:
		# 不做淡入, 但仍在时间点到达后才出现
		tween.tween_callback(func() -> void: target.modulate.a = 1.0)
		pass
	pass


## 百分比 (两位小数), 例: 98.42%
func _format_percent(value: float) -> String:
	return "%.2f%%" % value


## 整数
func _format_int(value: float) -> String:
	return str(int(round(value)))


## 水晶, 例: ◇ +14
func _format_crystal(value: float) -> String:
	return "◇ +" + str(int(round(value)))


## 填入歌曲标题
## 标题由 Gameplay.load_list() 从谱面的 General 里取出后写入 Global
func _update_song_info() -> void:
	var song_title: String = Global.current_song_title
	if song_title.is_empty():
		# 拿不到标题时不要留一个孤零零的 =
		title_label.text = ""
		return

	title_label.text = "& " + song_title
	pass


# ---------- 按钮信号绑定 ----------
func _on_continue_pressed() -> void:
	Global.play_ui_click_audio()

	var scene_manager: Node = get_parent()
	if scene_manager and scene_manager.has_method("back_to_previous_scene"):
		scene_manager.back_to_previous_scene()
		pass
	pass
