# 应许之路（Path of Promise） — Game Design Document

**Version:** 0.6 · **Updated:** 2026-11-23 · [Features](#feature-index) · [Decisions](#decisions) · [Change log](#change-log) · [Architecture](ARCHITECTURE.md)

## 已确认的玩法方向 · 2026-11-23

主模式采用《杀戮尖塔 2》的分支路线与局内组合。特定章节采用《Whiteout Survival》所代表的生存建设与人员分配。以下资源数量、回合长度和示例奖励为待试玩参数。

手机横屏操作的竞品研究、输入约定与审核任务见[界面操作研究](MOBILE_INTERACTION_RESEARCH.md)。

### 常规章节 · 队伍远征

每站先预览地形、已知代价和下一处分岔，再选路、安排队员行动、结算并获得一项能改变后续解法的能力或装备。队员疲劳、物资与装备随队走到本章终点。首轮可用公开行动列表做组合，随机抽牌另行试玩决定。存档保留路线、奖励及已结算事件，读档后继续同一局。

伯特利试局（创 13:1–12）：河谷可补水但拥挤，山脊耗水但可提前观察下一站。河谷队选用牧人“分群”，腾出浅岸，再让取水者用双罐装水；山脊队先认路，再用空出的行程照顾疲劳队员。给玩家提前看见至少一个后续节点，使眼前装备的用途可推断。两路都进入亚伯兰让罗得先选的事件，结算展示各队还剩多少水、谁能继续劳动。路线、劳动与数值属于玩法创作。

商品、装备、NPC 对话及线索如何影响选路，见[伯特利旅途系统设计](features/bethel-campaign/trade-gear-clues.md)。

### 灵力系统（方向确认，章节规则待试玩）

辨明行止、群体勉励、领受托付及职责分担的经文校核、资料来源与试制规则见[灵力系统经文审阅稿](SPIRIT_SCRIPTURE_NOTES.md)。

灵力作为与商品、装备并列的章节系统成立。界面以经文实际用语标注事件，如“神的灵”“耶和华的灵”，并可查看书卷与节数。将人物、经文中的处境和使命绑定到章节节点。玩家操作的是人物如何履行使命；神迹与应许的发生依经文安排。通用的劝和、守约、互助保留为关系行动。祷告与敬拜可独立呈现。局内组合由同行者、装备、材料与人员分配提供；不以反复祷告、奉献交易或击败敌人积攒圣灵点数。

**建设章节试案：比撒列与会幕。** 出 31:1–6、35:30–35 将神的灵、智慧、工艺及教导联系到具体人物；35:34 也提到亚何利亚伯。玩家在工段排班时可让比撒列亲自加工，本班完成一项工序，或安排他与学工同班，本班少一份成品，下一班多一位可分担此工序的工匠。排班前显示两班预计产出。学工与班次为原创机制，职责和工艺依经文呈现。

**远征章节试案：基甸召集众人。** 士 6:33–35 记载危机、耶和华的灵降在基甸身上、吹角和遣使。到达该剧情节点后出现吹角行动；随后玩家分配使者走两条集合路线。可让熟路者同行以提前获知一处阻碍，也可把熟路者留给辎重队。路线决定沿途支援与物资状态，召集的经文次序保留。路线与补给取舍属于关卡创作。

**伯特利试局。** 创 13:5–12 的牧人争执与亚伯兰礼让，通过对话、实际让路和安置人手呈现。借罐、托付、浅岸调停均标为关卡创作；该段经文未记载圣灵降临事件。编剧条目记录经文、译本、人物、章节触发条件、可选操作与创作部分；重开存档保留已发生的剧情节点。审核重点为中英文经文用词、人物归属与玩法是否暗示原文未记载的因果。

### 身份与祭祀职责（角色设计提案）

角色面板显示人物在群体中的身份、此章职责与经文出处。资料条目区分经文明称、叙事所见的行动及玩法改编。可称早期家族领袖承担“祭司性职责”；人物头衔依经文选用。中英文用职称 Priest 对应明确的祭司身份，家族领袖卡上写“主持家族献祭 / Leads household sacrifice”。

|人物|面板与依据|玩家行为|
|---|---|---|
|挪亚|家族领袖；出方舟后筑坛献祭（创 8:18–22）|洪水退去、家人和活物出方舟后，由工程总览转到家族视角。玩家以挪亚身份筑坛，依经文呈现取洁净牲畜和飞鸟献祭，随后进入应许叙事。沿用祭坛阶段隐藏经营 HUD 的已有规则，祭物由章节准备，避免库存不足导致经文事件无法推进。|
|亚伯兰|家族领袖；筑坛、求告耶和华的名（创 12:7–8，13:3–4、18）|旧坛成为旅途地标。返抵伯特利时可循旧路抵坛，家人在行程日志回看首次安营与今天的处境，随后进入两家牧人争执。这条地标线索表达空间记忆，不预告罗得将选择何地。|
|麦基洗德|撒冷王、至高神的祭司（创 14:18–20）|营救归来，由麦基洗德迎接并祝福亚伯兰，玩家以亚伯兰身份回应，按经文次序呈现十分之一。将此帐目单列为章节叙事事件，与商人报价和护送佣金分别记录。|

献祭、祝福与领受启示分别绑定经文中的行动者及事件。献祭完成写入纪事与剧情进度；交易价格、战力和神谕触发概率不读取祭物价值。玩家的策略自由放在安置家庭、安排守护与恢复行程等处，改编动作逐项标注。存档恢复可回看已完成纪事，不重复献祭、扣物或发放奖励。

### 特定章节 · 生存建设

方舟试局（创 6:14–22）：把有限人手分给备料、运输、施工。在这个试局里，早班派人修坡道会少运一批木料，后两班每趟可多运；直接投入船体则先完成当日工段。用同一批人、相同截止时间比较两种排班。玩家失误可在下班次重新分工。建造方舟的经文事件保留，排班、坡道和效率为玩法创作。此类章节结算人员状态与物资，在叙事连续的后续节点读取；跨时代章节各自建立初始队伍。

### 首轮验收

同一张四站地图设置两处分岔和两套队员组合。记录玩家第二次选路、是否主动更换行装，以及能否指出第一站的选择怎样改变第三站。方舟另测玩家能否预判调走一名工人造成的瓶颈。剧情、探索、营地美术和小队动作服务于所在章节的主要决定。

## v0.5 即时战略原型记录

以下保留既有设计、系统清单与原型实施历史。后续章节的模式与优先级以本页上方 2026-11-23 决策为准。

### 原型概述
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
