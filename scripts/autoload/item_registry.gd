## ItemRegistry - 道具数据注册表
## 管理所有道具的数据，提供查询接口
extends Node

# 所有已注册的道具数据
var _items: Dictionary = {}  # {id: ItemData}

# 按类型分类的道具
var _items_by_type: Dictionary = {}  # {ItemType: [ids]}

# 资源路径
const ITEM_RESOURCE_PATH = "res://resources/items/"


func _ready() -> void:
	print("[ItemRegistry] 道具注册表已初始化")
	_load_all_items()
	_register_default_items()


## 加载所有道具资源
func _load_all_items() -> void:
	var dir = DirAccess.open(ITEM_RESOURCE_PATH)
	if dir == null:
		push_warning("[ItemRegistry] 无法打开道具资源目录: %s" % ITEM_RESOURCE_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_path = ITEM_RESOURCE_PATH + file_name
			var item_data = load(resource_path) as ItemData
			if item_data:
				register_item(item_data)

		file_name = dir.get_next()

	dir.list_dir_end()
	print("[ItemRegistry] 已加载 %d 种道具" % _items.size())


## 注册默认道具（代码中定义，用于快速测试）
func _register_default_items() -> void:
	if _items.size() > 0:
		return

	# 鬼烛 - 照明道具
	var ghost_candle = ItemData.new()
	ghost_candle.id = "ghost_candle"
	ghost_candle.display_name = "鬼烛"
	ghost_candle.description = "用特殊材料制成的蜡烛，能驱散鬼域中的黑暗。对惧光的鬼有特殊效果。"
	ghost_candle.item_type = ItemData.ItemType.LIGHT
	ghost_candle.target_type = ItemData.TargetType.AREA
	ghost_candle.rarity = 1
	ghost_candle.max_stack = 3
	ghost_candle.use_count = 1
	ghost_candle.light_radius = 150.0
	ghost_candle.duration = 60.0  # 持续60秒
	ghost_candle.damage = 10  # 对惧光的鬼造成伤害
	ghost_candle.buy_price = 50
	ghost_candle.sell_price = 20
	register_item(ghost_candle)

	# 坟土 - 封印道具
	var grave_soil = ItemData.new()
	grave_soil.id = "grave_soil"
	grave_soil.display_name = "坟土"
	grave_soil.description = "从古老坟墓中取得的泥土，蕴含着镇压亡灵的力量。用于封印和捕获鬼。"
	grave_soil.item_type = ItemData.ItemType.CAPTURE
	grave_soil.target_type = ItemData.TargetType.SINGLE_GHOST
	grave_soil.rarity = 1
	grave_soil.max_stack = 5
	grave_soil.use_count = 1
	grave_soil.capture_bonus = 0.2  # +20%捕获率
	grave_soil.damage = 15  # 对鬼造成伤害
	grave_soil.buy_price = 80
	grave_soil.sell_price = 30
	register_item(grave_soil)

	# 符水 - 恢复道具
	var talisman_water = ItemData.new()
	talisman_water.id = "talisman_water"
	talisman_water.display_name = "符水"
	talisman_water.description = "经过道士开光的清水，饮用后可以恢复精神和体力。"
	talisman_water.item_type = ItemData.ItemType.RECOVERY
	talisman_water.target_type = ItemData.TargetType.SELF
	talisman_water.rarity = 0
	talisman_water.max_stack = 5
	talisman_water.use_count = 1
	talisman_water.hp_restore = 30
	talisman_water.san_restore = 20
	talisman_water.buy_price = 30
	talisman_water.sell_price = 10
	register_item(talisman_water)

	# 红纸 - 防护道具
	var red_paper = ItemData.new()
	red_paper.id = "red_paper"
	red_paper.display_name = "红纸"
	red_paper.description = "遮眼用的红纸，可以暂时让鬼无法锁定你。但使用时你也看不见鬼。"
	red_paper.item_type = ItemData.ItemType.PROTECTION
	red_paper.target_type = ItemData.TargetType.SELF
	red_paper.rarity = 1
	red_paper.max_stack = 3
	red_paper.use_count = 1
	red_paper.duration = 10.0
	red_paper.effect_id = "invisible_to_ghosts"
	red_paper.buy_price = 60
	red_paper.sell_price = 25
	register_item(red_paper)

	# 棺材钉 - 高级封印道具
	var coffin_nail = ItemData.new()
	coffin_nail.id = "coffin_nail"
	coffin_nail.display_name = "棺材钉"
	coffin_nail.description = "从古老棺材上取下的铁钉，蕴含强大的镇压之力。对厉鬼有特效。"
	coffin_nail.item_type = ItemData.ItemType.CAPTURE
	coffin_nail.target_type = ItemData.TargetType.SINGLE_GHOST
	coffin_nail.rarity = 2
	coffin_nail.max_stack = 2
	coffin_nail.use_count = 1
	coffin_nail.capture_bonus = 0.35  # +35%捕获率
	coffin_nail.damage = 30
	coffin_nail.status_effect = "sealed"  # 封印状态
	coffin_nail.buy_price = 200
	coffin_nail.sell_price = 80
	register_item(coffin_nail)

	# 镇魂丹 - 高级恢复道具
	var soul_pill = ItemData.new()
	soul_pill.id = "soul_pill"
	soul_pill.display_name = "镇魂丹"
	soul_pill.description = "古方炼制的丹药，能大幅恢复精神状态，驱散心中的恐惧。"
	soul_pill.item_type = ItemData.ItemType.RECOVERY
	soul_pill.target_type = ItemData.TargetType.SELF
	soul_pill.rarity = 2
	soul_pill.max_stack = 3
	soul_pill.use_count = 1
	soul_pill.hp_restore = 50
	soul_pill.san_restore = 50
	soul_pill.status_effect = "clear_debuffs"
	soul_pill.buy_price = 150
	soul_pill.sell_price = 60
	register_item(soul_pill)

	# 鬼绳 - 驭鬼道具
	var ghost_rope = ItemData.new()
	ghost_rope.id = "ghost_rope"
	ghost_rope.display_name = "鬼绳"
	ghost_rope.description = "能够束缚鬼的特殊绳索，可以提高己方鬼的忠诚度。"
	ghost_rope.item_type = ItemData.ItemType.GHOST_BUFF
	ghost_rope.target_type = ItemData.TargetType.CONTROLLED_GHOST
	ghost_rope.rarity = 2
	ghost_rope.max_stack = 2
	ghost_rope.use_count = 1
	ghost_rope.loyalty_bonus = 20.0
	ghost_rope.buy_price = 120
	ghost_rope.sell_price = 50
	register_item(ghost_rope)

	print("[ItemRegistry] 已注册 %d 种默认道具" % _items.size())


## 注册一个道具
func register_item(item_data: ItemData) -> void:
	if item_data.id.is_empty():
		push_warning("[ItemRegistry] 尝试注册无ID的道具数据")
		return

	_items[item_data.id] = item_data

	# 按类型分类
	var type_key = item_data.item_type
	if not _items_by_type.has(type_key):
		_items_by_type[type_key] = []
	_items_by_type[type_key].append(item_data.id)

	EventBus.debug("注册道具: %s (%s)" % [item_data.display_name, item_data.id])


## 获取道具数据
func get_item(item_id: String) -> ItemData:
	return _items.get(item_id, null)


## 获取所有道具ID
func get_all_item_ids() -> Array:
	return _items.keys()


## 获取所有道具数据
func get_all_items() -> Array:
	return _items.values()


## 获取指定类型的道具ID列表
func get_items_by_type(item_type: ItemData.ItemType) -> Array:
	return _items_by_type.get(item_type, [])


## 随机获取一个道具（根据掉落权重）
func get_random_item(item_type: ItemData.ItemType = -1) -> ItemData:
	var pool: Array

	if item_type == -1:
		pool = _items.values()
	else:
		var ids = get_items_by_type(item_type)
		pool = ids.map(func(id): return _items[id])

	if pool.is_empty():
		return null

	# 根据掉落权重选择
	var total_weight = 0.0
	for item in pool:
		total_weight += item.drop_weight

	var roll = randf() * total_weight
	var current_weight = 0.0

	for item in pool:
		current_weight += item.drop_weight
		if roll <= current_weight:
			return item

	return pool[-1]


## 根据稀有度获取道具
func get_items_by_rarity(rarity: int) -> Array:
	var result: Array = []

	for item_data in _items.values():
		if item_data.rarity == rarity:
			result.append(item_data)

	return result


## 检查道具是否存在
func has_item(item_id: String) -> bool:
	return _items.has(item_id)
