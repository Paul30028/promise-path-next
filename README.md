# 应许之路 · 新工程

全新工程，位于 `promise-path-next`。旧版 `promise-path` 未被覆盖。本仓库当前是列祖营地的**系统原型**：可操作的三维场景、七名角色、暂停排指令、劳动、侦察、三张情境战术卡、剧情抉择和本地存档。首批 14 个原创 `.glb` 模型已经接入实时场景；它们是可运行的造型样板，尚未达到最终 A 版商业美术质量。当前流程短于目标 15—20 分钟，完整样章仍在制作。

## 本地运行

```powershell
npm install
npm run dev
```

打开 `http://localhost:5180/`。`npm run build` 同时检查 TypeScript 并生成 `dist/`。

`npm run models:build` 重新生成首批模型，`npm run models:check` 检查 GLB 格式与三角面预算。

## 工程范围

- `src/game.ts`：版本化状态、角色、指令队列、资源结算与存档。
- `src/World.tsx`：Three.js 场景与选择/地面操作。
- `src/App.tsx`：队伍、行动、剧情与移动端界面。
- `docs/PROJECT_PLAN.md`：玩法、战斗、阶段目标与决策。
- `docs/ART_BIBLE.md`：A 版美术制作规格。
- `docs/STORY_HISTORY.md`：经文与历史依据、审阅清单。
- `docs/STORYBOARD.md`：样章分镜原稿与审核栏。
- `docs/TECH.md`：架构、数据扩展、性能与验证。
- `docs/REFERENCE_GAMES.md`：竞品拆解、机制转译与开源项目边界。
- `design/runtime-target/`：可在浏览器渲染的横屏 App 美术原稿、场景目标图、生成提示词与制作验收；场景图尚未制成实时 3D 资产。
- `design/modeling/`：已接入游戏的首批 `.glb` 模型清单与实际运行截图；源脚本在 `tools/model-assets.mjs`。
- `design/ui-v2/`：中英文、横竖屏的实际运行截图和界面第二版规范。
- `docs/ENGINE_REVIEW.md`：现有技术与 Godot 迁移的阶段评审。

## 设备

Web 构建和桌面 Chrome 的入口、取水、暂停执行已验证。Android/iOS 原生工程已生成，Android 调试包构建状态见最终交付记录。iOS 编译需 macOS/Xcode。当前没有实体设备性能数据。
