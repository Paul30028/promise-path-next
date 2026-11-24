# 《应许之路》Godot 4.7 工业化技术架构与重构实施规范

- **文档版本**：`v6.0`
- **引擎基准**：Godot Engine `4.7.2-stable`（桌面端 `Forward+` Vulkan / 移动端 `Mobile` 渲染器自适应）
- **主力工程根目录**：`c:\AI\gemini\promise-path-next\godot-pilot\`（原根目录 `src/` Web 栈冻结归档，不再修改或双写）
- **配套业务需求单**：[V6_MASTER_OVERHAUL_MODIFICATION_SPEC.md](file:///c:/AI/gemini/promise-path-next/design/V6_MASTER_OVERHAUL_MODIFICATION_SPEC.md)

---

## 1. 目标模块与目录架构（Clean Modular Layout）

为彻底终结 2,000 行巨石脚本（`camp_pilot.gd` / `ch00_noah_ark.gd`），全工程重构为**「数据层（Resources & JSON） + 纯逻辑仿真层（Deterministic Sim） + 3D 表现与物理层（Controllers & Prefabs） + 统一 UI/叙事壳层」**四层解耦结构：

```text
godot-pilot/
├── addons/                          # 已启用上游 MIT 插件：phantom_camera, godot_state_charts, dialogue_manager
├── assets/
│   ├── audio/                       # 商业合规音效与环境循环 (.wav / .ogg)
│   ├── cc0_models/                  # PolyHaven 自然崖壁/巨石/灌木扫描资产 (带碰撞预制)
│   ├── models/                      # 优化后角色/写实四足动物/方舟30段模型 (零废稿，单动物 <2.5MB)
│   └── textures/                    # PBR 材质贴图与 UI 羊皮卷/青铜图集
├── data/
│   ├── chapters/                    # 章节剧情事件与抉择配置 (ch00_noah_ark.json, ch01_bethel.json...)
│   └── dialogues/                   # Dialogue Manager .dialogue 脚本（支持中英双语键值）
├── resources/                       # 强类型 Godot Resource 配置 (.tres) — 严禁在脚本硬编码数值！
│   ├── chapter_balance_ch00.tres    # 伐木产出、建舟速率、木栅成本/HP、天象阈值
│   └── cast_profiles_ch00.tres      # 一家八口姓名、专长倍率、初始挂件配置
├── scenes/
│   ├── main_menu.tscn               # 游戏统一启动主入口 (project.godot -> run/main_scene)
│   ├── overworld_prologue.tscn      # 近东宏观战役画卷
│   ├── ch00_noah_ark.tscn           # 序章：挪亚方舟场景（含静态光照、NavigationRegion3D、StateChart）
│   ├── ch01_bethel_camp.tscn        # 第一章：示剑与伯特利营地
│   ├── prefabs/                     # 可视化预制体 (.tscn) — 严禁在代码里几百行 new() 拼装！
│   │   ├── actor_humanoid.tscn      # CharacterBody3D + Skeleton3D + AnimationTree + NavigationAgent3D
│   │   ├── actor_quadruped.tscn     # 四足写实动物预制体 + NavigationAgent3D
│   │   ├── choppable_tree.tscn      # 可砍伐歌斐木实体（含受击震颤 Tween + 倒树落叶粒子）
│   │   ├── world_hotspot.tscn       # Area3D 交互热区 + 呼吸金环
│   │   └── fp_oil_lamp.tscn         # 第一人称右手摇曳古陶橄榄油灯 Viewmodel + OmniLight3D
│   └── ui/
│       ├── hud_biblical_v3.tscn     # 青铜日晷 + 四徽章资源栏 + 右上正典手卷 + 自适应触控区
│       ├── tactical_bubbles.tscn    # [Space] 沙盘俯瞰 3D 建筑头顶加减人投射气泡
│       ├── codex_drawer.tscn        # [J] 正典经文与历史/玩法改编考据抽屉
│       └── pause_save_menu.tscn     # [ESC] 暂停、三槽位存读档、音量与中英切换
├── scripts/
│   ├── autoload/                    # 全局单例
│   │   ├── save_manager.gd          # 版本化原子存读档 + CampaignState 跨章继承
│   │   ├── async_scene_loader.gd    # ResourceLoader 多线程流式加载 + 羊皮卷过场
│   │   ├── input_router.gd          # InputMap 初始化、键鼠/手柄/触屏设备自动识别
│   │   └── audio_director.gd        # Master / Music / Ambience / SFX / InteriorReverb 五总线混音控制
│   ├── core/                        # 跨章节 100% 通用核心组件
│   │   ├── player_controller_3d.gd  # CharacterBody3D 第三/第一人称无缝切换 + 指针锁定 + 台阶攀爬
│   │   ├── rts_tactical_camera.gd   # PhantomCamera 驱动的跟随/沙盘俯瞰平滑切换 + 镜头微震 (Trauma)
│   │   ├── unit_worker_ai.gd        # 通用工人状态机 (伐木/搬运/锤建/熬漆/灭火/持盾守卫)
│   │   ├── raid_crisis_director.gd  # 多路袭击波次、士气结算与火把引燃木料堆危机
│   │   └── story_stage_director.gd  # 连接 StateChart + DialogueManager + JSON choices 的叙事引擎
│   └── chapters/                    # 薄章节胶水层（每章控制在 <= 350 行！）
│       └── ch00_noah_coordinator.gd # 仅负责绑定序章特有 30 段方舟显隐、登舟序列与彩虹触发
├── translations/
│   └── messages.csv                 # UTF-8 多语言表 (keys, zh_CN, en_US)
└── tests/
    └── run_ci.gd                    # godot --headless 自动化回归测试总入口（非零退出码阻断错误）
```

---

## 2. 核心系统技术方案与接口契约

### 2.1 纯函数经济与建造仿真内核（`DeterministicArkSim`）
遵循 `gamedev-core` 状态快照原则，所有资源、倒计时、火势与工程进度计算封装于无节点依赖的 `RefCounted` 类中，方便单测直接以 `1000x` 倍速验证数值平衡：

```gdscript
class_name ArkBalanceConfig
extends Resource

@export var total_days: float = 240.0
@export var tree_chop_hits: int = 4
@export var timber_per_log: int = 12
@export var build_timber_cost_per_worker_sec: float = 2.8
@export var build_pct_per_worker_sec: float = 1.35
@export var pitch_rate_per_worker_sec: float = 2.0
@export var provisions_rate_per_worker_sec: float = 1.6
@export var palisade_build_timber_cost: int = 40
@export var palisade_repair_timber_cost: int = 20
@export var palisade_max_hp: float = 300.0
@export var fire_burn_timber_per_sec: float = 3.5
```

- **和睦度工效曲线（Harmony Multiplier）**：
  $$\text{WorkMultiplier} = \text{clamp}\left(0.75 + \frac{\text{harmony} - 50}{100} \times 0.8, \; 0.75, \; 1.35\right)$$
- **可序列化快照**：提供 `to_dict() -> Dictionary` 与 `from_dict(d: Dictionary) -> void`，直接供 `SaveManager` 落盘。

### 2.2 物理碰撞层矩阵与标准角色控制器（`Physics & PlayerController3D`）
彻底废除手写 `clampf` 伪碰撞，统一启用 Godot 3D 物理层（Project Settings -> 3D Physics Layers）：

| Layer Bit | 名称 | 挂载对象 | 说明 |
| :--- | :--- | :--- | :--- |
| `Bit 1 (1)` | `TerrainGround` | 260×260m 高地 `StaticBody3D` (`ConcavePolygonShape3D`) | 所有角色、动物、雨滴碰撞地面 |
| `Bit 2 (2)` | `ArkAndStructures` | 方舟三层甲板/侧梯/栏杆、木栅、南村房屋、巨石、树干 | 阻挡角色穿模；相机弹簧臂 `SpringArm3D` 防穿墙检测 |
| `Bit 3 (4)` | `Actors` | 挪亚 `CharacterBody3D`、家人、村民、强人 | 胶囊体 `r=0.36m, h=1.72m`，配合 RVO 避障防叠人 |
| `Bit 4 (8)` | `Animals` | 10 只四足写实动物 | 独立层，登舟排队时互不卡死楼梯 |
| `Bit 5 (16)` | `InteractAreas` | `world_hotspot.tscn`、建筑派工点击体、船舱声学区 `Area3D` | 仅触发信号与射线拾取，不产生物理推挤 |

- **方舟精确碰撞生成**：在 [build_noahs_ark_glb.py](file:///c:/AI/gemini/promise-path-next/design/prologue-noah/build_noahs_ark_glb.py) 中同步输出简化静态碰撞网格组 `Ark_WalkableCollider-col`（包含三层实心甲板、北侧 `Z=-2.15` 两段斜坡梯面、四周船壁、栏杆与外侧登船跳板）；`CharacterBody3D` 设置 `floor_max_angle = deg_to_rad(46.0)` 与 `floor_snap_length = 0.35`，天然支持平顺上下三层木梯与跳板，零踏空、零穿栏杆！
- **CS2 级第一人称控制**：
  - 进入第一人称时调用 `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`，在 `_unhandled_input(event: InputEventMouseMotion)` 中直接以 `-event.relative.x * mouse_sens` 更新 Yaw、`-event.relative.y * mouse_sens` 更新 Pitch（无需按住鼠标键）；
  - 挂载 `fp_oil_lamp.tscn` 至 `Camera3D` 子节点 `(0.28, -0.26, -0.42)`，叠加基于水平速度的 Lissajous 步伐微摆：`offset = Vector2(sin(t*7.0)*0.012, abs(cos(t*7.0))*0.016) * speed_ratio`。

### 2.3 寻路避障与分层骨骼动画管线（`AI & AnimationTree`）
1. **动态烘焙导航网格（`NavigationRegion3D`）**：
   - 地面与方舟下层甲板、外跳板加入同一个 `NavigationMeshSourceGeometryData3D` 组，设置 `agent_radius = 0.42`、`agent_max_climb = 0.45`；
   - 所有家人、强人、动物挂载 `NavigationAgent3D`（`avoidance_enabled = true`, `radius = 0.48`），通过 `velocity_computed` 回调驱动移动，彻底解决跳板拥挤叠模。
2. **人物上下半身混合（`AnimationTree`）**：
   - 根节点使用 `AnimationNodeBlendTree`：`BaseLocomotion`（`Idle / Walk / Run` 一维 `BlendSpace1D`） → 经 `UpperBodyBlend`（`AnimationNodeBlend2`，骨骼遮罩勾选 `Spine, Chest, Neck, Head, UpperArm_L/R, Forearm_L/R`）混合上半身动作（扛原木、持圆盾、举火把、挥木槌），实现**边跑动边自然举盾/举火把**，消除全身硬切。
3. **写实动物自动四足绑骨与网格减面脚本（`design/prologue-noah/rig_and_optimize_animals.py`）**：
   - 使用 Python（`trimesh` / `pyfqmr` 或四边形聚类简化 + 1024px JPEG 贴图重打包）将 `CC0_Bull / Horse / Deer / Lion / Sheep_Grab3D.glb` 从 `12–24 MB` 压缩至 **`< 2.2 MB`（`6,000–10,000 tris`）**；
   - 自动注入 9 骨骼四足骨架（`Root -> Pelvis -> Spine -> Neck -> Head` + 四肢肩髋关节 `Leg_FL, Leg_FR, Leg_BL, Leg_BR`），按动物前后肢真实坐标分区赋权，生成对角步态 `Walk`（FL+BR 同相，FR+BL 反相）与舱内 `StallRest`（轻微呼吸 + 颈部缓抬低头）。

### 2.4 零泄漏资源加载与五总线空间声学（`Loader & AudioDirector`）
1. **根治 `GlbAssetLoader` 退出泄漏**：
   - 删除 [glb_asset_loader.gd](file:///c:/AI/gemini/promise-path-next/godot-pilot/scripts/glb_asset_loader.gd) 中持有未入树 `Node3D` 的 `static var _cache` 及运行时 `GLTFDocument.append_from_buffer()` 分支；
   - 100% 统一使用 `ResourceLoader.load(res_path, "PackedScene")`（自动复用引擎底层引用计数缓存与移动端 `ETC2/ASTC` 硬件压缩纹理），确保退出进程时 **0 ObjectDB instances leaked**。
2. **五总线混音与船舱隔音混响（`AudioServer` 布局）**：
   - 启动时由 `AudioDirector` 构建标准音频总线：
     - `Master`
       - `Music`
       - `Ambience`（挂载 `AudioEffectLowPassFilter`，默认 `cutoff_hz = 20000`）
       - `SFX_Exterior`（挂载同一低通滤波控制）
       - `SFX_Interior`（挂载 `AudioEffectReverb`：`room_size = 0.62, damping = 0.72, wet = 0.28`，营造厚重雪松木船共鸣腔）
       - `UI`
   - 方舟内部铺设 `ArkInteriorAcousticZone`（`Area3D`）：当摄像机进入舱内（或开启第一人称），`0.4s` 平滑 Tween 将 `Ambience` 与 `SFX_Exterior` 的 `cutoff_hz` 降至 **`780 Hz`**（外部暴雨狂雷立刻化作低沉闷响），同时渐入舱内 `AudioStreamPlayer3D`（船肋嘎吱木鸣声、油灯细微火苗声、各畜栏 3D 牛羊马呼吸声）。

### 2.5 版本化原子存档与国际化架构（`SaveManager & i18n`）
1. **原子存档格式（`user://saves/slot_{0..3}.json`）**：
   - 写入流程：序列化 JSON → 写入 `slot_0.json.tmp` → `FileAccess.flush()` → `DirAccess.rename_absolute("slot_0.json.tmp", "slot_0.json")`，杜绝闪退坏档。
   - 标准 Schema：
     ```json
     {
       "saveSchemaVersion": 2,
       "savedAtIso": "2026-11-24T10:00:00+08:00",
       "language": "zh_CN",
       "currentScene": "res://scenes/ch00_noah_ark.tscn",
       "campaignCarryover": {
         "noahCovenantWitnessed": true,
         "harmonyBonus": 6,
         "waterBonus": 0
       },
       "chapterState": {
         "chapterId": "ch00_noah_ark",
         "currentEventId": "noah_03_hull_decks",
         "daysRemaining": 148.5,
         "arkBuildPct": 52.4,
         "timber": 64,
         "pitch": 18,
         "provisions": 68,
         "harmony": 84,
         "palisadePct": 100.0,
         "palisadeHp": 245.0,
         "workers": {"log": 2, "build": 2, "pitch": 1, "guard": 2},
         "choiceHistory": ["noah_accept_blueprint", "keel_family_rotation"]
       }
     }
     ```
2. **中英双语国际化（`translations/messages.csv`）**：
   - 所有 UI 控件与系统提示禁止写死中文字符串，统一调用 `tr("UI_DAYS_TO_FLOOD") % days`；
   - 经文文本在 `.json` 中同时提供 `bodyZh`（公有领域和合本 CUV）与 `bodyEn`（公有领域英文 WEB 译本，规避现代商业译本版权限制），切换语言时通过信号 `SaveManager.locale_changed` 全场实时刷新，无需重启场景。

---

## 3. 四阶段绞杀者重构实施计划与 CI 验收门禁

为保证工程每一步都可随时双击运行试玩，严禁一次性推倒重来，按以下 **4 个独立可交付阶段（Phases A–D）** 推进：

| 阶段 | 核心交付物 | 自动化与实机验收门禁（全部通过方可进下一阶段） |
| :--- | :--- | :--- |
| **Phase A<br/>资产瘦身、动物四足绑骨与零泄漏底座** | 1. 清理 `assets/models` 重复历史废稿 GLB<br/>2. 运行 `rig_and_optimize_animals.py`：5 种写实动物减面至 `<2.5MB` 并注入 9 骨骼四足 `Idle/Walk/StallRest` 动画<br/>3. 修复 `GlbAssetLoader` 泄漏；建立 `tests/run_ci.gd` | • `models/` 总体积下降 `>60%`<br/>• 动物登舟四足真实交替迈步<br/>• `godot --headless -s tests/run_ci.gd` 退出码 `0` 且 **0 leaked instances** |
| **Phase B<br/>真实物理世界、CS2 第一人称提灯与空间声学** | 1. 地形 + 方舟 30 段脚手架模型（含 `-col` 三层甲板/北侧梯/栏杆精确碰撞）<br/>2. `PlayerController3D`（`CharacterBody3D` + 免按键直转第一人称 + 右手摇曳油灯 + `InputMap`）<br/>3. `NavigationRegion3D` 寻路避障 + 船舱五总线隔音混响与 3D 牲畜/木船音效 | • 第一人称移动鼠标直接 360° 环视，手持油灯照亮畜栏，绝不穿墙或踏空<br/>• 进出船舱风雨声隔音切换明显<br/>• 工程每涨 `3.3%` 脚手架内长出新船板 |
| **Phase C<br/>商业主菜单、存档系统与情节剧作真闭环** | 1. `main_menu.tscn` + `pause_save_menu.tscn` + `SaveManager` 原子存读档 + 串联「主菜单→挪亚→宏观画卷→第一章」<br/>2. 激活 `StateChart + DialogueManager + PhantomCamera` 驱动 `ch00_noah_ark.json` 全分支抉择，零瞬移过幕<br/>3. 一家八口具名化 + 四场核心名场面（晴空受嘲、按剑止戈、创7:16神手自动封门留白、提灯巡舱放鸽） | • 新开档→中途存档→关游戏重开→点“继续立约之旅”精确恢复建造进度与船体阶段<br/>• 四场名场面演出与 `harmony` 工效联动实机跑通 |
| **Phase D<br/>青铜日晷 UI V3、`[Space]` 沙盘气泡派工与双端适配** | 1. `hud_biblical_v3.tscn`（青铜日晷盘 + 四徽章资源栏 + 右上独立 `📜 正典考据手卷 [J]`）<br/>2. `[Space]` 沙盘俯瞰慢动作 + 3D 建筑头顶气泡直点派人 + 实体砍树搬木跳字 + 火把烧木救火危机 + 四幕天象递进<br/>3. `zh_CN / en_US` 双语切换 + `1920×1080` / `844×390` / `390×844` 触屏摇杆全适配 | • 字幕条零括号免责杂音，正典手卷独立可查<br/>• 桌面端与 `844×390` / `390×844` 移动端自动截图验收零重叠、按钮均 `>=44px` |
