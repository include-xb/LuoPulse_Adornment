## InputProcesser.gd 输入处理器
## 每个 Column 节点挂载一个实例, 处理该轨道的触屏/按键输入判定
##
## 两条判定时机: 按下 (press_judge: tap / hold 头判) 与 松手
## (_release_judge: release 的判定时刻 —— 见 Script/Core/NoteTemplate/Release.gd)。
## 黄键两者都不走: 它由音符自己在进入判定区时查一次本轨是否被按住 (见 Drag.gd)


extends Node3D


## 当前轨道数 (1 ~ 4)
@export var column: int = 0

## 轨道节点
@export var single_track: MeshInstance3D # = $SingleTrack

## 粒子效果
@export var gpu_particles_3d: GPUParticles3D # = $GPUParticles3D


## 轨道材质副本 (每列独立, 用于触屏高亮)
var _track_material: ShaderMaterial = null

## 判定线材质副本 (每列独立, 命中时闪光)
var _judging_material: ShaderMaterial = null

## 判定线节点 (与轨道复用同一个 shader, 自己的材质从未被驱动过)
@onready var _judging_strip: MeshInstance3D = $Judging

## 粒子材质副本 (每列独立, 按判定等级染色)
var _particle_material: StandardMaterial3D = null

## 轨道高亮强度 (shader uniform)
var _highlight: float = 0.0

## 最大高亮强度
var max_highlight: float = 0.6

## 轨道高亮衰减速度
const HIGHLIGHT_FADE: float = 8.0

## 判定线高亮强度 (命中时被 flash_track 点亮)
var _judging_highlight: float = 0.0

## 判定线高亮衰减速度 (比轨道更快, 强调"一击即散")
const JUDGING_HIGHLIGHT_FADE: float = 10.0

## 当前触摸计数 (支持多点触控)
var _touch_count: int = 0

## 自动播放 hold 是否处于按住状态 (用于持续高亮)
var is_autoplay_holding: bool = false

## 是否正在长按 (hold)
var is_holding: bool = false

## 当前正在持有的 hold 音符
var current_hold_note: MeshInstance3D = null

## 当前帧触摸时间 (由 Gameplay 传入)
var _touch_time: float = -999999.0

## 不参与"按下时刻"判定的音符类型
## INFO: 红键等松手时结算 (见 _release_judge); 黄键由"进入判定区时本轨是否被按住"决定。
##       它们若留在候选里, 会占住本列唯一的"最近"名额, 把稍远的 tap / hold 挡掉
const PRESS_EXEMPT_TYPES: Array[String] = [ "release", "drag" ]


# ---------- 节点重载函数 ----------
func _ready() -> void:
	var src: ShaderMaterial = single_track.get_active_material(0)
	_track_material = src.duplicate()
	single_track.material_override = _track_material

	# 判定线与轨道复用同一个 shader, 同样需要独立副本, 否则 4 条轨道会互相污染
	var judging_src: ShaderMaterial = _judging_strip.get_active_material(0)
	_judging_material = judging_src.duplicate()
	_judging_strip.material_override = _judging_material

	# 粒子网格与材质也可能是 4 列共享的, 两份都要复制。
	# 只在这里复制一次, 之后命中时只改颜色/数量, 避免每次命中都分配资源。
	var particle_mesh: Mesh = gpu_particles_3d.draw_pass_1.duplicate() as Mesh
	gpu_particles_3d.draw_pass_1 = particle_mesh
	_particle_material = particle_mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	particle_mesh.surface_set_material(0, _particle_material)

	# 粒子的最终颜色 = 材质色 × 贴图色, 而原贴图自带蓝色渐变,
	# 会把音符颜色染歪 (黄键会偏绿)。这里把贴图的 RGB 中和成白色、
	# 只保留它的透明度衰减, 让材质色单独决定色相。
	_neutralize_particle_texture()

	# 按列错开透明排序层级, 理由见 Global.SORT_LAYER_STEP
	single_track.sorting_offset = float(column) * Global.SORT_LAYER_STEP
	_judging_strip.sorting_offset = float(column) * Global.SORT_LAYER_STEP
	pass


## 把粒子贴图的 RGB 中和成白色, 只保留原有的透明度衰减
## 这样粒子的色相完全由 _particle_material.albedo_color 决定
func _neutralize_particle_texture() -> void:
	if _particle_material == null:
		return
	var src: GradientTexture2D = _particle_material.albedo_texture as GradientTexture2D
	if src == null or src.gradient == null:
		return

	var gradient: Gradient = src.gradient.duplicate()
	var colors: PackedColorArray = gradient.colors
	for i: int in colors.size():
		colors[i] = Color(1.0, 1.0, 1.0, colors[i].a)
		pass
	gradient.colors = colors

	# 复制整张贴图 (连同 fill / 尺寸等设置一起), 只换掉渐变
	var neutral: GradientTexture2D = src.duplicate() as GradientTexture2D
	neutral.gradient = gradient
	_particle_material.albedo_texture = neutral
	pass


func _process(delta: float) -> void:
	# 轨道高亮: 按住期间保持满亮, 松开后指数衰减
	if _touch_count > 0 or is_autoplay_holding:
		_highlight = max_highlight
		_track_material.set_shader_parameter("highlight", _highlight)
		pass
	elif _highlight > 0.0:
		_highlight = _decay_value(_highlight, HIGHLIGHT_FADE, delta)
		_track_material.set_shader_parameter("highlight", _highlight)
		pass

	# 判定线高亮: 命中时被点亮, 独立且更快地衰减
	if _judging_highlight > 0.0:
		_judging_highlight = _decay_value(_judging_highlight, JUDGING_HIGHLIGHT_FADE, delta)
		_judging_material.set_shader_parameter("highlight", _judging_highlight)
		pass

	if is_holding and not is_instance_valid(current_hold_note):
		is_holding = false
		current_hold_note = null
		pass
	pass


# ---------- 工具函数 ----------
## 获取当前列的所有在判定区间的音符
func _get_column_notes() -> Array:
	var result: Array = []
	for note in Global.judging_area:
		if not is_instance_valid(note):
			continue
		var note_column: int = note.get("column")
		if note_column == column:
			result.append(note)
			pass
		pass
	return result


## 本轨道当前是否被玩家按住
## 供 release 音符判断"是否已接管" —— 判据与 _process 里的轨道高亮保持一致
func is_pressed() -> bool:
	return _touch_count > 0


# ---------- 触屏输入 ----------
## 被按下
func on_touch_pressed(master_time: float) -> void:
	_touch_time = master_time
	_touch_count += 1

	_highlight = max_highlight
	_track_material.set_shader_parameter("highlight", _highlight)

	if _touch_count > 1:
		return

	press_judge(master_time)
	pass


## 被释放
## @param is_synthetic: 暂停等内部路径合成的"松手" —— 只收拾长按状态, 不结算红键
## INFO: 能走到这里说明本轨的触摸计数刚好归零, 也就是"松手的那一刻本轨确实按着" ——
##       红键结算需要的条件天然成立, 不需要额外判断玩家是否接管过它
func on_touch_released(master_time: float, is_synthetic: bool = false) -> void:
	_touch_time = master_time
	_touch_count = maxi(0, _touch_count - 1)

	if _touch_count > 0:
		return

	if is_holding:
		if is_instance_valid(current_hold_note) and current_hold_note.has_method("on_released"):
			current_hold_note.on_released(master_time)
			pass
		is_holding = false
		current_hold_note = null
		pass

	# 暂停合成的松手只用来收拾长按状态: 玩家手指其实还按着, 不能拿它结算红键
	if not is_synthetic:
		_release_judge(master_time)
		pass
	pass


# ---------- 判定 ----------
## 被按下后对音符进行判定
func press_judge(master_time: float) -> void:
	if is_holding:
		if not is_instance_valid(current_hold_note):
			is_holding = false
			current_hold_note = null
			pass
		else:
			return
		pass

	# 获取当前轨道判定区间内的所有有效音符
	var column_notes: Array = _get_column_notes()

	if column_notes.is_empty():
		return

	# 找到距判定线最近的音符 (时间偏移绝对值最小)
	var best_note = null
	var best_offset: float = INF

	for note in column_notes:
		if not is_instance_valid(note):
			continue
		if note.has_method("is_judgable") and not note.is_judgable():
			continue
		# INFO: 红键与黄键都不参与"按下时刻"判定 (见 PRESS_EXEMPT_TYPES 的说明)
		if PRESS_EXEMPT_TYPES.has(str(note.get("type"))):
			continue
		var offset: float = abs(master_time - float(note.get("time")))
		# INFO: 候选只看得出如今还在当前判定窗口内 —— 窗口被 heart 特效收紧时,
		#       窗口外的音符早已被音符自己从 judging_area 摘掉了
		if offset < best_offset and offset <= float(Global.lost_time):
			best_offset = offset
			best_note = note
			pass
		pass

	if best_note == null:
		return

	var note_type: String = best_note.get("type")

	match note_type:
		"tap", "heart":
			if best_note.has_method("judge"):
				best_note.judge(master_time)
				pass
			pass
		"drag":
			# 不会走到这里: 黄键在候选扫描时就被排除了 (它看的是进入判定区时的轨道状态)
			pass
		"release":
			# 不会走到这里: 红键在候选扫描时就被排除了 (见上面的 continue)
			pass
		"hold":
			if best_note.has_method("is_head_judgable") and best_note.is_head_judgable():
				best_note.judge_head(master_time)
				is_holding = true
				current_hold_note = best_note
				pass
			elif best_note.has_method("is_head_judgable") and not best_note.is_head_judgable():
				# 头部已判定, 开始 hold
				is_holding = true
				current_hold_note = best_note
				if best_note.has_method("on_hold_start"):
					best_note.on_hold_start(master_time)
					pass
				pass
			pass
		pass
	pass


## 松手判定: 结算本列判定区内最近的 release 音符
## INFO: 松手的时刻就是这次判定的时刻, 具体分级交给音符自己的 judge() (与 tap 同一套)
## INFO: 只认 release 类型 —— 长条的尾判走 on_touch_released 里 current_hold_note 那条路,
##       这里若不限类型, 会把同列长条的尾判一起结算掉
func _release_judge(master_time: float) -> void:
	var column_notes: Array = _get_column_notes()
	if column_notes.is_empty():
		return

	var best_note: Variant = null
	var best_offset: float = INF

	for note in column_notes:
		if not is_instance_valid(note):
			continue
		if str(note.get("type")) != "release":
			continue
		if note.has_method("is_judgable") and not note.is_judgable():
			continue
		var offset: float = abs(master_time - float(note.get("time")))
		if offset < best_offset and offset <= float(Global.lost_time):
			best_offset = offset
			best_note = note
			pass
		pass

	if best_note == null:
		return
	if best_note.has_method("on_released"):
		best_note.on_released(master_time)
		pass
	pass


# ---------- 轨道 / 判定线反馈 ----------
## 命中的视觉反馈: 点亮轨道与判定线 (仅触发高亮, 不参与判定)
## @param strength: 高亮强度 (0.0 ~ 1.0), 由判定等级决定
func flash_track(strength: float = 1.0) -> void:
	var value: float = clampf(strength, 0.0, 1.0)

	_highlight = maxf(_highlight, value)
	_track_material.set_shader_parameter("highlight", _highlight)

	# 判定线是玩家视线的焦点, 这一处闪光最容易被感知
	_judging_highlight = maxf(_judging_highlight, value)
	_judging_material.set_shader_parameter("highlight", _judging_highlight)
	pass


## 设置本列粒子的爆发样式 (染色 + 数量)
## 材质已在 _ready 中复制过, 这里只改参数, 不会每次命中都分配资源
## @param color: 粒子颜色 (由判定等级决定)
## @param amount: 粒子数量
func set_particle_style(color: Color, amount: int) -> void:
	if _particle_material:
		_particle_material.albedo_color = color
		pass
	gpu_particles_3d.amount = amount
	pass


## 清空本轨道的进行中状态 (触摸计数 / 长按 / 高亮)
## 用于"此后不再接受轨道输入"的场合 (例如结束时提示弹出):
## 此时松手事件不会再传进来, 必须主动把状态清掉, 否则被按住的轨道会一直亮着
## 注意: 不会替长音符补一次松手判定 —— 歌曲已结束, 让它自己按原有逻辑收尾更安全
func reset_input_state() -> void:
	_touch_count = 0
	is_holding = false
	current_hold_note = null

	_highlight = 0.0
	_track_material.set_shader_parameter("highlight", _highlight)

	_judging_highlight = 0.0
	_judging_material.set_shader_parameter("highlight", _judging_highlight)
	pass


## 指数衰减到 0 (快起快落, 比线性衰减更"脆"), 低于阈值直接归零避免残留
func _decay_value(value: float, fade_speed: float, delta: float) -> float:
	var next: float = maxf(0.0, value - fade_speed * delta * value)
	if next < 0.01:
		return 0.0
	return next


# ---------- 自动播放 ----------


## 自动播放 hold: 设置按住状态 (按住期间持续高亮, 松开后恢复衰减)
func set_autoplay_hold(is_active: bool) -> void:
	is_autoplay_holding = is_active
	if is_active:
		# _highlight = 0.8
		pass
	_track_material.set_shader_parameter("highlight", _highlight)
	pass
