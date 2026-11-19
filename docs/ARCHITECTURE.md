# 应许之路（Path of Promise） — Architecture

**Updated:** 2026-11-19 · [GDD](GDD.md)

## 1. Stack
| | |
|---|---|
| Engine / framework | React `^19.0.0` + Three.js `^0.181.0` (`@react-three/fiber ^9.0.0`) |
| Language | TypeScript `~5.7.3` |
| Build / bundler | Vite `^6.1.0` |
| Target runtime | Modern WebGL2 desktop & mobile browsers; Android/iOS via `@capacitor/core ^8.0.0` |
| Key libraries | `three`, `@react-three/fiber`, `react`, `react-dom` |

## 2. Structure
```
Boot (main.tsx) → App.tsx (125ms fixed-step tick loop)
  ├─ Pure State Snapshot Engine (src/game.ts + src/config.ts)
  ├─ 3D WebGL Battlefield (src/World.tsx: shadows, procedural canvas terrain, smooth fog, billboards)
  └─ 3-Section AoE DOM HUD Overlay (src/App.tsx + src/Minimap.tsx + src/style.css)
```

## 3. Module map
| Module / folder | Responsibility | Used by features |
|---|---|---|
| `src/config.ts` | 唯一静态数值、蓝图、兵种模板、地标与策令配置源 | [carrier-logistics](features/carrier-logistics/implementation.md), [territory-and-building](features/territory-and-building/implementation.md), [combat-and-counters](features/combat-and-counters/implementation.md), [bethel-campaign](features/bethel-campaign/implementation.md), [rts-camera-and-hud](features/rts-camera-and-hud/implementation.md) |
| `src/game.ts` | 纯函数确定性 RTS 状态机（`tick`, `placeBuilding`, `recruitCarrier`, `trainMilitary`, `assignSupervise`, `computeCombatDamage`, `resolveParting`） | [carrier-logistics](features/carrier-logistics/implementation.md), [territory-and-building](features/territory-and-building/implementation.md), [combat-and-counters](features/combat-and-counters/implementation.md), [bethel-campaign](features/bethel-campaign/implementation.md) |
| `src/World.tsx` | 45° 实时阴影 3D 战场、程序化地表与道路纹理、双线性平滑迷雾、绿/红选址虚影与微缩精灵渲染 | [territory-and-building](features/territory-and-building/implementation.md), [rts-camera-and-hud](features/rts-camera-and-hud/implementation.md) |
| `src/Minimap.tsx` | 45° 菱形等距战术小地图与回主帐/空闲工人/缩放快捷工具 | [rts-camera-and-hud](features/rts-camera-and-hud/implementation.md) |
| `src/App.tsx` | 顶栏资源条、左下 3×4 建造格、中下分组编队面板、三选一策令弹窗与创 13 分地弹窗 | [bethel-campaign](features/bethel-campaign/implementation.md), [rts-camera-and-hud](features/rts-camera-and-hud/implementation.md) |
| `tools/slice-codex-v5.mjs` | 零依赖 PNG 连通域与谷值分割切片脚本 | [rts-camera-and-hud](features/rts-camera-and-hud/implementation.md) |
| `tools/test-game-rules.mjs` | Node + esbuild 自动化规则回归测试套件 | 全 Feature `testing.md` |

## 4. Cross-cutting conventions
- **Config and tuning:** 所有 `design.md` 中的数值表项一对一映射到 `src/config.ts` 的 `LEVEL1_CONFIG.numbers`、`unitTemplates` 与 `buildingBlueprints`，严禁在 `World.tsx` 或 `App.tsx` 中硬编码业务常数。
- **Persistence:** `localStorage` 键 `promise-path-next-save-v5`（`schemaVersion: 5`）保存完整 `Game` 快照，跨章节结算摘要存入 `promise-path-campaign-summary-v1`；版本或字段校验不匹配时安全回退至 `newGame()`。
- **Rendering / UI layering:** 3D `<Canvas shadows>` 全屏铺底（`z-index: 0`），DOM 三段式 HUD 通过 `pointer-events: none` 容器与 `pointer-events: auto` 子面板叠加在顶层（`z-index: 4–10`）。

## 5. File layout
```
promise-path-next/
  docs/             # GDD.md, ARCHITECTURE.md, features/<slug>/{design,implementation,testing}.md
  design/           # Codex v5.0 原稿样图与早期提案归档
  public/clay/      # 切片后的透明 PNG 角色、兵种与微缩建筑贴图
  src/              # config.ts, game.ts, World.tsx, Minimap.tsx, App.tsx, i18n.ts, style.css
  tools/            # slice-codex-v5.mjs, test-game-rules.mjs, codex-mcp-server.mjs
```

## 6. Testing and tooling
- 运行 `node tools/test-game-rules.mjs`：通过 `esbuild` 打包 `src/game.ts` 并在 Node 中执行 6 大核心规则套件，输出 `ALL_GAME_RULE_TESTS_PASSED`。
- 运行 `python ../.agent/skills/game-docs/scripts/check_docs.py docs`：校验文档索引、状态一致性与证明注解。

## 7. Build and release
- 本地开发：`npm run dev`（端口 `5180`）
- 生产构建与类型检查：`npm run build`（`tsc -b && vite build`）
