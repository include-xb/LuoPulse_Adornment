extends Node

# 保存目录 (user://CustomizedPlaylist)
const SAVE_DIR := "user://CustomizedPlaylist"

# 临时文件后缀: 先下到 <文件名>.part, 全部写完后再改名成正式文件
# 避免下载中断/失败时把已经存在的可用文件截断销毁
const TEMP_SUFFIX := ".part"

# 本地校验记录: 记录每个成功下载并通过 SHA256 校验的文件
const LOCAL_MANIFEST_FILE := "resource_manifest.json"
const LOCAL_MANIFEST_VERSION := 1

# 资源服务 (见 API_README.md)
const API_BASE_URL := "https://lpserver.thirhythm.top"
const SONG_PACKAGE_MODULE := "sympathy"

# 本地 API Key 脚本 (已加入 .gitignore, 从 ApiKey.example.gd 复制后填写)
const API_KEY_SCRIPT_PATH := "res://Script/GameManager/ApiKey.gd"
const API_KEY_CONST_NAME := "API_KEY"

# 普通 API 请求超时 (秒)
const API_TIMEOUT := 20.0

# /api/sha256 首次请求会在服务端计算全部文件哈希, 需要更长的超时
const SHA256_TIMEOUT := 180.0

# 下载超时时间（秒）。0 表示不超时，适合大文件下载，防止因网络波动中断
const TIMEOUT := 0.0

# 最大重定向次数，应对网盘的 302 跳转
const MAX_REDIRECTS := 5

# 单个文件下载失败后的最大重试次数
const MAX_RETRY: int = 3

# 两次重试之间的等待时间 (秒)
const RETRY_DELAY: float = 1.0

# 计算 SHA256 时每次读取的字节数 (1 MiB)
const HASH_CHUNK_SIZE: int = 1048576


## 单个文件的下载进度变化 (0.0 ~ 1.0), 仅在已知文件总大小时发出
signal download_progress(ratio: float)

var http_request: HTTPRequest

## 正在接收响应体, 用于在 _process 中上报字节进度
var _is_receiving: bool = false

## 正式文件路径, 下载全部完成后才写入
var full_save_path: String

## 临时文件路径, 下载过程中落盘的位置
var temp_save_path: String

## 本地校验记录: 文件名 -> { "size": int, "sha256": String }
var _local_manifest: Dictionary = { }
var _is_local_manifest_loaded: bool = false


## 拉取远端曲包列表
## @return: { "is_ok": bool, "files": Array[Dictionary] }, 每项为 { name, url, size }
func fetch_remote_files() -> Dictionary:
	var json: Variant = await _fetch_api_json(
		"/api/download?module=%s" % SONG_PACKAGE_MODULE,
		API_TIMEOUT
	)
	if not json is Dictionary:
		return { "is_ok": false, "files": [ ] }

	var raw_files: Variant = (json as Dictionary).get("files", [ ])
	if not raw_files is Array:
		push_error("下载列表缺少 files 字段")
		return { "is_ok": false, "files": [ ] }

	var files: Array[Dictionary] = [ ]
	for item: Variant in (raw_files as Array):
		if not item is Dictionary:
			continue
		var entry: Dictionary = item as Dictionary
		var file_name: String = str(entry.get("name", ""))
		var url: String = str(entry.get("url", ""))
		var size: int = int(entry.get("size", -1))
		if not _is_valid_file_name(file_name) or url.is_empty() or size < 0:
			push_error("下载列表包含无效条目, 已跳过: %s" % file_name)
			continue
		files.append({
			"name": file_name,
			"url": url,
			"size": size,
		})
		pass

	return { "is_ok": true, "files": files }


## 拉取远端曲包 SHA256 列表
## @return: { "is_ok": bool, "sha256": Dictionary } (文件名 -> 哈希)
func fetch_remote_sha256() -> Dictionary:
	var json: Variant = await _fetch_api_json(
		"/api/sha256?module=%s" % SONG_PACKAGE_MODULE,
		SHA256_TIMEOUT
	)
	if not json is Dictionary:
		return { "is_ok": false, "sha256": { } }

	var raw_files: Variant = (json as Dictionary).get("files", [ ])
	if not raw_files is Array:
		push_error("SHA256 列表缺少 files 字段")
		return { "is_ok": false, "sha256": { } }

	var hashes: Dictionary = { }
	for item: Variant in (raw_files as Array):
		if not item is Dictionary:
			continue
		var entry: Dictionary = item as Dictionary
		var file_name: String = str(entry.get("name", ""))
		var sha256: String = str(entry.get("sha256", "")).to_lower()
		if not _is_valid_file_name(file_name) or not _is_valid_sha256(sha256):
			push_error("SHA256 列表包含无效条目, 已跳过: %s" % file_name)
			continue
		hashes[file_name] = sha256
		pass

	return { "is_ok": true, "sha256": hashes }


## 按"本地缺失或大小不一致"筛出本次需要下载的文件
func get_pending_files(remote_files: Array) -> Array[Dictionary]:
	var pending: Array[Dictionary] = [ ]
	for item: Variant in remote_files:
		if not item is Dictionary:
			continue
		var file: Dictionary = item as Dictionary
		var file_name: String = str(file.get("name", ""))
		var remote_size: int = int(file.get("size", -1))
		var local_path: String = SAVE_DIR.path_join(file_name)
		var local_size: int = _get_file_size(local_path)
		if local_size < 0 or local_size != remote_size:
			pending.append(file)
			pass
		pass
	return pending


## 删除远端已下架、但本地仍存在的曲包
## INFO: 远端列表为空时视为异常/未配置, 不做批量删除, 避免服务器配置错误清空玩家数据
## @param remote_files: 远端文件条目列表
## @return: 实际删除的文件名
func delete_orphan_packages(remote_files: Array) -> Array[String]:
	var deleted: Array[String] = [ ]
	if remote_files.is_empty():
		return deleted

	var remote_names: Dictionary = { }
	for item: Variant in remote_files:
		if item is Dictionary:
			remote_names[str((item as Dictionary).get("name", ""))] = true
			pass
		pass

	var local_names: Array[String] = _list_local_package_names()
	if local_names.is_empty():
		return deleted

	_ensure_local_manifest_loaded()
	var is_manifest_changed: bool = false

	for file_name: String in local_names:
		if remote_names.has(file_name):
			continue
		var err: Error = DirAccess.remove_absolute(SAVE_DIR.path_join(file_name))
		if err != OK:
			push_error("删除本地曲包失败: %s, 错误码: %d" % [ file_name, err ])
			continue
		deleted.append(file_name)
		print("已删除远端不存在的曲包: ", file_name)
		if _local_manifest.has(file_name):
			_local_manifest.erase(file_name)
			is_manifest_changed = true
			pass
		pass

	if is_manifest_changed:
		_save_local_manifest()
		pass
	return deleted


## 列出本地曲包目录下的 .lpz 文件名 (不含路径前缀)
func _list_local_package_names() -> Array[String]:
	var names: Array[String] = [ ]
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return names

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "lpz":
			names.append(file_name)
			pass
		file_name = dir.get_next()
		pass
	dir.list_dir_end()
	return names


## 下载并校验单个文件, 失败会自动重试
## @param file: 远端文件条目 { name, url, size }
## @param expected_sha256: 服务端给出的 SHA256
## @return: 是否下载且校验成功
func download_file(file: Dictionary, expected_sha256: String) -> bool:
	_ensure_directory_exists()

	var file_name: String = str(file.get("name", ""))
	var url: String = str(file.get("url", ""))
	var remote_size: int = int(file.get("size", -1))
	var expected: String = expected_sha256.to_lower()

	if not _is_valid_file_name(file_name) or url.is_empty() or not _is_valid_sha256(expected):
		push_error("下载参数无效, 已跳过: %s" % file_name)
		return false

	full_save_path = SAVE_DIR.path_join(file_name)
	temp_save_path = full_save_path + TEMP_SUFFIX
	print("开始下载: ", file_name)

	for attempt: int in MAX_RETRY:
		_discard_temp_file()
		# 让上一轮请求结束后的节点状态完成清理, 再发起下一次请求
		await get_tree().process_frame

		var err: Error = _request_once(url)
		if err != OK:
			push_error("请求发起失败，错误码: %d" % err)
			await get_tree().create_timer(RETRY_DELAY).timeout
			continue

		_is_receiving = true
		# await 多参数信号拿到的是参数数组 [result, response_code, headers, body]
		var args: Array = await http_request.request_completed
		_is_receiving = false
		if await _finish_request(args, expected, remote_size):
			print("下载并校验成功: ", full_save_path)
			_record_verified_file(file_name, expected, remote_size)
			return true

		push_error("第 %d 次下载或校验失败: %s" % [ attempt + 1, file_name ])
		await get_tree().create_timer(RETRY_DELAY).timeout
		pass

	# 用尽重试次数, 清理残缺文件并放弃该文件
	_discard_temp_file()
	push_error("下载失败, 已用尽重试次数: %s" % file_name)
	return false


## 带鉴权请求 API, 返回解析后的 JSON; 任何失败返回 null
func _fetch_api_json(api_path: String, timeout: float) -> Variant:
	var api_key: String = _get_api_key()
	if api_key.is_empty():
		push_error("API Key 未配置, 跳过本次资源检查")
		return null

	# INFO: API 请求使用独立节点, 避免和下载共用节点时的状态干扰
	await get_tree().process_frame
	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = timeout
	request.max_redirects = MAX_REDIRECTS
	request.use_threads = true
	# 必须清空 download_file, 否则响应体会被写进磁盘而不是作为 body 返回
	request.download_file = ""
	add_child(request)

	var headers: PackedStringArray = PackedStringArray([ "X-API-Key: %s" % api_key ])
	print("请求 API: %s" % (API_BASE_URL + api_path))
	var err: Error = request.request(API_BASE_URL + api_path, headers)
	if err != OK:
		push_error("API 请求发起失败, 错误码: %d (%s)" % [ err, api_path ])
		request.queue_free()
		return null

	var args: Array = await request.request_completed
	print("API 响应: %s, result=%d, http=%d" % [ api_path, int(args[0]), int(args[1]) ])
	request.queue_free()
	if not _is_request_ok(args):
		return null

	var body: PackedByteArray = args[3] as PackedByteArray
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null:
		push_error("API 响应不是合法 JSON: %s" % api_path)
		return null
	return parsed


## 从独立脚本读取 API Key; 文件缺失或未填写时返回空串
func _get_api_key() -> String:
	if not ResourceLoader.exists(API_KEY_SCRIPT_PATH):
		push_error("缺少 API Key 文件: %s (请复制 ApiKey.example.gd 并填写)" % API_KEY_SCRIPT_PATH)
		return ""

	var api_key_script: Script = load(API_KEY_SCRIPT_PATH) as Script
	if api_key_script == null:
		push_error("API Key 文件无法加载: %s" % API_KEY_SCRIPT_PATH)
		return ""

	var constants: Dictionary = api_key_script.get_script_constant_map()
	var api_key: String = str(constants.get(API_KEY_CONST_NAME, "")).strip_edges()
	print("API Key 已加载, 长度: %d" % api_key.length())
	return api_key


## 上报当前文件的字节进度, 供外部进度条使用
func _process(_delta: float) -> void:
	if not _is_receiving or http_request == null:
		return

	# 302 跳转/握手阶段还不知道文件总大小, 此时不上报
	var body_size: int = http_request.get_body_size()
	if body_size <= 0:
		return

	var ratio: float = clampf(float(http_request.get_downloaded_bytes()) / float(body_size), 0.0, 1.0)
	download_progress.emit(ratio)
	pass


func _ensure_directory_exists() -> void:
	# 使用 DirAccess 确保 user://data 目录存在
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err := DirAccess.make_dir_absolute(SAVE_DIR)
		if err != OK:
			push_error("无法创建目录: %s，错误码: %d" % [ SAVE_DIR, err ])
		else:
			print("已创建目录: ", SAVE_DIR)
			pass
		pass
	pass


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
	request.timeout = TIMEOUT
	# 关键步骤：设置 download_file，HTTPRequest 会自动将响应体写入磁盘
	request.download_file = temp_save_path
	return request.request(url)


## 校验一次请求的网络层结果与 HTTP 状态码
## @param args: request_completed 信号的参数 [result, response_code, headers, body]
func _is_request_ok(args: Array) -> bool:
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

	return true


## 校验一次下载的结果, 通过则把临时文件改名成正式文件
## @param args: request_completed 信号的参数 [result, response_code, headers, body]
func _finish_request(args: Array, expected_sha256: String, expected_size: int) -> bool:
	if not _is_request_ok(args):
		return false

	# 验证文件是否已成功写入临时文件
	if not FileAccess.file_exists(temp_save_path):
		push_error("临时文件未写入: %s" % temp_save_path)
		return false

	var actual_size: int = _get_file_size(temp_save_path)
	if expected_size >= 0 and actual_size != expected_size:
		push_error("文件大小不一致 (期望 %d, 实际 %d): %s" % [ expected_size, actual_size, temp_save_path ])
		return false

	var actual_sha256: String = await _compute_sha256_async(temp_save_path)
	if actual_sha256.is_empty():
		push_error("无法计算文件 SHA256: %s" % temp_save_path)
		return false

	if actual_sha256 != expected_sha256:
		push_error(
			"SHA256 校验失败: %s\n  期望: %s\n  实际: %s" % [ temp_save_path, expected_sha256, actual_sha256 ]
		)
		return false

	# 下载确实完整且内容一致后, 才用临时文件替换正式文件
	var err: Error = _promote_temp_file()
	if err != OK:
		push_error("临时文件改名失败, 错误码: %d" % err)
		return false

	return true


## 在后台线程计算文件 SHA256, 避免校验大文件时卡住启动界面
func _compute_sha256_async(path: String) -> String:
	var result: Array = [ "" ]
	var thread: Thread = Thread.new()
	var err: Error = thread.start(_sha256_worker.bind(path, result))
	if err != OK:
		push_warning("后台校验线程启动失败, 改为同步计算: %s" % path)
		_sha256_worker(path, result)
		return str(result[0])

	while thread.is_alive():
		await get_tree().process_frame
		pass
	thread.wait_to_finish()
	return str(result[0])


## 分块读取文件并计算 SHA256, 线程与同步兜底共用
func _sha256_worker(path: String, result: Array) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)

	var remaining: int = file.get_length()
	while remaining > 0:
		var chunk: PackedByteArray = file.get_buffer(mini(remaining, HASH_CHUNK_SIZE))
		if chunk.is_empty():
			file.close()
			return
		context.update(chunk)
		remaining -= chunk.size()
		pass
	file.close()

	result[0] = context.finish().hex_encode()
	pass


## 记录一个已通过校验的文件
func _record_verified_file(file_name: String, sha256: String, size: int) -> void:
	_ensure_local_manifest_loaded()
	_local_manifest[file_name] = {
		"size": size,
		"sha256": sha256,
	}
	_save_local_manifest()
	pass


func _ensure_local_manifest_loaded() -> void:
	if _is_local_manifest_loaded:
		return
	_is_local_manifest_loaded = true
	_local_manifest = { }

	var path: String = SAVE_DIR.path_join(LOCAL_MANIFEST_FILE)
	if not FileAccess.file_exists(path):
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开本地资源清单: %s" % path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("本地资源清单格式不对: %s" % path)
		return

	var raw_files: Variant = (parsed as Dictionary).get("files", { })
	if raw_files is Dictionary:
		_local_manifest = raw_files as Dictionary
	pass


func _save_local_manifest() -> void:
	_ensure_directory_exists()
	var path: String = SAVE_DIR.path_join(LOCAL_MANIFEST_FILE)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入本地资源清单: %s" % path)
		return

	var data: Dictionary = {
		"version": LOCAL_MANIFEST_VERSION,
		"files": _local_manifest,
	}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	pass


## 只接受纯文件名, 防止远端条目带路径穿越
func _is_valid_file_name(file_name: String) -> bool:
	if file_name.is_empty():
		return false
	if file_name != file_name.get_file():
		return false
	if file_name == "." or file_name == "..":
		return false
	return true


func _is_valid_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		var is_digit: bool = code >= 48 and code <= 57
		var is_lower_hex: bool = code >= 97 and code <= 102
		if not is_digit and not is_lower_hex:
			return false
		pass
	return true


func _get_file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = file.get_length()
	file.close()
	return size


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
