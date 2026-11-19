# RTS camera and HUD: testing

**Updated:** 2026-11-19 · [Design](design.md) · [Implementation](implementation.md)

## Acceptance criteria
- [x] 开局主帐区域在战争迷雾中处于可见状态（`isVisibleInFog(g.fog, -4.8, 2.5) === true`），而北岭狼王处于未探索迷雾中（`false`）。 *(`tools/test-game-rules.mjs` › Section 1)*
- [x] 全项目通过 TypeScript 严格类型检查与 Vite 生产打包（`npm run build` 退出码 `0`）。 *(build check 2026-11-19: `tsc -b && vite build`)*

## Playtest checks
1. 点击顶栏「⚒️ 空闲」按钮或按 `.` 键，确认自动选中空闲工人并将镜头平滑移至其位置。
2. 点击或拖动右下角 45° 菱形小地图，确认相机视口框实时同步跟随。

## History
- 2026-11-19: criteria written and verified by `tools/test-game-rules.mjs` and `npm run build`.
