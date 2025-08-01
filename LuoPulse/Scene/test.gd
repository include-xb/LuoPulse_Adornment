## test.gd 用于各种测试的脚本
## 可以在这里写各种测试代码，比如按键检测等等


extends Node


func _process(delta: float) -> void:
	if Input.is_action_just_released("ui_accept"):
		Global.display_notice("Notice: there is a notice.")
		pass
	pass
