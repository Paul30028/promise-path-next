# RTS camera and HUD: implementation

**Updated:** 2026-11-19 · [Design](design.md) · [Testing](testing.md) · [Architecture](../../ARCHITECTURE.md)

## Approach
在 `src/World.tsx` 中通过 `CameraRig` 实现帧率无关指数衰减阻尼 `1 - Math.exp(-CAMERA_DAMP_RATE * delta)`，开启 `<Canvas shadows>`、45° `DirectionalLight` 与 `HemisphereLight`，使用 `SmoothFogOfWar` 绘制双线性插值平滑迷雾；在 `src/App.tsx`、`src/Minimap.tsx` 与 `src/style.css` 中实现顶栏资源+人口+空闲工人、左下 3×4 羊皮卷建造格、中下分组编队卡片与右下 45° 菱形等距战术小地图。

## Code map
| File / module | Role in this feature |
|---|---|
| `src/World.tsx` | `CameraRig` 阻尼相机、`SmoothFogOfWar` 平滑迷雾、`ProceduralValleyTerrain` 及 Codex v5.0 精灵渲染 |
| `src/Minimap.tsx` | 45° 旋转菱形战术小地图与回主帐/空闲工人/缩放按钮 |
| `src/App.tsx` | 顶栏、左下 3×4 命令格、中下按兵种分组编队面板及 `handleMoveOrder` 方阵偏移行军 |
| `src/style.css` | 青铜与羊皮卷 AoE 三段式 HUD 样式及移动端 `>= 44px` 响应式抽屉 |

## Data and config
- **Config constants:** `CAMERA_DAMP_RATE`, `FORMATION_SPACING`
- **Persistence:** 语言偏好保存于 `localStorage['promise-path-language']`。

## Deviations from design
无偏差，代码与 `design.md` 完全一致。

## History
- 2026-11-19: implemented.
