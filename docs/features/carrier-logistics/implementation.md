# Carrier logistics: implementation

**Updated:** 2026-11-19 · [Design](design.md) · [Testing](testing.md) · [Architecture](../../ARCHITECTURE.md)

## Approach
在纯函数状态机 `src/game.ts` 中实现搬运工采集读条（`GATHER_CHANNEL_TICKS`）、手部挂载 `carrying` 货品载荷、基于 `findNearestDropOff(x, z)` 搜索最近已建成且带 `isDropOff: true` 的交货建筑、沿主帐与已建成建筑连线 `1.35u` 道路网触发 `ROAD_SPEED_MULT` 移速加成，以及主母撒莱 `assignSupervise` 驻扎建筑时的 `+25%` 向上取整入库加成与 `trainMilitary` 转职消耗搬运工防死锁校验。

## Code map
| File / module | Role in this feature |
|---|---|
| `src/config.ts` | 定义 `LEVEL1_CONFIG.numbers`（初始 4 资源、人口、搬运量、道路倍率、督工倍率）与 `unitTemplates.carrier` |
| `src/game.ts` | `recruitCarrier`, `trainMilitary`, `assignSupervise`, 以及 `tick()` 中的 `findNearestDropOff` 与 `isOnRoad` |
| `src/World.tsx` | `ProceduralValleyTerrain` 自动绘制主帐至各完工建筑的运货沙土路；`UnitBillboard` 渲染搬运工手部携带物与督工金环 |

## Data and config
- **Config constants:** `INITIAL_FOOD`, `INITIAL_WATER`, `INITIAL_WOOD`, `INITIAL_STONE`, `BASE_POP_CAP`, `HOUSE_POP_BONUS`, `CARRIER_RECRUIT_COST_FOOD`, `CARRIER_BATCH_AMOUNT`, `GATHER_CHANNEL_TICKS`, `ROAD_SPEED_MULT`, `SARAI_SUPERVISE_YIELD_MULT`, `SARAI_SUPERVISE_TRAIN_MULT`
- **Persistence:** 随 `Game` 快照保存于 `localStorage['promise-path-next-save-v5']`（`schemaVersion: 5`）。

## Deviations from design
无偏差，代码与 `design.md` 完全一致。

## History
- 2026-11-19: implemented.
