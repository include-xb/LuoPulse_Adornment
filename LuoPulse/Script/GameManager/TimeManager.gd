extends Node


class_name TimeManager


# 计时器开始的时间 (毫秒)
var start_time: int = 0


# 启动计时器
func start() -> void:
	start_time = Time.get_ticks_msec()
	pass


# 获取经过的时间 (毫秒)
func get_passed_time() -> int:
	return Time.get_ticks_msec() - start_time
