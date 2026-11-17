# 列祖营地首批实时模型

生成命令：`npm run models:build`。检查命令：`npm run models:check`。模型源程序为 `tools/model-assets.mjs`，输出为 14 个 glTF 2.0 `.glb`。单位为米、Y 轴向上、角色面向 +Z，使用哑光 PBR 顶点材质，无外部贴图。角色手脚有独立命名节点，可由游戏代码做基础动作。

角色：`character_abram/sarai/lot/eli/nura/asa/mara.glb`。场景：`tent_ready`、`tent_frame`、`water_jar`、`wood_bundle`、`olive_tree`、`sheep`、`spring`。所有文件由本工程脚本原创生成，可重复构建。当前只完成造型与简单摆臂/迈步，不包含骨骼蒙皮、面部表情、精细织物贴图、疲劳/施工/交谈动画；这些仍是商业版美术制作任务。

验收先以实际浏览器画面、角色辨识和模型预算为准。历史造型仍需按 `docs/STORY_HISTORY.md` 审阅。
