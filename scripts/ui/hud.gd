## HUD - 游戏内界面
## 显示玩家状态、道具快捷栏、驭鬼状态等
extends CanvasLayer

# ==================== 节点引用 ====================
@onready var hp_bar: ProgressBar = $MarginContainer/TopLeft/HPBar/ProgressBar
@onready var hp_value: Label = $MarginContainer/TopLeft/HPBar/Value
@onready var san_bar: ProgressBar = $MarginContainer/TopLeft/SANBar/ProgressBar
@onready var san_value: Label = $MarginContainer/TopLeft/SANBar/Value
@onready var ghost_slot1: Panel = $MarginContainer/TopLeft/GhostSlots/Slot1
@onready var ghost_slot2: Panel = $MarginContainer/TopLeft/GhostSlots/Slot2
@onready var notification_label: Label = $MarginContainer/BottomCenter/NotificationLabel
@onready var interact_hint: Label = $MarginContainer/BottomCenter/InteractHint

# ==================== 通知队列 ====================
var notification_queue: Array[Dictionary] = []
var is_showing_notification: bool = false


func _ready() -> void:
	_connect_signals()
	_initialize_ui()


func _connect_signals() -> void:
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.player_san_changed.connect(_on_san_changed)
	EventBus.ui_notification_requested.connect(_on_notification_requested)
	EventBus.ghost_captured.connect(_on_ghost_captured)
	EventBus.ghost_loyalty_changed.connect(_on_ghost_loyalty_changed)
	# Refresh slots when a run starts or ends (controlled ghosts cleared).
	EventBus.domain_entered.connect(_on_domain_entered)
	EventBus.domain_exited.connect(_on_domain_exited)
	EventBus.game_over.connect(_on_game_over)
	EventBus.ghost_escaped.connect(_on_ghost_escaped)


func _initialize_ui() -> void:
	# 初始化显示
	_on_hp_changed(GameManager.player_data.current_hp, GameManager.player_data.max_hp)
	_on_san_changed(GameManager.player_data.current_san, GameManager.player_data.max_san)
	_update_ghost_slots()

	notification_label.text = ""
	interact_hint.text = ""


# ==================== HP/SAN 更新 ====================
func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_value.text = "%d/%d" % [current, maximum]

	# HP低时变色
	if float(current) / float(maximum) < 0.3:
		hp_bar.modulate = Color(1, 0.3, 0.3)
	else:
		hp_bar.modulate = Color.WHITE


func _on_san_changed(current: int, maximum: int) -> void:
	san_bar.max_value = maximum
	san_bar.value = current
	san_value.text = "%d/%d" % [current, maximum]

	# SAN低时变色
	if float(current) / float(maximum) < 0.3:
		san_bar.modulate = Color(0.5, 0.3, 1)
	else:
		san_bar.modulate = Color.WHITE


# ==================== 驭鬼槽更新 ====================
func _update_ghost_slots() -> void:
	var controlled = GameManager.player_data.controlled_ghosts

	# 更新槽位1
	if controlled.size() > 0:
		var ghost_id = controlled[0]
		var ghost_data = GhostRegistry.get_ghost(ghost_id)
		if ghost_data:
			ghost_slot1.modulate = ghost_data.get_type_color()
			ghost_slot1.tooltip_text = ghost_data.display_name
	else:
		ghost_slot1.modulate = Color(0.3, 0.3, 0.3)
		ghost_slot1.tooltip_text = "空槽位"

	# 更新槽位2
	if controlled.size() > 1:
		var ghost_id = controlled[1]
		var ghost_data = GhostRegistry.get_ghost(ghost_id)
		if ghost_data:
			ghost_slot2.modulate = ghost_data.get_type_color()
			ghost_slot2.tooltip_text = ghost_data.display_name
	else:
		ghost_slot2.modulate = Color(0.3, 0.3, 0.3)
		ghost_slot2.tooltip_text = "空槽位"


func _on_ghost_captured(_ghost: Node) -> void:
	_update_ghost_slots()


func _on_ghost_escaped(_ghost: Node) -> void:
	_update_ghost_slots()


func _on_domain_entered(_domain_type: String) -> void:
	_update_ghost_slots()


func _on_domain_exited() -> void:
	_update_ghost_slots()


func _on_game_over(_is_victory: bool) -> void:
	_update_ghost_slots()


func _on_ghost_loyalty_changed(ghost: Node, loyalty: float) -> void:
	# 忠诚度过低时警告
	if loyalty < 20:
		_on_notification_requested("%s 的忠诚度很低！" % ghost.ghost_data.display_name, "warning")


# ==================== 通知系统 ====================
func _on_notification_requested(message: String, type: String) -> void:
	notification_queue.append({
		"message": message,
		"type": type
	})

	if not is_showing_notification:
		_show_next_notification()


func _show_next_notification() -> void:
	if notification_queue.is_empty():
		is_showing_notification = false
		return

	is_showing_notification = true
	var notification = notification_queue.pop_front()

	# 设置颜色
	match notification.type:
		"success":
			notification_label.modulate = Color(0.3, 1, 0.3)
		"warning":
			notification_label.modulate = Color(1, 0.8, 0.2)
		"danger":
			notification_label.modulate = Color(1, 0.3, 0.3)
		"error":
			notification_label.modulate = Color(1, 0, 0)
		_:
			notification_label.modulate = Color(1, 1, 0.9)

	notification_label.text = notification.message

	# 淡入
	notification_label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(notification_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(notification_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_show_next_notification)


# ==================== 交互提示 ====================
func show_interact_hint(text: String) -> void:
	interact_hint.text = text


func hide_interact_hint() -> void:
	interact_hint.text = ""


# ==================== 道具快捷栏 ====================
func update_item_slot(slot_index: int, item_data: ItemData) -> void:
	var slot_name = "Item%d" % (slot_index + 1)
	var slot = $MarginContainer/TopRight/ItemSlots.get_node_or_null(slot_name)

	if slot == null:
		return

	if item_data == null:
		slot.modulate = Color(0.3, 0.3, 0.3)
		slot.tooltip_text = "空"
	else:
		slot.modulate = item_data.get_rarity_color()
		slot.tooltip_text = item_data.display_name
