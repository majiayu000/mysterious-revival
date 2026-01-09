## GhostRule - 鬼的规律资源类
## 定义鬼的行为规律，玩家需要发现并利用这些规律
@tool
class_name GhostRule
extends Resource

# ==================== 规律类型枚举 ====================
enum RuleType {
	BEHAVIOR,    # 行为规律 - 鬼的行动模式
	WEAKNESS,    # 弱点规律 - 可以被利用的弱点
	TRIGGER,     # 触发规律 - 特定条件触发的行为
	IMMUNITY     # 免疫规律 - 对某些攻击免疫
}

# ==================== 基础信息 ====================
@export var rule_id: String = ""  # 规律唯一ID
@export var rule_name: String = ""  # 规律名称（玩家可见）
@export_multiline var description: String = ""  # 规律描述
@export_multiline var hint: String = ""  # 给玩家的提示（未发现时显示???）
@export var rule_type: RuleType = RuleType.BEHAVIOR

# ==================== 发现条件 ====================
@export_group("发现条件")
@export var discovery_condition: String = ""  # 发现条件描述
@export var observation_count_required: int = 3  # 需要观察多少次才能发现
@export var discovery_san_cost: int = 5  # 发现规律消耗的SAN值

# ==================== 规律效果 ====================
@export_group("规律效果")
@export var trigger_condition: String = ""  # 触发条件（用于脚本判断）
@export var effect_description: String = ""  # 效果描述
@export var counter_method: String = ""  # 破解/利用方法

# ==================== 战斗加成 ====================
@export_group("战斗加成")
@export var damage_multiplier: float = 1.0  # 利用规律后的伤害倍率
@export var accuracy_bonus: float = 0.0  # 命中率加成
@export var stun_chance: float = 0.0  # 眩晕概率


## 检查是否满足触发条件
## context 是一个字典，包含当前战斗状态信息
func check_trigger(context: Dictionary) -> bool:
	match trigger_condition:
		"hp_below_50":
			return context.get("hp_ratio", 1.0) < 0.5
		"in_darkness":
			return context.get("light_level", 1.0) < 0.3
		"player_not_looking":
			return not context.get("player_looking", true)
		"door_knocked_3_times":
			return context.get("knock_count", 0) >= 3
		"near_mirror":
			return context.get("near_mirror", false)
		"turn_count_multiple_3":
			return context.get("turn_count", 0) % 3 == 0
		_:
			return false


## 获取规律类型名称
func get_type_name() -> String:
	match rule_type:
		RuleType.BEHAVIOR:
			return "行为"
		RuleType.WEAKNESS:
			return "弱点"
		RuleType.TRIGGER:
			return "触发"
		RuleType.IMMUNITY:
			return "免疫"
		_:
			return "未知"


## 获取显示文本（根据是否已发现）
func get_display_text(is_discovered: bool) -> String:
	if is_discovered:
		return description
	else:
		return "??? (需要更多观察)"


## 获取提示文本
func get_hint_text(is_discovered: bool) -> String:
	if is_discovered:
		return counter_method
	else:
		return hint if not hint.is_empty() else "继续观察这只鬼的行为..."
