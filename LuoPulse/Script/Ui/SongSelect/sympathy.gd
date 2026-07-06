## Sympathy 共鸣主线
##
## 可以切换到这里的场景:
## 		- MainMenu 游戏主页面
## 		- Gameplay 游戏界面
## 		- SettingMenu 设置页面
## 		- CardMenu 资料卡界面
## 从这里可以前往: 
## 		- Gameplay 游戏界面
## 		- MainMenu 游戏主页面
## 		- SettingMenu 设置页面
## 		- CardMenu 资料卡界面


extends Control


@onready var background: TextureRect = $Background
@onready var cover: TextureRect = $Cover




func _ready() -> void:
	Global.game_mode = Global.GameMode.Sympathy
	background.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())
	cover.material.set_shader_parameter("gray_scale", Global.get_current_gray_scale())

# ============================================================
# LPZ 文件读取
# ============================================================

## 从 .lpz 文件中读取封面图片，返回 ImageTexture
func _read_cover_from_lpz(lpz_path: String) -> ImageTexture:
	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		push_error("无法打开 .lpz 文件: %s" % lpz_path)
		return null

	var cover_path := ""
	for f in zip.get_files():
		if f.get_file() == "cover.png":
			cover_path = f
			break

	if cover_path == "":
		zip.close()
		push_error("在 .lpz 中找不到 cover.png: %s" % lpz_path)
		return null

	var img_bytes := zip.read_file(cover_path)
	zip.close()

	var img := Image.new()
	var load_err := img.load_png_from_buffer(img_bytes)
	if load_err != OK:
		push_error("无法解码封面图片: %s" % cover_path)
		return null

	return ImageTexture.create_from_image(img)


## 从 .lpz 文件中读取 chart.lp，返回 General 部分的字典
func _read_chart_from_lpz(lpz_path: String) -> Dictionary:
	var zip := ZIPReader.new()
	var err := zip.open(lpz_path)
	if err != OK:
		return {}

	var chart_path := ""
	for f in zip.get_files():
		if f.get_file() == "chart.lp":
			chart_path = f
			break

	if chart_path == "":
		zip.close()
		return {}

	var json_bytes := zip.read_file(chart_path)
	zip.close()

	var json_str := json_bytes.get_string_from_utf8()

	var json := JSON.new()
	var parse_err := json.parse(json_str)
	if parse_err != OK:
		push_error("无法解析 chart.lp: %s" % lpz_path)
		return {}

	var data = json.get_data()
	if data is Dictionary and data.has("General"):
		return data["General"]

	return {}


func _on_button_pressed() -> void:
	SceneManager.change_scene("res://Scene/Ui/Menu/MainMenu.tscn")
	pass # Replace with function body.
