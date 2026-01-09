## DoorKnocker - 敲门鬼
## 基于小说中的敲门鬼设定：
## - 会站在门外敲门，敲门声有特定节奏（咚-咚咚）
## - 敲满3次后会进入房间
## - 进入后会带来"鬼域"效果，周围事物加速腐朽
## - 规律：打断敲门可以重置计数
class_name DoorKnocker
extends GhostBase

# ==================== 敲门鬼特有状态 ====================
enum DoorKnockerState {
	APPROACHING_DOOR,  # 接近门
	KNOCKING,          # 敲门中
	ENTERING,          # 进入中
	CORRUPTING         # 腐蚀周围
}

# ==================== 敲门相关 ====================
@export var knock_interval: float = 2.0  # 敲门间隔
@export var knocks_to_enter: int = 3  # 敲多少次后进入
@export var corruption_radius: float = 100.0  # 腐蚀范围
@export var corruption_damage: int = 5  # 腐蚀伤害/秒

var current_knock_count: int = 0
var target_door: Node2D = null
var knocker_state: DoorKnockerState = DoorKnockerState.APPROACHING_DOOR
var knock_timer: float = 0.0
var is_knocking: bool = false

# ==================== 腐蚀效果 ====================
var corruption_effect_active: bool = false
var corruption_timer: float = 0.0


func _ready() -> void:
	super._ready()
	_setup_door_knocker_rules()


func _setup_door_knocker_rules() -> void:
	# 如果没有从资源加载规律，创建默认规律
	if ghost_data and ghost_data.rules.is_empty():
		var knock_rule = GhostRule.new()
		knock_rule.rule_id = "door_knocker_pattern"
		knock_rule.rule_name = "敲门节奏"
		knock_rule.description = "敲门鬼会以固定节奏敲门：一长两短（咚-咚咚）。敲满3次后会强制进入。"
		knock_rule.hint = "注意听敲门的节奏..."
		knock_rule.rule_type = GhostRule.RuleType.BEHAVIOR
		knock_rule.trigger_condition = "door_knocked_3_times"
		knock_rule.counter_method = "在它完成第3次敲门前打断它（攻击或使用道具），可以重置敲门计数。"
		knock_rule.discovery_condition = "观察敲门鬼敲门3次"
		knock_rule.observation_count_required = 3

		var weakness_rule = GhostRule.new()
		weakness_rule.rule_id = "door_knocker_weakness"
		weakness_rule.rule_name = "门的束缚"
		weakness_rule.description = "敲门鬼必须通过门进入，无法穿墙。如果门被封印，它会被困在外面。"
		weakness_rule.hint = "它似乎对门有某种执念..."
		weakness_rule.rule_type = GhostRule.RuleType.WEAKNESS
		weakness_rule.counter_method = "使用棺材钉封印门，可以完全阻止敲门鬼进入。"

		ghost_data.rules.append(knock_rule)
		ghost_data.rules.append(weakness_rule)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if not is_controlled:
		_process_door_knocker(delta)


func _process_door_knocker(delta: float) -> void:
	match knocker_state:
		DoorKnockerState.APPROACHING_DOOR:
			_approach_door(delta)
		DoorKnockerState.KNOCKING:
			_perform_knocking(delta)
		DoorKnockerState.ENTERING:
			_enter_room(delta)
		DoorKnockerState.CORRUPTING:
			_corrupt_surroundings(delta)


# ==================== 接近门 ====================
func _approach_door(delta: float) -> void:
	if target_door == null:
		target_door = _find_nearest_door()

	if target_door == null:
		# 没有门，直接追逐玩家
		if target != null:
			change_state(GhostState.CHASE)
		return

	# 移动到门前
	var direction = (target_door.global_position - global_position).normalized()
	velocity = direction * ghost_data.move_speed * 0.5
	move_and_slide()

	# 到达门前
	if global_position.distance_to(target_door.global_position) < 20:
		velocity = Vector2.ZERO
		knocker_state = DoorKnockerState.KNOCKING
		_start_knocking()


func _find_nearest_door() -> Node2D:
	var doors = get_tree().get_nodes_in_group("door")
	if doors.is_empty():
		return null

	var nearest: Node2D = null
	var nearest_distance: float = INF

	for door in doors:
		var distance = global_position.distance_to(door.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = door

	return nearest


# ==================== 敲门行为 ====================
func _start_knocking() -> void:
	is_knocking = true
	knock_timer = 0.0
	current_knock_count = 0

	# 更新规律上下文
	rule_context["knock_count"] = current_knock_count

	EventBus.notify("听到了敲门声...", "warning")


func _perform_knocking(delta: float) -> void:
	knock_timer += delta

	if knock_timer >= knock_interval:
		knock_timer = 0.0
		_knock_once()

		if current_knock_count >= knocks_to_enter:
			knocker_state = DoorKnockerState.ENTERING
			is_knocking = false


func _knock_once() -> void:
	current_knock_count += 1
	rule_context["knock_count"] = current_knock_count

	# 播放敲门音效（咚-咚咚的节奏）
	_play_knock_sound()

	# 发送敲门事件，让玩家有机会发现规律
	EventBus.debug("敲门鬼敲门: %d/%d" % [current_knock_count, knocks_to_enter])

	# 检查是否有玩家在观察，如果是则增加规律发现进度
	_check_rule_discovery()


func _play_knock_sound() -> void:
	# TODO: 播放敲门音效
	# 节奏：咚（长）-咚咚（两短）
	pass


func _check_rule_discovery() -> void:
	# 如果玩家在附近观察，增加规律发现进度
	if target != null and global_position.distance_to(target.global_position) < 200:
		if not "door_knocker_pattern" in discovered_rules:
			var observe_count = rule_context.get("observe_count", 0) + 1
			rule_context["observe_count"] = observe_count

			if observe_count >= 3:
				discovered_rules.append("door_knocker_pattern")
				EventBus.ghost_rule_discovered.emit(ghost_data.id, "door_knocker_pattern")


# ==================== 进入房间 ====================
func _enter_room(delta: float) -> void:
	# 进入动画/效果
	if target_door and target_door.has_method("open"):
		target_door.open()

	# 进入后开始腐蚀
	await get_tree().create_timer(1.0).timeout
	knocker_state = DoorKnockerState.CORRUPTING
	corruption_effect_active = true

	EventBus.notify("敲门鬼进入了！周围开始腐朽...", "danger")


# ==================== 腐蚀效果 ====================
func _corrupt_surroundings(delta: float) -> void:
	if not corruption_effect_active:
		return

	corruption_timer += delta

	# 每秒对范围内的玩家造成伤害
	if corruption_timer >= 1.0:
		corruption_timer = 0.0
		_apply_corruption_damage()

	# 同时追逐玩家
	if target != null:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * ghost_data.move_speed * 0.7
		move_and_slide()


func _apply_corruption_damage() -> void:
	# 对范围内的玩家造成伤害和SAN损失
	var players = get_tree().get_nodes_in_group("player")

	for player in players:
		if player is Player:
			var distance = global_position.distance_to(player.global_position)
			if distance <= corruption_radius:
				player.take_damage(corruption_damage)
				player.lose_sanity(3)


# ==================== 打断敲门（规律利用） ====================
func interrupt_knocking() -> void:
	"""打断敲门，重置计数"""
	if knocker_state == DoorKnockerState.KNOCKING:
		current_knock_count = 0
		rule_context["knock_count"] = 0
		knock_timer = 0.0

		EventBus.notify("打断了敲门鬼！", "success")
		EventBus.debug("敲门计数重置")

		# 被打断后短暂眩晕
		knocker_state = DoorKnockerState.APPROACHING_DOOR
		stun(2.0)


# ==================== 重写受伤逻辑 ====================
func _on_damaged(damage: int) -> void:
	super._on_damaged(damage)

	# 被攻击时如果正在敲门，有机会打断
	if knocker_state == DoorKnockerState.KNOCKING:
		if randf() < 0.7:  # 70%概率打断
			interrupt_knocking()


# ==================== 重写攻击逻辑 ====================
func _perform_attack() -> void:
	if target == null or not target.has_method("take_damage"):
		return

	# 敲门鬼的攻击：抓握
	target.take_damage(ghost_data.attack)

	if target is Player:
		target.lose_sanity(10)  # 额外SAN损失


# ==================== 状态进入/退出 ====================
func _enter_state(state: GhostState) -> void:
	super._enter_state(state)

	match state:
		GhostState.STUNNED:
			corruption_effect_active = false
			is_knocking = false


func _exit_state(state: GhostState) -> void:
	super._exit_state(state)


# ==================== 己方鬼技能 ====================
func _use_ability(ability: GhostAbility, ability_target: Node) -> void:
	match ability.id:
		"terrifying_knock":
			_ability_terrifying_knock(ability_target)
		"decay_touch":
			_ability_decay_touch(ability_target)
		_:
			super._use_ability(ability, ability_target)


func _ability_terrifying_knock(ability_target: Node) -> void:
	"""恐怖敲门 - 对目标造成伤害并降低其速度"""
	if ability_target == null:
		return

	if ability_target.has_method("take_damage"):
		ability_target.take_damage(int(ghost_data.attack * 1.5))

	if ability_target is GhostBase:
		# 对敌方鬼造成减速效果
		ability_target.ghost_data.speed = int(ability_target.ghost_data.speed * 0.7)

	EventBus.notify("%s 使用了恐怖敲门！" % ghost_data.display_name, "info")


func _ability_decay_touch(ability_target: Node) -> void:
	"""腐朽之触 - 造成持续伤害"""
	if ability_target == null:
		return

	# 造成初始伤害
	if ability_target.has_method("take_damage"):
		ability_target.take_damage(ghost_data.attack)

	# TODO: 添加持续伤害debuff

	EventBus.notify("%s 使用了腐朽之触！" % ghost_data.display_name, "info")
