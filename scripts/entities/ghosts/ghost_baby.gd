## GhostBaby - 鬼婴
## 基于小说设定：
## - 浑身惨白、双眼漆黑的婴儿形态
## - 只在黑暗中移动，光照下静止不动
## - 移动速度快，攻击力高但防御低
## - 规律：使用光源可以限制其行动
class_name GhostBaby
extends GhostBase

# ==================== 鬼婴特有属性 ====================
@export var light_threshold: float = 0.3  # 光照阈值，低于此值才能移动
@export var dash_speed_multiplier: float = 2.0  # 冲刺速度倍率
@export var cry_interval: float = 5.0  # 哭泣间隔

var is_in_light: bool = false
var current_light_level: float = 0.0
var cry_timer: float = 0.0
var is_dashing: bool = false


func _ready() -> void:
	super._ready()
	_setup_ghost_baby_rules()


func _setup_ghost_baby_rules() -> void:
	if ghost_data and ghost_data.rules.is_empty():
		# 主要规律：惧光
		var light_rule = GhostRule.new()
		light_rule.rule_id = "ghost_baby_light"
		light_rule.rule_name = "惧光本能"
		light_rule.description = "鬼婴只能在黑暗中移动。当处于光照下时，它会完全静止，无法行动。"
		light_rule.hint = "它似乎很怕某种东西..."
		light_rule.rule_type = GhostRule.RuleType.WEAKNESS
		light_rule.trigger_condition = "in_darkness"
		light_rule.counter_method = "使用鬼烛或其他光源照射鬼婴，可以使其完全无法移动。"
		light_rule.damage_multiplier = 1.5  # 在光照下受到的伤害增加

		# 次要规律：哭声
		var cry_rule = GhostRule.new()
		cry_rule.rule_id = "ghost_baby_cry"
		cry_rule.rule_name = "婴儿啼哭"
		cry_rule.description = "鬼婴会周期性发出哭声，哭声会降低听到者的SAN值。"
		cry_rule.hint = "那哭声...让人心神不宁..."
		cry_rule.rule_type = GhostRule.RuleType.BEHAVIOR
		cry_rule.counter_method = "远离哭声范围，或使用防护道具。"

		ghost_data.rules.append(light_rule)
		ghost_data.rules.append(cry_rule)


func _physics_process(delta: float) -> void:
	_update_light_level()
	cry_timer += delta

	if cry_timer >= cry_interval:
		cry_timer = 0.0
		_cry()

	super._physics_process(delta)


func _update_light_level() -> void:
	"""更新当前光照等级"""
	# 检测周围的光源
	current_light_level = _calculate_light_level()
	is_in_light = current_light_level >= light_threshold

	rule_context["light_level"] = current_light_level
	rule_context["in_darkness"] = not is_in_light


func _calculate_light_level() -> float:
	"""计算当前位置的光照等级"""
	var light_level = 0.0

	# 获取场景中所有光源
	var lights = get_tree().get_nodes_in_group("light_source")

	for light in lights:
		if not is_instance_valid(light):
			continue

		var distance = global_position.distance_to(light.global_position)
		var light_radius = light.get("light_radius") if light.has_method("get") else 100.0

		if distance < light_radius:
			# 距离越近，光照越强
			var intensity = 1.0 - (distance / light_radius)
			light_level = max(light_level, intensity)

	# 检查玩家持有的光源
	if target != null and target is Player:
		# 假设玩家的光源范围
		var player_light_radius = 80.0
		var distance = global_position.distance_to(target.global_position)
		if distance < player_light_radius:
			var intensity = 1.0 - (distance / player_light_radius)
			light_level = max(light_level, intensity * 0.5)

	return light_level


# ==================== 重写状态处理 ====================
func _state_idle(delta: float) -> void:
	if is_in_light:
		# 在光照下静止
		velocity = Vector2.ZERO
		return

	super._state_idle(delta)


func _state_patrol(delta: float) -> void:
	if is_in_light:
		velocity = Vector2.ZERO
		return

	super._state_patrol(delta)


func _state_chase(delta: float) -> void:
	if is_in_light:
		# 在光照下无法追逐
		velocity = Vector2.ZERO
		return

	if target == null or not is_instance_valid(target):
		target = null
		change_state(GhostState.IDLE)
		return

	# 鬼婴的追逐：快速冲刺
	var direction = (target.global_position - global_position).normalized()
	var speed = ghost_data.move_speed * (dash_speed_multiplier if is_dashing else 1.0)

	velocity = direction * speed
	move_and_slide()

	# 检查是否进入攻击范围
	if global_position.distance_to(target.global_position) < 25:
		change_state(GhostState.ATTACK)

	# 随机开始冲刺
	if not is_dashing and randf() < 0.02:
		_start_dash()


func _start_dash() -> void:
	"""开始冲刺"""
	is_dashing = true

	# 冲刺持续短暂时间
	await get_tree().create_timer(0.5).timeout
	is_dashing = false


# ==================== 哭泣行为 ====================
func _cry() -> void:
	"""发出哭声，对范围内的玩家造成SAN伤害"""
	var cry_radius = 150.0
	var san_damage = 5

	# 播放哭声音效
	_play_cry_sound()

	# 对范围内的玩家造成SAN伤害
	var players = get_tree().get_nodes_in_group("player")

	for player in players:
		if player is Player:
			var distance = global_position.distance_to(player.global_position)
			if distance <= cry_radius:
				player.lose_sanity(san_damage)

				if distance < 50:
					EventBus.notify("婴儿的哭声刺入你的脑海...", "warning")


func _play_cry_sound() -> void:
	# TODO: 播放哭声音效
	EventBus.debug("鬼婴发出哭声")


# ==================== 重写攻击逻辑 ====================
func _perform_attack() -> void:
	if target == null or not target.has_method("take_damage"):
		return

	# 鬼婴的攻击：抓挠
	target.take_damage(ghost_data.attack)

	if target is Player:
		# 额外效果：使玩家短暂减速
		target.lose_sanity(8)


# ==================== 受伤处理 ====================
func _on_damaged(damage: int) -> void:
	# 如果在光照下受到攻击，伤害增加
	if is_in_light:
		var extra_damage = int(damage * 0.5)
		current_hp -= extra_damage
		EventBus.debug("鬼婴在光照下受到额外伤害: %d" % extra_damage)

	super._on_damaged(damage)


# ==================== 己方鬼技能 ====================
func _use_ability(ability: GhostAbility, ability_target: Node) -> void:
	match ability.id:
		"shadow_dash":
			_ability_shadow_dash(ability_target)
		"terrifying_cry":
			_ability_terrifying_cry()
		_:
			super._use_ability(ability, ability_target)


func _ability_shadow_dash(ability_target: Node) -> void:
	"""暗影冲刺 - 快速冲向目标并造成伤害"""
	if ability_target == null:
		return

	is_dashing = true

	# 瞬移到目标附近
	var direction = (ability_target.global_position - global_position).normalized()
	global_position = ability_target.global_position - direction * 30

	if ability_target.has_method("take_damage"):
		ability_target.take_damage(int(ghost_data.attack * 1.8))

	await get_tree().create_timer(0.3).timeout
	is_dashing = false

	EventBus.notify("%s 使用了暗影冲刺！" % ghost_data.display_name, "info")


func _ability_terrifying_cry() -> void:
	"""恐怖啼哭 - 对所有敌人造成SAN伤害并可能使其眩晕"""
	var cry_radius = 200.0

	# 获取范围内的敌人
	var enemies = get_tree().get_nodes_in_group("enemy" if is_controlled else "player")

	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= cry_radius:
			if enemy is Player:
				enemy.lose_sanity(15)
			elif enemy is GhostBase:
				# 对敌方鬼造成眩晕
				if randf() < 0.4:
					enemy.stun(1.5)

	EventBus.notify("%s 发出恐怖的啼哭！" % ghost_data.display_name, "info")
