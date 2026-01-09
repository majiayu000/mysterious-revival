## GhostRegistry - 鬼数据注册表
## 管理所有鬼的数据，提供查询接口
extends Node

# 所有已注册的鬼数据
var _ghosts: Dictionary = {}  # {id: GhostData}

# 按类型分类的鬼
var _ghosts_by_type: Dictionary = {}  # {GhostType: [ids]}

# 资源路径
const GHOST_RESOURCE_PATH = "res://resources/ghosts/"


func _ready() -> void:
	print("[GhostRegistry] 鬼数据注册表已初始化")
	_load_all_ghosts()
	_register_default_ghosts()


## 加载所有鬼资源
func _load_all_ghosts() -> void:
	var dir = DirAccess.open(GHOST_RESOURCE_PATH)
	if dir == null:
		push_warning("[GhostRegistry] 无法打开鬼资源目录: %s" % GHOST_RESOURCE_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_path = GHOST_RESOURCE_PATH + file_name
			var ghost_data = load(resource_path) as GhostData
			if ghost_data and ghost_data.validate():
				register_ghost(ghost_data)

		file_name = dir.get_next()

	dir.list_dir_end()
	print("[GhostRegistry] 已加载 %d 种鬼" % _ghosts.size())


## 注册默认的鬼（代码中定义，用于快速测试）
func _register_default_ghosts() -> void:
	# 如果已经从资源加载了鬼，跳过默认注册
	if _ghosts.size() > 0:
		return

	# 敲门鬼
	var door_knocker = GhostData.new()
	door_knocker.id = "door_knocker"
	door_knocker.display_name = "敲门鬼"
	door_knocker.description = "一个身穿黑色长衫，浑身布满尸斑的老人。他会站在门外不断敲门，敲门声有着诡异的节奏。"
	door_knocker.backstory = "据说是一位孤独死去的老人，生前总是渴望有人来访。死后化为厉鬼，永远在寻找下一个'客人'。"
	door_knocker.ghost_type = GhostData.GhostType.DANGEROUS
	door_knocker.threat_level = 4
	door_knocker.max_hp = 120
	door_knocker.attack = 15
	door_knocker.defense = 8
	door_knocker.speed = 3
	door_knocker.capture_difficulty = 0.6
	door_knocker.capture_hp_threshold = 0.25
	door_knocker.base_loyalty = 40.0
	register_ghost(door_knocker)

	# 鬼婴
	var ghost_baby = GhostData.new()
	ghost_baby.id = "ghost_baby"
	ghost_baby.display_name = "鬼婴"
	ghost_baby.description = "一个浑身惨白、双眼漆黑的婴儿形态厉鬼。只在黑暗中行动，光照下会静止不动。"
	ghost_baby.backstory = "夭折婴儿的怨念所化，对生者充满嫉妒与渴望。"
	ghost_baby.ghost_type = GhostData.GhostType.NORMAL
	ghost_baby.threat_level = 2
	ghost_baby.max_hp = 60
	ghost_baby.attack = 20
	ghost_baby.defense = 3
	ghost_baby.speed = 8
	ghost_baby.move_speed = 80.0
	ghost_baby.capture_difficulty = 0.3
	ghost_baby.capture_hp_threshold = 0.4
	ghost_baby.base_loyalty = 60.0
	register_ghost(ghost_baby)

	# 病鬼
	var sick_ghost = GhostData.new()
	sick_ghost.id = "sick_ghost"
	sick_ghost.display_name = "病鬼"
	sick_ghost.description = "一个面色苍白、不断咳嗽的鬼。咳嗽声会暴露它的位置，但被它触碰会感染诅咒。"
	sick_ghost.backstory = "因病痛折磨而死的人所化，将生前的痛苦带给每一个遇见它的人。"
	sick_ghost.ghost_type = GhostData.GhostType.DANGEROUS
	sick_ghost.threat_level = 3
	sick_ghost.max_hp = 80
	sick_ghost.attack = 8
	sick_ghost.defense = 5
	sick_ghost.speed = 4
	sick_ghost.capture_difficulty = 0.4
	sick_ghost.capture_hp_threshold = 0.35
	sick_ghost.base_loyalty = 55.0
	register_ghost(sick_ghost)

	print("[GhostRegistry] 已注册 %d 种默认鬼" % _ghosts.size())


## 注册一个鬼
func register_ghost(ghost_data: GhostData) -> void:
	if ghost_data.id.is_empty():
		push_warning("[GhostRegistry] 尝试注册无ID的鬼数据")
		return

	_ghosts[ghost_data.id] = ghost_data

	# 按类型分类
	var type_key = ghost_data.ghost_type
	if not _ghosts_by_type.has(type_key):
		_ghosts_by_type[type_key] = []
	_ghosts_by_type[type_key].append(ghost_data.id)

	EventBus.debug("注册鬼: %s (%s)" % [ghost_data.display_name, ghost_data.id])


## 获取鬼数据
func get_ghost(ghost_id: String) -> GhostData:
	return _ghosts.get(ghost_id, null)


## 获取所有鬼ID
func get_all_ghost_ids() -> Array:
	return _ghosts.keys()


## 获取所有鬼数据
func get_all_ghosts() -> Array:
	return _ghosts.values()


## 获取指定类型的鬼ID列表
func get_ghosts_by_type(ghost_type: GhostData.GhostType) -> Array:
	return _ghosts_by_type.get(ghost_type, [])


## 随机获取一个鬼
func get_random_ghost(ghost_type: GhostData.GhostType = -1) -> GhostData:
	var pool: Array

	if ghost_type == -1:
		pool = _ghosts.values()
	else:
		var ids = get_ghosts_by_type(ghost_type)
		pool = ids.map(func(id): return _ghosts[id])

	if pool.is_empty():
		return null

	return pool[randi() % pool.size()]


## 根据威胁等级范围获取鬼
func get_ghosts_by_threat_range(min_threat: int, max_threat: int) -> Array:
	var result: Array = []

	for ghost_data in _ghosts.values():
		if ghost_data.threat_level >= min_threat and ghost_data.threat_level <= max_threat:
			result.append(ghost_data)

	return result


## 检查鬼是否存在
func has_ghost(ghost_id: String) -> bool:
	return _ghosts.has(ghost_id)
