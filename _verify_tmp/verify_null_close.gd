@tool
extends Node


## 临时验证脚本: 复刻 Launch.gd _load_game_config 第 330-335 行的错误分支
func run_open_fail() -> String:
	print("VERIFY: entering run_open_fail")
	var config_path: String = "user://__no_such_dir_verify__/config.json"
	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	print("VERIFY: file == null -> ", file == null)
	if !file:
		file.close()
		push_error("VERIFY: intended push_error after close")
		return "ERROR_BRANCH_DONE"
	print("VERIFY: opened (unexpected)")
	return "OPENED"
