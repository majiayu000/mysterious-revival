## GhostData - 鬼的数据资源类
## 定义一种鬼的所有静态属性
@tool
class_name GhostData
extends Resource

# ==================== 鬼的等级枚举 ====================
enum GhostType {
	NORMAL,     # 普通级 - 容易对付
	DANGEROUS,  # 危险级 - 需要策略
	DISASTER,   # 灾难级 - 极度危险
	CALAMITY    # 大灾难级 - Boss级别
}

# ==================== 基础信息 ====================
@export var id: String = ""  # 唯一标识符
@export var display_name: String = ""  # 显示名称
@export_multiline var description: String = ""  # 描述
@export_multiline var backstory: String = ""  # 背景故事

# ==================== 视觉资源 ====================
@export var sprite: Texture2D  # 精灵图
@export var portrait: Texture2D  # 头像（用于UI）
@export var animation_frames: SpriteFrames  # 动画帧

# ==================== 等级与稀有度 ====================
@export var ghost_type: GhostType = GhostType.NORMAL
@export_range(1, 10) var threat_level: int = 1  # 威胁等级

# ==================== 基础属性 ====================
@export_group("基础属性")
@export var max_hp: int = 100
@export var attack: int = 10
@export var defense: int = 5
@export var speed: int = 5  # 影响行动顺序
@export var move_speed: float = 50.0  # 移动速度（像素/秒）

# ==================== 驭鬼相关 ====================
@export_group("驭鬼属性")
@export_range(0.0, 1.0) var capture_difficulty: float = 0.5  # 捕获难度
@export var capture_hp_threshold: float = 0.3  # HP低于此比例才能捕获
@export var base_loyalty: float = 50.0  # 被捕获后的初始忠诚度
@export var loyalty_decay_rate: float = 1.0  # 忠诚度衰减速率（每回合）

# ==================== 规律相关 ====================
@export_group("规律")
@export var rules: Array[Resource] = []  # GhostRule 数组

# ==================== 技能相关 ====================
@export_group("技能")
@export var abilities: Array[Resource] = []  # GhostAbility 数组

# ==================== 掉落相关 ====================
@export_group("掉落")
@export var drop_items: Array[String] = []  # 可掉落的道具ID
@export var drop_chance: float = 0.3  # 掉落概率

# ==================== AI行为 ====================
@export_group("AI行为")
@export var aggression: float = 0.5  # 攻击性 (0-1)
@export var patrol_radius: float = 100.0  # 巡逻范围
@export var detection_radius: float = 150.0  # 检测玩家的范围


## 获取鬼的等级名称
func get_type_name() -> String:
	match ghost_type:
		GhostType.NORMAL:
			return "普通级"
		GhostType.DANGEROUS:
			return "危险级"
		GhostType.DISASTER:
			return "灾难级"
		GhostType.CALAMITY:
			return "大灾难级"
		_:
			return "未知"


## 获取鬼的等级颜色
func get_type_color() -> Color:
	match ghost_type:
		GhostType.NORMAL:
			return Color.WHITE
		GhostType.DANGEROUS:
			return Color.YELLOW
		GhostType.DISASTER:
			return Color.ORANGE_RED
		GhostType.CALAMITY:
			return Color.DARK_RED
		_:
			return Color.GRAY


## 计算捕获成功率
func calculate_capture_rate(current_hp_ratio: float, capture_item_bonus: float = 0.0) -> float:
	if current_hp_ratio > capture_hp_threshold:
		return 0.0  # HP太高无法捕获

	var base_rate = (1.0 - capture_difficulty) * 0.5
	var hp_bonus = (capture_hp_threshold - current_hp_ratio) * 0.5
	var total_rate = base_rate + hp_bonus + capture_item_bonus

	return clamp(total_rate, 0.0, 0.95)  # 最高95%成功率


## 验证数据完整性
func validate() -> bool:
	if id.is_empty():
		push_warning("GhostData: id 不能为空")
		return false
	if display_name.is_empty():
		push_warning("GhostData: display_name 不能为空")
		return false
	if max_hp <= 0:
		push_warning("GhostData: max_hp 必须大于0")
		return false
	return true
