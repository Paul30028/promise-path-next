# Bethel campaign: testing

**Updated:** 2026-11-19 · [Design](design.md) · [Implementation](implementation.md)

## Acceptance criteria
- [x] 时代晋升或完成支线后 `pendingPerkChoices` 增加，`choosePerk(g, 'bronzeSpear')` 正常激活策令并扣减待选次数。 *(`tools/test-game-rules.mjs` › Section 4)*
- [x] 第四幕 `resolveParting(g, 'share', true)` 正常推进至 `resolved`、保留罗得东迁正典结局，并通过 `saveGame` / `loadGame`（`schemaVersion: 5`）持久化校验。 *(`tools/test-game-rules.mjs` › Section 6)*

## Playtest checks
1. 点击左上角支线胶囊「支线：迷途羔羊林地」，观察斥候以利以谢前往探索并在完成后弹出三选一圣约策令弹窗。
2. 清空北岭敌群后点击「与罗得议事」，确认弹出创世记 13:8–18 三分支对话且点亮 `#02` 圣约石。

## History
- 2026-11-19: criteria written and verified by `tools/test-game-rules.mjs`.
