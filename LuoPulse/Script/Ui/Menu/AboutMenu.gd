## AboutMenu 关于页面


extends Control


func _on_back_pressed() -> void:
	SceneManager.change_scene("res://Scene/Ui/Menu/MainMenu.tscn")


func _on_thanks_pressed() -> void:
	SceneManager.change_scene("res://Scene/Ui/Menu/ThanksMenu.tscn")
