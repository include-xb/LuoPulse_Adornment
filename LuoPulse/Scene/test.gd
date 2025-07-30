## test.gd 用于各种测试的脚本
## 可以在这里写各种测试代码，比如按键检测等等


extends Node


# 按键是否按下
var is_pressed: bool = false

# 按键是否松开
var is_released: bool = false

# 按键是否长按
var is_long_pressed: bool = false


func _input(event: InputEvent) -> void:
	# 只处理键盘事件
	if not event is InputEventKey:
		return
	
	var key_event = event as InputEventKey
	# 按键方式判断(已完成)
	if key_event.is_pressed() and (not is_pressed) and (not is_long_pressed):
		is_pressed = true
		is_released = false
		is_long_pressed = true
		pass
	elif key_event.is_released():
		is_pressed = false
		is_released = true
		is_long_pressed = false
		pass
	else:
		is_pressed = false
		is_released = false
		pass
	
	if is_pressed:
		# 获取按键名称, 并大写
		var key: String = OS.get_keycode_string(key_event.keycode).to_upper()
		if not key in Global.KEY_LIST:
			return
		for column_index in range(Global.KEY_LIST.size()):
			if key == Global.KEY_LIST[column_index]:
				# 按键处理
				print("按下了按键: " + key)
				pass

		# 按键处理
	pass	
