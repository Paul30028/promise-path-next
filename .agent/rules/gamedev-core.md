---
trigger: always_on
description: Antigravity Game Studio Core Architecture, Config Separation, Art Direction & Visual Self-Check Loop Rules
---

# GameDev Core Architecture & Studio Rules (`gamedev-core`)

## 1. 默认技术栈与数据解耦规范（Tech Stack & Data-Driven Separation）
- **Web 3D / 2.5D 核心栈**：默认采用 `Vite + TypeScript + Three.js (@react-three/fiber)`（或 Canvas 2.5D / GLSL 着色器管线），移动端通过 `Capacitor` 封装。
- **严禁硬编码数值与关卡配置**：
  - 所有角色属性、移动速度、资源产出/消耗、建筑升级成本、卡牌效果、章节坐标与事件文本，**必须抽离到独立的 `src/config.ts` 或 `src/data/*.json` 中**，禁止在渲染组件（`World.tsx` / `App.tsx`）中硬编码业务逻辑数值。
  - 状态机（`src/game.ts`）必须保持纯函数快照演进（Pure State Snapshot + Deterministic `tick()`），确保随时可序列化存档、回放与单测。

## 2. 美术与叙事红线（Art & Narrative Guardrails）
- **轻写实微缩 AoE 比例规范（3.5–4.5 头身）**：
  - 告别大头萌系公仔，采用紧凑扎实、轮廓清晰、带 45° 实时阳光投影的轻写实微缩模型比例（参考 *The Settlers: New Allies* / *Northgard* / *Thronefall*），兼顾旧约历史肃穆感与桌面/手机端高辨识度。
- **彻底去阿拉伯化 & 忠于《圣经·旧约》历史语境**：
  - 严禁出现现代或中世纪阿拉伯刻板符号（禁止阿拉伯方格/纯色包头巾配黑色/彩色头箍 `Keffiyeh + Agal`、禁止现代沙漠贝都因帐篷、禁止伊斯兰穹顶或弯刀）。
  - 采用纯正古希伯来/地中海黎凡特元素与艺术再创作：自然微卷发与麻花编发、黄金橄榄叶冠冕、古犹太青铜护额箍、未漂白亚麻配琉璃蓝（Tekhelet）与石榴红织边、衣角四繸（Tzitzit）、未凿原石筑成的十二石立约祭坛、木柱织锦凉亭大帐、梯田橄榄林与山泉。
- **经文主干神圣不可篡改**：
  - 严格区分「经文正典事实（Canon Anchor）」与「策略过程/随行同伴改编（Adaptation）」。玩家决策改变的是达成目标的准备成本、同伴体力与家族和睦度，不得反转经文明确记载的核心结局。

## 3. 视觉自检与构建闭环（Mandatory Visual & Build Verification Loop）
每次修改 3D/2.5D 场景、角色动作或 UI 布局后，必须执行以下闭环验证，严禁“盲改即交付”：
1. **静态类型与构建检查**：运行 `npm run check` 或 `npm run build`，确保零 TypeScript 类型错误与打包告警。
2. **浏览器实机视觉自检**：
   - 启动本地开发服务（`npm run dev`），通过内置浏览器子代理（`browser`）或 Playwright 打开实时页面并截图。
   - 逐项检查：**① 是否有 UI 元素重叠或中英文文本溢出；② 角色贴图/模型是否有穿模、破面或透明通道异常；③ 控制台（Console）是否零运行时报错；④ 移动端横屏（844×390）与竖屏（390×844）触控按钮是否均满足 `>= 44px` 可达性**。
3. **联创美术管线**：需要新增或迭代高精位图场景、角色三视图或透明切片时，优先调度本机 `codex`（内置 `imagegen` + `frontend-design`）生成，并在验收后同步归档至项目 `public/` 与 `design/` 目录。
