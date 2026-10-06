extends NoteBase


# Drag (黄键): 只要轨道被按住就算过, 不看按下时刻的手艺
#
# 在判定区 (最大判定区间) 内的任意一帧, 只要本轨被按住就算"通过":
# 	通过后继续下落到判定线才碎裂, 恒定判为"和一";
# 	若按住时已经越过判定线, 则当场碎裂, 同样判"和一"。
# 直到越过最大判定区间都没被按住 → 由基类的漏键判定接手, 算"丢失"。
# INFO: 判定与"按下时刻"无关, 所以黄键不参与 InputProcesser 的按下候选 (见 press_judge);
#       整个判定区都是补救机会 —— 没赶上刚进入判定区的那一刻, 还来得及按住它


var type: String = "drag"

## 是否已经通过 (通过后就等判定线, 或越过判定线时当场结算)
var _is_passed: bool = false


# ---------- 节点重载函数 ----------
func _physics_process(delta: float) -> void:
	super(delta)
	_update_judge()
	pass


# ---------- 判定 ----------
## 每帧推进判定
func _update_judge() -> void:
	if is_removed or is_judged:
		return

	if not _is_passed:
		_check_pass()
		pass

	if not _is_passed:
		# 还没通过: 不往下走 —— 越过最大判定区间后由基类的漏键判定接手
		return
	pass

	# 通过了的: 到判定线 (或已经越过判定线) 才碎裂
	# INFO: 与上面同一帧内结算, 所以"越过判定线之后才按住"也是当场碎裂
	if root_node.master_time - float(time) >= 0.0:
		# INFO: 传 time 而不是当前时刻 —— 黄键不看手艺, 只要按住就是"和一";
		#       越过判定线之后才按住的那种, 也因此同样判"和一"
		judge(float(time))
		pass
	pass


## 还没通过时: 判定区内任意一帧被按住就算通过
## INFO: 没通过也什么都不做 —— 越过最大判定区间之后由基类的漏键判定接手 (算 Lost)
func _check_pass() -> void:
	var time_offset: float = root_node.master_time - float(time)
	var in_judging_area: bool = time_offset >= float(Global.start_judge_time) and time_offset <= float(Global.end_judge_time)
	if in_judging_area and _is_column_held():
		_is_passed = true
		pass
	pass


## 自动播放: 不必特殊处理 —— "本轨被按住"会把自动播放一并算作按住
func _autoplay(_master_time: float) -> void:
	pass
