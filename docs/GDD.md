# 应许之路（Path of Promise） — Game Design Document

**Version:** 0.5 · **Updated:** 2026-11-19 · [Features](#feature-index) · [Decisions](#decisions) · [Change log](#change-log) · [Architecture](ARCHITECTURE.md)

## Summary
玩家扮演《旧约·创世记》列祖时代的族长亚伯兰，在伯特利与艾城之间的迦南高地建立半游牧营地、派工程先驱插界石扩张领土、组建搬运工道路物流网，并率领家丁矛兵与投石手抵御北岭群狼与外敌掠夺。每一章围绕一块「圣约纪念石」展开，在严守经文正典结局（如创 13 章亚伯兰礼让、罗得东迁约旦河平原）的前提下，通过经济布局、地标升级与战术微操决定家族和睦度与跨章节战备继承。

| | |
|---|---|
| Genre and camera | 轻写实微缩即时战略（RTS，融合《帝国时代 IV》与《工人物语：新兴同盟》），45° 等距俯视可缩放相机 |
| Audience | 16–45 岁策略/历史/圣经文化爱好者，兼顾桌面微操玩家与移动端触控策略玩家 [ASSUMPTION] |
| Platforms and input | Web 桌面端（键鼠：左键框选 + 右键上下文 + 热键）与移动端（Capacitor 封装，触控点选/框选切换） |
| Session | 单章战役 12–18 分钟；全 12 圣约石战役约 3–4 小时 [ASSUMPTION] |
| Engine | Vite + TypeScript + Three.js (`@react-three/fiber`) + 纯函数确定性状态机 (`src/game.ts`) |
| Scope | 垂直切片（M1–M3：第一章《伯特利与艾城》完整可玩 + 十二圣约石战役脉络） |
| References | *Age of Empires IV*（双护甲克制公式、地标升时代、主母督工、Crucible 三选一策令）；*The Settlers: New Allies*（搬运工自动道路物流、搬运工即兵源池、工程先驱扩地与野外地标）；*Northgard*（3.5–4.5 头身轻写实微缩可读性） |

## Pillars
1. **看得到的物流链（Settlers Logistics over Magic Teleports）.** 任何采集所得都不会凭空加进顶栏数字，必须由采集者或专职搬运工沿着营地道路网亲手运回货栈或工地；征兵直接消耗搬运工名额，逼迫玩家在“物流吞吐”与“前线兵力”间做真实取舍。
2. **硬克制与地形高地（AoE4 Tactical Triangle & High Ground）.** 放弃无脑堆数值与 MOBA 华丽滚键盘技能，胜负取决于「矛兵架枪反冲锋 → 投石手风筝步兵 + 高地 +25% 伤害 → 斥候切后排」的三角克制，以及在隘口自由选址修筑瞭望箭塔。
3. **轻写实微缩与纯正古希伯来考据（3.5–4.5 Head-Tall Levantine Authenticity）.** 告别 2.4 头身大头萌系公仔与中世纪阿拉伯刻板符号（禁 Keffiyeh + Agal），采用 3.5–4.5 头身微缩写实比例、45° 实时阳光落地阴影、琉璃蓝（Tekhelet）亚麻织边与未凿十二石祭坛。
4. **经文正典不可篡改，策略过程自由分支（Canon Anchor vs. Strategic Adaptation）.** 玩家无法篡改经文记载的结局（如创 13 罗得先选约旦河平原），但通过野外地标争夺、Crucible 圣约策令与分地筹备分支，深刻改变达成结局的物资代价与下一章《但地夜袭》的初始家丁阵容。

## Core loop
```
派工程先驱扩地/勘探 → 自由选址建采集营与道路 → 搬运工自动运货入库 → 建地标升时代/转职家丁兵种 → 依托高地箭塔与克制阵型迎战 → 达成正典剧情抉择并点亮圣约石
```
- **Seconds:** 左键框选单位、右键下达移动/采集/集火指令（[RTS 相机与三段式 HUD](features/rts-camera-and-hud/design.md)），观察搬运工沿土路运送陶罐与木料（[搬运工物流与督工](features/carrier-logistics/design.md)），微操矛兵架枪与投石手分火（[双护甲战斗与兵种克制](features/combat-and-counters/design.md)）。
- **Minutes:** 派工程先驱插界石扩张领土、抢占野外古井地标、自由选址放置伐木营/房舍/箭塔并建造二选一时代地标（[领土扩张与自由建造](features/territory-and-building/design.md)），在完成支线时挑选三选一「圣约策令」（[伯特利战役剧本](features/bethel-campaign/design.md)）。
- **Session and between sessions:** 历经第一章四幕剧情化解狼群与牧人争执，完成创世记 13:8–18 礼让分地，点亮 `#02` 圣约纪念石并将剩余物资、和睦度与护送情报写入存档，承接至第二章《但地夜袭》。

## Feature index

| Feature | Status | Scope | Summary | Docs |
|---|---|---|---|---|
| Carrier logistics | implemented | MVP | 5 资源体系、搬运工沿道路自动运货、搬运工转职兵源池及撒莱督工加成 | [design](features/carrier-logistics/design.md) · [impl](features/carrier-logistics/implementation.md) · [test](features/carrier-logistics/testing.md) |
| Territory and building | implemented | MVP | 工程先驱插界石扩地、绿/红虚影自由选址建造、野外地标修复与二选一地标升时代 | [design](features/territory-and-building/design.md) · [impl](features/territory-and-building/implementation.md) · [test](features/territory-and-building/testing.md) |
| Combat and counters | implemented | MVP | AoE4 双护甲公式、矛兵架枪/投石手高地+25%/斥候克制、Boids防卡位与防过量集火 | [design](features/combat-and-counters/design.md) · [impl](features/combat-and-counters/implementation.md) · [test](features/combat-and-counters/testing.md) |
| Bethel campaign | implemented | MVP | 创 13:1–18 四幕剧本、3 条动态支线、Crucible 三选一圣约策令与三分支正典分地 | [design](features/bethel-campaign/design.md) · [impl](features/bethel-campaign/implementation.md) · [test](features/bethel-campaign/testing.md) |
| RTS camera and HUD | implemented | MVP | 左键框选+右键上下文、45° 实时阴影、三层平滑迷雾与 AoE 三段式 HUD（含菱形小地图） | [design](features/rts-camera-and-hud/design.md) · [impl](features/rts-camera-and-hud/implementation.md) · [test](features/rts-camera-and-hud/testing.md) |
| Dan night raid | idea | later | 第二章（创 14:1–24）：率 318 家丁与幔利同盟分队夜袭四王联军营地救回罗得 | — |
| Crucible survival | idea | later | 可重玩 PvE 波次守卫模式：随机词条、昼夜敌潮与圣约祭坛排行榜 | — |
| Twelve stones metagame | idea | later | 串联创世记至撒母耳记 12 块圣约纪念石的战役大地图与跨章遗产系统 | — |

## Milestones
1. **M1, 核心经济与自由建造灰盒:** [Carrier logistics](features/carrier-logistics/design.md), [Territory and building](features/territory-and-building/design.md) · done when: 工程先驱可扩地并在任意合法空地放置伐木营/蓄水站，搬运工自动往返货栈入库，撒莱督工生效且 `tools/test-game-rules.mjs` 断言全部通过。
2. **M2, 双护甲战斗与防卡位/防过量微操:** [Combat and counters](features/combat-and-counters/design.md) · done when: 矛兵架枪、投石手高地 +25% 伤害与 Pending Damage 智能分火、箭塔自动防御及 Boids 半圆包抄在自动化测试与实机下零卡死。
3. **M3, 第一章四幕剧本与 AoE 三段式 HUD 实机闭环:** [Bethel campaign](features/bethel-campaign/design.md), [RTS camera and HUD](features/rts-camera-and-hud/design.md) · done when: 切入 Codex v5.0 轻写实微缩人物与建筑切片，完成四幕主线+3支线+三选一策令，通过 `npm run build` 及桌面（1280×800）、手机横屏（844×390）、竖屏（390×844）实机视觉检验。

## Decisions

| ID | Date | Decision | Alternatives considered | Why | Affects |
|---|---|---|---|---|---|
| D-001 | 2026-11-18 | 采用路线 A：保留序章 `#01 诺亚彩虹之约` 为战役大地图锚点，优先交付第一章 `#02 伯特利与艾城` 可玩垂直切片 | 从零先做诺亚方舟建造关；直接跳到出埃及记 | 伯特利立营与创 13 分地最契合 RTS 采集、建营、防狼与外交抉择，且能直接衔接创 14 但地夜袭 | [Bethel campaign](features/bethel-campaign/design.md) |
| D-002 | 2026-11-19 | 美术比例由 2.4 头身大头萌系 Q 版切换为 3.5–4.5 头身轻写实微缩 AoE 风（《工人物语 / Northgard》比例） | 保留 2.4 头身大头公仔；改为 1:7 纯写实比例 | 2.4 头身玩具感冲淡旧约历史感；1:7 在手机屏上过小难辨识；3.5–4.5 头身兼顾历史厚重感与跨端高辨识度 | [RTS camera and HUD](features/rts-camera-and-hud/design.md) |
| D-003 | 2026-11-19 | 经济底层融合《工人物语：新兴同盟》的“自动搬运工 + 搬运工即兵源池”与《帝国时代 4》的“撒莱主母督工” | 纯 AoE 村民万能采集且独立募兵；点击瞬时加资源 | 解决此前“走到点瞬时加资源、缺乏动作逻辑”的痛点，且“征兵消耗搬运工”能自然产生后勤与军事的张力 | [Carrier logistics](features/carrier-logistics/design.md) |
| D-004 | 2026-11-19 | 建造与时代演进采用“工程先驱扩地 + 自由选址绿/红虚影 + 二选一地标升时代” | 仅允许在 3 个固定死槽位点击建造 | 固定槽位丧失了 AoE“贴树林建伐木场缩运距、用房舍和箭塔卡山口”的空间建筑学乐趣 | [Territory and building](features/territory-and-building/design.md) |
| D-005 | 2026-11-19 | 战斗采用 `seicing.com` AoE4 双护甲公式 + Boids 弧形包抄 + 飞行弹道预扣血（Anti-Overkill），移除华丽 MOBA QWER 滚键盘技能 | 保留 LoL 式英雄 QWER 范围轰炸技能 | 保持纯正历史 RTS 调性，仅保留亚伯兰类似 AoE4 蒙古“汗”的冷却型指令号角光环，同时根治 `r/aoe4` 社区痛恨的近战堵车与远程过量集火 | [Combat and counters](features/combat-and-counters/design.md) |
| D-006 | 2026-11-19 | 战役中融入 3 条可选支线与 *The Crucible* 式“三选一圣约策令”局内构筑 | 纯线性固定脚本任务 | 吸收游民星空战役攻略的双轨结构与 `r/aoe4` 社区对 Crucible 模式的高口碑，消除传统单机战役的重复跑腿感 | [Bethel campaign](features/bethel-campaign/design.md) |
| D-007 | 2026-11-19 | 扩展 64×48 真实 3D 地形、新增「没药医治帐篷」「活体羊群牧养」「创 13:4 筑坛求告」及结局「举目观看」全图迷雾揭开，底部 HUD 改为双页签情境网格 | 扁平 48×36 地图与 14 格平铺按钮 | 解决地形单调、伤员无处医治、牧群摩擦具象化与移动端竖屏视野遮挡问题 | [Territory and building](features/territory-and-building/design.md) · [RTS camera and HUD](features/rts-camera-and-hud/design.md) |

## Open questions
- **Assumptions to confirm:**
  - [ASSUMPTION] 第一章资源采用 5 项顶栏指标：`粮草(Food)`、`饮水(Water)`、`木料(Wood)`、`石料(Stone)` 与 `人口(Pop 6/12)`，与原稿样图顶栏对齐。
  - [ASSUMPTION] 手机竖屏（390×844）下将左下 3×4 建造格与中下编队面板合并为底部可切换双抽屉，保证所有触控按钮 `>= 44×44px`。
- **Risks:**
  - *自由建造寻路阻挡风险*：玩家若用建筑把主帐完全围死会导致搬运工卡住 → 在建造虚影校验时强制保留至少 1.2u 宽度的出入口通道。
  - *搬运工全部转职为士兵导致死锁*：当搬运工仅剩 1 人时禁用兵营征召按钮，并在主帐提供免费缓慢恢复或耗粮招募搬运工机制。

## Change log
**0.5 (2026-11-19):** 按 `game-docs` 规范建立标准 GDD 与 5 大核心 Feature 设计文档，融合 AoE4 (`seicing.com` / 游民星空 / `r/aoe4`) 与《工人物语：新兴同盟》机制；记录决策 D-001 至 D-006。
