# 《应许之路》工程架构、双模态交互与叙事剧作体检归档（M0 → M1.5 演进记录）

- **状态（Status）**：`全部 8 项底层架构病灶与 4 大软实力断层已在 M0 + M1.5 + Phase A 闭环解决`
- **关联索引**：[返回全库文档总索引](../DOCUMENTATION_INDEX.md)

---

## 一、底层工程八大病灶闭环对照表

| 编号 | 重构前病灶（原型期） | M0 + M1.5 + Phase A 商业架构落地方案 | 对应代码模块 |
| :---: | :--- | :--- | :--- |
| **01** | 单文件 2,400+ 行巨石脚本（`camp_pilot.gd` / `ch00_noah_ark.gd`）且硬编码数值 | 抽离通用宿主 `ChapterRuntimeHost`、纯函数仿真 `DeterministicEconomySim` 与 `.tres` 资源表；双章协调器严格压至 `<= 350` 行（344 行 / 230 行） | [chapter_runtime_host.gd](../../godot-pilot/scripts/core/chapter_runtime_host.gd)、[deterministic_economy_sim.gd](../../godot-pilot/scripts/core/deterministic_economy_sim.gd) |
| **02** | 全场景零物理碰撞体，仅靠数学公式算高度 | 实装 5 层 3D 物理矩阵（`TerrainGround` / `ArkAndStructures` / `Actors` / `Animals` / `InteractAreas`）、`CharacterBody3D` 胶囊爬梯与方舟三层实体碰撞 | [patriarch_player_3d.gd](../../godot-pilot/scripts/core/patriarch_player_3d.gd)、[world_physics_builder.gd](../../godot-pilot/scripts/core/world_physics_builder.gd) |
| **03** | 零 `.tscn` 预制体且同步阻塞切关 | 建立 `fp_oil_lamp.tscn`、`world_hotspot.tscn`、`hud_biblical_v3.tscn` 预制体，并接入 `ResourceLoader.load_threaded_request` 异步过场加载 | [scene_transition.gd](../../godot-pilot/scripts/scene_transition.gd) |
| **04** | 运行时 `GLTFDocument` 绕过显存压缩并导致退出泄漏 | 全面改为编辑器预导入 `PackedScene`，彻底消除静态孤立节点缓存 | [glb_asset_loader.gd](../../godot-pilot/scripts/glb_asset_loader.gd) |
| **05** | 无主菜单、无磁盘存档、跨章流程断裂 | 实装实时 3D 亚拉腊晨曦主菜单、`CampaignSaveV3` 原子防坏档写入、`240×135` 缩略图槽位与跨章 `carryover_ledger` 继承 | [main_menu.gd](../../godot-pilot/scripts/main_menu.gd)、[save_manager.gd](../../godot-pilot/scripts/save_manager.gd) |
| **06** | 动物无骨骼静态平移且模型目录膨胀逾 180 MB | 5 类四足写实动物（牛/羊/马/鹿/狮）完成 9 骨骼绑定与网格减面（`114 MB → 8.37 MB`），清理全部重复废稿 GLB | [humanoid_rig_helper.gd](../../godot-pilot/scripts/core/humanoid_rig_helper.gd) |
| **07** | 中文字符串硬编码，海外市场无法本地化 | 全量接入 `TranslationServer`（`messages.csv` 中英双语表）与公有领域经文（中文和合本 `CUV 1919` / 英文 `WEB`）一键热切换 | [messages.csv](../../godot-pilot/translations/messages.csv) |
| **08** | 缺乏自动化回归门禁 | 建立 47 项商业无头 CI 套件（JSON 事件图连通性、行数红线、1000x 经济确定性、Gameplay 2.0 回放、骨骼动画、存档往返） | [run_ci.gd](../../godot-pilot/tests/run_ci.gd) |

---

## 二、序章《诺亚方舟与彩虹之约》五拍史诗剧作结构（严守正典红线）

| 戏剧节拍 | 经文正典锚点（不可篡改） | 可玩人性冲突与角色弧光编排 |
| :--- | :--- | :--- |
| **第一拍：孤寂领命** | 创 6:13–14 地上满了强暴，神命造三百肘方舟 | 隐藏经营 HUD，寂静山脊上白发挪亚跪祷领命，天光落下定立三百肘龙骨基桩 |
| **第二拍：晴空嘲笑** | 来 11:7 “挪亚因着信，既蒙神指示他未见的事……” | 烈日晴空下雇工离去、乡邻哄笑；次子**含**擦汗动摇、**挪亚之妻**递水抚慰，抉择直接联动全家 `信心效率乘区（0.75x–1.35x）` |
| **第三拍：义人止戈** | 创 6:9, 11 “挪亚是个义人……地上满了强暴” | 暮色中强人分南路与东南侧翼举火把袭扰木料堆；挪亚按剑止戈，率家人在南坡立起木栅盾阵或开仓分粮非致命退敌，并赴山泉提水扑救火情 |
| **第四拍：百兽归舟与神手封门** | 创 7:7–16 洁净与不洁净活物成双入舟，“耶和华就把他关在方舟里头” | 暴雨倾盆，一家八口具名角色与成双写实牛羊马鹿狮沿跳板入舱；全员进舱后**无需玩家按键，侧门轰然自动封死，5 秒全黑静默留白浮现《创 7:16》** |
| **第五拍：渊面堵漏与新叶破晓** | 创 8:1–20；9:12–17 鸽子衔回新拧橄榄叶，筑坛献祭，彩虹永约 | 第一人称提陶油灯巡视三层船舱、涂抹松香封堵下舱渗水缝，登三层一肘透光窗放飞白鸽；水退后全员于亚拉腊山十二石祭坛俯伏感恩（零功利计分），仰望彩虹永约 |
