## BattleSystem - 回合制战斗系统
## 管理驭鬼战斗的流程和逻辑
class_name BattleSystem
extends Node

# ==================== 战斗状态枚举 ====================
enum BattleState {
	INACTIVE,       # 非战斗状态
	STARTING,       # 战斗开始
	PLAYER_TURN,    # 玩家回合
	ENEMY_TURN,     # 敌人回合
	EXECUTING,      # 执行动作中
	VICTORY,        # 胜利
	DEFEAT          # 失败
}

# ==================== 信号 ====================
signal battle_started
signal battle_ended(is_victory: bool)
signal turn_changed(is_player_turn: bool)
signal action_executed(actor: Node, action: String, target: Node)

# ==================== 节点引用 ====================
var ghost_control: GhostControlSystem
var player: Player

# ==================== 战斗数据 ====================
var current_state: BattleState = BattleState.INACTIVE
var player_ghosts: Array[GhostBase] = []
var enemy_ghosts: Array[GhostBase] = []
var turn_order: Array = []  # 行动顺序
var current_turn_index: int = 0
var turn_count: int = 0
## Bumped on start/abort so resumed awaits from a prior battle cannot continue.
var _battle_generation: int = 0

# ==================== 战斗配置 ====================
@export var turn_delay: float = 0.5  # 回合间延迟


func _ready() -> void:
	add_to_group("battle_system")
	# Abort before run-reset handlers free controlled ghosts (game_over / domain exit).
	EventBus.game_over.connect(_on_run_reset)
	EventBus.domain_exited.connect(_on_run_reset)


func initialize(p_ghost_control: GhostControlSystem, p_player: Player) -> void:
	ghost_control = p_ghost_control
	player = p_player


func _on_run_reset(_arg = null) -> void:
	abort_battle()


func is_battle_active() -> bool:
	return current_state != BattleState.INACTIVE


func _is_battle_generation(generation: int) -> bool:
	return generation == _battle_generation and current_state != BattleState.INACTIVE


## Stop an in-flight battle without emitting victory/defeat or forcing IN_DOMAIN.
## Safe to call when game_over already owns GameManager state.
func abort_battle() -> void:
	if current_state == BattleState.INACTIVE:
		return

	# Invalidate every pending await tied to this battle epoch.
	_battle_generation += 1
	current_state = BattleState.INACTIVE
	player_ghosts.clear()
	enemy_ghosts.clear()
	turn_order.clear()
	current_turn_index = 0
	turn_count = 0


# ==================== 战斗流程 ====================
func start_battle(enemies: Array[GhostBase]) -> void:
	"""开始战斗"""
	if current_state != BattleState.INACTIVE:
		return

	_battle_generation += 1
	var generation := _battle_generation
	current_state = BattleState.STARTING
	enemy_ghosts = enemies.duplicate()
	player_ghosts = ghost_control.get_all_controlled_ghosts()

	# 检查是否有可战斗的单位
	if player_ghosts.is_empty():
		EventBus.notify("你没有可战斗的鬼！", "error")
		end_battle(false)
		return

	if enemy_ghosts.is_empty():
		EventBus.notify("没有敌人。", "info")
		end_battle(true)
		return

	turn_count = 0
	_calculate_turn_order()

	EventBus.battle_started.emit(player_ghosts, enemy_ghosts)
	battle_started.emit()

	GameManager.change_state(GameManager.GameState.IN_BATTLE)

	# 开始第一个回合
	await get_tree().create_timer(0.5).timeout
	if not _is_battle_generation(generation):
		return
	_start_next_turn()


func end_battle(is_victory: bool) -> void:
	"""结束战斗"""
	if current_state == BattleState.INACTIVE:
		return

	# Invalidate in-flight turn/action awaits for this battle, then own the end epoch.
	var ending_generation := _battle_generation
	_battle_generation += 1
	current_state = BattleState.VICTORY if is_victory else BattleState.DEFEAT

	if is_victory:
		EventBus.notify("战斗胜利！", "success")
		_process_victory_rewards()
	else:
		EventBus.notify("战斗失败...", "danger")

	EventBus.battle_ended.emit(is_victory)
	battle_ended.emit(is_victory)

	# 清理战斗数据
	await get_tree().create_timer(1.0).timeout
	# Abort or a newer battle epoch may have superseded this end_battle await.
	if _battle_generation != ending_generation + 1:
		return
	_cleanup_battle()

	# Never override terminal run states (GAME_OVER / VICTORY) back to IN_DOMAIN.
	if GameManager.current_state in [
		GameManager.GameState.GAME_OVER,
		GameManager.GameState.VICTORY,
		GameManager.GameState.MAIN_MENU,
	]:
		return

	GameManager.change_state(GameManager.GameState.IN_DOMAIN)


func _cleanup_battle() -> void:
	current_state = BattleState.INACTIVE
	player_ghosts.clear()
	enemy_ghosts.clear()
	turn_order.clear()
	current_turn_index = 0
	turn_count = 0


# ==================== 回合系统 ====================
func _calculate_turn_order() -> void:
	"""计算行动顺序（基于速度）"""
	turn_order.clear()

	var all_units: Array = []
	all_units.append_array(player_ghosts)
	all_units.append_array(enemy_ghosts)

	# 按速度排序
	all_units.sort_custom(func(a, b):
		return a.ghost_data.speed > b.ghost_data.speed
	)

	turn_order = all_units


func _start_next_turn() -> void:
	"""开始下一个回合"""
	if current_state == BattleState.INACTIVE:
		return

	# 检查战斗结束条件
	if _check_battle_end():
		return

	# 找到下一个可行动的单位
	var active_unit = _get_next_active_unit()

	if active_unit == null:
		# 所有单位都行动过了，开始新回合
		turn_count += 1
		current_turn_index = 0
		_update_rule_context()
		_start_next_turn()
		return

	# 判断是玩家方还是敌人方
	var is_player_turn = active_unit in player_ghosts
	current_state = BattleState.PLAYER_TURN if is_player_turn else BattleState.ENEMY_TURN

	EventBus.battle_turn_started.emit(is_player_turn)
	turn_changed.emit(is_player_turn)

	if is_player_turn:
		# 玩家回合，等待玩家输入
		_wait_for_player_input(active_unit)
	else:
		# 敌人回合，AI行动
		var generation := _battle_generation
		await get_tree().create_timer(turn_delay).timeout
		if not _is_battle_generation(generation):
			return
		# Freed mid-delay: keep the battle moving instead of stalling ENEMY_TURN.
		if not is_instance_valid(active_unit):
			_start_next_turn()
			return
		_execute_enemy_turn(active_unit)


func _get_next_active_unit() -> GhostBase:
	"""获取下一个可行动的单位"""
	while current_turn_index < turn_order.size():
		var unit = turn_order[current_turn_index]
		current_turn_index += 1

		if is_instance_valid(unit) and unit.is_alive():
			return unit

	return null


func _check_battle_end() -> bool:
	"""检查战斗是否结束"""
	if current_state == BattleState.INACTIVE:
		return true

	# 移除已死亡的单位
	player_ghosts = player_ghosts.filter(func(g): return is_instance_valid(g) and g.is_alive())
	enemy_ghosts = enemy_ghosts.filter(func(g): return is_instance_valid(g) and g.is_alive())

	if enemy_ghosts.is_empty():
		end_battle(true)
		return true

	if player_ghosts.is_empty():
		end_battle(false)
		return true

	return false


func _update_rule_context() -> void:
	"""更新所有鬼的规律上下文"""
	for ghost in turn_order:
		if is_instance_valid(ghost):
			ghost.rule_context["turn_count"] = turn_count


# ==================== 玩家行动 ====================
func _wait_for_player_input(ghost: GhostBase) -> void:
	"""等待玩家输入"""
	if current_state == BattleState.INACTIVE or not is_instance_valid(ghost):
		return

	var generation := _battle_generation

	# 这里应该显示战斗UI，让玩家选择行动
	EventBus.debug("等待玩家指挥 %s" % ghost.ghost_data.display_name)

	# 暂时使用简单的自动行动
	# TODO: 实现完整的战斗UI
	await get_tree().create_timer(0.5).timeout

	if not _is_battle_generation(generation):
		return
	if not is_instance_valid(ghost):
		_start_next_turn()
		return
	if enemy_ghosts.is_empty():
		return

	# 自动攻击第一个敌人
	var target = enemy_ghosts[0]
	if not is_instance_valid(target):
		_start_next_turn()
		return
	execute_attack(ghost, target)


func execute_attack(attacker: GhostBase, target: GhostBase) -> void:
	"""执行攻击"""
	if current_state == BattleState.INACTIVE or current_state == BattleState.EXECUTING:
		return
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return

	var generation := _battle_generation
	current_state = BattleState.EXECUTING

	# 计算伤害
	var damage = _calculate_damage(attacker, target)
	target.take_damage(damage, attacker)

	EventBus.debug("%s 攻击 %s 造成 %d 伤害" % [
		attacker.ghost_data.display_name,
		target.ghost_data.display_name,
		damage
	])

	action_executed.emit(attacker, "attack", target)
	EventBus.battle_action_performed.emit(attacker, "attack", target)

	# 检查目标是否可以被捕获
	if target not in player_ghosts and target._can_be_captured():
		EventBus.notify("%s 可以被捕获了！" % target.ghost_data.display_name, "info")

	await get_tree().create_timer(turn_delay).timeout
	if not _is_battle_generation(generation):
		return
	_start_next_turn()


func execute_ability(caster: GhostBase, ability: GhostAbility, target: Node) -> void:
	"""执行技能"""
	if current_state == BattleState.INACTIVE or current_state == BattleState.EXECUTING:
		return
	if not is_instance_valid(caster):
		return

	var generation := _battle_generation
	current_state = BattleState.EXECUTING

	# 检查冷却
	if caster.cooldown_timers.get(ability.id, 0) > 0:
		EventBus.notify("技能冷却中", "warning")
		current_state = BattleState.PLAYER_TURN
		return

	# 执行技能效果
	match ability.ability_type:
		GhostAbility.AbilityType.ATTACK:
			_execute_attack_ability(caster, ability, target)
		GhostAbility.AbilityType.BUFF:
			_execute_buff_ability(caster, ability, target)
		GhostAbility.AbilityType.DEBUFF:
			_execute_debuff_ability(caster, ability, target)
		GhostAbility.AbilityType.SPECIAL:
			_execute_special_ability(caster, ability, target)

	# 设置冷却
	caster.cooldown_timers[ability.id] = ability.cooldown_turns

	action_executed.emit(caster, "ability:" + ability.id, target)

	await get_tree().create_timer(turn_delay).timeout
	if not _is_battle_generation(generation):
		return
	_start_next_turn()


func execute_capture(target: GhostBase) -> void:
	"""在战斗中尝试捕获"""
	if not target._can_be_captured():
		EventBus.notify("目标HP还太高，无法捕获", "warning")
		return

	var success = ghost_control.attempt_capture(target)

	if success:
		enemy_ghosts.erase(target)
		player_ghosts.append(target)
		turn_order.erase(target)  # 从行动顺序中移除再添加

	_start_next_turn()


func execute_use_item(item: ItemData, target: Node = null) -> void:
	"""在战斗中使用道具"""
	# TODO: 实现道具使用逻辑
	var generation := _battle_generation
	await get_tree().create_timer(turn_delay).timeout
	if not _is_battle_generation(generation):
		return
	_start_next_turn()


# ==================== 敌人AI ====================
func _execute_enemy_turn(ghost: GhostBase) -> void:
	"""执行敌人的回合"""
	if player_ghosts.is_empty():
		return

	# 简单AI：选择最近/最弱的目标攻击
	var target = _select_ai_target(ghost)

	if target == null:
		_start_next_turn()
		return

	# 检查是否使用技能
	var ability = _select_ai_ability(ghost)

	if ability != null and randf() < 0.3:  # 30%概率使用技能
		execute_ability(ghost, ability, target)
	else:
		execute_attack(ghost, target)


func _select_ai_target(attacker: GhostBase) -> GhostBase:
	"""AI选择攻击目标"""
	if player_ghosts.is_empty():
		return null

	# 优先攻击低HP的目标
	var targets = player_ghosts.duplicate()
	targets.sort_custom(func(a, b):
		return a.get_hp_ratio() < b.get_hp_ratio()
	)

	return targets[0]


func _select_ai_ability(ghost: GhostBase) -> GhostAbility:
	"""AI选择技能"""
	if ghost.ghost_data == null or ghost.ghost_data.abilities.is_empty():
		return null

	var available_abilities: Array = []

	for ability in ghost.ghost_data.abilities:
		if ability is GhostAbility:
			# 检查冷却
			if ghost.cooldown_timers.get(ability.id, 0) <= 0:
				available_abilities.append(ability)

	if available_abilities.is_empty():
		return null

	# 根据AI优先级选择
	available_abilities.sort_custom(func(a, b):
		return a.ai_priority > b.ai_priority
	)

	return available_abilities[0]


# ==================== 伤害计算 ====================
func _calculate_damage(attacker: GhostBase, target: GhostBase) -> int:
	"""计算基础攻击伤害"""
	var base_damage = attacker.ghost_data.attack
	var defense = target.ghost_data.defense

	# 基础伤害公式
	var damage = max(1, base_damage - defense / 2)

	# 暴击判定
	if randf() < 0.1:  # 10%暴击率
		damage = int(damage * 1.5)
		EventBus.debug("暴击！")

	# 规律加成
	damage = _apply_rule_bonus(attacker, target, damage)

	return damage


func _apply_rule_bonus(attacker: GhostBase, target: GhostBase, damage: int) -> int:
	"""应用规律加成"""
	# 如果玩家已经发现了目标的规律，给予伤害加成
	if target.ghost_data == null:
		return damage

	var ghost_id = target.ghost_data.id
	var discovered = GameManager.player_data.discovered_rules.get(ghost_id, [])

	if not discovered.is_empty():
		# 每发现一个规律，增加10%伤害
		var bonus = 1.0 + discovered.size() * 0.1
		damage = int(damage * bonus)

	return damage


# ==================== 技能效果 ====================
func _execute_attack_ability(caster: GhostBase, ability: GhostAbility, target: Node) -> void:
	if target == null or not target is GhostBase:
		return

	var damage = ability.calculate_damage(caster.ghost_data.attack, target.ghost_data.defense)

	# 暴击判定
	if ability.roll_critical():
		damage = int(damage * ability.critical_multiplier)
		EventBus.debug("技能暴击！")

	# 命中判定
	if not ability.roll_hit():
		EventBus.debug("技能未命中")
		return

	target.take_damage(damage, caster)

	# 状态效果
	if ability.roll_status_effect():
		_apply_status_effect(target, ability.status_effect, ability.status_duration)


func _execute_buff_ability(caster: GhostBase, ability: GhostAbility, target: Node) -> void:
	# TODO: 实现增益效果
	pass


func _execute_debuff_ability(caster: GhostBase, ability: GhostAbility, target: Node) -> void:
	# TODO: 实现减益效果
	pass


func _execute_special_ability(caster: GhostBase, ability: GhostAbility, target: Node) -> void:
	# TODO: 实现特殊效果
	pass


func _apply_status_effect(target: Node, effect_id: String, duration: int) -> void:
	# TODO: 实现状态效果系统
	EventBus.debug("应用状态效果: %s 持续 %d 回合" % [effect_id, duration])


# ==================== 战斗奖励 ====================
func _process_victory_rewards() -> void:
	"""处理战斗胜利奖励"""
	# 给玩家的鬼增加忠诚度
	ghost_control.boost_all_loyalty(5.0)

	# 减少技能冷却
	for ghost in player_ghosts:
		for ability_id in ghost.cooldown_timers.keys():
			ghost.cooldown_timers[ability_id] = max(0, ghost.cooldown_timers[ability_id] - 1)

	# TODO: 掉落物品、经验等
