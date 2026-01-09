## GameManager - 游戏状态管理
## 管理游戏的整体状态、流程控制
extends Node

# ==================== 游戏状态枚举 ====================
enum GameState {
	MAIN_MENU,      # 主菜单
	IN_DOMAIN,      # 在鬼域中探索
	IN_BATTLE,      # 战斗中
	PAUSED,         # 暂停
	GAME_OVER,      # 游戏结束
	VICTORY         # 胜利
}

# ==================== 当前状态 ====================
var current_state: GameState = GameState.MAIN_MENU
var previous_state: GameState = GameState.MAIN_MENU

# ==================== 玩家数据 ====================
var player_data: Dictionary = {
	"max_hp": 100,
	"current_hp": 100,
	"max_san": 100,
	"current_san": 100,
	"max_ghost_slots": 2,  # 最大驭鬼槽位
	"controlled_ghosts": [],  # 当前控制的鬼
	"inventory": [],  # 背包
	"discovered_rules": {}  # 已发现的规律 {ghost_id: [rule_ids]}
}

# ==================== 当前鬼域数据 ====================
var current_domain: Dictionary = {
	"type": "",
	"difficulty": 1,
	"floor": 1,
	"enemies_defeated": 0,
	"items_collected": 0
}

# ==================== 游戏统计 ====================
var statistics: Dictionary = {
	"total_runs": 0,
	"victories": 0,
	"ghosts_captured": 0,
	"ghosts_defeated": 0,
	"rules_discovered": 0
}


func _ready() -> void:
	print("[GameManager] 游戏管理器已初始化")
	_connect_signals()


func _connect_signals() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.ghost_captured.connect(_on_ghost_captured)
	EventBus.ghost_rule_discovered.connect(_on_rule_discovered)


# ==================== 状态切换 ====================
func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return

	previous_state = current_state
	current_state = new_state

	match new_state:
		GameState.MAIN_MENU:
			_enter_main_menu()
		GameState.IN_DOMAIN:
			_enter_domain()
		GameState.IN_BATTLE:
			_enter_battle()
		GameState.PAUSED:
			_enter_paused()
		GameState.GAME_OVER:
			_enter_game_over()
		GameState.VICTORY:
			_enter_victory()

	EventBus.debug("状态切换: %s -> %s" % [GameState.keys()[previous_state], GameState.keys()[new_state]])


func _enter_main_menu() -> void:
	get_tree().paused = false


func _enter_domain() -> void:
	get_tree().paused = false
	EventBus.domain_entered.emit(current_domain.type)


func _enter_battle() -> void:
	get_tree().paused = false
	EventBus.battle_started.emit(player_data.controlled_ghosts, [])


func _enter_paused() -> void:
	get_tree().paused = true
	EventBus.game_paused.emit()


func _enter_game_over() -> void:
	statistics.total_runs += 1
	EventBus.game_over.emit(false)


func _enter_victory() -> void:
	statistics.total_runs += 1
	statistics.victories += 1
	EventBus.game_over.emit(true)


# ==================== 玩家数据操作 ====================
func modify_hp(amount: int) -> void:
	player_data.current_hp = clamp(player_data.current_hp + amount, 0, player_data.max_hp)
	EventBus.player_hp_changed.emit(player_data.current_hp, player_data.max_hp)

	if player_data.current_hp <= 0:
		EventBus.player_died.emit()


func modify_san(amount: int) -> void:
	player_data.current_san = clamp(player_data.current_san + amount, 0, player_data.max_san)
	EventBus.player_san_changed.emit(player_data.current_san, player_data.max_san)

	# SAN值过低会产生负面效果
	if player_data.current_san < 20:
		EventBus.notify("精神状态危险！可能出现幻觉...", "warning")


func can_control_more_ghosts() -> bool:
	return player_data.controlled_ghosts.size() < player_data.max_ghost_slots


func add_controlled_ghost(ghost_id: String) -> bool:
	if not can_control_more_ghosts():
		EventBus.notify("驭鬼槽已满！", "error")
		return false

	player_data.controlled_ghosts.append(ghost_id)
	return true


func remove_controlled_ghost(ghost_id: String) -> void:
	player_data.controlled_ghosts.erase(ghost_id)


# ==================== 背包操作 ====================
func add_item_to_inventory(item_id: String) -> bool:
	if player_data.inventory.size() >= 10:  # 背包上限
		EventBus.notify("背包已满！", "error")
		return false

	player_data.inventory.append(item_id)
	EventBus.inventory_changed.emit()
	return true


func remove_item_from_inventory(item_id: String) -> bool:
	var index = player_data.inventory.find(item_id)
	if index == -1:
		return false

	player_data.inventory.remove_at(index)
	EventBus.inventory_changed.emit()
	return true


func has_item(item_id: String) -> bool:
	return item_id in player_data.inventory


# ==================== 鬼域操作 ====================
func start_domain(domain_type: String, difficulty: int = 1) -> void:
	current_domain = {
		"type": domain_type,
		"difficulty": difficulty,
		"floor": 1,
		"enemies_defeated": 0,
		"items_collected": 0
	}

	# 重置玩家状态
	player_data.current_hp = player_data.max_hp
	player_data.current_san = player_data.max_san
	player_data.inventory.clear()

	change_state(GameState.IN_DOMAIN)


func end_domain(is_victory: bool) -> void:
	if is_victory:
		change_state(GameState.VICTORY)
	else:
		change_state(GameState.GAME_OVER)


# ==================== 信号回调 ====================
func _on_player_died() -> void:
	change_state(GameState.GAME_OVER)


func _on_ghost_captured(_ghost: Node) -> void:
	statistics.ghosts_captured += 1


func _on_rule_discovered(ghost_id: String, rule_id: String) -> void:
	if not player_data.discovered_rules.has(ghost_id):
		player_data.discovered_rules[ghost_id] = []

	if rule_id not in player_data.discovered_rules[ghost_id]:
		player_data.discovered_rules[ghost_id].append(rule_id)
		statistics.rules_discovered += 1
		EventBus.notify("发现了新的规律！", "success")


# ==================== 暂停控制 ====================
func toggle_pause() -> void:
	if current_state == GameState.PAUSED:
		change_state(previous_state)
		EventBus.game_resumed.emit()
	elif current_state in [GameState.IN_DOMAIN, GameState.IN_BATTLE]:
		change_state(GameState.PAUSED)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
