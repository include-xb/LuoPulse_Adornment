extends NoteBase


# Release (红键): 按下对应轨道, 在判定线处松手
#
# 松手的那一刻才判定, 与 tap / drag 共用同一套判定区间与反馈
# (Harmonious / Sympathetic / Aware / Lost, heart 特效期间会整组收紧)。
# 从头到尾不按、或一直按住不放, 都会在离开判定区时按 Lost 结算 ——
# 旧版"不可触摸, 忽略即安全通过"的语义已废弃。


var type: String = "release"

## 已接管时本体向白色混合的比例
const TAKEOVER_BRIGHTEN: float = 0.5

## 接管前的本体颜色 (首次点亮时才读取, 见 _set_takeover_light)
var _idle_color: Color = Color.WHITE

## 是否已经记录过 _idle_color
var _is_color_captured: bool = false

## 当前是否处于"已接管"高亮状态
var _is_lit: bool = false


# ---------- 节点重载函数 ----------
func _physics_process(delta: float) -> void:
	super(delta)
	_refresh_takeover_light()
	pass


# ---------- 判定 ----------
## 由 InputProcesser 在本轨松手时调用 —— 松手的时刻就是这次判定的时刻
## INFO: 直接交给 judge(), 于是判定分级 / EARLY-LATE 反馈 / 轨道闪光 / 打击音 /
##       背景脉冲 / 粒子爆炸全部与 tap 走同一条链路, 这里不重复实现
func on_released(master_time: float) -> void:
	judge(master_time)
	pass


## 自动播放: 到判定线时替玩家松手 (judge() 在 is_autoplay 下会把偏移归零 → 恒定和一)
## INFO: 不碰 InputProcesser 的 is_autoplay_holding —— 那是长条在维护的单个开关,
##       红键去写会在自己被 queue_free 掉时留下一根永久满亮的轨道; 点亮完全由本音符自持
func _autoplay(master_time: float) -> void:
	if not is_removed and not is_judged and master_time >= float(time):
		judge(master_time)
		pass
	pass


# ---------- 接管外观 ----------
## 每帧刷新"已接管"外观: 本轨被按住 且 自己在判定区内 → 本体调亮
func _refresh_takeover_light() -> void:
	var is_lit_now: bool = false

	if not is_removed and not is_judged:
		var offset: float = root_node.master_time - float(time)
		var in_judging_area: bool = offset >= float(Global.start_judge_time) and offset <= float(Global.end_judge_time)
		if in_judging_area:
			is_lit_now = _is_column_held()
			pass
		pass

	_set_takeover_light(is_lit_now)
	pass


## 设置"已接管"外观
## INFO: 材质是场景的 sub_resource, 同场所有红键共享一份 —— 必须复制一份挂到
##       material_override 上, 与 NoteBase._apply_multi_tap_color 同一个理由。
##       取色延到首次点亮才做: 那时 _ready() 早已跑完, 多押提示的调亮已经写进
##       当前生效的材质, 照抄它才不会把多押调亮覆盖掉
func _set_takeover_light(is_lit_now: bool) -> void:
	if is_lit_now == _is_lit:
		return
	_is_lit = is_lit_now

	var src: ShaderMaterial = get_active_material(0)
	if src == null:
		return

	if not _is_color_captured:
		var raw: Variant = src.get_shader_parameter("original_color")
		if raw is Color:
			_idle_color = raw
			pass
		_is_color_captured = true
		pass

	var mat: ShaderMaterial = material_override
	if mat == null:
		mat = src.duplicate()
		material_override = mat
		pass

	mat.set_shader_parameter(
		"original_color",
		_idle_color.lightened(TAKEOVER_BRIGHTEN) if is_lit_now else _idle_color
	)
	pass


## 取本体颜色 —— 接管调亮只算外观, 粒子要跟着接管前的原色走 (否则会偏粉)
func get_note_color() -> Color:
	if _is_color_captured:
		return _idle_color
	return super()
