## GhostAbility - 鬼的技能资源类
## 定义鬼在战斗中可以使用的技能
@tool
class_name GhostAbility
extends Resource

# ==================== 技能类型枚举 ====================
enum AbilityType {
	ATTACK,      # 攻击技能
	DEBUFF,      # 减益技能
	BUFF,        # 增益技能
	SPECIAL,     # 特殊技能
	PASSIVE      # 被动技能
}

# ==================== 目标类型枚举 ====================
enum TargetType {
	SINGLE_ENEMY,   # 单个敌人
	ALL_ENEMIES,    # 所有敌人
	SINGLE_ALLY,    # 单个友方
	ALL_ALLIES,     # 所有友方
	SELF,           # 自身
	RANDOM          # 随机目标
}

# ==================== 基础信息 ====================
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

# ==================== 类型 ====================
@export var ability_type: AbilityType = AbilityType.ATTACK
@export var target_type: TargetType = TargetType.SINGLE_ENEMY

# ==================== 使用条件 ====================
@export_group("使用条件")
@export var cooldown_turns: int = 0  # 冷却回合数
@export var loyalty_required: float = 0.0  # 需要的最低忠诚度
@export var hp_cost_percent: float = 0.0  # HP消耗百分比
@export var san_damage_to_player: int = 0  # 对玩家造成的SAN伤害

# ==================== 伤害与效果 ====================
@export_group("效果数值")
@export var base_damage: int = 0  # 基础伤害
@export var damage_multiplier: float = 1.0  # 伤害倍率（基于攻击力）
@export var accuracy: float = 1.0  # 命中率
@export var critical_chance: float = 0.1  # 暴击率
@export var critical_multiplier: float = 1.5  # 暴击倍率

# ==================== 状态效果 ====================
@export_group("状态效果")
@export var status_effect: String = ""  # 施加的状态效果ID
@export var status_chance: float = 0.0  # 状态效果触发概率
@export var status_duration: int = 0  # 状态持续回合

# ==================== 特殊效果 ====================
@export_group("特殊效果")
@export var heal_percent: float = 0.0  # 治疗百分比
@export var defense_modifier: float = 0.0  # 防御修正
@export var speed_modifier: float = 0.0  # 速度修正
@export var special_effect_id: String = ""  # 特殊效果ID

# ==================== AI使用权重 ====================
@export_group("AI")
@export var ai_priority: float = 1.0  # AI使用优先级
@export var ai_hp_threshold: float = 1.0  # AI在HP低于此比例时优先使用


## 计算实际伤害
func calculate_damage(attacker_attack: int, target_defense: int) -> int:
	var raw_damage = base_damage + int(attacker_attack * damage_multiplier)
	var final_damage = max(1, raw_damage - target_defense)
	return final_damage


## 检查是否暴击
func roll_critical() -> bool:
	return randf() < critical_chance


## 检查是否命中
func roll_hit() -> bool:
	return randf() < accuracy


## 检查是否触发状态效果
func roll_status_effect() -> bool:
	return randf() < status_chance


## 获取技能类型名称
func get_type_name() -> String:
	match ability_type:
		AbilityType.ATTACK:
			return "攻击"
		AbilityType.DEBUFF:
			return "减益"
		AbilityType.BUFF:
			return "增益"
		AbilityType.SPECIAL:
			return "特殊"
		AbilityType.PASSIVE:
			return "被动"
		_:
			return "未知"


## 获取技能完整描述
func get_full_description() -> String:
	var parts: Array[String] = []

	parts.append(description)
	parts.append("")  # 空行

	if base_damage > 0 or damage_multiplier > 0:
		parts.append("伤害: %d + %.0f%% 攻击力" % [base_damage, damage_multiplier * 100])

	if accuracy < 1.0:
		parts.append("命中率: %.0f%%" % (accuracy * 100))

	if critical_chance > 0:
		parts.append("暴击率: %.0f%% (%.1fx)" % [critical_chance * 100, critical_multiplier])

	if status_effect != "" and status_chance > 0:
		parts.append("%.0f%% 概率施加 [%s] %d 回合" % [status_chance * 100, status_effect, status_duration])

	if cooldown_turns > 0:
		parts.append("冷却: %d 回合" % cooldown_turns)

	if loyalty_required > 0:
		parts.append("需要忠诚度: %.0f" % loyalty_required)

	return "\n".join(parts)
