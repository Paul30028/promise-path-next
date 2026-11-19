# Combat and counters: implementation

**Updated:** 2026-11-19 · [Design](design.md) · [Testing](testing.md) · [Architecture](../../ARCHITECTURE.md)

## Approach
在 `src/game.ts` 中通过 `computeCombatDamage(attacker, target)` 实现双护甲（`meleeArmor` / `rangedArmor`）、目标标签克制（`bonusVsBeast` / `bonusVsInfantry`）与高地 1.25× 加成；在 `tick()` 中实现家丁矛兵 `braceCd` 架枪反冲锋双倍伤害与 `stunTicks` 眩晕、远程投石手与瞭望箭塔发射时对目标登记 `pendingDamage` 的智能分火（Anti-Overkill）、亚伯兰 `blowHorn` 号角光环，以及 `stepTowards` 中的 Boids 软分离力与弧形包抄槽位。

## Code map
| File / module | Role in this feature |
|---|---|
| `src/config.ts` | 定义 `unitTemplates.spearman`、`unitTemplates.slinger`、`actors` 与 `enemies` 的攻防、标签及高地倍率 |
| `src/game.ts` | `computeCombatDamage`, `blowHorn`, 以及 `tick()` 中的 Boids 包抄、架枪反冲锋与 `pendingDamage` 智能分火 |
| `src/World.tsx` | `UnitBillboard`, `EnemyBillboard`, `CombatProjectilesAndEffects` 渲染飞行弹道、架枪震击环与号角光环 |

## Data and config
- **Config constants:** `HIGH_GROUND_MULT`, `BRACE_STUN_TICKS`, `HORN_AURA_COOLDOWN_TICKS`, `HORN_AURA_DURATION_TICKS`
- **Persistence:** `enemies`, `projectiles`, `hornCooldown` 随 `Game` 快照保存（`schemaVersion: 5`）。

## Deviations from design
无偏差，代码与 `design.md` 完全一致。

## History
- 2026-11-19: implemented.
