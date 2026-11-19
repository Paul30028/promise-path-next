# Carrier logistics（搬运工道路物流与主母督工）

**Status:** implemented · **Updated:** 2026-11-19 · [GDD](../../GDD.md) · [Implementation](implementation.md) · [Testing](testing.md)

服务于第一支柱 **「看得到的物流链」**（决策 D-003）。所有资源（`粮草 Food`、`饮水 Water`、`木料 Wood`、`石料 Stone`）均需经过「采集读条 → 实物产出 → 搬运工沿道路运至最近货栈/主帐 → 入库结算」四步闭环；同时搬运工兼作兵营征兵的人力池，配合主母撒莱的「督工统筹（Supervise）」构成经济引擎。

## Rules
1. **就近交货（Drop-off Routing）**：搬运工（如夏甲及后续招募的营地搬运工）在山泉、树林、牧场或采石场完成采集读条后，手部挂载对应 3D 货品（双耳陶水罐、原木捆、石块、粮袋），自动寻路前往**距离最近的已完工交货建筑**（`主营大帐`、`伐木货栈` 或 `水井蓄水站`）。
2. **自动循环与道路提速**：货品送达交货建筑后，对应顶栏资源增加，且该搬运工若无新指令，**自动折返原资源点继续下一轮采集**；当搬运工处于已铺设的**营地土路/石板路**半径 `1.2u` 内时，移动速度提升 `30%`。
3. **搬运工即兵源池（Workforce Dilemma）**：玩家在 `主营大帐` 消耗粮草与饮水招募新搬运工（受当前 `人口上限` 约束）；在 `家丁哨营` 训练 **家丁矛兵** 或 **家丁投石手** 时，除消耗木料/粮草外，**必须将 1 名现有搬运工转职为该士兵**。
4. **防死锁保底**：当营地存活搬运工 `<= 1` 人时，`家丁哨营` 的征兵按钮自动锁定并提示“需至少保留 1 名搬运工维持营地后勤”。
5. **撒莱主母督工（Supervise）**：选中撒莱右键点击 `主营大帐`、`伐木货栈` 或 `家丁哨营`，撒莱进入该建筑旁 `1.5u` 督工状态：
   - 督工经济建筑：所有向该建筑交货的资源结算量 **向上取整增加 25%**（例如单趟 4 木变为 5 木）；
   - 督工军事/主帐建筑：该建筑的单位训练与科技研发进度速度 **提升 50%**。同一时间撒莱只能督工 1 座建筑。

## Numbers
| Name | Value | Unit | What to watch in playtests |
|---|---|---|---|
| `INITIAL_FOOD` | 120 | food | 开局是否足够招募 2 名新搬运工并启动首座建筑 [ASSUMPTION] |
| `INITIAL_WATER` | 80 | water | 开局水井建立前是否会断水 [ASSUMPTION] |
| `INITIAL_WOOD` | 100 | wood | 开局能否顺利放下伐木场与首座房舍 [ASSUMPTION] |
| `INITIAL_STONE` | 40 | stone | 是否逼迫玩家派乌珥勘探北坡石矿以建瞭望箭塔 [ASSUMPTION] |
| `BASE_POP_CAP` | 8 | pop | 初始主帐提供人口上限（开局已占 6 人） |
| `HOUSE_POP_BONUS` | 4 | pop | 每座副帐房舍增加的人口上限 |
| `CARRIER_RECRUIT_COST_FOOD` | 50 | food | 招募 1 名新搬运工的粮草成本 [ASSUMPTION] |
| `CARRIER_BATCH_AMOUNT` | 10 | res/trip | 普通搬运工单趟携带资源量（夏甲专精饮水为 15） |
| `GATHER_CHANNEL_TIME` | 2.0 | s | 采集点读条耗时（16 ticks @ 125ms） |
| `ROAD_SPEED_MULT` | 1.30 | × | 道路网上的搬运移速倍率 |
| `SARAI_SUPERVISE_YIELD_MULT` | 1.25 | × | 撒莱督工货栈时的单次入库倍率 |
| `SARAI_SUPERVISE_TRAIN_MULT` | 1.50 | × | 撒莱督工哨营/主帐时的训练加速倍率 |

## Edge cases
- **目标资源点在搬运途中耗尽**：搬运工交完手头最后一趟货物后，自动搜寻同类型且处于已探索视野内 `8.0u` 范围内的相邻资源点；若无则切换为 `idle` 并亮起顶栏「空闲工人」提示。
- **交货建筑被毁或未完工**：未完工（`built === false`）的货栈不作为交货点，搬运工自动回退至 `主营大帐` 交货。
- **携带途中被改派建造或移动**：若改派为去交货建筑，则直接入库；若改派去其他地点，手头携带货物清零以防凭空刷资源。

## Interactions
| Feature | How they connect |
|---|---|
| [Territory and building](../territory-and-building/design.md) | 贴近森林/石矿自由建造 `伐木货栈` 可把搬运往返时间从 12s 缩短至 3s |
| [Combat and counters](../combat-and-counters/design.md) | 兵营训练矛兵/投石手直接转职消耗 1 名搬运工 |
| [RTS camera and HUD](../rts-camera-and-hud/design.md) | 顶栏显示 4 资源、人口 `当前/上限` 与「空闲工人」一键定位按钮 |

## Open questions
- [ASSUMPTION] 道路采用“建筑建成后自动与主帐生成连接土路，玩家亦可花费 10 石料升级为石板路”的半自动模式，兼顾手机触控便捷性。

## History
- 2026-11-19: designed (D-003).
