# 移动端运行规格原稿 v1

`camp-scene-v1.png` 是内置 ImageGen 生成的**场景美术目标图**。`mobile-landscape-v1.html` 用真实 HTML/CSS 叠加任务、资源、角色与操作区；这份界面文件可在手机浏览器渲染，但场景图目前为静态图，不是可操纵的 3D 模型。正式游戏仍使用 `src/World.tsx` 的实时渲染，须通过建模、贴图、骨骼、动画、关卡和性能优化达到此视觉目标。

推荐战术场景横屏 844×390 CSS px 作为基准；剧情阅读和菜单可继续支持竖屏。场景约占宽度 65%，右侧操作区约 35%。队伍栏容纳七名角色并可横向滑动，常用动作和暂停按钮同屏可见，按钮高度至少 44 CSS px。实际适配范围、触控尺寸和目标设备帧率须经真机验证。浏览器渲染截图为 `mobile-landscape-v1.png`。

与旧 A 版相比，此稿压缩为一座完成帐棚、一座施工框架、一个水源、一捆木料、三只羊、两棵树和七名角色。图片背景仍含较多花草石块；最终 3D 资源需按实例化植被与可见性预算再删减。原稿中的角色与物件没有经历史考证定稿，不作为出版时的历史复原声明。

## ImageGen 原始提示词

输入参考：`../../assets/references/a-clay-cast.png`。工具：内置 ImageGen。输出：`camp-scene-v1.png`。

> Create ONE production-facing mobile game gameplay scene art target for the Bible strategy adventure Promise Path. Use the supplied A-version sheet only for rounded clay miniature character style and warm woven materials. This must look like a plausible real-time 3D game camera render for a mid-range Android phone, not a cinematic illustration. Square-ish landscape playable view composition, 4:3 aspect ratio. Fixed three-quarter isometric camera about 40 degrees above, weak perspective or orthographic, entire small walkable Canaan hillside camp visible. Exactly seven distinct 2.7-head-tall chibi adult/elder characters, each about 9-12% of image height so readable on mobile: Abram in blue-grey cloak with curved staff, Sarai muted terracotta shawl, Lot brown with shepherd rope, olive scout with small pack, teal water carrier with one clay jar, copper builder with tool belt, violet-grey elder. Show a completed single cloth tent toward upper left, a simple unfinished tent frame to upper right, one small spring on left, one compact bundle of wooden poles on right, three sheep near camp, two olive trees, a few rocks, clear walkable paths and open negative space around interactables. Select Abram with a subtle gold ground ring; one small unobtrusive waypoint marker. Matte hand-sculpted clay, simple woven cloth texture, warm sand ground, calm soft directional sun and baked-looking shadows, restrained color and polygon density, no ornate clutter, no distant city, no complex waterfall, no extra characters, no lettering, no words, no numerals, no logos, no HUD, no borders, no comic panels. Accurate character continuity with the supplied A reference. The final image should be a clean art plate that could be rebuilt with glTF models, atlased textures, one sun light, ambient fill and instanced props, and remain visually legible at 390px width.

## 制作验收

1. 首批需建模：亚伯兰、撒莱、罗得、侦察者、水手、工匠、长者；帐棚两状态；泉水、木料、三只羊、地表、树与石。
2. 手机目标先按 30 FPS，Web 桌面按 60 FPS 设计；此图本身无法证明性能达标。
3. 同尺寸截图做盲测：七人中至少 6 人能靠轮廓和配色辨识；水源、木料、可建设帐棚 3 秒内能找到。
4. 模型和贴图须保留编辑源文件、LOD、骨骼与动画，按 `docs/ART_BIBLE.md` 输出 `.glb`。
