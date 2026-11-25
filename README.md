# 应许之路（Path of Promise）

**轻写实微缩圣经历史策略叙事史诗（Godot 4.7 Forward+ / Mobile 跨端主力工程）**

玩家带领家族与同行者走过《创世记》至《撒母耳记下》的 20 个救赎历史节点（点亮 12 块立约见证石）。在严守圣经正典核心事实（公有领域经文：中文《和合本 CUV 1919》/ 英文《World English Bible WEB》）与纯正古黎凡特历史考据的前提下，融合 **族长亲临微操（羊角号集结 / 节拍蓄力协力）、第一人称陶土油灯船舱与主帐漫游、具名同伴特长词条与疲劳轮休、三槽实体工坊科技、`[Space]` 战术暂停与写实情境行动卡，以及历代志环境试炼词缀**。

---

## 📚 全库技术文档与剧情方案导航

- 👉 **[全库技术文档与剧情方案总索引（一站式入口）](./docs/DOCUMENTATION_INDEX.md)**
- **全战役顶层剧情总纲（20 节点：`Ch00` 诺亚方舟 → `Ch11` 锡安大卫之城）**：[design/FULL_CAMPAIGN_DESIGN_SPEC_V6.md](./design/FULL_CAMPAIGN_DESIGN_SPEC_V6.md)
- **Godot 4.7 通用卡带引擎与工业化技术总案（v6.0）**：[design/FULL_CAMPAIGN_TECHNICAL_ARCHITECTURE_V6.md](./design/FULL_CAMPAIGN_TECHNICAL_ARCHITECTURE_V6.md)
- **对标 Steam Top 10 可玩性拆解与 Gameplay 2.0 / 上架缺陷审计**：[docs/STEAM_TOP10_PLAYABILITY_AND_LAUNCH_AUDIT.md](./docs/STEAM_TOP10_PLAYABILITY_AND_LAUNCH_AUDIT.md)
- **Steam 商业发行、云存档/成就与 Steam Deck 绿标合规规范**：[design/STEAM_RELEASE_READINESS_SPEC.md](./design/STEAM_RELEASE_READINESS_SPEC.md)
- **五种玩法融合项目总案 & GDD**：[docs/PROJECT_PLAN.md](./docs/PROJECT_PLAN.md) · [docs/GDD.md](./docs/GDD.md)

---

## 🚀 快速运行与自动化商业 CI 门禁（主力工程 `godot-pilot/`）

环境要求：**Godot Engine `4.7.2-stable`**（桌面端 Vulkan `Forward+` / 移动端 `Mobile`）。

```powershell
# 1. 启动实时 3D 亚拉腊晨曦主菜单（可进入 Ch00 诺亚方舟 / P01 近东画卷 / Ch01 伯特利筑坛，并勾选历代志试炼词缀）
Godot_v4.7.2-stable_win64_console.exe --path godot-pilot

# 2. 运行全套 47 项商业无头 CI 门禁（JSON 事件图、<=350 行协调器红线、1000x 经济确定性、Gameplay 2.0 回放、骨骼动画与原子存档校验）
Godot_v4.7.2-stable_win64_console.exe --headless --path godot-pilot -s res://tests/run_ci.gd
```

### 核心模块目录（`godot-pilot/`）
- `scripts/core/`：跨 12 章共享的 V6 卡带核心层（`chapter_runtime_host.gd`、`deterministic_economy_sim.gd`、`gameplay_v2_director.gd`、`patriarch_player_3d.gd`、`world_physics_builder.gd`、`humanoid_rig_helper.gd`、`story_state_director.gd`）
- `scripts/ui/gameplay_v2_hud_bar.gd` & `scripts/prologue_ui_v3.gd`：双语自适应青铜日晷 HUD、3D 派工气泡、战术手牌坞、缩略图存档槽与移动端虚拟摇杆
- `data/` & `translations/messages.csv`：中英双语（`zh_CN` CUV / `en_US` WEB）事件图、考据手卷与全界面本地化表
- `resources/`：强类型章节数值配置（`ch00_balance.tres`、`ch01_balance.tres`）

---

## 🏛 历史原型归档说明（`src/`）

根目录下的 `src/`（Vite + TypeScript + Three.js）为早期 Web 系统验证原型，已按研发规范**冻结归档保留**（可通过 `npm install && npm run build` 独立构建参考），全部商业化战役研发统一在 `godot-pilot/` 中演进。
