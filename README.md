# 应许之路 · 新工程

全新工程，位于 `promise-path-next`。旧版 `promise-path` 未被覆盖。本仓库当前是列祖营地的**系统原型**：可操作的三维场景、七名角色、暂停排指令、劳动、侦察与警戒、剧情抉择和本地存档。程序几何体用于验证玩法，不代表最终 A 版美术。当前流程短于目标 15—20 分钟，完整样章仍在制作。

## 本地运行

```powershell
npm install
npm run dev
```

打开 `http://localhost:5180/`。`npm run build` 同时检查 TypeScript 并生成 `dist/`。

## 工程范围

- `src/game.ts`：版本化状态、角色、指令队列、资源结算与存档。
- `src/World.tsx`：Three.js 场景与选择/地面操作。
- `src/App.tsx`：队伍、行动、剧情与移动端界面。
- `docs/PROJECT_PLAN.md`：玩法、战斗、阶段目标与决策。
- `docs/ART_BIBLE.md`：A 版美术制作规格。
- `docs/STORY_HISTORY.md`：经文与历史依据、审阅清单。
- `docs/STORYBOARD.md`：样章分镜原稿与审核栏。
- `docs/TECH.md`：架构、数据扩展、性能与验证。

## 设备

Web 构建和桌面 Chrome 的入口、取水、暂停执行已验证。Android/iOS 原生工程已生成，Android 调试包构建状态见最终交付记录。iOS 编译需 macOS/Xcode。当前没有实体设备性能数据。
