## UnderlineButton 带下划线的按钮组件
##
## 可复用的菜单按钮，包含一个文字按钮和底部下划线分隔线


extends VBoxContainer


signal pressed


@onready var button: Button = $Button
@onready var separator: HSeparator = $Separator


func _ready() -> void:
	button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	pressed.emit()


func set_text(new_text: String) -> void:
	button.text = new_text


func get_text() -> String:
	return button.text


func set_button_enabled(enabled: bool) -> void:
	button.disabled = !enabled


func set_separator_visible(p_visible: bool) -> void:
	separator.visible = p_visible
