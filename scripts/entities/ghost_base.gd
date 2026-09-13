## GhostBase - 鬼的基类
## 所有鬼类型的基础类，处理通用逻辑
class_name GhostBase
extends CharacterBody2D

# ==================== 鬼的状态枚举 ====================
enum GhostState {
	IDLE,           # 空闲
	PATROL,         # 巡逻
	CHASE,          # 追逐玩家
	ATTACK,         # 攻击中
	STUNNED,        # 眩晕
	CAPTURED,       # 被捕获（己方鬼）
	EXECUTING_RULE  # 执行规律行为
}

# ==================== 导出属性 ====================
@export var ghost_data: GhostData  # 鬼的数据

# ==================== 节点引用 ====================
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var state_machine: Node = $StateMachine if has_node("StateMachine") else null

# ==================== 运行时属性 ====================
var current_hp: int = 100
var current_state: GhostState = GhostState.IDLE
var is_controlled: bool = false  # 是否被玩家控制
var loyalty: float = 0.0  # 忠诚度（仅对己方鬼有效）
var owner_player: Player = null  # 控制者

# ==================== 规律相关 ====================
var rule_context: Dictionary = {}  # 规律判断上下文
var discovered_rules: Array = []  # 已被发现的规律
var current_rule_data: GhostRule = null  # 当前执行的规律

# ==================== AI相关 ====================
var target: Node2D = null  # 当前目标
var home_position: Vector2  # 初始位置
var patrol_points: Array[Vector2] = []  # 巡逻点
var current_patrol_index: int = 0

# ==================== 战斗相关 ====================
var cooldown_timers: Dictionary = {}  # 技能冷却计时器


func _ready() -> void:
	home_position = global_position
	_initialize_from_data()
	_connect_signals()
	_setup_detection_area()


func _initialize_from_data() -> void:
	if ghost_data == null:
		push_warning("[Ghost] 没有设置 ghost_data")
		return

	current_hp = ghost_data.max_hp
	loyalty = ghost_data.base_loyalty if is_controlled else 0.0

	# 初始化规律上下文
	rule_context = {
		"hp_ratio": 1.0,
		"light_level": 1.0,
		"player_looking": false,
		"knock_count": 0,
		"near_mirror": false,
		"turn_count": 0
	}


func _connect_signals() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)


func _setup_detection_area() -> void:
	if detection_area and ghost_data:
		var shape = detection_area.get_node_or_null("CollisionShape2D")
		if shape and shape.shape is CircleShape2D:
			shape.shape.radius = ghost_data.detection_radius


func _physics_process(delta: float) -> void:
	if is_controlled:
		_process_controlled_ghost(delta)
	else:
		_process_enemy_ghost(delta)

	_update_rule_context()
	_check_rules()


# ==================== 敌方鬼AI ====================
func _process_enemy_ghost(delta: float) -> void:
	match current_state:
		GhostState.IDLE:
			_state_idle(delta)
		GhostState.PATROL:
			_state_patrol(delta)
		GhostState.CHASE:
			_state_chase(delta)
		GhostState.ATTACK:
			_state_attack(delta)
		GhostState.STUNNED:
			_state_stunned(delta)
		GhostState.EXECUTING_RULE:
			_state_executing_rule(delta)


func _state_idle(delta: float) -> void:
	# 空闲状态，等待发现玩家
	if target != null:
		change_state(GhostState.CHASE)
	elif randf() < 0.01:  # 随机开始巡逻
		change_state(GhostState.PATROL)


func _state_patrol(delta: float) -> void:
	if target != null:
		change_state(GhostState.CHASE)
		return

	if patrol_points.is_empty():
		_generate_patrol_points()

	# 移动到巡逻点
	var patrol_target = patrol_points[current_patrol_index]
	var direction = (patrol_target - global_position).normalized()

	velocity = direction * ghost_data.move_speed * 0.5
	move_and_slide()

	# 到达巡逻点
	if global_position.distance_to(patrol_target) < 10:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

		# 有概率停下来
		if randf() < 0.3:
			change_state(GhostState.IDLE)


func _state_chase(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = null
		change_state(GhostState.IDLE)
		return

	var direction = (target.global_position - global_position).normalized()
	velocity = direction * ghost_data.move_speed

	move_and_slide()

	# 检查是否进入攻击范围
	if global_position.distance_to(target.global_position) < 30:
		change_state(GhostState.ATTACK)


func _state_attack(delta: float) -> void:
	# 攻击逻辑（由子类实现具体攻击方式）
	_perform_attack()

	# 攻击后短暂冷却
	await get_tree().create_timer(1.0).timeout

	if target != null and is_instance_valid(target):
		change_state(GhostState.CHASE)
	else:
		change_state(GhostState.IDLE)


func _state_stunned(delta: float) -> void:
	# 眩晕状态，什么都不做
	pass


func _state_executing_rule(delta: float) -> void:
	# 执行规律行为（由子类实现）
	pass


func _generate_patrol_points() -> void:
	patrol_points.clear()

	var radius = ghost_data.patrol_radius if ghost_data else 100.0

	for i in range(4):
		var angle = TAU * i / 4.0 + randf_range(-0.5, 0.5)
		var point = home_position + Vector2(cos(angle), sin(angle)) * radius * randf_range(0.5, 1.0)
		patrol_points.append(point)


# ==================== 己方鬼行为 ====================
func _process_controlled_ghost(delta: float) -> void:
	# 被控制的鬼跟随玩家或执行命令
	if owner_player == null:
		return

	# 更新忠诚度
	_update_loyalty(delta)

	# 如果没有战斗目标，跟随玩家
	if target == null:
		_follow_owner(delta)


func _follow_owner(delta: float) -> void:
	if owner_player == null:
		return

	var follow_distance = 60.0
	var distance = global_position.distance_to(owner_player.global_position)

	if distance > follow_distance:
		var direction = (owner_player.global_position - global_position).normalized()
		velocity = direction * ghost_data.move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO


func _update_loyalty(delta: float) -> void:
	if not is_controlled:
		return

	# 忠诚度随时间衰减
	loyalty -= ghost_data.loyalty_decay_rate * delta

	if loyalty < 0:
		loyalty = 0
		_rebel()

	EventBus.ghost_loyalty_changed.emit(self, loyalty)


func _rebel() -> void:
	# 鬼反叛
	is_controlled = false
	owner_player = null
	EventBus.ghost_rebelled.emit(self)
	EventBus.notify("%s 挣脱了控制！" % ghost_data.display_name, "danger")


# ==================== 规律系统 ====================
func _update_rule_context() -> void:
	rule_context["hp_ratio"] = float(current_hp) / float(ghost_data.max_hp) if ghost_data else 1.0
	# 其他上下文由子类更新


func _check_rules() -> void:
	if ghost_data == null or ghost_data.rules.is_empty():
		return

	for rule in ghost_data.rules:
		if rule is GhostRule and rule.check_trigger(rule_context):
			_execute_rule(rule)
			break


func _execute_rule(rule: GhostRule) -> void:
	# 执行规律行为（由子类重写）
	current_rule_data = rule
	change_state(GhostState.EXECUTING_RULE)


# ==================== 战斗接口 ====================
func take_damage(damage: int, source: Node = null) -> void:
	var actual_damage = max(1, damage - ghost_data.defense)
	current_hp -= actual_damage

	EventBus.damage_dealt.emit(source, self, actual_damage)

	# 受伤效果
	_on_damaged(actual_damage)

	if current_hp <= 0:
		_on_defeated()


func _on_damaged(damage: int) -> void:
	# 受伤闪烁
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _on_defeated() -> void:
	EventBus.ghost_defeated.emit(self)

	# 检查是否可以被捕获
	if _can_be_captured():
		# 等待玩家尝试捕获
		change_state(GhostState.STUNNED)
	else:
		_die()


func _can_be_captured() -> bool:
	if ghost_data == null:
		return false

	# Zero HP is defeat, not capture: require living HP so lethal damage
	# reaches _die() via _on_defeated, while mid-battle capture still
	# works for 0 < hp_ratio <= capture_hp_threshold.
	if current_hp <= 0:
		return false

	var hp_ratio = float(current_hp) / float(ghost_data.max_hp)
	return hp_ratio <= ghost_data.capture_hp_threshold


func _die() -> void:
	# 鬼被消灭（不是被捕获）
	queue_free()


func _perform_attack() -> void:
	# 基础攻击，由子类重写实现特殊攻击
	if target == null or not target.has_method("take_damage"):
		return

	target.take_damage(ghost_data.attack)


# ==================== 捕获系统 ====================
func attempt_capture(capture_bonus: float = 0.0) -> bool:
	if ghost_data == null:
		return false

	var hp_ratio = float(current_hp) / float(ghost_data.max_hp)
	var capture_rate = ghost_data.calculate_capture_rate(hp_ratio, capture_bonus)

	var success = randf() < capture_rate

	if success:
		_on_captured()

	return success


func _on_captured() -> void:
	is_controlled = true
	loyalty = ghost_data.base_loyalty
	current_state = GhostState.CAPTURED
	target = null

	EventBus.ghost_captured.emit(self)


func assign_owner(player: Player) -> void:
	owner_player = player
	is_controlled = true


func release() -> void:
	is_controlled = false
	owner_player = null
	loyalty = 0
	EventBus.ghost_escaped.emit(self)


# ==================== 状态管理 ====================
func change_state(new_state: GhostState) -> void:
	if new_state == current_state:
		return

	_exit_state(current_state)
	current_state = new_state
	_enter_state(new_state)


func _enter_state(state: GhostState) -> void:
	# 进入状态的逻辑，由子类重写
	pass


func _exit_state(state: GhostState) -> void:
	# 退出状态的逻辑，由子类重写
	pass


# ==================== 检测回调 ====================
func _on_detection_area_entered(body: Node2D) -> void:
	if body is Player and not is_controlled:
		target = body


func _on_detection_area_exited(body: Node2D) -> void:
	if body == target:
		target = null


# ==================== 命令接口（己方鬼） ====================
func command_attack(attack_target: GhostBase) -> void:
	if not is_controlled:
		return

	target = attack_target
	change_state(GhostState.CHASE)


func command_use_ability(ability_id: String, ability_target: Node = null) -> bool:
	if not is_controlled:
		return false

	# 检查冷却
	if cooldown_timers.has(ability_id) and cooldown_timers[ability_id] > 0:
		return false

	# 查找技能
	for ability in ghost_data.abilities:
		if ability is GhostAbility and ability.id == ability_id:
			# 检查忠诚度要求
			if loyalty < ability.loyalty_required:
				EventBus.notify("忠诚度不足，%s 拒绝使用此技能" % ghost_data.display_name, "warning")
				return false

			_use_ability(ability, ability_target)
			cooldown_timers[ability_id] = ability.cooldown_turns
			return true

	return false


func _use_ability(ability: GhostAbility, ability_target: Node) -> void:
	# 使用技能的逻辑，由子类实现具体效果
	pass


# ==================== 工具方法 ====================
func get_hp_ratio() -> float:
	if ghost_data == null:
		return 1.0
	return float(current_hp) / float(ghost_data.max_hp)


func is_alive() -> bool:
	return current_hp > 0


func stun(duration: float) -> void:
	change_state(GhostState.STUNNED)

	await get_tree().create_timer(duration).timeout

	if current_state == GhostState.STUNNED:
		change_state(GhostState.IDLE)
