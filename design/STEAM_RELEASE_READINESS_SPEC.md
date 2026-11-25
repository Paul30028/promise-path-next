# 《应许之路》上架 Steam 专项优化与发行合规技术规范（v6.0）

- **状态（Status）**：`双语 WEB/CUV 经文合规、5 总线混响、缩略图存档与 Gameplay 2.0 已实装；GodotSteam / 手柄绿标待 Phase B 实装`
- **关联全章总案**：[FULL_CAMPAIGN_DESIGN_SPEC_V6.md](./FULL_CAMPAIGN_DESIGN_SPEC_V6.md) · [FULL_CAMPAIGN_TECHNICAL_ARCHITECTURE_V6.md](./FULL_CAMPAIGN_TECHNICAL_ARCHITECTURE_V6.md) · [STEAM_TOP10_PLAYABILITY_AND_LAUNCH_AUDIT.md](../docs/STEAM_TOP10_PLAYABILITY_AND_LAUNCH_AUDIT.md)
- **目标标准**：一次通过 Valve 商店与包体双轨审核 + 冲击 **Steam Deck Verified（绿标）** + 适配 Steam 新品节（Next Fest）高转化独立 Demo

---

## 一、Valve 审核生死线与法务合规（漏一项直接拒审或下架）

### 1. Steam 生成式 AI 内容问卷强制披露（Content Survey）
- **现状核查**：项目前期角色三视图、部分概念底图与基础 3D 角色网格使用了 AI 辅助生成（Pre-generated），运行时无实时 AI 生成（No Live-generated AI）。
- **必须执行的合规动作**：
  - 在 Steamworks 后台填写 **Content Survey** 时，必须如实勾选 **Pre-Generated AI Content**，简要说明：*“部分概念原画、卷轴插画及基础 3D 网格在研发期借助 AI 工具辅助生成，并经人工重拓扑、骨骼绑定、材质修缮与历史考据校对；游戏运行期间不包含任何实时生成式 AI。”*

### 2. 圣经译本与开源资产全球商用版权排雷（极易踩坑！）
- **英文圣经译本版权红线**：现代主流英文译本（如 **ESV、NIV、NLT、NASB**）均受严格商业版权保护，未经出版方书面授权在付费商业游戏中大段引用会触发法务下架！
  - **解决方案**：简体/繁体中文统一采用公有领域 **《和合本 (CUV 1919)》**；英文版**严禁直接抓取 ESV/NIV**，统一采用 100% 公有领域且现代易读的 **《World English Bible (WEB)》**（或古典庄重风《KJV / ASV 1901》），彻底实现全球零版税、零侵权风险！
- **随包开源协议声明（`LICENSES/THIRD_PARTY_NOTICES.txt`）**：
  - Godot 4 引擎采用 MIT 协议，**法律强制要求在游戏内「关于/制作人员（Credits）」页面或随包文本中保留 Godot Engine 版权与 FreeType / ENet / mbedTLS 声明**（可通过 `Engine.get_copyright_info()` 与 `Engine.get_license_text()` 自动生成展示页）；
  - 同步列入 `Phantom Camera`、`Dialogue Manager`、`Godot State Charts`（均为 MIT）及 PolyHaven / Grab3D（CC0 1.0）资产清单。

### 3. Godot 4.7 导出 `.pck` 必改配置（防止正式包黑屏）
- **核心隐患**：Godot 导出 `.exe/.pck` 时默认**丢弃所有 `.json` 与 `.txt` 非资源文件**！当前项目全部章节数据（`data/*.json`）在编辑器可运行，直接导出上架会立即启动黑屏。
- **强制规范**：
  1. 创建受版本控制的 `godot-pilot/export_presets.cfg`（秘钥保留在忽略提交的 `.godot/export_credentials.cfg`），在 Windows / Linux 预设中显式写入：
     `include_filter="data/*.json, data/**/*.json, LICENSES/*.txt"`；
  2. 每次上传 SteamPipe 前必须执行无模板真包冒烟门禁：
     ```powershell
     Godot_v4.7.2-stable_win64_console.exe --headless --path godot-pilot --export-pack "Windows Desktop" build/smoke.pck
     Godot_v4.7.2-stable_win64_console.exe --headless --main-pack build/smoke.pck --quit-after 180
     ```
     确认零 `SCRIPT ERROR` 且零文件缺失后方可推包。

---

## 二、消除 PC 玩家“首日差评雷区”：桌面端硬核设置（PC QoL）

Steam 核心玩家对“简陋手游移植感”容忍度极低，主菜单与 `ESC` 设置页必须实装以下 **PC 标准四件套**：

| 类别 | 必备可调选项 | 技术实现要点 |
| :--- | :--- | :--- |
| **显示与多屏适配** | • 显示模式：**无边框全屏（默认）** / 独占全屏 / 窗口化<br/>• 分辨率：`1280×720`、`1280×800 (16:10)`、`1920×1080`、`2560×1440`、`3840×2160` 及 **`21:9` 超宽屏（`3440×1440`）**<br/>• 帧率上限（`60 / 120 / 144 / 无限制`）与 VSync 开关 | 超宽屏下 HUD 锚定于中央 `16:9` 安全框内，两侧自然延展 3D 视野不拉伸；窗口失去焦点（切屏）自动降低后台帧率至 `15 FPS` 省电 |
| **四档画质预设** | • `低（核显稳60帧） / 中 / 高 / 史诗` 一键切换 + 细项微调<br/>• 阴影质量、全局光照（`SDFGI` 开关）、体积雾、环境光遮蔽（`SSAO`）、草丛密度 | 低配档自动切换轻量环境光 + 关闭 `SDFGI` 与体积雾，确保核显轻薄本流畅运行 |
| **防晕 3D 与辅助功能** | • **第一人称视野角 FOV 滑条（`65°–95°`）**<br/>• **第一人称步伐摇晃开关（Head Bob On/Off）**<br/>• **镜头震动强度滑条（`0%–100%`）**<br/>• **全局字号放大档位（`100% / 120%`）** | 策略玩家群体中包含大量不习惯 FPS 晃动的玩家，提供一键关闭步伐晃动可显著降低差评退款率 |
| **全键位重映射** | • 支持键盘 `WASD / 方向键 / 交互 / 沙盘` 自定义改键与冲突检测 + 鼠标灵敏度 + Y轴反转 | 序列化保存至 `user://settings.cfg`，按键提示随改键实时刷新 |

---

## 三、Steamworks 原生功能接入架构（`PlatformSteamAdapter`）

采用**松耦合插件适配层**接入 [GodotSteam](https://godotsteam.com/)（GDExtension 版，无需重编引擎！）：当检测到 Steam 客户端运行时激活完整生态，在 Android 端或本地独立开发启动时自动静默降级，绝不崩溃。

1. **Steam 云存档（Steam Cloud）**：
   - 优先配置 Steamworks 后台 **Auto-Cloud**：指向 `user://saves/*.json` 与 `user://settings.cfg`，并使用 `{64BitSteamID}` 子目录做多账号隔离，实现 PC 与 Steam Deck 跨设备秒级续玩。
2. **Steam 成就系统（28 枚立约与策略成就）**：
   - **12 枚正典主线成就**：点亮 `#01 彩虹之约` 至 `#12 大卫永约`；
   - **16 枚高玩策略与探索成就**：如 *《义人止戈》（序章零木料损失且非致命击退强人）*、*《提灯看顾》（洪水幕第一人称巡视全部三层甲板与十只活物）*、*《活水宽阔》（第四章零冲突挖出利河伯深井）*、*《瓦瓶火把》（第十章基甸三百勇士零伤亡破敌）*。
3. **Steam 覆盖层（Overlay）与富状态（Rich Presence）**：
   - 监听 `Steam.overlay_toggled(active: bool)`：玩家按 `Shift+Tab` 呼出指南或聊天时自动触发游戏暂停；
   - 实时推送好友列表状态（如 `序章 · 修筑方舟 (距洪水 82 天)`），提升社区自然曝光。

---

## 四、冲击「Steam Deck 绿标认证（Deck Verified）」五项硬指标

策略与单机叙事品类在 Steam Deck 上拥有极高完播率。严格对照 Valve 官方硬件审核清单逐条达标：

1. **原生 `1280×800`（16:10）满屏渲染**：不留上下黑边，UI 四角不贴边裁切。
2. **手柄开箱即玩（Full Controller Reachability）**：从主菜单、新建存档、沙盘派工、第一人称提灯巡舱到正典手卷翻页，100% 可用摇杆与十字键操作，无需触碰触摸屏。
3. **动态输入图标切换（Dynamic Controller Glyphs）**：一旦检测到手柄输入，所有界面上的 `[E]`、`[F]`、`[Space]`、`[J]` **必须在同一帧切换为 Xbox / Steam Deck 对应按键图标**（残留键鼠提示会被判黄标 `Playable` 而非绿标 `Verified`！）。
4. **最小字号红线**：在 `1280×800` 分辨率下，所有资源数字、考据手卷与字幕像素高度强制 **`>= 12px`**（绝不出现 `<9px` 的蚂蚁字）。
5. **Deck 续航与帧率档**：启动时若检测到 `Steam.isSteamRunningOnSteamDeck()`，首次默认套用 **“Deck 专属平衡画质档”**（`800p @ 45–60 FPS`，关闭高耗电 `SDFGI`，保留柔和体积光与高质量阴影）。

---

## 五、SteamPipe 分包更新与新品节（Next Fest）发行工程

### 1. 增量补丁体积优化（Patch-Size Hygiene）
- SteamPipe 按 `~1 MB` 数据块做二进制差分更新。**严禁开启全局 `.pck` 加密或跨包重压缩**（否则改一行代码会导致玩家重下整个几百 MB 包体）。
- 采用按卷分包加载策略：`core.pck`（核心代码与 UI）+ `ch00_01_demo.pck` + `vol1_patriarchs.pck` + `vol2_exodus_kingdom.pck`，使日常修 Bug 热更新下载量控制在 **`< 5 MB`**。

### 2. 独立免费 Demo App 与心愿单转化闭环
- 将 **M1 黄金切片（`Ch00 诺亚方舟完全体` + `P01 出吾珥画卷` + `Ch01 伯特利七区`）** 建立独立的 **Steam Demo AppID** 参加 **Steam 新品节（Next Fest）**：
  - Demo 通关结算画面（幔利橡树筑坛 & 第二章但地夜袭预告）正中央放置醒目的 **`★ 将《应许之路》加入 Steam 心愿单`** 按钮，点击直接调用 `Steam.activateGameOverlayToStore(FULL_GAME_APP_ID, Steam.OVERLAY_TO_STORE_FLAG_ADD_TO_CART_AND_SHOW)` 弹出内嵌商店页！
  - Demo 与正式版共享同一套 `CampaignSaveV3` 云存档路径，购买正式版后一键无缝继承序章与第一章全部进度和加成。

### 3. 上架日历倒排硬时间窗（提前锁死，不可压缩！）
根据 Valve 官方规则，首次发行的自然日硬性等待期如下，必须在研发进入 **M1** 时即同步启动商店注册：
- **T - 60 天**：注册 Steamworks 合作伙伴、提交税务验证（`10–15` 工作日）、缴纳 \$100 App Fee（触发新开发者 **`21 天` 冷却期**）；
- **T - 35 天**：完成胶囊图套组（Header / Small / Vertical / Library Hero，缩略图级高对比度手绘史诗构图）、前 5 秒直入高潮实机宣传片（巨浪托舟 → 提灯看百兽 → 红海分水）、填写含 AI 披露的 Content Survey，提交商店页审核（`3–5` 工作日）；
- **T - 25 天**：商店页过审后**立即手动点击 `Post as Coming Soon`**（公开展示必须满 **`>= 14 天`** 才能解锁发售按钮！），同步开启心愿单积累；
- **T - 10 天**：使用专用构建小号运行 `check_steam_build.py --strict` 校验 `.vdf`，经 `beta` 分支实机验证后推至 `default` 并提交 **Build Review**（预留至少 `7` 个工作日）；
- **T - 0 天**：人工点击 `Release App` 正式上线。
