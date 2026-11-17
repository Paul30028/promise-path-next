# 竞品拆解与转译清单 v0.1

目的：把参考作品转成《应许之路》的可验证设计问题。以下“要研究”是制作任务，不代表团队已购买、通关或完成实玩。优先记录操作过程、因果链、失败恢复与制作成本，再决定是否采用。

## 第一批深拆：直接决定样章骨架

| 作品 | 重点观察 | 转译成《应许之路》的实验 | 验收问题 |
|---|---|---|---|
| The Banner Saga 系列 | 车队补给、士气、人口、叙事选择和战斗后果如何互相影响 | 水和粮、队员体力、信任、迁徙时间形成至少两步因果链；剧情结果延续到下一站 | 玩家是否能在选择前理解代价，又在稍后认出后果？ |
| RimWorld | 劳动优先级、人物需求和关系如何生成事件 | 七人各有职责与疲劳阈值；工作模板自动重复；争执由资源和关系触发 | 玩家是否在管理优先级，而非不停重复点按钮？ |
| Desperados III | Showdown Mode 暂停、排指令、同步执行与计划失败反馈 | 暂停时给两名队员各排一条动作，再一次执行；手机端至多显示当前两步 | 失败后能否看见是哪条指令和哪个时机出了问题？ |
| Harold Halibut | 手工模型、扫描、清理、材质、灯光如何保持一致 | A 版先做 1 人、1 帐棚、3 件物件的完整制作样板 | 缩到手机俯视镜头后，材质与轮廓是否仍可辨？ |

[Banner Saga 玩法资料](https://bannersaga.fandom.com/wiki/Gameplay)将车队选择、补给、士气和战斗联系起来；需通过实玩确认具体数值与界面细节。[Desperados III 官方网站](https://desperados3.thqnordic.com/)明确介绍 Showdown Mode 的暂停能力。[Unity 对 Harold Halibut 制作流程的采访](https://legacy-activation.unity3d.com/resources/slow-bros-harold-halibut)说明实物扫描后的材质清理、导入与灯光工作，这比单纯模仿“黏土外观”更适合作为商业化生产参考。

## 第二批：按系统验证

| 系统 | 作品 | 要记录的具体机制 | 本项目的取舍 |
|---|---|---|---|
| 迁徙与群体 | Dead In Vinland、Vagrus: The Riven Realms、King of Dragon Pass / Six Ages、The Oregon Trail | 每日分工、路线成本、氏族事件、简洁的补给提示 | 不让五套资源同时成为样章的阅读负担；先验证水、木、体力、羊群 |
| 潜行战术 | Shadow Tactics、Door Kickers | 视野和巡逻提示、预排动作、同步触发、移动端计划输入 | Shadow Tactics 参考同步执行；暂停规划以 Desperados III 为主，Door Kickers 用于触控节奏观察 |
| 建设治理 | Banished、Going Medieval、Frostpunk / Frostpunk 2 | 资源链长度、建造反馈、社会压力与治理抉择 | 初期营地只做 2—3 级资源链；大型聚落系统留给适合的后续章节 |
| 剧情人物 | Wildermyth、Ash of Gods: Redemption、Pentiment | 年龄/伤病连续性、选择后果、信息差与对白 | 固定经文主事件；玩家可改变准备、关系、代价和知情程度 |
| 美术工艺 | Clay Jam、The Neverhood、The Midnight Walk、Platypus Reclayed | 触感、帧动画、光影与扫描物的风格统一 | A 版保留手作感，但角色轮廓和 UI 读数优先适配手机 |

此表是研究议程，具体机制与平台信息在实玩和官方资料核对后逐项补证。尤其不直接照搬其他作品的剧情、美术、UI 排列或数值。

## 补充：战术卡牌参考

用户清单中缺少第五玩法的专项参考。建议考察 [Fights in Tight Spaces](https://store.steampowered.com/app/1265820/Fights_in_Tight_Spaces/) 的卡牌与位置关系，以及 [Griftlands](https://store.steampowered.com/app/601840/Griftlands/) 的谈判与战斗两套行动结构。对《应许之路》的实验是：同一次危机允许防卫、撤离或谈判，各自使用角色、装备和地形构成不同“手牌”，结果回写同一世界状态。当前原型仅有三张固定情境卡；完整牌组、抽牌和敌方回合尚未实现。

## 已核对的两处差异

1. **Shadow Tactics 的 Shadow Mode 与暂停不是同一能力。** 可研究预排及同步执行，但[玩家社群讨论](https://steamcommunity.com/app/418240/discussions/0/1290691308574425457/)指出其规划时游戏仍在运行；[Desperados III 官方说明](https://desperados3.thqnordic.com/)明确支持暂停。实玩时进一步记录版本和平台差异。
2. **The Midnight Walk 已发售。** [Steam 页面](https://store.steampowered.com/app/2863640/The_Midnight_Walk/)列出的发行日期为 2025 年 5 月 8 日，不再用“即将发售”标注。

## 开源项目与商业化边界

[OpenDeathValley](https://github.com/OpenDeathValley/OpenDeathValley) 是《Desperados: Wanted Dead or Alive》的开源引擎复刻；仓库当前主要为 C/CMake，`master` 分支最近代码推送记录为 2022 年 12 月。其仓库 [LICENSE](https://github.com/OpenDeathValley/OpenDeathValley/blob/master/LICENSE) 为 GPLv3。可阅读行为队列、视野和地图等实现思路；在商业版授权方式确定前，不复制其源码或资产到本工程。仓库简介本身不足以证明它已经实现当前所需的暂停、多角色控制和寻路质量，须按代码逐项验证。

## 实玩拆解记录模板

每个参考游戏记录同一张表：测试平台和版本；游玩时长；一个具体场景；玩家可见信息；三次关键操作；代价何时显示；结果何时发生；失败与恢复；手机端可读性；需要的模型、动画、UI、音效和工程量。优先完成上表四个深拆，再决定是否扩大参考范围。
