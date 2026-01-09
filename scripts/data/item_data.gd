## ItemData - 道具数据资源类
## 定义游戏中所有道具的属性
@tool
class_name ItemData
extends Resource

# ==================== 道具类型枚举 ====================
enum ItemType {
	CAPTURE,     # 封印类 - 用于捕获鬼
	LIGHT,       # 照明类 - 驱散黑暗
	PROTECTION,  # 防护类 - 免疫伤害
	RECOVERY,    # 恢复类 - 恢复HP/SAN
	GHOST_BUFF,  # 驭鬼类 - 强化己方鬼
	CONSUMABLE,  # 消耗品 - 一次性使用
	KEY_ITEM     # 关键道具 - 剧情/解谜用
}

# ==================== 使用目标枚举 ====================
enum TargetType {
	SELF,           # 对自己使用
	SINGLE_GHOST,   # 对单个鬼使用
	ALL_GHOSTS,     # 对所有鬼使用
	CONTROLLED_GHOST,  # 对己方鬼使用
	AREA,           # 区域效果
	NONE            # 无需目标（被动效果）
}

# ==================== 基础信息 ====================
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

# ==================== 类型与稀有度 ====================
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var target_type: TargetType = TargetType.SELF
@export_enum("普通", "稀有", "史诗", "传说") var rarity: int = 0

# ==================== 使用限制 ====================
@export_group("使用限制")
@export var max_stack: int = 5  # 最大堆叠数量
@export var use_count: int = 1  # 可使用次数（-1为无限）
@export var cooldown: float = 0.0  # 冷却时间（秒）
@export var can_use_in_battle: bool = true  # 战斗中可用
@export var can_use_in_explore: bool = true  # 探索中可用

# ==================== 效果数值 ====================
@export_group("效果数值")
@export var hp_restore: int = 0  # 恢复HP
@export var san_restore: int = 0  # 恢复SAN
@export var damage: int = 0  # 造成伤害
@export var capture_bonus: float = 0.0  # 捕获成功率加成
@export var loyalty_bonus: float = 0.0  # 忠诚度加成
@export var duration: float = 0.0  # 效果持续时间（秒）

# ==================== 特殊效果 ====================
@export_group("特殊效果")
@export var effect_id: String = ""  # 特殊效果ID（用于脚本处理）
@export var light_radius: float = 0.0  # 照明范围
@export var status_effect: String = ""  # 施加的状态效果
@export var rule_reveal_chance: float = 0.0  # 揭示规律的概率

# ==================== 获取与价值 ====================
@export_group("获取")
@export var buy_price: int = 0  # 购买价格（0=不可购买）
@export var sell_price: int = 0  # 出售价格
@export var drop_weight: float = 1.0  # 掉落权重


## 获取道具类型名称
func get_type_name() -> String:
	match item_type:
		ItemType.CAPTURE:
			return "封印"
		ItemType.LIGHT:
			return "照明"
		ItemType.PROTECTION:
			return "防护"
		ItemType.RECOVERY:
			return "恢复"
		ItemType.GHOST_BUFF:
			return "驭鬼"
		ItemType.CONSUMABLE:
			return "消耗品"
		ItemType.KEY_ITEM:
			return "关键道具"
		_:
			return "未知"


## 获取稀有度颜色
func get_rarity_color() -> Color:
	match rarity:
		0:  # 普通
			return Color.WHITE
		1:  # 稀有
			return Color.CORNFLOWER_BLUE
		2:  # 史诗
			return Color.MEDIUM_PURPLE
		3:  # 传说
			return Color.GOLD
		_:
			return Color.GRAY


## 获取稀有度名称
func get_rarity_name() -> String:
	match rarity:
		0:
			return "普通"
		1:
			return "稀有"
		2:
			return "史诗"
		3:
			return "传说"
		_:
			return "未知"


## 检查是否可以使用
func can_use(context: Dictionary) -> bool:
	var in_battle = context.get("in_battle", false)

	if in_battle and not can_use_in_battle:
		return false
	if not in_battle and not can_use_in_explore:
		return false

	return true


## 获取效果描述
func get_effect_description() -> String:
	var effects: Array[String] = []

	if hp_restore > 0:
		effects.append("恢复 %d HP" % hp_restore)
	if san_restore > 0:
		effects.append("恢复 %d SAN" % san_restore)
	if damage > 0:
		effects.append("造成 %d 伤害" % damage)
	if capture_bonus > 0:
		effects.append("捕获率 +%d%%" % int(capture_bonus * 100))
	if light_radius > 0:
		effects.append("照明范围 %.0f" % light_radius)
	if duration > 0:
		effects.append("持续 %.1f 秒" % duration)

	if effects.is_empty():
		return description
	else:
		return "\n".join(effects)
