## SidebarButton 侧栏条目
##
## 只负责显示: 标题 / 锁定态 / 选中态 (> 标题 <)。
## 点击后打开哪张资料卡、哪块碎片由 Notebook 决定 —— 这里不引用任何业务节点。


class_name SidebarButton extends Button


## 未解锁条目的占位
const LOCKED_PLACEHOLDER: String = "???"


## 条目 ID (资料卡用下标字符串, 故事碎片用碎片序号)
var item_id: String = ""

## 解锁后应显示的原始标题 (不包含选中态的 > <)
var plain_title: String = ""

## 当前是否处于选中态
var is_selected: bool = false

## 是否未解锁 (锁定条目只显示 ???, 也不参与选中)
var is_locked: bool = false


## 初始化条目
## @param id: 条目 ID
## @param title: 解锁后显示的标题
## @param locked: 是否未解锁
func setup(id: String, title: String, locked: bool) -> void:
	item_id = id
	plain_title = title
	is_locked = locked
	disabled = locked
	set_selected(false)
	pass


## 设置选中态: 选中时用 > 标题 < 包起来, 未选中 / 未解锁时恢复普通标题
func set_selected(selected: bool) -> void:
	is_selected = selected
	if is_locked:
		text = LOCKED_PLACEHOLDER
		return
	if is_selected:
		text = "> %s <" % plain_title
		return
	text = plain_title
	pass
