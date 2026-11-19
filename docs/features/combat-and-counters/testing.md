# Combat and counters: testing

**Updated:** 2026-11-19 · [Design](design.md) · [Implementation](implementation.md)

## Acceptance criteria
- [x] `computeCombatDamage` 对高地（`z = -6.0`）远程单位打击低地步兵（`rangedArmor = 1`, `bonusVsInfantry = 5`）精确返回 `Math.round((12 + 5 - 1) * 1.25) = 20`。 *(`tools/test-game-rules.mjs` › Section 5)*
- [x] 颁布【大马色青铜矛锋】策令并训练家丁矛兵后，矛兵面板与架枪机制正常生效。 *(`tools/test-game-rules.mjs` › Section 4)*

## Playtest checks
1. 选中战兵点击北岭灰狼，观察近战单位呈弧形包抄不卡位，家丁矛兵触发蓝色架枪震晕光环。
2. 点击左下「守望号角」，观察亚伯兰周围友军脚下出现青色护甲/移速增益环。

## History
- 2026-11-19: criteria written and verified by `tools/test-game-rules.mjs`.
