## MultiTapLine 多压连线
##
## 把"同一毫秒到达判定线"的那几个音符用一条白色横线连起来。
##
## INFO: 挂在 Track 下, **不是**任何一根 Column 的子节点 —— 换位效果直接改
##       Column.position.x, 挂到某一列下就只会跟着那一根跑, 换位后线就歪了
## INFO: 线画在音符"下层": 音符本体保持干净, 线只在两音符之间的缝隙里露出来
##       (音符宽 0.8、列间距 1.0, 所以每个缝约 0.2 宽), 天然是把相邻音符缝在一起
## INFO: 位置每帧从音符的实际 position 读 —— 音符自己受 is_gaming 门控, 所以暂停
##       与继续倒计时期间线会跟着一起冻住, 不需要自己再接一份 master_time


extends MeshInstance3D


class_name MultiTapLine


## 线的深度 (世界单位); 宽度由 scale.x 拉伸, 网格本身是单位宽
## INFO: 线被音符盖住后只在两音符之间的缝里露出来, 露出的高度就是这个深度 ——
##       取得太小会看不清, 太大就不像"线"了 (音符本身的深度是 0.3)
const LINE_DEPTH: float = 0.05

## 线的颜色 (白色, 留一点透明度免得像一块实心板)
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)

## 线的 y: 低于音符的 0.03、等于长条的 0.02, 且仍高于轨道面 (0)
const LINE_Y: float = 0.015

## 排序层级
## INFO: 平躺的半透明 quad 不写深度, 前后只看"相机距离 − sorting_offset", 且 key 越小越靠前
## INFO: 必须给一个**明显为负**的值, 而不是 0 —— 排序取的是物体原点, 而本节点的原点落在
##       两列的正中 (比两端音符都更靠近屏幕中心 = 相机更近), 只靠 0 的话它会反过来压住
##       内侧那颗音符。负 0.5 足以盖过这个差 (近处最坏情况约 0.32), 又远小于它与轨道面
##       原点 (z = -10, 距离约 11) 的差距, 不会掉到轨道面后面去
## 见 Global.SORT_LAYER_STEP
const LINE_SORTING_OFFSET: float = -0.5

## 两端最近时的最小跨度 (同列重复音符这类畸形谱面的兜底, 避免 scale.x = 0)
const MIN_SPAN: float = 0.01


## 本组同时按下的音符
var _notes: Array = [ ]


# ---------- 节点重载函数 ----------
func _ready() -> void:
	sorting_offset = LINE_SORTING_OFFSET
	position.y = LINE_Y

	# 网格与材质都在代码里建: 组数只有运行时才知道, 场景侧没有任何可配置的内容
	# x 方向留 1, 由 scale.x 拉伸到实际跨度
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2(1.0, LINE_DEPTH)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = LINE_COLOR

	mesh.material = material
	self.mesh = mesh
	pass


func _process(_delta: float) -> void:
	var valid: Array = [ ]
	for note in _notes:
		if is_instance_valid(note):
			valid.append(note)
			pass
		pass

	# 少于两个就没什么可连的了 (同压的音符会各自被判定 / 漏键而陆续消失)
	if valid.size() < 2:
		queue_free()
		return

	var min_x: float = INF
	var max_x: float = -INF
	for note in valid:
		var note_x: float = note.global_position.x
		min_x = minf(min_x, note_x)
		max_x = maxf(max_x, note_x)
		pass

	# Track 是单位变换, 所以这里的 position 就是世界坐标
	position.x = (min_x + max_x) * 0.5
	position.z = _note_head_z(valid[0])
	scale.x = maxf(max_x - min_x, MIN_SPAN)
	pass


# ---------- 接口 ----------
## 绑定这一组同时按下的音符 (由 Gameplay 在批量加载时调用)
func setup(notes: Array) -> void:
	_notes = notes
	pass


# ---------- 工具函数 ----------
## 取音符"到达判定线那一端"的 z
## INFO: 交给音符自己回答 (NoteBase.get_head_z / Hold.get_head_z) —— 长条的 position
##       是长条中心, 到达判定线的是它的下边缘, 只有它自己知道该怎么换算
func _note_head_z(note: MeshInstance3D) -> float:
	if note.has_method("get_head_z"):
		return note.get_head_z()
	return note.position.z
