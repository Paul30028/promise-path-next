export type Language = 'zh' | 'en';
const STORAGE = 'promise-path-language';
export function loadLanguage(): Language { try { return localStorage.getItem(STORAGE)==='en'?'en':'zh'; } catch { return 'zh'; } }
export function saveLanguage(language:Language) { try { localStorage.setItem(STORAGE,language); } catch { /* display choice for this session */ } }

export const copy = {
  zh: {
    title:'应许之路', camp:'列祖旅途营地', help:'操作说明', chapter:'列祖旅途 / 第一幕', place:'迦南丘陵', source:'创世记 13 章 · 改编场景',
    waiting:'等待执行', working:'队伍行动中', moveHint:'点选人物，点击地面安排移动',
    objective:'当前目标', objectiveRef:'创 13:1—12', chapterTitle:'水源与牧道',
    objectiveEnd:'已作出选择，旅程将继续。', objectiveThreat:'野兽接近羊群。选择队员和战术行动。', objectiveBuild:'取水、收木，再搭起新帐棚。', objectiveScout:'帐棚已建好。派人侦察山脊。', objectiveTalk:'危险已解除。与罗得商谈牧道。',
    arrived:'抵达', setCamp:'搭营', scoutStep:'侦察', decide:'抉择', water:'水', timber:'木料', tents:'帐棚', herd:'羊群', trust:'信任',
    squad:'队伍', selected:'人已选', busy:'人执行中', actions:'行动指令', inOrder:'按顺序执行', tactical:'战术选择', tacticalHint:'选队员后安排',
    carrier:'取水', carrierDetail:'泉边 · 获得饮水', gather:'收木', gatherDetail:'林缘 · 获得木料', build:'搭帐棚', buildDetail:'消耗 2 木、1 水', scout:'侦察', scoutDetail:'查看山脊', talk:'与罗得交谈', talkDetail:'推进故事',
    defend:'警戒驱离', defendDetail:'领队、侦察者更稳妥', torch:'火把威慑', retreat:'转移羊群',
    paused:'已暂停', running:'执行中', saved:'进度已保存', saveFailed:'存档失败', clear:'清空', execute:'执行指令', pause:'暂停安排', restart:'重新开始', restartConfirm:'重新开始这段旅程？当前进度会被覆盖。',
    noActor:'先选择一名队员。', received:'名队员收到', queued:'，恢复后执行。', sent:'。', cleared:'已清空所选队员的指令。',
    storyIntro:'列祖旅途 · 第一段', arrival:'抵达丘陵', arrivalBody:'亚伯兰与罗得的牲畜增多。先稳定营地：取水、备料、搭帐棚、勘察道路，然后与罗得交谈。', sourceNote:'人物与事件依据《创世记》13:1—12；其他队员姓名、野兽和资源数值为游戏创作。',
    helpBody:'点击角色可多选。点击地面安排移动；右侧按钮安排工作。暂停时可排多条指令，执行时队员按顺序行动。', helpSteps:'先给取水者安排取水，给工匠安排收木与搭棚，派侦察者前往山脊。野兽出现后，派领队或侦察者驱离。与罗得交谈会触发故事抉择。', artNote:'角色和营地已加载本工程制作的 glTF 模型，仍是造型样板。', begin:'开始行动',
    choiceRef:'剧情抉择 · 创世记 13:5—12', dispute:'牧人的争执', disputeBody:'罗得的牧人与亚伯兰的牧人起了争执。泉水和牧地有限，双方需要分开牧放。你可以决定怎样准备这次分离。', share:'先共用水源，再有序分开', shareCost:'消耗 2 水 · 信任 +2', separate:'立即迁移，尽快分开', separateCost:'羊群 −1 · 信任 +1', adaptationNote:'资源结果是游戏改编。经文记载亚伯兰提议分开，由罗得先选择方向。',
    leader:'领队', organizer:'管事', herdsman:'牧人', scoutRole:'侦察', carrierRole:'取水', builder:'工匠', elder:'长者', energy:'体力', selectedPerson:'选中人物', nextOrders:'待执行', idle:'等待指令', choosePerson:'选择人物，查看状态与指令。',
  },
  en: {
    title:'Path of Promise', camp:'The Patriarchs’ Camp', help:'How to play', chapter:'Patriarchs / Act I', place:'Hills of Canaan', source:'Genesis 13 · Adapted scene',
    waiting:'Awaiting orders', working:'Party in motion', moveHint:'Select people, then tap the ground to move',
    objective:'Current objective', objectiveRef:'Gen 13:1–12', chapterTitle:'Water and Pasture',
    objectiveEnd:'A choice has been made. The journey continues.', objectiveThreat:'Wild animals approach the flock. Choose a person and a tactic.', objectiveBuild:'Fetch water and timber, then raise a new tent.', objectiveScout:'The tent is ready. Send someone to scout the ridge.', objectiveTalk:'The danger has passed. Speak with Lot about pasture.',
    arrived:'Arrive', setCamp:'Camp', scoutStep:'Scout', decide:'Decide', water:'Water', timber:'Timber', tents:'Tents', herd:'Flock', trust:'Trust',
    squad:'Party', selected:'selected', busy:'on task', actions:'Orders', inOrder:'Executed in order', tactical:'Tactical choice', tacticalHint:'Choose a person first',
    carrier:'Fetch water', carrierDetail:'Spring · gain water', gather:'Gather wood', gatherDetail:'Grove · gain timber', build:'Raise tent', buildDetail:'Costs 2 wood, 1 water', scout:'Scout ridge', scoutDetail:'Survey the route', talk:'Speak with Lot', talkDetail:'Advance the story',
    defend:'Drive away', defendDetail:'Leader or scout is safer', torch:'Use a torch', retreat:'Move the flock',
    paused:'Paused', running:'Running', saved:'Progress saved', saveFailed:'Save failed', clear:'Clear', execute:'Execute', pause:'Pause', restart:'Restart', restartConfirm:'Restart this journey? Your current progress will be replaced.',
    noActor:'Select a party member first.', received:'party members assigned', queued:'. They will act when resumed.', sent:'.', cleared:'Orders cleared for selected party members.',
    storyIntro:'Patriarchs · Chapter One', arrival:'Arrival in the Hills', arrivalBody:'Abram and Lot have grown their flocks. Secure the camp: find water and timber, raise a tent, scout the ridge, then speak with Lot.', sourceNote:'People and events draw on Genesis 13:1–12. Other crew names, the wild animal encounter, and resource numbers are fictional additions.',
    helpBody:'Tap people to select them. Tap the ground to move; use the order buttons to assign work. While paused, queue several orders. People follow them in sequence when resumed.', helpSteps:'Send the water carrier to the spring and the builder to gather wood and raise a tent. Scout the ridge. If animals threaten the flock, send a leader or scout to drive them away. Speaking with Lot opens a story choice.', artNote:'Characters and camp objects use this project’s playable glTF models; the art is still in development.', begin:'Begin',
    choiceRef:'Story choice · Genesis 13:5–12', dispute:'The Herders’ Dispute', disputeBody:'Lot’s herders quarrel with Abram’s. Water and pasture are limited, and the two groups must separate. Decide how to prepare for the parting.', share:'Share water, then part in order', shareCost:'Spend 2 water · Trust +2', separate:'Move out at once', separateCost:'Flock −1 · Trust +1', adaptationNote:'Resource outcomes are a game adaptation. Genesis says Abram proposed the separation and let Lot choose first.',
    leader:'Leader', organizer:'Steward', herdsman:'Herder', scoutRole:'Scout', carrierRole:'Carrier', builder:'Builder', elder:'Elder', energy:'Stamina', selectedPerson:'Selected person', nextOrders:'Queued orders', idle:'Awaiting orders', choosePerson:'Select a person to see their status and orders.',
  },
} as const;
export type CopyKey = keyof typeof copy.zh;
export const actorNames:Record<string,{zh:string;en:string}> = {
  abram:{zh:'亚伯兰',en:'Abram'}, sarai:{zh:'撒莱',en:'Sarai'}, lot:{zh:'罗得',en:'Lot'},
  eli:{zh:'以利',en:'Eli'}, nura:{zh:'努拉',en:'Nura'}, asa:{zh:'亚撒',en:'Asa'}, mara:{zh:'玛拉',en:'Mara'},
};
const people:Record<string,string> = Object.fromEntries(Object.values(actorNames).map(({zh,en})=>[zh,en]));
const orderNames:Record<string,string> = {'移动':'Move','取水':'Fetch water','收集木料':'Gather wood','搭建帐棚':'Raise tent','侦察山脊':'Scout ridge','与罗得交谈':'Speak with Lot','警戒驱离':'Drive away','火把威慑':'Use a torch','转移羊群':'Move the flock'};
export function localizeOrder(label:string,lang:Language){return lang==='zh'?label:(orderNames[label]??label);}
export function localizeLog(line:string,lang:Language):string {
  if(lang==='zh')return line;
  if(line.includes('营地抵达丘陵边'))return 'The party reaches the hills. Find water, timber, and a safe route before assigning work.';
  const assignment=line.match(/^(\d+) 名队员收到「(.+)」指令(，恢复后执行。|。)$/);
  if(assignment)return `${assignment[1]} party member${assignment[1]==='1'?'':'s'} assigned “${orderNames[assignment[2]]??assignment[2]}”${assignment[3].startsWith('，')?'; they will act when resumed.':'.'}`;
  if(line==='已清空所选队员的指令。')return 'Orders cleared for selected party members.';
  if(line==='请先选一名队员。'||line==='先选择一名队员。')return 'Select a party member first.';
  const person=Object.keys(people).find(name=>line.startsWith(name+' '));
  const name=person?people[person]:undefined;
  if(name&&line.includes('从泉边带回'))return `${name} brought back ${line.match(/(\d+) 份水/)?.[1]??''} water.`;
  if(name&&line.includes('收集了'))return `${name} gathered 2 bundles of timber.`;
  if(name&&line.includes('搭起一座帐棚'))return `${name} raised a tent, using 2 timber and 1 water.`;
  if(name&&line.includes('驱离野兽'))return `${name} drove the animals away and protected the flock.`;
  if(name&&line.includes('赶走野兽'))return `${name} drove them away, but one sheep was lost.`;
  if(name&&line.includes('点燃备用木料'))return `${name} used a torch to drive them away. Timber −1; Trust +1.`;
  if(name&&line.includes('带羊群绕到高地'))return `${name} moved the flock to higher ground. Water −1; no sheep lost.`;
  const fixed:Record<string,string>={
    '材料不足，施工未完成。':'Not enough materials to finish the tent.',
    '先搭起帐棚并处理羊群危险，再与罗得商谈。':'Raise a tent and protect the flock before speaking with Lot.',
    '罗得的牧人与营地牧人争执。请决定怎样准备分开牧放。':'Lot’s herders quarrel with ours. Decide how to prepare for parting.',
    '罗得望向两条不同的路，等待你的决定。':'Lot looks toward two different roads, waiting for a decision.',
    '侦察者发现野兽接近羊群。行动暂停，请选一张情境战术卡。':'The scout spots wild animals near the flock. Paused: choose a tactic.',
    '山脊可看见泉水与较安全的高地。':'From the ridge, the spring and safer high ground are visible.',
    '没有可用木料，火把行动失败。':'No timber is available for a torch.',
    '缺少饮水，无法转移羊群。':'There is not enough water to move the flock.',
  };
  if(fixed[line])return fixed[line];
  if(line.startsWith('先共用泉水，'))return 'The groups share water before parting. Trust improves, but camp water falls. Lot chooses the Jordan plain first.';
  if(line.startsWith('立即分开牧放，')||line.startsWith('立即迁移，'))return 'The groups separate at once. A sheep is lost. Lot chooses the Jordan plain first; Abram stays in Canaan.';
  return line;
}
