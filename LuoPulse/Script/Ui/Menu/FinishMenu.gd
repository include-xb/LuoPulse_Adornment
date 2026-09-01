## FinishMenu 结算页面
##
## 节点结构定义在 FinishMenu.tscn 中, 本脚本只负责把 Global.gameplay_result 的数据填入对应节点

extends Control


@onready var grade_label: Label = $ResultsBox/GradeLabel
@onready var acc_label: Label = $ResultsBox/HBoxContainer/DataGrid/AccCount
@onready var harmonious_count: Label = $ResultsBox/HBoxContainer/JudgingGrid/HarmoniousCount
@onready var sympathetic_count: Label = $ResultsBox/HBoxContainer/JudgingGrid/SympatheticCount
@onready var aware_count: Label = $ResultsBox/HBoxContainer/JudgingGrid/AwareCount
@onready var lost_count: Label = $ResultsBox/HBoxContainer/JudgingGrid/LostCount
@onready var combo_label: Label = $ResultsBox/HBoxContainer/DataGrid/ComboCount
@onready var notes_label: Label = $ResultsBox/HBoxContainer/DataGrid/NotesCount
@onready var crystal_label: Label = $ResultsBox/Crystal/CrystalCount


func _ready() -> void:
	_show_results()
	pass


## 将 Global.gameplay_result 的数据填入结算界面, 并发放水晶奖励
func _show_results() -> void:
	var result: Dictionary = Global.gameplay_result

	# 评级 (颜色随评级动态变化)
	grade_label.text = result.get("grade", "-")
	grade_label.add_theme_color_override("font_color", result.get("grade_color", Color.GRAY))

	# 准度
	acc_label.text = "%.2f%%" % (result.get("accuracy", 0.0) * 100.0)

	# 各判定等级计数
	harmonious_count.text = str(result.get("harmonious", 0))
	sympathetic_count.text = str(result.get("sympathetic", 0))
	aware_count.text = str(result.get("aware", 0))
	lost_count.text = str(result.get("lost", 0))

	# 最大连击与总音符
	combo_label.text = str(result.get("max_combo", 0))
	notes_label.text = str(result.get("total_notes", 0))

	# 水晶奖励
	var crystal_earned: int = result.get("crystal_earned", 0)
	crystal_label.text = "+" + str(crystal_earned)
	Global.crystal += crystal_earned
	Global.save_user_data()
	pass


func _on_continue_pressed() -> void:
	Global.play_ui_click_audio()

	var scene_manager: Node = get_parent()
	if scene_manager and scene_manager.has_method("back_to_previous_scene"):
		scene_manager.back_to_previous_scene()
		pass
	pass
