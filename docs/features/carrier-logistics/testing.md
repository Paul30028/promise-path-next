# Carrier logistics: testing

**Updated:** 2026-11-19 · [Design](design.md) · [Implementation](implementation.md)

## Acceptance criteria
- [x] 开局初始化 4 项资源为 `120 粮草`、`80 饮水`、`100 木料`、`40 石料`，初始人口上限为 `8`。 *(`tools/test-game-rules.mjs` › Section 1)*
- [x] 撒莱驻扎督工新建成的 `伐木与采石货栈` 时，夏甲交纳 `15 饮水` 实际入库量向上取整增加 25%（`+19 饮水`）。 *(`tools/test-game-rules.mjs` › Section 2)*
- [x] `recruitCarrier` 消耗粮草增加搬运工，且 `trainMilitary('spearman')` 在训练家丁矛兵时将 1 名现有搬运工转职为士兵。 *(`tools/test-game-rules.mjs` › Section 4)*

## Playtest checks
1. 在左下 `3×4` 面板点击「招搬运工」，确认粮草 `-50` 且主帐旁新增 1 名搬运工。
2. 点击「撒莱督工」，确认撒莱走至货栈旁并显示金色督工光环。

## History
- 2026-11-19: criteria written and verified by `tools/test-game-rules.mjs`.
