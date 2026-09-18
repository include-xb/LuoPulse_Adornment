extends Node

# 保存目录 (user://CustomizedPlaylist)
const SAVE_DIR := "user://CustomizedPlaylist"

# 临时文件后缀: 先下到 <文件名>.part, 全部写完后再改名成正式文件
# 避免下载中断/失败时把已经存在的可用文件截断销毁
const TEMP_SUFFIX := ".part"

# 超时时间（秒）。0 表示不超时，适合大文件下载，防止因网络波动中断[reference:3]
const TIMEOUT := 0.0

# 最大重定向次数，应对网盘的 302 跳转[reference:4]
const MAX_REDIRECTS := 5

# 单个文件下载失败后的最大重试次数
const MAX_RETRY: int = 3

# 两次重试之间的等待时间 (秒)
const RETRY_DELAY: float = 1.0

var http_request: HTTPRequest

## 正式文件路径, 下载全部完成后才写入
var full_save_path: String

## 临时文件路径, 下载过程中落盘的位置
var temp_save_path: String


## 下载单个曲包, 失败会自动重试
## @param url: 下载链接, 文件名取自链接末段 (例: ".../EGoCb/2.lpz" → "2.lpz")
## @return: 是否下载成功 (文件已存在时视为成功并跳过)
func download(url: String) -> bool:
	_ensure_directory_exists()

	var file_name: String = url.get_file()
	full_save_path = SAVE_DIR.path_join(file_name)
	temp_save_path = full_save_path + TEMP_SUFFIX

	# 已经下载过 → 跳过。
	# 因为只有完整下完才会改名成正式文件, 所以"存在"即"完整"
	if FileAccess.file_exists(full_save_path):
		print("已存在, 跳过: ", file_name)
		return true

	for attempt: int in MAX_RETRY:
		_discard_temp_file()

		var err := _request_once(url)
		if err != OK:
			push_error("请求发起失败，错误码: %d" % err)
			await get_tree().create_timer(RETRY_DELAY).timeout
			continue

		# await 多参数信号拿到的是参数数组 [result, response_code, headers, body]
		var args: Array = await http_request.request_completed
		if _finish_request(args):
			print("下载成功: ", full_save_path)
			print("绝对路径: ", ProjectSettings.globalize_path(full_save_path))
			return true

		push_error("第 %d 次下载失败: %s" % [ attempt + 1, file_name ])
		await get_tree().create_timer(RETRY_DELAY).timeout
		pass

	# 用尽重试次数, 清理残缺文件并放弃该文件
	_discard_temp_file()
	push_error("下载失败, 已用尽重试次数: %s" % url)
	return false


func _ensure_directory_exists() -> void:
	# 使用 DirAccess 确保 user://data 目录存在
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err := DirAccess.make_dir_absolute(SAVE_DIR)
		if err != OK:
			push_error("无法创建目录: %s，错误码: %d" % [SAVE_DIR, err])
		else:
			print("已创建目录: ", SAVE_DIR)


## 惰性创建并复用 HTTPRequest 节点
func _ensure_http_request() -> HTTPRequest:
	if http_request == null:
		http_request = HTTPRequest.new()
		http_request.timeout = TIMEOUT
		http_request.max_redirects = MAX_REDIRECTS
		# 启用多线程，避免阻塞主线程，特别适合下载大文件
		http_request.use_threads = true
		add_child(http_request)
		pass
	return http_request


## 发起一次请求, 响应体写入临时文件
func _request_once(url: String) -> Error:
	var request: HTTPRequest = _ensure_http_request()
	# 关键步骤：设置 download_file，HTTPRequest 会自动将响应体写入磁盘[reference:6]
	request.download_file = temp_save_path
	return request.request(url)


## 校验一次请求的结果, 通过则把临时文件改名成正式文件
## @param args: request_completed 信号的参数 [result, response_code, headers, body]
func _finish_request(args: Array) -> bool:
	var result: int = args[0]
	var response_code: int = args[1]

	# 检查网络层结果[reference:7]
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("网络错误，结果码: %d" % result)
		return false

	# 检查 HTTP 状态码 (200-299 表示成功)
	if response_code < 200 or response_code >= 300:
		push_error("HTTP 错误，状态码: %d" % response_code)
		return false

	# 验证文件是否已成功写入临时文件
	if not FileAccess.file_exists(temp_save_path):
		push_error("临时文件未写入: %s" % temp_save_path)
		return false

	# 下载确实完整落盘后, 才用临时文件替换正式文件
	var err := _promote_temp_file()
	if err != OK:
		push_error("临时文件改名失败, 错误码: %d" % err)
		return false

	return true


## 把临时文件改名成正式文件 (覆盖旧文件)
func _promote_temp_file() -> Error:
	# Windows 下 rename 到已存在的文件会失败, 先移除旧文件
	if FileAccess.file_exists(full_save_path):
		var remove_err := DirAccess.remove_absolute(full_save_path)
		if remove_err != OK:
			return remove_err
		pass
	return DirAccess.rename_absolute(temp_save_path, full_save_path)


## 下载失败时清理临时文件, 避免残缺文件残留
func _discard_temp_file() -> void:
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
		pass
	pass


# 可选：读取下载后的文件内容示例
# func _load_downloaded_file() -> void:
#     var file = FileAccess.open(full_save_path, FileAccess.READ)
#     if file:
#         var content = file.get_buffer(file.get_length())
#         file.close()
#         print("文件大小: ", content.size(), " 字节")
