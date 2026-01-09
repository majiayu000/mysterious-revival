## EventBus - 全局事件总线
## 用于解耦各个系统之间的通信
extends Node

# ==================== 游戏流程事件 ====================
signal game_started
signal game_paused
signal game_resumed
signal game_over(is_victory: bool)
signal domain_entered(domain_type: String)
signal domain_exited

# ==================== 玩家事件 ====================
signal player_hp_changed(current_hp: int, max_hp: int)
signal player_san_changed(current_san: int, max_san: int)
signal player_died
signal player_moved(position: Vector2)

# ==================== 鬼相关事件 ====================
signal ghost_spawned(ghost: Node)
signal ghost_defeated(ghost: Node)
signal ghost_captured(ghost: Node)
signal ghost_escaped(ghost: Node)
signal ghost_rule_discovered(ghost_id: String, rule_id: String)
signal ghost_loyalty_changed(ghost: Node, loyalty: float)
signal ghost_rebelled(ghost: Node)  # 鬼反叛

# ==================== 战斗事件 ====================
signal battle_started(player_ghosts: Array, enemy_ghosts: Array)
signal battle_ended(is_victory: bool)
signal battle_turn_started(is_player_turn: bool)
signal battle_turn_ended
signal battle_action_performed(actor: Node, action: String, target: Node)
signal damage_dealt(attacker: Node, target: Node, damage: int)

# ==================== 道具事件 ====================
signal item_picked_up(item_data: Resource)
signal item_used(item_data: Resource, target: Node)
signal item_dropped(item_data: Resource)
signal inventory_changed

# ==================== UI事件 ====================
signal ui_inventory_toggle_requested
signal ui_ghost_info_requested(ghost: Node)
signal ui_dialog_requested(text: String, options: Array)
signal ui_notification_requested(message: String, type: String)

# ==================== 调试事件 ====================
signal debug_message(message: String)


func _ready() -> void:
	print("[EventBus] 事件总线已初始化")


## 发送通知消息的便捷方法
func notify(message: String, type: String = "info") -> void:
	ui_notification_requested.emit(message, type)


## 发送调试消息
func debug(message: String) -> void:
	if OS.is_debug_build():
		debug_message.emit(message)
		print("[DEBUG] ", message)
