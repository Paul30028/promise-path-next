# Godot 4 移动端非破坏性验证切片（`godot-pilot`）

> **目的**：在不改动现有 Three.js / React / Capacitor 工程（`src/`）的前提下，用同一套 `.glb` 资产对比 Godot 4 的移动端帧率、Draw Calls、内存占用与开发效率，作为是否全面迁移 Godot 4 的实测依据。

## 1. 当前已就绪内容
- `project.godot`：Godot 4.4+，采用移动端友好的 `gl_compatibility`（OpenGL ES 3）渲染器、横屏适配 `1280×720`、`emulate_touch_from_mouse=true`。
- `scenes/camp_pilot.tscn`：35–45° 俯视相机、暖金斜阳 `DirectionalLight3D`、AgX 色调映射 `WorldEnvironment`、`64×48` 地表与 6 个基线 `.glb` 资产（亚伯兰、主帐、陶罐、橄榄树、绵羊、山泉）。
- `scripts/camp_pilot.gd`：支持触控/鼠标拖动平移镜头、点击地面射线检测移动亚伯兰、左上角实时显示 `FPS / Draw Calls / Static Mem (MB)`。
- 静态校验：`check_godot_project.py` 已通过（`0 errors, 0 warnings`）。

## 2. 替换成 0 成本开源 3D 小样（下一步）
1. 打开免费 MIT 开源工具 **Microsoft TRELLIS**（HuggingFace Space `microsoft/TRELLIS` 或 Google Colab 免费 T4）或本机 RTX 5060 (8 GB) 跑 **Hunyuan3D-2mini**：
   - 上传 `design/review-slice-01/inputs/` 下已裁切好的 `abram_front.png`、`abram_back.png`、`abram_left.png`、`abram_right_flipped.png` 生成 `CHR_Abram.glb`；
   - 上传 `prop_amphora_ref.png` 或 `bldg_main_tent_ref.png` 生成道具/建筑 `.glb`。
2. 在免费 **Blender** 中清理面数（人物控在 `4k–5k` 三角面、Y 向上/+Z 朝前）→ 用免费 **Reallusion AccuRIG** 自动绑骨 + **Mixamo** 套待机/行走动画 → 导出 `glTF 2.0 (.glb)` 覆盖 `godot-pilot/assets/models/character_abram.glb`。
3. 在 `design/review-slice-01/ASSET_BREAKDOWN.md` 补全该 `.glb` 的来源、许可核验日期与修改记录。

## 3. 本机运行与 Android 对比验收
1. 安装免费的 [Godot 4.4+ (Standard)](https://godotengine.org/download/windows/)（MIT 开源免费）。
2. 在 Godot 管理器中导入 `godot-pilot/project.godot` 并点击运行（F5），核对左上角实时 `FPS / Draw Calls / Memory`。
3. 安装 Godot Android Export Template，导出调试 APK 到本机 `guardian34` 模拟器或中端真机，记录首屏时间、包体大小与帧率，决定是否全面迁移。
