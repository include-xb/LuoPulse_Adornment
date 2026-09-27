## AboutMenu 关于页面


extends Control


func _on_back_pressed() -> void:
	$"..".back_to_previous_scene()


func _on_thanks_pressed() -> void:
	$"..".start_scene_by_path("res://Scene/Ui/Menu/ThanksMenu.tscn")
