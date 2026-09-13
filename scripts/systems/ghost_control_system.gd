## GhostControlSystem - 驭鬼控制系统
## 管理玩家对鬼的控制、命令和交互
class_name GhostControlSystem
extends Node

# ==================== 信号 ====================
signal ghost_added(ghost: GhostBase)
signal ghost_removed(ghost: GhostBase)
signal command_executed(ghost: GhostBase, command: String)

# ==================== 配置 ====================
@export var max_controlled_ghosts: int = 2
@export var capture_cooldown: float = 3.0

# ==================== 状态 ====================
var controlled_ghosts: Array[GhostBase] = []
var selected_ghost_index: int = 0
var can_capture: bool = true
var owner_player: Player = null


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	EventBus.ghost_rebelled.connect(_on_ghost_rebelled)
	# Run reset / end-of-run: despawn live controlled instances and clear slots.
	EventBus.domain_exited.connect(_on_domain_exited)
	EventBus.game_over.connect(_on_game_over)


func initialize(player: Player) -> void:
	owner_player = player
	max_controlled_ghosts = GameManager.player_data.max_ghost_slots


func _process(delta: float) -> void:
	_process_ghost_loyalty(delta)
	_handle_ghost_selection_input()


# ==================== 捕获系统 ====================
func attempt_capture(target_ghost: GhostBase, capture_item: ItemData = null) -> bool:
	"""尝试捕获一只鬼"""
	if not can_capture:
		EventBus.notify("捕获冷却中...", "warning")
		return false

	if controlled_ghosts.size() >= max_controlled_ghosts:
		EventBus.notify("驭鬼槽已满！需要先释放一只鬼。", "error")
		return false

	if target_ghost == null or not target_ghost.is_alive():
		return false

	# 计算捕获加成
	var capture_bonus = 0.0
	if capture_item != null:
		capture_bonus = capture_item.capture_bonus

	# 尝试捕获
	var success = target_ghost.attempt_capture(capture_bonus)

	if success:
		_add_ghost(target_ghost)
		EventBus.notify("成功捕获了 %s！" % target_ghost.ghost_data.display_name, "success")

		# 触发捕获冷却
		_start_capture_cooldown()
	else:
		EventBus.notify("捕获失败！鬼挣脱了束缚。", "warning")
		# 失败后鬼会短暂眩晕
		target_ghost.stun(1.0)

	return success


func _add_ghost(ghost: GhostBase) -> void:
	"""添加一只鬼到控制列表"""
	if ghost in controlled_ghosts:
		return

	controlled_ghosts.append(ghost)
	ghost.assign_owner(owner_player)

	# 同步到GameManager
	GameManager.add_controlled_ghost(ghost.ghost_data.id)

	ghost_added.emit(ghost)
	EventBus.ghost_captured.emit(ghost)


func release_ghost(ghost: GhostBase) -> void:
	"""释放一只鬼"""
	if ghost not in controlled_ghosts:
		return

	controlled_ghosts.erase(ghost)
	ghost.release()

	# 从GameManager移除
	GameManager.remove_controlled_ghost(ghost.ghost_data.id)

	ghost_removed.emit(ghost)
	EventBus.notify("释放了 %s", "info")


func release_ghost_at_index(index: int) -> void:
	"""通过索引释放鬼"""
	if index < 0 or index >= controlled_ghosts.size():
		return

	release_ghost(controlled_ghosts[index])


func release_all() -> void:
	"""释放并清理所有受控鬼实例，与 GameManager 槽位同步（开局/结算）"""
	var ghosts := controlled_ghosts.duplicate()
	controlled_ghosts.clear()
	selected_ghost_index = 0
	GameManager.player_data.controlled_ghosts.clear()

	for ghost in ghosts:
		if not is_instance_valid(ghost):
			continue
		ghost.release()
		ghost_removed.emit(ghost)
		ghost.queue_free()


func _on_domain_exited() -> void:
	release_all()


func _on_game_over(_is_victory: bool) -> void:
	release_all()


func _start_capture_cooldown() -> void:
	can_capture = false
	await get_tree().create_timer(capture_cooldown).timeout
	can_capture = true


# ==================== 命令系统 ====================
func command_attack(ghost_index: int, target: GhostBase) -> void:
	"""命令指定的鬼攻击目标"""
	if ghost_index < 0 or ghost_index >= controlled_ghosts.size():
		return

	var ghost = controlled_ghosts[ghost_index]

	# 检查忠诚度
	if ghost.loyalty < 30:
		if randf() < 0.3:  # 30%概率拒绝命令
			EventBus.notify("%s 拒绝了你的命令！" % ghost.ghost_data.display_name, "warning")
			return

	ghost.command_attack(target)
	command_executed.emit(ghost, "attack")


func command_use_ability(ghost_index: int, ability_id: String, target: Node = null) -> void:
	"""命令指定的鬼使用技能"""
	if ghost_index < 0 or ghost_index >= controlled_ghosts.size():
		return

	var ghost = controlled_ghosts[ghost_index]
	var success = ghost.command_use_ability(ability_id, target)

	if success:
		command_executed.emit(ghost, "ability:" + ability_id)


func command_follow(ghost_index: int) -> void:
	"""命令鬼跟随玩家"""
	if ghost_index < 0 or ghost_index >= controlled_ghosts.size():
		return

	var ghost = controlled_ghosts[ghost_index]
	ghost.target = null
	ghost.change_state(GhostBase.GhostState.CAPTURED)

	command_executed.emit(ghost, "follow")


func command_all_attack(target: GhostBase) -> void:
	"""命令所有鬼攻击"""
	for i in range(controlled_ghosts.size()):
		command_attack(i, target)


func command_all_follow() -> void:
	"""命令所有鬼跟随"""
	for i in range(controlled_ghosts.size()):
		command_follow(i)


# ==================== 选择系统 ====================
func _handle_ghost_selection_input() -> void:
	if Input.is_action_just_pressed("select_ghost_1"):
		select_ghost(0)
	elif Input.is_action_just_pressed("select_ghost_2"):
		select_ghost(1)


func select_ghost(index: int) -> void:
	if index < 0 or index >= controlled_ghosts.size():
		return

	selected_ghost_index = index
	EventBus.debug("选中鬼: %s" % controlled_ghosts[index].ghost_data.display_name)


func get_selected_ghost() -> GhostBase:
	if selected_ghost_index < 0 or selected_ghost_index >= controlled_ghosts.size():
		return null

	return controlled_ghosts[selected_ghost_index]


# ==================== 忠诚度管理 ====================
func _process_ghost_loyalty(delta: float) -> void:
	"""处理所有鬼的忠诚度变化"""
	for ghost in controlled_ghosts:
		# 忠诚度由Ghost自己处理，这里只做额外检查

		# 低忠诚度时有概率发生随机事件
		if ghost.loyalty < 20 and randf() < 0.001:  # 很小的概率
			_trigger_low_loyalty_event(ghost)


func _trigger_low_loyalty_event(ghost: GhostBase) -> void:
	"""触发低忠诚度事件"""
	var event_roll = randf()

	if event_roll < 0.3:
		# 拒绝下一个命令
		EventBus.notify("%s 看起来很不满..." % ghost.ghost_data.display_name, "warning")
	elif event_roll < 0.6:
		# 对玩家造成少量伤害
		if owner_player:
			owner_player.take_damage(5)
			EventBus.notify("%s 暗中伤害了你！" % ghost.ghost_data.display_name, "danger")
	# 剩余情况不发生事件


func boost_loyalty(ghost_index: int, amount: float) -> void:
	"""提升指定鬼的忠诚度"""
	if ghost_index < 0 or ghost_index >= controlled_ghosts.size():
		return

	var ghost = controlled_ghosts[ghost_index]
	ghost.loyalty = min(100.0, ghost.loyalty + amount)
	EventBus.ghost_loyalty_changed.emit(ghost, ghost.loyalty)


func boost_all_loyalty(amount: float) -> void:
	"""提升所有鬼的忠诚度"""
	for ghost in controlled_ghosts:
		ghost.loyalty = min(100.0, ghost.loyalty + amount)
		EventBus.ghost_loyalty_changed.emit(ghost, ghost.loyalty)


# ==================== 事件回调 ====================
func _on_ghost_rebelled(ghost: GhostBase) -> void:
	"""鬼反叛时的处理"""
	if ghost in controlled_ghosts:
		controlled_ghosts.erase(ghost)
		GameManager.remove_controlled_ghost(ghost.ghost_data.id)
		ghost_removed.emit(ghost)

		# 反叛的鬼变成敌人
		ghost.is_controlled = false
		ghost.target = owner_player


# ==================== 查询方法 ====================
func get_ghost_count() -> int:
	return controlled_ghosts.size()


func has_ghost(ghost: GhostBase) -> bool:
	return ghost in controlled_ghosts


func get_ghost_at(index: int) -> GhostBase:
	if index < 0 or index >= controlled_ghosts.size():
		return null
	return controlled_ghosts[index]


func get_all_controlled_ghosts() -> Array[GhostBase]:
	return controlled_ghosts.duplicate()


func can_control_more() -> bool:
	return controlled_ghosts.size() < max_controlled_ghosts


func get_total_loyalty() -> float:
	"""获取所有鬼的平均忠诚度"""
	if controlled_ghosts.is_empty():
		return 0.0

	var total = 0.0
	for ghost in controlled_ghosts:
		total += ghost.loyalty

	return total / controlled_ghosts.size()
