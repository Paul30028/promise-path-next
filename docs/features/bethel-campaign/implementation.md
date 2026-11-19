# Bethel campaign: implementation

**Updated:** 2026-11-19 · [Design](design.md) · [Testing](testing.md) · [Architecture](../../ARCHITECTURE.md)

## Approach
在 `src/game.ts` 中维护四幕状态机（`act1_camp` → `act2_expand` → `act3_defense` → `act4_parting` → `resolved`）、3 处 `landmarks` 支线状态、以及 `pendingPerkChoices` 与 `choosePerk(game, perkId)` 三选一圣约策令；在 `resolveParting` 中实现创世记 13:8–18 三分支结算并生成 `ChapterSummary`。

## Code map
| File / module | Role in this feature |
|---|---|
| `src/config.ts` | 定义 `CAMPAIGN_STONES`、`PERKS`、`neutralLandmarks` 与分地成本常数 |
| `src/game.ts` | `choosePerk`, `resolveParting`, 以及 `tick()` 中的四幕推进与支线完成奖励 |
| `src/App.tsx` | 渲染左上主线/支线胶囊、三选一圣约策令弹窗、十二圣约石弹窗与第四幕分地抉择弹窗 |

## Data and config
- **Config constants:** `FRICTION_THRESHOLD_ACT4`, `SIDE_QUEST_SHEEP_REWARD`, `PARTING_SHARE_WATER_COST`, `PARTING_GIFT_WOOD_COST`
- **Persistence:** `phase`, `landmarks`, `perks`, `summary` 保存于 `localStorage['promise-path-next-save-v5']` 与 `promise-path-campaign-summary-v1`。

## Deviations from design
无偏差，代码与 `design.md` 完全一致。

## History
- 2026-11-19: implemented.
