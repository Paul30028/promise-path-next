# Combat and counters（双护甲伤害公式、三角克制与防卡位/防过量微操）

**Status:** implemented · **Updated:** 2026-11-19 · [GDD](../../GDD.md) · [Implementation](implementation.md) · [Testing](testing.md)

服务于第二支柱 **「硬克制与地形高地」**（决策 D-005）。完全采用 `seicing.com` 记录的《帝国时代 IV》底层双护甲与兵种标签额外伤害公式，并针对 `r/aoe4` 社区高频痛点内置 **Boids 半圆包抄防卡位** 与 **远程弹道预扣血（Anti-Overkill）**。

## Rules
1. **双护甲与标签克制伤害公式**：
   - 攻击分为 `melee（近战）`、`ranged（远程）`、`torch（火把拆建筑）` 三类；
   - 每个单位与建筑拥有独立的 `meleeArmor` 与 `rangedArmor`；
   - 单次命中实际伤害：
     $$\text{Damage} = \max\Big(1,\ \big(\text{BaseAttack} + \text{TagBonus} - \text{TargetArmor}\big) \times \text{HighGroundMult}\Big)$$
   - **高地加成（High Ground）**：当攻击者所在地形海拔高于目标（如北岭高坡 `z < -4.0` 打低谷）时，`HighGroundMult = 1.25`（`+25%` 伤害）。
2. **三大战斗兵种与架枪/风筝克制环**：
   - **家丁矛兵（Spearman，标签：`infantry`, `melee`）**：对 `beast（野兽）` 与 `cavalry（骑兵）` 附带 `+12` 额外伤害；静止迎敌时触发 **架枪反冲锋（Brace）**，使首个冲锋至 `1.8u` 内的野狼或骑手承受双倍反击并眩晕 `0.75s`；弱点：`rangedArmor = 0`，被远程风筝克制。
   - **家丁投石手（Slinger，标签：`infantry`, `ranged`）**：远程物理弹道攻击（射程 `6.5u`），对 `infantry` 附带 `+5` 额外伤害；弱点：近战血薄，被高移速斥候或突进狼王贴脸克制。
   - **以利以谢 / 轻装斥候（Scout，标签：`cavalry`, `melee`）**：高移速（`0.28u/tick`）、高视野（`11.0u`）、自带 `rangedArmor = 3` 顶箭雨切后排并负责开迷雾，但被矛兵克制。
3. **亚伯兰「族长号角光环」（Khan-style Aura）**：
   - 亚伯兰不设脱离历史的魔法轰炸技能，而是拥有冷却 `15s` 的 **【守望号角】** 指令：吹响后 `6.0s` 内，半径 `7.5u` 内所有友军近战/远程护甲 `+2`、移速 `+15%`。
4. **Boids 半圆包抄防卡位（Anti-Traffic-Jam Steering）**：
   - 多个近战单位围攻同一目标时，不直接挤向目标中心点 `(tx, tz)`，而是按单位 `id` 哈希分配目标周围半径 `1.35u` 圆周上的独立包抄槽位，并施加单位间排斥分离力（半径 `0.75u`），杜绝互相卡位转圈。
5. **远程弹道预扣血防过量集火（Anti-Overkill Targeting）**：
   - 投石手与瞭望箭塔发射弹道时，立即在目标身上登记 `pendingDamage += expectedDamage`（弹道命中或销毁时释放）；
   - 当某敌人的 `hp - pendingDamage <= 0` 时，后续准备发射的投石手与箭塔自动将索敌优先级切换至下一存活敌人，实现零火力浪费。

## Numbers
| Name | Value | Unit | What to watch in playtests |
|---|---|---|---|
| `SPEARMAN_HP` | 140 | hp | 能否顶住 2 头灰狼围攻至少 12 秒 |
| `SPEARMAN_ATK` | 12 (+12 vs beast/cav) | dmg | 架枪反制野狼时是否具备明显优势 |
| `SPEARMAN_ARMOR` | 2 近 / 0 远 | armor | 近战耐打但怕远程 |
| `SLINGER_HP` | 95 | hp | 被贴脸时是否需要矛兵保护 |
| `SLINGER_ATK` | 11 (+5 vs infantry) | dmg | 集中点射与高地 +25% 时的输出效率 |
| `SLINGER_RANGE` | 6.5 | world units | 站在矛兵身后输出的舒适距离 |
| `SCOUT_ARMOR` | 1 近 / 3 远 | armor | 顶远程火力侦察与切后排能力 |
| `HIGH_GROUND_MULT` | 1.25 | × | 北坡高地箭塔与投石手的压制力 |
| `BRACE_STUN_DURATION` | 0.75 | s | 矛兵架枪拦截狼群冲锋的手感 |
| `HORN_AURA_COOLDOWN` | 15.0 | s | 亚伯兰吹角增益节奏 |

## Edge cases
- **目标在飞行弹道命中前已被近战砍死**：飞行中的石弹/箭矢到达终点后消散并清零 `pendingDamage`，不引发负血或空指针。
- **所有敌人都即将被空中弹道击杀（`hp - pendingDamage <= 0`）**：允许最后多余的射手继续射击最近目标，避免射手在残局发呆。

## Interactions
| Feature | How they connect |
|---|---|
| [Carrier logistics](../carrier-logistics/design.md) | 招募每名矛兵或投石手均需从现有搬运工中转职 1 人 |
| [Territory and building](../territory-and-building/design.md) | 建造军事地标或铁匠摊可研发 `青铜矛锋（近战+2）` 与 `合身皮甲（双甲+1）` |

## Open questions
- [ASSUMPTION] 第一章敌军包含北岭灰狼、东谷饿狼、北岭狼王及 1 支游荡劫掠斥候小队，以便完整验证矛兵、投石手与斥候的三角克制。

## History
- 2026-11-19: designed (D-005).
