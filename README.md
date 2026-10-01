# 神秘复苏：鬼域求生
## Mysterious Revival: Ghost Domain Survival

基于小说《神秘复苏》的 Godot 4.5 / GDScript Roguelike 驭鬼战斗学习项目，围绕鬼的行为规律、捕获与回合制战斗展开，仍有待开发功能。

[快速开始](#快速开始) · [游戏设计](docs/GAME_DESIGN.md) · [开发指南](docs/DEVELOPMENT_GUIDE.md)

## 快速开始

1. 克隆本仓库，安装 Godot 4.5（项目配置使用 Forward Plus 渲染器）。
2. 在 Godot 项目管理器中导入根目录的 `project.godot`。
3. 在编辑器中按 `F5` 运行配置的主场景 `scenes/main/main_menu.tscn`。

项目尚未提供公开在线试玩；源码运行需要 Godot 编辑器。

## 项目定位与第一次运行

这是 Godot / GDScript 学习原型。同名商业手游曾有 [TapTap 官方首发公告](https://www.taptap.cn/moment/464017863213060067)；该历史公告不代表当前下载或运营状态，本仓库也不提供手游账号、礼包码或安装包。

按快速开始导入后，从主菜单点击「开始游戏」，当前 [菜单脚本](scripts/ui/main_menu.gd) 会进入学校鬼域第一层。设置按钮目前只显示「设置功能开发中...」，没有设置界面。设计文档描述的是设计目标，完成情况请结合下面的待开发清单和源码查看。

## 从一个系统开始阅读

| 想学习的任务 | 阅读路径 | 建议观察 |
|---|---|---|
| 场景启动与事件传递 | [主菜单](scripts/ui/main_menu.gd) → [状态管理](scripts/autoload/game_manager.gd) → [事件总线](scripts/autoload/event_bus.gd) | 开始按钮怎样切换鬼域和场景 |
| 移动和交互 | [玩家](scripts/entities/player.gd) | 输入怎样触发移动、交互和背包请求；发出请求不等于完整 UI 已实现 |
| 捕获与鬼的行为 | [驭鬼系统](scripts/systems/ghost_control_system.gd) → [鬼基类](scripts/entities/ghost_base.gd) → [敲门鬼](scripts/entities/ghosts/door_knocker.gd) | 捕获条件、忠诚度和单个鬼的行为规律 |

先读 [游戏设计](docs/GAME_DESIGN.md) 理解鬼域与规律，再用 [开发指南](docs/DEVELOPMENT_GUIDE.md) 找类与扩展点。项目许可声明为「仅供学习使用」，仓库尚未附通用开源许可证文件。

## 游戏特色

- **驭鬼系统**：捕获鬼、培养忠诚度、指挥战斗
- **规律系统**：每种鬼都有独特的行为规律，发现并利用它们
- **回合制战斗**：策略性的驭鬼对战
- **像素风格**：复古的 2D 俯视角画面

## 技术栈

- Godot 4.x
- GDScript
- 像素风 2D 图形

## 项目结构

```
mysterious_revival/
├── project.godot          # Godot 项目配置
├── scenes/                # 场景文件
│   ├── main/             # 主场景（菜单等）
│   ├── ghost_domain/     # 鬼域场景
│   ├── entities/         # 实体场景（玩家、鬼、道具）
│   └── ui/               # UI 场景
├── scripts/              # 脚本文件
│   ├── autoload/         # 全局单例
│   │   ├── event_bus.gd       # 事件总线
│   │   ├── game_manager.gd    # 游戏状态管理
│   │   ├── ghost_registry.gd  # 鬼数据注册表
│   │   └── item_registry.gd   # 道具注册表
│   ├── entities/         # 实体脚本
│   │   ├── player.gd          # 玩家
│   │   ├── ghost_base.gd      # 鬼基类
│   │   └── ghosts/            # 具体鬼类型
│   │       ├── door_knocker.gd  # 敲门鬼
│   │       ├── ghost_baby.gd    # 鬼婴
│   │       └── sick_ghost.gd    # 病鬼
│   ├── systems/          # 游戏系统
│   │   ├── ghost_control_system.gd  # 驭鬼控制
│   │   └── battle_system.gd         # 战斗系统
│   ├── data/             # 数据类定义
│   │   ├── ghost_data.gd       # 鬼数据
│   │   ├── ghost_rule.gd       # 鬼的规律
│   │   ├── ghost_ability.gd    # 鬼的技能
│   │   └── item_data.gd        # 道具数据
│   └── ui/               # UI 脚本
│       ├── main_menu.gd        # 主菜单
│       └── hud.gd              # 游戏内 HUD
├── resources/            # 资源文件（.tres）
│   ├── ghosts/           # 鬼的数据资源
│   └── items/            # 道具数据资源
└── assets/               # 美术/音效资源
    ├── sprites/          # 精灵图
    ├── audio/            # 音效
    └── fonts/            # 字体
```

## 核心系统

### 1. 驭鬼系统 (GhostControlSystem)
- 捕获敌方鬼（HP低于阈值时）
- 管理己方鬼的忠诚度
- 指挥己方鬼进行战斗
- 忠诚度过低时鬼可能反叛

### 2. 规律系统 (GhostRule)
每种鬼都有独特的规律：
- **敲门鬼**：敲3次门后进入，打断可重置
- **鬼婴**：只在黑暗中移动，光照下静止
- **病鬼**：咳嗽暴露位置，触碰感染诅咒

### 3. 战斗系统 (BattleSystem)
- 回合制战斗
- 基于速度的行动顺序
- 技能系统（冷却、忠诚度要求）
- 捕获机会

## 操作说明

- **WASD/方向键**：移动
- **E**：交互
- **I**：发出背包切换请求（完整背包 UI 仍需结合当前实现确认）
- **ESC**：暂停

## 已实现的鬼

| 鬼名 | 等级 | 规律 |
|------|------|------|
| 敲门鬼 | 危险级 | 敲3次门进入，可打断重置 |
| 鬼婴 | 普通级 | 惧光，黑暗中快速移动 |
| 病鬼 | 危险级 | 咳嗽暴露位置，感染诅咒 |

## 已实现的道具

| 道具 | 类型 | 效果 |
|------|------|------|
| 鬼烛 | 照明 | 驱散黑暗，克制惧光鬼 |
| 坟土 | 封印 | 提高捕获成功率 |
| 符水 | 恢复 | 恢复 HP 和 SAN |
| 红纸 | 防护 | 暂时对鬼隐身 |
| 棺材钉 | 封印 | 高级封印道具 |
| 镇魂丹 | 恢复 | 大量恢复+清除debuff |
| 鬼绳 | 驭鬼 | 提升己方鬼忠诚度 |

## 下一步开发

- [ ] 完善战斗 UI
- [ ] 添加音效系统
- [ ] 实现道具使用逻辑
- [ ] 添加更多鬼域类型
- [ ] 实现存档系统
- [ ] 添加永久升级系统

## 开发者

学习项目，基于小说《神秘复苏》（作者：佛前献花）

## 许可

仅供学习使用

## 问题反馈与更新

遇到问题时，请在 [Issues](https://github.com/majiayu000/mysterious-revival/issues) 写明浏览器或编辑器版本、所用提交、复现步骤和报错文字。当前源码变化见 [提交记录](https://github.com/majiayu000/mysterious-revival/commits/main/)。
