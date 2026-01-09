# 开发指南 - 神秘复苏：鬼域求生

## 目录
1. [项目架构](#项目架构)
2. [核心系统详解](#核心系统详解)
3. [添加新鬼类型](#添加新鬼类型)
4. [添加新道具](#添加新道具)
5. [添加新鬼域](#添加新鬼域)
6. [战斗系统扩展](#战斗系统扩展)
7. [调试技巧](#调试技巧)

---

## 项目架构

### 文件结构
```
mysterious_revival/
├── scripts/
│   ├── autoload/          # 全局单例（自动加载）
│   │   ├── event_bus.gd   # 事件总线 - 解耦各系统
│   │   ├── game_manager.gd # 游戏状态管理
│   │   ├── ghost_registry.gd # 鬼数据注册
│   │   └── item_registry.gd  # 道具数据注册
│   ├── data/              # 数据类定义（Resource）
│   ├── entities/          # 实体脚本
│   └── systems/           # 游戏系统
├── scenes/                # 场景文件
├── resources/             # 资源文件（.tres）
└── assets/                # 美术/音效资源
```

### 核心设计模式

1. **事件驱动** - 通过 `EventBus` 单例实现系统间通信
2. **数据驱动** - 鬼/道具的属性通过 Resource 定义
3. **组件化** - 实体通过组合脚本实现功能

---

## 核心系统详解

### 1. EventBus（事件总线）
```gdscript
# 发送事件
EventBus.player_hp_changed.emit(current_hp, max_hp)

# 监听事件
EventBus.player_hp_changed.connect(_on_hp_changed)

# 发送通知（便捷方法）
EventBus.notify("发现了新规律！", "success")
```

**主要事件类型：**
- 游戏流程：`game_started`, `game_over`, `domain_entered`
- 玩家状态：`player_hp_changed`, `player_san_changed`, `player_died`
- 鬼相关：`ghost_spawned`, `ghost_captured`, `ghost_rule_discovered`
- 战斗：`battle_started`, `battle_ended`, `damage_dealt`
- 道具：`item_picked_up`, `item_used`

### 2. GameManager（游戏管理器）
```gdscript
# 切换游戏状态
GameManager.change_state(GameManager.GameState.IN_BATTLE)

# 修改玩家数据
GameManager.modify_hp(-10)  # 扣血
GameManager.modify_san(-5)  # 降SAN

# 开始鬼域
GameManager.start_domain("school", 1)  # 类型, 难度
```

### 3. GhostRegistry（鬼注册表）
```gdscript
# 获取鬼数据
var ghost_data = GhostRegistry.get_ghost("door_knocker")

# 随机获取一种鬼
var random_ghost = GhostRegistry.get_random_ghost(GhostData.GhostType.DANGEROUS)

# 获取所有鬼ID
var all_ids = GhostRegistry.get_all_ghost_ids()
```

### 4. ItemRegistry（道具注册表）
```gdscript
# 获取道具数据
var item = ItemRegistry.get_item("ghost_candle")

# 随机获取道具（基于权重）
var random_item = ItemRegistry.get_random_item(ItemData.ItemType.RECOVERY)
```

---

## 添加新鬼类型

### 步骤 1：创建鬼数据类（可选，使用默认数据）
在 `ghost_registry.gd` 的 `_register_default_ghosts()` 中添加：

```gdscript
# 新鬼示例：镜鬼
var mirror_ghost = GhostData.new()
mirror_ghost.id = "mirror_ghost"
mirror_ghost.display_name = "镜鬼"
mirror_ghost.description = "只能通过镜子反射攻击的鬼"
mirror_ghost.ghost_type = GhostData.GhostType.DANGEROUS
mirror_ghost.threat_level = 5
mirror_ghost.max_hp = 100
mirror_ghost.attack = 12
mirror_ghost.defense = 10
mirror_ghost.speed = 6
mirror_ghost.capture_difficulty = 0.5
register_ghost(mirror_ghost)
```

### 步骤 2：创建鬼脚本
在 `scripts/entities/ghosts/` 创建新脚本：

```gdscript
# mirror_ghost.gd
class_name MirrorGhost
extends GhostBase

func _ready() -> void:
    super._ready()
    _setup_rules()

func _setup_rules() -> void:
    # 添加规律
    var rule = GhostRule.new()
    rule.rule_id = "mirror_reflection"
    rule.rule_name = "镜像规律"
    rule.description = "只能通过镜子反射来攻击"
    rule.rule_type = GhostRule.RuleType.WEAKNESS
    rule.counter_method = "找到镜子，通过反射攻击"
    ghost_data.rules.append(rule)

# 重写特定行为...
func _perform_attack() -> void:
    # 自定义攻击逻辑
    pass
```

### 步骤 3：创建场景
复制 `ghost_base.tscn` 并修改：
- 更改脚本引用为新脚本
- 调整碰撞形状
- 添加特有节点

---

## 添加新道具

### 在 ItemRegistry 中注册
```gdscript
var new_item = ItemData.new()
new_item.id = "soul_lantern"
new_item.display_name = "魂灯"
new_item.description = "能看到隐藏的鬼"
new_item.item_type = ItemData.ItemType.LIGHT
new_item.target_type = ItemData.TargetType.SELF
new_item.rarity = 2  # 史诗
new_item.light_radius = 200.0
new_item.duration = 30.0
new_item.effect_id = "reveal_ghosts"  # 特殊效果ID
register_item(new_item)
```

### 实现特殊效果
在道具使用逻辑中检查 `effect_id` 并实现对应效果。

---

## 添加新鬼域

### 步骤 1：创建鬼域场景
1. 复制 `school_domain.tscn`
2. 修改地图布局
3. 配置生成的鬼和道具

### 步骤 2：添加到鬼域列表
在 `GameManager` 或专门的鬼域管理器中注册新鬼域。

### 鬼域结构
```
GhostDomain (Node2D)
├── TileMap           # 地图瓦片
├── Walls             # 墙壁碰撞
├── Player            # 玩家实例
├── Ghosts            # 鬼容器
├── Items             # 道具容器
├── Doors             # 门（可交互）
├── CanvasModulate    # 整体光照调整
└── DomainController  # 鬼域控制脚本
```

---

## 战斗系统扩展

### 添加新技能
1. 在 `GhostAbility` 资源中定义技能数据
2. 在鬼的脚本中实现 `_use_ability()` 方法

```gdscript
func _use_ability(ability: GhostAbility, target: Node) -> void:
    match ability.id:
        "new_skill":
            _ability_new_skill(target)
        _:
            super._use_ability(ability, target)

func _ability_new_skill(target: Node) -> void:
    # 实现技能逻辑
    pass
```

### 添加状态效果
1. 创建状态效果管理系统
2. 在战斗系统中调用状态效果

---

## 调试技巧

### 使用 EventBus.debug()
```gdscript
EventBus.debug("当前鬼数量: %d" % ghosts.size())
```
仅在调试模式下输出。

### 常用调试命令
在编辑器控制台或脚本中：
```gdscript
# 查看所有注册的鬼
print(GhostRegistry.get_all_ghost_ids())

# 查看玩家数据
print(GameManager.player_data)

# 强制触发事件
EventBus.ghost_rule_discovered.emit("door_knocker", "knock_pattern")
```

### 可视化调试
- 使用 `draw_*` 方法绘制碰撞区域
- 在鬼域中显示敌人检测范围

---

## 待开发功能清单

### 高优先级
- [ ] 完善战斗 UI（技能选择、目标选择）
- [ ] 道具使用逻辑
- [ ] 玩家精灵图和动画
- [ ] 鬼的精灵图和动画
- [ ] 基础音效

### 中优先级
- [ ] 存档系统
- [ ] 永久升级系统（Meta Progression）
- [ ] 更多鬼域类型
- [ ] 鬼图鉴 UI
- [ ] 规律笔记本 UI

### 低优先级
- [ ] 成就系统
- [ ] 排行榜
- [ ] 多语言支持
- [ ] 手柄支持

---

## 代码规范

### 命名约定
- 类名：PascalCase（`GhostBase`, `DoorKnocker`）
- 函数/变量：snake_case（`ghost_data`, `_on_damage`）
- 常量：UPPER_SNAKE_CASE（`MAX_HP`, `GHOST_RESOURCE_PATH`）
- 私有成员：前缀下划线（`_ghosts`, `_process_battle`）

### 注释规范
```gdscript
## 类的文档注释
class_name MyClass
extends Node

# 普通注释
var my_var: int = 0

## 函数文档注释
## @param target 目标节点
## @return 是否成功
func my_function(target: Node) -> bool:
    pass
```

---

## 资源推荐

### Godot 学习
- [Godot 官方文档](https://docs.godotengine.org/)
- [GDQuest 教程](https://www.gdquest.com/)

### 像素美术
- [Aseprite](https://www.aseprite.org/) - 像素画工具
- [Piskel](https://www.piskelapp.com/) - 免费在线像素画
- [OpenGameArt](https://opengameart.org/) - 免费素材

### 音效
- [Freesound](https://freesound.org/) - 免费音效
- [BFXR](https://www.bfxr.net/) - 复古音效生成器
