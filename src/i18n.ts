export type Language = 'zh' | 'en';
const STORAGE = 'promise-path-language';
export function loadLanguage(): Language {
  try { return localStorage.getItem(STORAGE) === 'en' ? 'en' : 'zh'; } catch { return 'zh'; }
}
export function saveLanguage(language: Language) {
  try { localStorage.setItem(STORAGE, language); } catch { /* ignore */ }
}

export const copy = {
  zh: {
    title: '应许之路', camp: '十二圣约纪念石 · 第一章', help: '操作说明', chapter: '列祖纪 / 第一章',
    place: '伯特利与艾城之间', source: '创世记 13:1–18 · Q版历史策略沙盘',
    waiting: '定格规划中', working: '家族行动中', moveHint: '点选人物后点击地面或指令卡 · 单指拖动平移地图',
    objective: '当前目标', objectiveRef: '创 13:1–18', chapterTitle: '那地容不下他们',
    objectiveDay1: '派夏甲汲水、乌珥收木，在东北角木架搭起第二座帐棚（需 2 木 1 水）。',
    objectiveDay2: '第二白昼：可修筑山脊瞭望岗（1 木）或安抚牧场摩擦，准备入夜危机。',
    objectiveCrisis: '山脊野狼逼近羊群！沙盘已定格，请选择队员与下方插画战术卡化解危机。',
    objectiveTalk: '危机已平息。派亚伯兰或撒莱前往东南草场与罗得商议分离。',
    objectiveEnd: '第一块历史圣约石已点亮！罗得东迁约旦平原，进度已承接至第二章《但地夜袭》。',
    step1: '立营', step2: '备战', step3: '夜警', step4: '礼让',
    water: '饮水', timber: '木料', tents: '帐棚', herd: '羊群', trust: '和睦', friction: '牧场摩擦',
    dayLabel: '白昼', squad: '家族成员', selected: '人已选', busy: '人行动中',
    multiOn: '多选:开', multiOff: '单选',
    actions: '白昼指令', inOrder: '按队列执行', tactical: '情境战术卡', tacticalHint: '绑定营地真实物资',
    carrier: '山泉汲水', carrierDetail: '夏甲 +3 · 其余 +2',
    gather: '收集木料', gatherDetail: '乌珥 +3 · 其余 +2',
    build: '搭新帐棚', buildDetail: '消耗 2 木 1 水 (上限1)',
    lookout: '修瞭望岗', lookoutDetail: '消耗 1 木 · 守卫加成',
    rest: '主帐歇息', restDetail: '回体 +40/55 · 零体力可用',
    mediate: '安抚牧人', mediateDetail: '降低草场摩擦 · 和睦 +1',
    scout: '勘察山脊', scoutDetail: '查看北侧牧道风险',
    talk: '与罗得议事', talkDetail: '进入创13分离抉择',
    defend: '地形警戒驱离', defendDetail: '亚伯兰/以利以谢/有岗哨零损失',
    torch: '松脂火把阵', torchDetail: '木料 −1 · 零损失 · 和睦+1',
    retreat: '饮水转移羊群', retreatDetail: '饮水 −1 · 绕行零损失',
    paused: '已定格', running: '推演中', saved: '进度已存', saveFailed: '存档失败',
    clear: '清空', execute: '执行', pause: '定格', restart: '重置',
    restartConfirm: '重新开始本章？当前进度将被覆盖。',
    noActor: '先选择一名家族成员。',
    storyIntro: '列祖纪 · 第一章（创世记 13:1–18）',
    arrival: '伯特利的高地营地',
    arrivalBody: '亚伯兰带着撒莱与罗得回到伯特利与艾城之间筑坛的地方。两家羊群增多，水草渐显拥挤。先安顿营地、修筑防护并护住羊群，再以礼让之心化解两家牧人的争执。',
    sourceNote: '经文锚点：创 13:1–18 亚伯兰主动提议分开、罗得先选约旦河平原。以利以谢提前入队与乌珥为游戏改编角色；山脊野狼危机为教程创作。',
    helpBody: '点选泥偶或头像选中队员（手机默认单选，可点「多选」切换）。点击地面走动，或点击白昼指令排入队列；单指滑动平移地图，双指或快捷胶囊快速定位。',
    helpSteps: '防死锁提示：体力耗尽时仍可派往左上主帐「主帐歇息」恢复；东北角帐棚最多建 1 座，山脊瞭望岗最多修 1 座。',
    begin: '进入营地',
    choiceRef: '经文核心抉择 · 创世记 13:8–18',
    dispute: '你我不可相争',
    disputeBody: '亚伯兰对罗得说：「你我不可相争，你的牧人和我的牧人也不可相争，因为我们是骨肉。遍地不都在你眼前吗？请你离开我：你向左，我就向右；你向右，我就向左。」在罗得举目选择约旦河平原之前，你决定如何筹备分离：',
    escortToggle: '派巧匠乌珥短途护送罗得一程后归营（为第二章提供道路情报）',
    share: '先共饮上泉，再从容分群', shareCost: '饮水 −2 · 和睦 +2 · 羊群完好',
    gift: '赠予备用木料，礼让先选', giftCost: '木料 −2 · 和睦 +3 · 骨肉情深',
    separate: '匆忙整装分道，避免摩擦升级', separateCost: '羊群 −1 · 和睦 +1 · 无物资消耗',
    adaptationNote: '经文定数：在所有分支中，均由亚伯兰主动求和、罗得自主先选约旦河平原东迁，随后亚伯兰在迦南得蒙土地与后裔应许（创 13:10–17）。',
    mapButton: '十二圣约石', mapTitle: '十二圣约纪念石 · 历史战役脉络',
    mapNote: '说明：十二枚纪念石是串联整部旧约各时代故事的艺术象征（序章为诺亚方舟与彩虹之约），并非声称经文记载同一座跨时代实体祭坛。',
    close: '关闭',
    flySpring: '💧 泉眼', flyAltar: '🔥 祭坛', flyPasture: '🐑 草场',
    leader: '族长', organizer: '主母', herdsman: '牧长', scoutRole: '斥候', carrierRole: '汲水', builder: '工匠',
    energy: '体力', selectedPerson: '当前选中', nextOrders: '队列', idle: '待命', choosePerson: '点选人物查看体力与指令。',
  },
  en: {
    title: 'Path of Promise', camp: 'Twelve Stones · Chapter 1', help: 'Guide', chapter: 'Patriarchs / Ch. 1',
    place: 'Between Bethel & Ai', source: 'Genesis 13:1–18 · Chibi Strategy Diorama',
    waiting: 'Tactical Pause', working: 'In Motion', moveHint: 'Select a figure, then tap ground or orders · Drag to pan',
    objective: 'Objective', objectiveRef: 'Gen 13:1–18', chapterTitle: 'The Land Could Not Support Them',
    objectiveDay1: 'Fetch water & wood, then raise the second tent on the northeast frame (2 wood, 1 water).',
    objectiveDay2: 'Day 2: Build the ridge lookout post (1 wood) or calm pasture friction before dusk.',
    objectiveCrisis: 'Wolves approach the flock on the ridge! Choose a responder and a tactical card.',
    objectiveTalk: 'Danger cleared. Speak with Lot in the southeast pasture to prepare the parting.',
    objectiveEnd: 'Chapter 1 Stone lit! Lot journeys east to the Jordan plain; state saved for Chapter 2 (Dan Raid).',
    step1: 'Camp', step2: 'Prep', step3: 'Watch', step4: 'Parting',
    water: 'Water', timber: 'Wood', tents: 'Tents', herd: 'Flock', trust: 'Harmony', friction: 'Friction',
    dayLabel: 'Day', squad: 'Household', selected: 'selected', busy: 'busy',
    multiOn: 'Multi:ON', multiOff: 'Single',
    actions: 'Day Orders', inOrder: 'Queued in order', tactical: 'Tactical Cards', tacticalHint: 'Uses live camp supplies',
    carrier: 'Fetch Water', carrierDetail: 'Hagar +3 · Others +2',
    gather: 'Gather Wood', gatherDetail: 'Ur +3 · Others +2',
    build: 'Raise Tent', buildDetail: '2 wood, 1 water (max 1)',
    lookout: 'Lookout Post', lookoutDetail: '1 wood · defense bonus',
    rest: 'Rest at Tent', restDetail: 'Restore +40/55 stamina',
    mediate: 'Calm Herders', mediateDetail: 'Reduce friction · Harmony +1',
    scout: 'Scout Ridge', scoutDetail: 'Check northern pass',
    talk: 'Speak with Lot', talkDetail: 'Open Gen 13 parting choice',
    defend: 'Guard & Drive Off', defendDetail: 'Abram/Eliezer/Lookout: 0 loss',
    torch: 'Thorn Torches', torchDetail: 'Wood −1 · 0 loss · Harmony +1',
    retreat: 'Move the Flock', retreatDetail: 'Water −1 · 0 loss',
    paused: 'Paused', running: 'Running', saved: 'Saved', saveFailed: 'Save failed',
    clear: 'Clear', execute: 'Execute', pause: 'Pause', restart: 'Restart',
    restartConfirm: 'Restart Chapter 1? Current progress will be reset.',
    noActor: 'Select a household member first.',
    storyIntro: 'Patriarchs · Chapter One (Genesis 13:1–18)',
    arrival: 'Camp on the Hills of Bethel',
    arrivalBody: 'Abram, Sarai, and Lot return between Bethel and Ai. With flocks growing, water and pasture grow tight. Establish the camp, guard the ridge, and prepare a peaceful parting.',
    sourceNote: 'Canon Anchor: Gen 13:1–18 Abram proposes peace and Lot chooses the Jordan plain first. Early Eliezer, Ur, and the ridge wolf tutorial are adapted gameplay additions.',
    helpBody: 'Tap a character or portrait to select (single-select by default on mobile; toggle Multi to command several). Drag with one finger to pan the camera.',
    helpSteps: 'No soft-locks: even at 0 stamina, a member can always walk to Rest at the main tent. Tent and lookout slots are capped at 1 each.',
    begin: 'Enter Camp',
    choiceRef: 'Core Narrative Choice · Genesis 13:8–18',
    dispute: 'Let There Be No Strife Between Us',
    disputeBody: 'Abram said to Lot, “Let there be no strife between you and me... Is not the whole land before you? Separate yourself from me.” Choose how to prepare before Lot selects the Jordan plain:',
    escortToggle: 'Send artisan Ur for a brief escort before returning (unlocks road intel in Ch. 2)',
    share: 'Share the upper spring, then part calmly', shareCost: 'Water −2 · Harmony +2 · Flock intact',
    gift: 'Gift spare timber & yield first choice', giftCost: 'Wood −2 · Harmony +3 · Kinship honored',
    separate: 'Pack hastily to halt the quarrel', separateCost: 'Flock −1 · Harmony +1 · No supply cost',
    adaptationNote: 'Biblical Canon: In every branch, Abram initiates peace, Lot chooses the Jordan Valley first, and Abram receives the promise in Canaan (Gen 13:10–17).',
    mapButton: '12 Stones', mapTitle: 'Twelve Memorial Stones · Old Testament Campaign',
    mapNote: 'Note: The 12 Memorial Stones are an artistic meta-map linking 12 Old Testament eras (starting with Noah’s Ark Prologue), not a single physical altar across eras.',
    close: 'Close',
    flySpring: '💧 Spring', flyAltar: '🔥 Altar', flyPasture: '🐑 Pasture',
    leader: 'Patriarch', organizer: 'Matriarch', herdsman: 'Herdsman', scoutRole: 'Guard', carrierRole: 'Water', builder: 'Artisan',
    energy: 'Stamina', selectedPerson: 'Selected', nextOrders: 'Queue', idle: 'Idle', choosePerson: 'Tap a character to inspect stamina and orders.',
  },
} as const;

export type CopyKey = keyof typeof copy.zh;
export const actorNames: Record<string, { zh: string; en: string }> = {
  abram: { zh: '亚伯兰', en: 'Abram' },
  sarai: { zh: '撒莱', en: 'Sarai' },
  lot: { zh: '罗得', en: 'Lot' },
  eli: { zh: '以利以谢', en: 'Eliezer' },
  nura: { zh: '夏甲', en: 'Hagar' },
  asa: { zh: '乌珥', en: 'Ur' },
};

const people: Record<string, string> = Object.fromEntries(Object.values(actorNames).map(({ zh, en }) => [zh, en]));
const orderNames: Record<string, string> = {
  '移动': 'Move', '山泉汲水': 'Fetch water', '收集木料': 'Gather wood', '搭新帐棚': 'Raise tent',
  '修瞭望岗': 'Lookout post', '主帐歇息': 'Rest at tent', '安抚牧人': 'Calm herders',
  '勘察山脊': 'Scout ridge', '与罗得议事': 'Speak with Lot',
  '地形警戒驱离': 'Guard & drive off', '松脂火把阵': 'Thorn torches', '饮水转移羊群': 'Move flock',
};

export function localizeOrder(label: string, lang: Language) {
  return lang === 'zh' ? label : (orderNames[label] ?? label);
}

export function localizeLog(line: string, lang: Language): string {
  if (lang === 'zh') return line;
  if (line.includes('营地抵达伯特利')) return 'Caravan arrives between Bethel and Ai. Fetch water, gather wood, and raise the second tent.';
  if (line.includes('进入第二白昼')) return 'Day 2 begins: daily water upkeep −1. Build a ridge lookout post or calm pasture friction before dusk.';
  if (line.includes('黄昏山脊危机')) return 'Dusk crisis: wolves approach the ridge! Paused so you can select a tactical card.';
  const assignment = line.match(/^(\d+) 名队员收到「(.+)」指令(，恢复后执行。|。)$/);
  if (assignment) return `${assignment[1]} member${assignment[1] === '1' ? '' : 's'} queued “${orderNames[assignment[2]] ?? assignment[2]}”${assignment[3].startsWith('，') ? ' (when resumed).' : '.'}`;
  if (line.includes('已清空')) return 'Cleared queued orders for selected members.';
  if (line.includes('先选择一名')) return 'Select a household member first.';
  const person = Object.keys(people).find(name => line.startsWith(name + ' '));
  const name = person ? people[person] : undefined;
  if (name && line.includes('从山泉带回')) return `${name} fetched ${line.match(/(\d+) 份/)?.[1] ?? '2'} water from the spring.`;
  if (name && line.includes('收集了')) return `${name} gathered ${line.match(/(\d+) 捆/)?.[1] ?? '2'} wood.`;
  if (name && line.includes('搭起第二座')) return `${name} raised the second nomadic tent (2 wood, 1 water).`;
  if (name && line.includes('立起木石瞭望岗')) return `${name} built the ridge lookout post (1 wood).`;
  if (name && line.includes('在主帐旁歇息')) return `${name} rested by the main tent and recovered stamina.`;
  if (name && line.includes('主动安抚')) return `${name} calmed the herdsmen; pasture friction dropped.`;
  if (name && line.includes('体力耗尽')) return `${name} is exhausted; send them to Rest at the main tent.`;
  if (name && line.includes('警戒驱离野兽')) return `${name} drove off the wolves with zero flock loss!`;
  if (name && line.includes('仓促赶走野兽')) return `${name} drove the wolves off, though 1 sheep strayed.`;
  if (name && line.includes('点燃荆棘火把')) return `${name} lit thorn torches on the ridge (Wood −1, Harmony +1).`;
  if (name && line.includes('绕至安全高地')) return `${name} led the flock to high ground (Water −1, zero loss).`;
  if (line.includes('材料不足')) return 'Not enough materials (requires 2 wood, 1 water).';
  if (line.includes('木料不足')) return 'Not enough wood (requires 1 wood).';
  if (line.includes('罗得')) return 'Abram initiates peace; Lot chooses the Jordan Valley eastward while Abram dwells in Canaan.';
  return line;
}
