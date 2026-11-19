# Territory and building: implementation

**Updated:** 2026-11-19 · [Design](design.md) · [Testing](testing.md) · [Architecture](../../ARCHITECTURE.md)

## Approach
在 `src/game.ts` 中维护 `territories: TerritoryCircle[]` 与 `boundaryPosts: BoundaryPostState[]`；通过 `isValidPlacement(game, kind, x, z)` 校验目标坐标是否处于领土圈内、距其他建筑 `>= MIN_BUILDING_SEPARATION`、不在泉池内且资源充足；在 `src/World.tsx` 中通过 `PlacementGhost` 渲染绿/红半透建筑虚影，并在 `tick()` 中支持工程先驱 `expand` 扩地与时代Ⅱ二选一地标落成晋升。

## Code map
| File / module | Role in this feature |
|---|---|
| `src/config.ts` | 定义 `buildingBlueprints`（含 2 座时代Ⅱ地标）、`boundaryPosts` 与 `neutralLandmarks` |
| `src/game.ts` | `isInTerritory`, `isValidPlacement`, `placeBuilding`, 以及 `tick()` 中的 `expand`、`repairLandmark` 与 `build` |
| `src/World.tsx` | `PlacementGhost`（绿/红选址虚影）、`BuildingBillboard`（施工脚手架与成品微缩贴图）与领土虚线环 |

## Data and config
- **Config constants:** `INITIAL_TERRITORY_RADIUS`, `BOUNDARY_EXPANSION_RADIUS`, `ENGINEER_SURVEY_TICKS`, `MIN_BUILDING_SEPARATION`, `COOP_BUILDER_SPEED_BONUS`
- **Persistence:** `territories`, `boundaryPosts`, `buildings`, `age` 随 `Game` 快照持久化（`schemaVersion: 5`）。

## Deviations from design
无偏差，代码与 `design.md` 完全一致。

## History
- 2026-11-19: implemented.
