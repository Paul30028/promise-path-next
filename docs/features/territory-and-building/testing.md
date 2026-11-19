# Territory and building: testing

**Updated:** 2026-11-19 · [Design](design.md) · [Implementation](implementation.md)

## Acceptance criteria
- [x] `isValidPlacement` 拒绝在领土圈外 `(14.0, -9.0)` 放置货栈，并允许在领土圈内 `(-9.5, 4.5)` 自由落址奠基与完工。 *(`tools/test-game-rules.mjs` › Section 2)*
- [x] 工程先驱乌珥对 `post-north` 执行 `expand` 读条完成后，`game.territories` 数量增加 1。 *(`tools/test-game-rules.mjs` › Section 3)*
- [x] 时代Ⅱ地标 `landmarkEncampment` 建造完成后，`game.age` 晋升为 `2` 并解锁 1 项圣约策令。 *(`tools/test-game-rules.mjs` › Section 4)*

## Playtest checks
1. 点击左下 `3×4` 面板中的「伐木货栈」，移动鼠标观察领土内显示绿色虚影、领土外显示红色虚影，点击绿圈成功奠基。
2. 点击「乌珥扩地」，观察乌珥前往界石桩敲击读条并扩大金色领土圈。

## History
- 2026-11-19: criteria written and verified by `tools/test-game-rules.mjs`.
