## SickGhost - 病鬼
## 基于小说设定：
## - 面色苍白、不断咳嗽的鬼
## - 咳嗽声会暴露它的位置
## - 被它触碰会感染诅咒（debuff）
## - 规律：可以通过咳嗽声定位，远程攻击有效
class_name SickGhost
extends GhostBase

# ==================== 病鬼特有属性 ====================
@export var cough_interval_min: float = 3.0  # 咳嗽最小间隔
@export var cough_interval_max: float = 8.0  # 咳嗽最大间隔
@export var infection_duration: float = 10.0  # 感染持续时间
@export var infection_damage_per_second: int = 2  # 感染每秒伤害

var cough_timer: float = 0.0
var next_cough_time: float = 5.0
var infected_targets: Dictionary = {}  # {target: remaining_time}


func _ready() -> void:
	super._ready()
	_setup_sick_ghost_rules()
	_randomize_next_cough()


func _setup_sick_ghost_rules() -> void:
	if ghost_data and ghost_data.rules.is_empty():
		# 主要规律：咳嗽暴露
		var cough_rule = GhostRule.new()
		cough_rule.rule_id = "sick_ghost_cough"
		cough_rule.rule_name = "病态咳嗽"
		cough_rule.description = "病鬼会不定期发出咳嗽声，暴露自己的位置。可以通过声音定位它。"
		cough_rule.hint = "咳咳...那是什么声音？"
		cough_rule.rule_type = GhostRule.RuleType.BEHAVIOR
		cough_rule.trigger_condition = "cough_sound"
		cough_rule.counter_method = "听到咳嗽声后立即警惕，利用声音定位病鬼的方向。"

		# 次要规律：感染
		var infection_rule = GhostRule.new()
		infection_rule.rule_id = "sick_ghost_infection"
		infection_rule.rule_name = "病疫诅咒"
		infection_rule.description = "被病鬼触碰会感染诅咒，持续受到伤害。需要使用符水或镇魂丹清除。"
		infection_rule.hint = "被它碰到后感觉身体不适..."
		infection_rule.rule_type = GhostRule.RuleType.TRIGGER
		infection_rule.counter_method = "避免近身接触，优先使用远程手段。如果被感染，使用恢复道具清除。"
		infection_rule.damage_multiplier = 0.8  # 远程攻击更有效

		# 弱点规律：虚弱体质
		var weakness_rule = GhostRule.new()
		weakness_rule.rule_id = "sick_ghost_weakness"
		weakness_rule.rule_name = "虚弱病体"
		weakness_rule.description = "病鬼的身体非常虚弱，防御力低，容易被击败。但要小心它的感染能力。"
		weakness_rule.hint = "它看起来很虚弱..."
		weakness_rule.rule_type = GhostRule.RuleType.WEAKNESS
		weakness_rule.counter_method = "集中火力快速击败，避免持久战。"

		ghost_data.rules.append(cough_rule)
		ghost_data.rules.append(infection_rule)
		ghost_data.rules.append(weakness_rule)


func _physics_process(delta: float) -> void:
	cough_timer += delta

	# 处理咳嗽
	if cough_timer >= next_cough_time:
		_cough()
		_randomize_next_cough()

	# 处理感染效果
	_process_infections(delta)

	super._physics_process(delta)


func _randomize_next_cough() -> void:
	cough_timer = 0.0
	next_cough_time = randf_range(cough_interval_min, cough_interval_max)


# ==================== 咳嗽行为 ====================
func _cough() -> void:
	"""发出咳嗽声"""
	_play_cough_sound()

	# 咳嗽会暴露位置给附近的玩家
	var reveal_radius = 200.0
	var players = get_tree().get_nodes_in_group("player")

	for player in players:
		if player is Player:
			var distance = global_position.distance_to(player.global_position)
			if distance <= reveal_radius:
				# 给玩家一个位置提示
				_reveal_position_to_player(player)

	# 更新规律发现进度
	_check_cough_rule_discovery()


func _play_cough_sound() -> void:
	# TODO: 播放咳嗽音效
	EventBus.debug("病鬼咳嗽了")


func _reveal_position_to_player(player: Player) -> void:
	"""向玩家暴露位置"""
	var direction = (global_position - player.global_position).normalized()
	var direction_text = _get_direction_text(direction)

	EventBus.notify("听到 %s 方向传来咳嗽声..." % direction_text, "info")


func _get_direction_text(direction: Vector2) -> String:
	var angle = direction.angle()

	if angle > -PI/4 and angle <= PI/4:
		return "东"
	elif angle > PI/4 and angle <= 3*PI/4:
		return "南"
	elif angle > 3*PI/4 or angle <= -3*PI/4:
		return "西"
	else:
		return "北"


func _check_cough_rule_discovery() -> void:
	"""检查咳嗽规律发现"""
	if "sick_ghost_cough" in discovered_rules:
		return

	var observe_count = rule_context.get("cough_observe_count", 0) + 1
	rule_context["cough_observe_count"] = observe_count

	if observe_count >= 2 and target != null:
		discovered_rules.append("sick_ghost_cough")
		EventBus.ghost_rule_discovered.emit(ghost_data.id, "sick_ghost_cough")


# ==================== 感染系统 ====================
func _infect_target(victim: Node) -> void:
	"""感染目标"""
	if victim in infected_targets:
		# 已感染，重置时间
		infected_targets[victim] = infection_duration
		return

	infected_targets[victim] = infection_duration
	EventBus.notify("你被病鬼感染了！", "danger")

	# 检查感染规律发现
	if "sick_ghost_infection" not in discovered_rules:
		discovered_rules.append("sick_ghost_infection")
		EventBus.ghost_rule_discovered.emit(ghost_data.id, "sick_ghost_infection")


func _process_infections(delta: float) -> void:
	"""处理所有感染效果"""
	var to_remove: Array = []

	for victim in infected_targets.keys():
		if not is_instance_valid(victim):
			to_remove.append(victim)
			continue

		infected_targets[victim] -= delta

		if infected_targets[victim] <= 0:
			to_remove.append(victim)
			continue

		# 每秒造成伤害
		if fmod(infected_targets[victim], 1.0) < delta:
			if victim.has_method("take_damage"):
				victim.take_damage(infection_damage_per_second)

	for victim in to_remove:
		infected_targets.erase(victim)
		if is_instance_valid(victim):
			EventBus.notify("感染效果消退了", "info")


func clear_infection(victim: Node) -> void:
	"""清除目标的感染"""
	if victim in infected_targets:
		infected_targets.erase(victim)
		EventBus.notify("感染被清除了！", "success")


# ==================== 重写攻击逻辑 ====================
func _perform_attack() -> void:
	if target == null or not target.has_method("take_damage"):
		return

	# 病鬼的攻击：触碰感染
	target.take_damage(ghost_data.attack)

	# 感染目标
	_infect_target(target)

	if target is Player:
		target.lose_sanity(5)


# ==================== 重写追逐逻辑 ====================
func _state_chase(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = null
		change_state(GhostState.IDLE)
		return

	# 病鬼移动较慢但持续追踪
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * ghost_data.move_speed

	move_and_slide()

	# 接触即攻击
	if global_position.distance_to(target.global_position) < 20:
		change_state(GhostState.ATTACK)


# ==================== 己方鬼技能 ====================
func _use_ability(ability: GhostAbility, ability_target: Node) -> void:
	match ability.id:
		"plague_breath":
			_ability_plague_breath()
		"disease_transfer":
			_ability_disease_transfer(ability_target)
		_:
			super._use_ability(ability, ability_target)


func _ability_plague_breath() -> void:
	"""瘟疫吐息 - 对前方扇形范围内的敌人造成伤害并感染"""
	var breath_range = 100.0
	var breath_angle = PI / 3  # 60度扇形

	var facing = velocity.normalized() if velocity.length() > 0 else Vector2.RIGHT

	# 获取范围内的敌人
	var enemies = get_tree().get_nodes_in_group("enemy" if is_controlled else "player")

	for enemy in enemies:
		var to_enemy = enemy.global_position - global_position
		var distance = to_enemy.length()

		if distance > breath_range:
			continue

		var angle = facing.angle_to(to_enemy.normalized())
		if abs(angle) > breath_angle / 2:
			continue

		# 在范围内
		if enemy.has_method("take_damage"):
			enemy.take_damage(int(ghost_data.attack * 0.8))

		_infect_target(enemy)

	EventBus.notify("%s 喷出瘟疫吐息！" % ghost_data.display_name, "info")


func _ability_disease_transfer(ability_target: Node) -> void:
	"""疾病转移 - 将自身debuff转移给目标，同时恢复少量HP"""
	if ability_target == null:
		return

	# 转移感染
	if ability_target not in infected_targets:
		_infect_target(ability_target)

	# 恢复HP
	var heal_amount = int(ghost_data.max_hp * 0.1)
	current_hp = min(ghost_data.max_hp, current_hp + heal_amount)

	EventBus.notify("%s 转移了疾病并恢复了生命！" % ghost_data.display_name, "info")
