# 《应许之路》(Path of Promise) 全库技术文档与剧情方案总索引

本索引汇总仓库内全部 **全战役 20 节点剧情策划、圣经正典考据边界、Godot 4.7 工业化通用卡带架构、Gameplay 2.0 可玩性方案与 Steam 商业上架规范**，便于团队研发、叙事审校与发行准备一站式查阅。

---

## 一、全战役顶层剧情总纲与分章剧本方案（Story & Narrative Plans）

1. **[《应许之路》全章总策划与全季 20 节点设计规范（v6.0 定案）](../design/FULL_CAMPAIGN_DESIGN_SPEC_V6.md)**
   - 覆盖《创世记》6 章至《撒母耳记下》7 章（大卫之约）完整救赎历史脉络：**12 个重度 3D 主章（`Ch00–Ch11`）+ 1 个可玩画卷序章（`P01`）+ 7 个纪年画卷桥接（`B01–B07`）**；
   - 定义四大核心玩法原型（圣工宏建型 / 族长建营外交型 / 大迁徙神迹渡河型 / 古近东奇袭高地战术型）、四条神学与历史红线及跨章存档继承（`Carryover`）总表。
2. **[序章《诺亚方舟与彩虹之约》故事与正典边界规范](../design/prologue-noah/PROLOGUE_NOAH_STORY_SPEC.md)**
   - 创世记 6–9 章八幕叙事结构、三百肘（`300×50×30` 肘）三层分间工程考据、一家八口庄重称谓规范与“神手封门（创 7:16）”留白演出准则。
3. **[三层宏观历史地理与世界画卷规范](../design/WORLD_MAP_SYSTEM_SPEC.md)**
   - 新月沃地（两河流域吾珥 → 哈兰 → 迦南山地 → 尼罗河歌珊 → 西乃旷野）地理坐标映射与画卷运镜规范。
4. **[第一章《示剑与伯特利筑坛》128×96 七分区关卡规格](../design/level-01/LEVEL01_MAP_SPEC.md)** & **[伯特利战役剧本与分地分支设计](./features/bethel-campaign/design.md)** · **[商队贸易、行装与线索系统](./features/bethel-campaign/trade-gear-clues.md)**
5. **[经文与古近东历史考据审阅底稿](./STORY_HISTORY.md)** · **[灵力与呼召系统经文审阅稿](./SPIRIT_SCRIPTURE_NOTES.md)** · **[首章分镜原稿](./STORYBOARD.md)**
6. **实机双语剧情与考据手卷数据表（CUV 1919 / WEB 公有领域经文）**：
   - 序章诺亚方舟：[ch00_noah_ark.json](../godot-pilot/data/ch00_noah_ark.json)
   - 宏观画卷巴别与出吾珥：[ch00_ur_call.json](../godot-pilot/data/ch00_ur_call.json)
   - 第一章示剑与伯特利：[ch01_bethel.json](../godot-pilot/data/ch01_bethel.json)
   - 全界面中英双语翻译母表：[messages.csv](../godot-pilot/translations/messages.csv)

---

## 二、Godot 4.7 工业化通用技术架构（Technical Architecture Specs）

1. **[《应许之路》全章通用引擎架构与工业化研发技术总案（v6.0）](../design/FULL_CAMPAIGN_TECHNICAL_ARCHITECTURE_V6.md)**
   - 「1 个通用宿主内核（`ChapterRuntimeHost`）+ 20 张章节数据卡带」插槽架构、四大玩法引擎子系统、共享角色/动物骨骼资产池与安装包预算（`< 450 MB`）。
2. **[Godot 4.7 物理层、五总线混响、异步加载与无头 CI 实施细则](../design/GODOT_TECHNICAL_ARCHITECTURE_SPEC.md)**
3. **[V6 核心体验、界面、双模态操控与剧作重构修改总单](../design/V6_MASTER_OVERHAUL_MODIFICATION_SPEC.md)**
4. **[项目总方案（五种可复用玩法融合决策）](./PROJECT_PLAN.md)** · **[游戏设计总纲（GDD）](./GDD.md)** · **[引擎架构与跨端技术评估](./ENGINE_REVIEW.md)**

---

## 三、Steam Top 10 可玩性对标与商业上架方案（Playability & Steam Launch）

1. **[对标 Steam 下载/在线榜 Top 10 可玩性深度拆解与上架缺陷全量审计](./STEAM_TOP10_PLAYABILITY_AND_LAUNCH_AUDIT.md)**
   - 拆解 *PUBG / 黑神话：悟空 / 幻兽帕鲁 / CS2 / 博德之门3 / 泰拉瑞亚 / 冰汽时代 / 风暴之城 / Thronefall* 留存铁律；
   - 详述 **Phase A（Gameplay 2.0：羊角号、节拍蓄力、工坊科技、战术手牌、提灯堵漏、迦南野狼、历代志试炼词缀）** 及正式上架前 22 项审核与工程检查单。
2. **[上架 Steam 专项优化、GodotSteam 云存档/成就与 Steam Deck 绿标合规规范](../design/STEAM_RELEASE_READINESS_SPEC.md)**
3. **[竞品拆解与机制转译清单](./REFERENCE_GAMES.md)** · **[横竖屏与移动端交互研究](./MOBILE_INTERACTION_RESEARCH.md)**

---

## 四、美术圣经、3D 资产管线与历史审计归档（Art & Engineering Audits）

1. **[A 版轻写实微缩美术圣经（3.5–4.5 头身古黎凡特规范）](./ART_BIBLE.md)** · **[画面与分屏视觉规格](./RESEARCH_AND_SCREEN_SPEC.md)**
2. **[工程架构、双模态交互与叙事剧作体检闭环归档（M0 → M1.5）](./audits/ENGINEERING_AND_UX_ARCHITECTURE_AUDIT.md)**
3. **[序章圣经正典与历史真实性二轮复审报告](../design/prologue-noah/review/CODEX_REAUDIT_V2.md)** · **[工具链与质量审计](./QUALITY_TOOL_AUDIT.md)**
4. **早期 RTS 原型子系统设计归档（`src/` 冻结参考栈）**：
   - [搬运工道路物流](./features/carrier-logistics/design.md) · [工程先驱扩地与自由建造](./features/territory-and-building/design.md) · [双护甲战斗与兵种克制](./features/combat-and-counters/design.md) · [RTS 相机与三段式 HUD](./features/rts-camera-and-hud/design.md)
