## Player - 玩家控制角色
## 处理玩家移动、交互、状态等
class_name Player
extends CharacterBody2D

# ==================== 导出属性 ====================
@export_group("移动")
@export var move_speed: float = 150.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

@export_group("属性")
@export var max_hp: int = 100
@export var max_san: int = 100

# ==================== 节点引用 ====================
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea

# ==================== 状态变量 ====================
var current_hp: int = 100
var current_san: int = 100
var is_moving: bool = false
var facing_direction: Vector2 = Vector2.DOWN
var can_move: bool = true
var is_interacting: bool = false

# ==================== 交互相关 ====================
var interactable_objects: Array = []  # 可交互对象列表


func _ready() -> void:
	# 同步GameManager中的数据
	current_hp = GameManager.player_data.current_hp
	current_san = GameManager.player_data.current_san
	max_hp = GameManager.player_data.max_hp
	max_san = GameManager.player_data.max_san

	_connect_signals()


func _connect_signals() -> void:
	# 连接交互区域信号
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)


func _physics_process(delta: float) -> void:
	if not can_move:
		return

	_handle_movement(delta)
	_update_animation()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()

	if event.is_action_pressed("inventory"):
		EventBus.ui_inventory_toggle_requested.emit()


# ==================== 移动处理 ====================
func _handle_movement(delta: float) -> void:
	var input_direction = _get_input_direction()

	if input_direction != Vector2.ZERO:
		# 有输入时加速
		velocity = velocity.move_toward(input_direction * move_speed, acceleration * delta)
		facing_direction = input_direction
		is_moving = true
	else:
		# 无输入时减速
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		is_moving = velocity.length() > 10

	move_and_slide()

	# 发送位置更新事件
	if is_moving:
		EventBus.player_moved.emit(global_position)


func _get_input_direction() -> Vector2:
	var direction = Vector2.ZERO

	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1

	return direction.normalized()


# ==================== 动画处理 ====================
func _update_animation() -> void:
	if not animation_player:
		return

	var anim_name = "idle"

	if is_moving:
		anim_name = "walk"

	# 根据朝向添加方向后缀
	var direction_suffix = _get_direction_suffix()
	var full_anim_name = anim_name + "_" + direction_suffix

	# 如果动画存在则播放
	if animation_player.has_animation(full_anim_name):
		if animation_player.current_animation != full_anim_name:
			animation_player.play(full_anim_name)
	elif animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)


func _get_direction_suffix() -> String:
	# 根据朝向返回动画后缀
	if abs(facing_direction.x) > abs(facing_direction.y):
		if facing_direction.x > 0:
			return "right"
		else:
			return "left"
	else:
		if facing_direction.y > 0:
			return "down"
		else:
			return "up"


# ==================== HP和SAN管理 ====================
func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	GameManager.player_data.current_hp = current_hp
	EventBus.player_hp_changed.emit(current_hp, max_hp)

	# 受伤闪烁效果
	_flash_damage()

	if current_hp <= 0:
		_die()


func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	GameManager.player_data.current_hp = current_hp
	EventBus.player_hp_changed.emit(current_hp, max_hp)


func lose_sanity(amount: int) -> void:
	current_san = max(0, current_san - amount)
	GameManager.player_data.current_san = current_san
	EventBus.player_san_changed.emit(current_san, max_san)

	# SAN过低警告
	if current_san < 20:
		_trigger_low_sanity_effect()


func restore_sanity(amount: int) -> void:
	current_san = min(max_san, current_san + amount)
	GameManager.player_data.current_san = current_san
	EventBus.player_san_changed.emit(current_san, max_san)


func _flash_damage() -> void:
	# 受伤闪烁效果
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _trigger_low_sanity_effect() -> void:
	# SAN过低的视觉/音效效果
	EventBus.notify("精神状态危险...", "warning")
	# TODO: 添加屏幕扭曲、幻觉等效果


func _die() -> void:
	can_move = false
	EventBus.player_died.emit()
	# TODO: 死亡动画


# ==================== 交互系统 ====================
func _try_interact() -> void:
	if interactable_objects.is_empty():
		return

	# 获取最近的可交互对象
	var closest = _get_closest_interactable()
	if closest and closest.has_method("interact"):
		is_interacting = true
		closest.interact(self)
		is_interacting = false


func _get_closest_interactable() -> Node:
	if interactable_objects.is_empty():
		return null

	var closest: Node = null
	var closest_distance: float = INF

	for obj in interactable_objects:
		if not is_instance_valid(obj):
			continue

		var distance = global_position.distance_to(obj.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = obj

	return closest


func _on_interaction_area_entered(body: Node2D) -> void:
	if body.is_in_group("interactable"):
		interactable_objects.append(body)


func _on_interaction_area_exited(body: Node2D) -> void:
	interactable_objects.erase(body)


# ==================== 状态控制 ====================
func set_can_move(value: bool) -> void:
	can_move = value
	if not can_move:
		velocity = Vector2.ZERO


func freeze() -> void:
	set_can_move(false)


func unfreeze() -> void:
	set_can_move(true)


# ==================== 工具方法 ====================
func get_hp_ratio() -> float:
	return float(current_hp) / float(max_hp)


func get_san_ratio() -> float:
	return float(current_san) / float(max_san)


func is_alive() -> bool:
	return current_hp > 0
