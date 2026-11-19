export type Role =
  | 'leader'
  | 'organizer'
  | 'herdsman'
  | 'scout'
  | 'carrier'
  | 'engineer'
  | 'spearman'
  | 'slinger';

export type UnitTag = 'infantry' | 'cavalry' | 'beast' | 'ranged' | 'melee' | 'civilian';
export type AttackKind = 'melee' | 'ranged' | 'torch';
export type ResourceKind = 'food' | 'water' | 'wood' | 'stone';

export type BuildingKind =
  | 'mainTent'
  | 'altar'
  | 'healingTent'
  | 'house'
  | 'depot'
  | 'watchtower'
  | 'barracks'
  | 'landmarkOlive'
  | 'landmarkEncampment';

export type OrderKind =
  | 'move'
  | 'attackMove'
  | 'gather'
  | 'build'
  | 'attack'
  | 'supervise'
  | 'expand'
  | 'repairLandmark'
  | 'rest'
  | 'mediate'
  | 'sacrifice'
  | 'talk';

export type LevelPhase = 'act1_camp' | 'act2_expand' | 'act3_defense' | 'act4_parting' | 'resolved';
export type PartingChoice = 'share' | 'gift' | 'separate';
export type PerkId = 'bronzeSpear' | 'livingAqueduct' | 'twinBrazier';

export interface BuildingBlueprint {
  kind: BuildingKind;
  nameZh: string;
  nameEn: string;
  descZh: string;
  descEn: string;
  sprite: string;
  costFood: number;
  costWater: number;
  costWood: number;
  costStone: number;
  buildTicks: number;
  maxHp: number;
  visionRadius: number;
  isDropOff?: boolean;
  popBonus?: number;
  isAge2Landmark?: boolean;
  attackRange?: number;
  attackDamage?: number;
  attackCooldown?: number;
}

export interface ResourceBlueprint {
  id: string;
  kind: ResourceKind;
  nameZh: string;
  nameEn: string;
  x: number;
  z: number;
  amount: number;
}

export interface BoundaryPostBlueprint {
  id: string;
  nameZh: string;
  nameEn: string;
  x: number;
  z: number;
  radius: number;
}

export interface NeutralLandmarkBlueprint {
  id: 'lostSheep' | 'ancientWell' | 'wolfDen';
  nameZh: string;
  nameEn: string;
  x: number;
  z: number;
  costWood: number;
  costStone: number;
}

export interface PerkConfig {
  id: PerkId;
  nameZh: string;
  nameEn: string;
  descZh: string;
  descEn: string;
}

export interface ActorConfig {
  id: string;
  name: string;
  role: Role;
  tags: UnitTag[];
  attackKind: AttackKind;
  color: string;
  startX: number;
  startZ: number;
  maxHp: number;
  maxEnergy: number;
  attack: number;
  bonusVsBeast: number;
  bonusVsInfantry: number;
  meleeArmor: number;
  rangedArmor: number;
  attackRange: number;
  speed: number;
  visionRadius: number;
  carryCapacity: number;
}

export interface EnemySpawnConfig {
  id: string;
  kind: 'wolf' | 'alphaWolf' | 'raider';
  nameZh: string;
  nameEn: string;
  tags: UnitTag[];
  attackKind: AttackKind;
  x: number;
  z: number;
  maxHp: number;
  attack: number;
  meleeArmor: number;
  rangedArmor: number;
  attackRange: number;
  speed: number;
  aggroRange: number;
}

export interface CampaignStone {
  index: number;
  id: string;
  eraZh: string;
  eraEn: string;
  titleZh: string;
  titleEn: string;
  ref: string;
  status: 'prologue' | 'current' | 'locked';
}

export const WORLD_DIMENSIONS = {
  width: 64,
  depth: 48,
  halfW: 32,
  halfD: 24,
  fogCols: 40,
  fogRows: 30,
} as const;

export const CAMPAIGN_STONES: CampaignStone[] = [
  { index: 1, id: 'noah-ark', eraZh: '序章 · 上古立约', eraEn: 'Prologue', titleZh: '诺亚方舟与彩虹之约', titleEn: 'Noah & Rainbow Covenant', ref: '创 6–9', status: 'prologue' },
  { index: 2, id: 'bethel-ai', eraZh: '第一章 · 列祖时期', eraEn: 'Chapter 1', titleZh: '伯特利与艾城筑坛', titleEn: 'Bethel & Ai Altar', ref: '创 13:1–18', status: 'current' },
  { index: 3, id: 'dan-rescue', eraZh: '第二章 · 列祖时期', eraEn: 'Chapter 2', titleZh: '但地夜袭救罗得', titleEn: 'Night Raid at Dan', ref: '创 14:1–24', status: 'locked' },
  { index: 4, id: 'mamre-stars', eraZh: '第三章 · 仰望应许', eraEn: 'Chapter 3', titleZh: '幔利橡树与星辰之约', titleEn: 'Stars at Mamre', ref: '创 15:1–21', status: 'locked' },
  { index: 5, id: 'beersheba-well', eraZh: '第四章 · 活水之约', eraEn: 'Chapter 4', titleZh: '别是巴水井与起誓', titleEn: 'Well of Beersheba', ref: '创 21 / 26', status: 'locked' },
  { index: 6, id: 'peniel-ford', eraZh: '第五章 · 雅博渡口', eraEn: 'Chapter 5', titleZh: '雅博渡口与改名以色列', titleEn: 'Ford of Jabbok', ref: '创 32:22–32', status: 'locked' },
  { index: 7, id: 'red-sea', eraZh: '第六章 · 出埃及', eraEn: 'Chapter 6', titleZh: '红海分水与逾越节', titleEn: 'Crossing the Red Sea', ref: '出 12–15', status: 'locked' },
  { index: 8, id: 'sinai-tabernacle', eraZh: '第七章 · 西乃立约', eraEn: 'Chapter 7', titleZh: '西乃山与会幕圣工', titleEn: 'Sinai & Tabernacle', ref: '出 19–40', status: 'locked' },
  { index: 9, id: 'jordan-crossing', eraZh: '第八章 · 过约旦河', eraEn: 'Chapter 8', titleZh: '约旦河十二石立碑', titleEn: 'Twelve Stones at Gilgal', ref: '书 3–4', status: 'locked' },
  { index: 10, id: 'jericho-walls', eraZh: '第九章 · 攻取应许地', eraEn: 'Chapter 9', titleZh: '耶利哥城与艾城', titleEn: 'Walls of Jericho', ref: '书 6–8', status: 'locked' },
  { index: 11, id: 'gideon-300', eraZh: '第十章 · 士师时期', eraEn: 'Chapter 10', titleZh: '基甸三百勇士夜战', titleEn: 'Gideon’s 300', ref: '士 7:1–25', status: 'locked' },
  { index: 12, id: 'mount-zion', eraZh: '第十一章 · 联合王国', eraEn: 'Chapter 11', titleZh: '锡安大卫之城', titleEn: 'City of David', ref: '撒下 5–7', status: 'locked' },
];

export const PERKS: PerkConfig[] = [
  {
    id: 'bronzeSpear',
    nameZh: '大马色青铜矛锋',
    nameEn: 'Damascus Bronze Spear',
    descZh: '所有家丁矛兵近战攻击 +4，架枪反冲锋眩晕延长至 1.2s',
    descEn: 'Spearmen +4 melee attack & 1.2s brace stun',
  },
  {
    id: 'livingAqueduct',
    nameZh: '山泉活水渠',
    nameEn: 'Living Spring Aqueduct',
    descZh: '所有交货点入库量 +35%，营地搬运工道路移速额外 +15%',
    descEn: '+35% drop-off yield & +15% carrier road speed',
  },
  {
    id: 'twinBrazier',
    nameZh: '守望双发烽火',
    nameEn: 'Twin Watchtower Braziers',
    descZh: '石木瞭望箭塔每次发射 2 支火箭，视野与射程 +2.5u',
    descEn: 'Watchtowers fire 2 flaming arrows & +2.5u range',
  },
];

export const LEVEL1_CONFIG = {
  id: 'genesis-13-bethel-v5',
  schemaVersion: 5,
  chapterNumber: 1,
  sourceRef: 'Genesis 13:1–18',
  tickMs: 125,
  numbers: {
    INITIAL_FOOD: 120,
    INITIAL_WATER: 80,
    INITIAL_WOOD: 100,
    INITIAL_STONE: 40,
    BASE_POP_CAP: 8,
    HOUSE_POP_BONUS: 4,
    CARRIER_RECRUIT_COST_FOOD: 50,
    CARRIER_BATCH_AMOUNT: 10,
    GATHER_CHANNEL_TICKS: 14,
    ROAD_SPEED_MULT: 1.30,
    SARAI_SUPERVISE_YIELD_MULT: 1.25,
    SARAI_SUPERVISE_TRAIN_MULT: 1.50,
    INITIAL_TERRITORY_RADIUS: 10.0,
    BOUNDARY_EXPANSION_RADIUS: 7.5,
    ENGINEER_SURVEY_TICKS: 20,
    MIN_BUILDING_SEPARATION: 2.4,
    COOP_BUILDER_SPEED_BONUS: 0.65,
    HIGH_GROUND_MULT: 1.25,
    BRACE_STUN_TICKS: 6,
    HORN_AURA_COOLDOWN_TICKS: 120,
    HORN_AURA_DURATION_TICKS: 48,
    FRICTION_THRESHOLD_ACT4: 75,
    SIDE_QUEST_SHEEP_REWARD: 60,
    PARTING_SHARE_WATER_COST: 40,
    PARTING_GIFT_WOOD_COST: 50,
    CAMERA_DAMP_RATE: 8.0,
    FORMATION_SPACING: 1.15,
    SACRIFICE_COST_FOOD: 30,
    SACRIFICE_COST_WOOD: 20,
    SACRIFICE_FRICTION_REDUCTION: 25,
    SACRIFICE_FAVOR_TICKS: 480,
    HEALING_TENT_AURA_RADIUS: 6.0,
    HEALING_TENT_HP_RATE: 1,
  },
  unitTemplates: {
    carrier: {
      role: 'carrier' as const,
      nameZh: '营地搬运工',
      nameEn: 'Camp Carrier',
      costFood: 50,
      costWood: 0,
      costWater: 0,
      maxHp: 120,
      attack: 6,
      bonusVsBeast: 0,
      bonusVsInfantry: 0,
      meleeArmor: 0,
      rangedArmor: 0,
      attackRange: 1.5,
      speed: 0.25,
      visionRadius: 6.5,
      carryCapacity: 10,
    },
    spearman: {
      role: 'spearman' as const,
      nameZh: '家丁矛兵',
      nameEn: 'House Spearman',
      costFood: 40,
      costWood: 25,
      costWater: 0,
      maxHp: 140,
      attack: 12,
      bonusVsBeast: 12,
      bonusVsInfantry: 0,
      meleeArmor: 2,
      rangedArmor: 0,
      attackRange: 1.9,
      speed: 0.24,
      visionRadius: 7.5,
      carryCapacity: 5,
    },
    slinger: {
      role: 'slinger' as const,
      nameZh: '家丁投石手',
      nameEn: 'House Slinger',
      costFood: 35,
      costWood: 30,
      costWater: 0,
      maxHp: 95,
      attack: 11,
      bonusVsBeast: 2,
      bonusVsInfantry: 5,
      meleeArmor: 0,
      rangedArmor: 1,
      attackRange: 6.5,
      speed: 0.25,
      visionRadius: 8.5,
      carryCapacity: 5,
    },
  },
  buildingBlueprints: [
    {
      kind: 'mainTent',
      nameZh: '主营大帐',
      nameEn: 'Patriarch Main Tent',
      descZh: '族长中心：可招募搬运工、交纳全部资源，提供初始领土与 +8 人口',
      descEn: 'Town Center: trains carriers, accepts all resources, +8 pop',
      sprite: '/clay/bldg_main_tent.png',
      costFood: 0,
      costWater: 0,
      costWood: 0,
      costStone: 0,
      buildTicks: 0,
      maxHp: 600,
      visionRadius: 10.0,
      isDropOff: true,
      popBonus: 8,
    },
    {
      kind: 'altar',
      nameZh: '十二石立约祭坛',
      nameEn: 'Twelve-Stone Altar',
      descZh: '未凿原石筑成的圣约祭坛，周围建筑施工与训练速度 +20%，可举行感恩燔祭求告主名',
      descEn: 'Unhewn stone altar granting +20% build/train speed & Covenant Sacrifice ritual',
      sprite: '/clay/bldg_altar.png',
      costFood: 0,
      costWater: 0,
      costWood: 0,
      costStone: 0,
      buildTicks: 0,
      maxHp: 500,
      visionRadius: 8.5,
    },
    {
      kind: 'healingTent',
      nameZh: '没药医治帐篷',
      nameEn: 'Balm Healing Sanctuary',
      descZh: '急救与康复处：驻留其附近的受伤战士与平民持续恢复生命值（+8 HP/s），驱散伤痛疲惫',
      descEn: 'Healing Sanctuary: rapidly restores health (+8 HP/s) to wounded units stationed nearby',
      sprite: '/clay/bldg_house.png',
      costFood: 0,
      costWater: 25,
      costWood: 45,
      costStone: 0,
      buildTicks: 18,
      maxHp: 320,
      visionRadius: 8.0,
    },
    {
      kind: 'house',
      nameZh: '副帐与蓄水石井',
      nameEn: 'Cistern House',
      descZh: '提供 +4 人口上限，并小幅降低草场摩擦',
      descEn: 'Provides +4 population capacity',
      sprite: '/clay/bldg_house.png',
      costFood: 0,
      costWater: 0,
      costWood: 40,
      costStone: 0,
      buildTicks: 20,
      maxHp: 280,
      visionRadius: 6.5,
      popBonus: 4,
    },
    {
      kind: 'depot',
      nameZh: '伐木与采石货栈',
      nameEn: 'Supply Depot',
      descZh: '就近交货点：建在森林、山泉或石矿旁可大幅缩短搬运工往返路程',
      descEn: 'Drop-off depot for wood, water, food, and stone',
      sprite: '/clay/bldg_depot.png',
      costFood: 0,
      costWater: 0,
      costWood: 50,
      costStone: 0,
      buildTicks: 22,
      maxHp: 320,
      visionRadius: 7.0,
      isDropOff: true,
    },
    {
      kind: 'watchtower',
      nameZh: '石木瞭望箭塔',
      nameEn: 'Stone-Timber Watchtower',
      descZh: '防御高塔：驱散大范围迷雾并自动向敌群发射火箭（智能分火）',
      descEn: 'Defensive tower that reveals fog and fires arrows',
      sprite: '/clay/bldg_watchtower.png',
      costFood: 0,
      costWater: 0,
      costWood: 40,
      costStone: 35,
      buildTicks: 28,
      maxHp: 420,
      visionRadius: 12.0,
      attackRange: 8.5,
      attackDamage: 18,
      attackCooldown: 10,
    },
    {
      kind: 'barracks',
      nameZh: '家丁备战哨营',
      nameEn: 'House Guard Barracks',
      descZh: '军事营地：将营地搬运工转职训练为「家丁矛兵」或「家丁投石手」',
      descEn: 'Converts carriers into House Spearmen or Slingers',
      sprite: '/clay/bldg_barracks.png',
      costFood: 0,
      costWater: 0,
      costWood: 80,
      costStone: 20,
      buildTicks: 30,
      maxHp: 450,
      visionRadius: 8.0,
    },
    {
      kind: 'landmarkOlive',
      nameZh: '地标：橄榄梯田庄园',
      nameEn: 'Landmark: Olive Terrace',
      descZh: '时代Ⅱ经济地标：晋升伯特利立约期，每 5s 自动产出 +8 粮草与 +5 饮水',
      descEn: 'Age II Economic Landmark: +8 food & +5 water every 5s',
      sprite: '/clay/bldg_house.png',
      costFood: 150,
      costWater: 0,
      costWood: 80,
      costStone: 40,
      buildTicks: 34,
      maxHp: 550,
      visionRadius: 9.5,
      isAge2Landmark: true,
      isDropOff: true,
    },
    {
      kind: 'landmarkEncampment',
      nameZh: '地标：大马色备战营垒',
      nameEn: 'Landmark: Damascus Redoubt',
      descZh: '时代Ⅱ军事地标：晋升伯特利立约期，建成即赠 2 名家丁矛兵并可快速募兵',
      descEn: 'Age II Military Landmark: grants 2 free Spearmen & trains units',
      sprite: '/clay/bldg_barracks.png',
      costFood: 150,
      costWater: 0,
      costWood: 80,
      costStone: 40,
      buildTicks: 34,
      maxHp: 600,
      visionRadius: 10.0,
      isAge2Landmark: true,
    },
  ] satisfies BuildingBlueprint[],
  initialBuildings: [
    { id: 'b-main', kind: 'mainTent' as const, x: -6.5, z: 3.5 },
    { id: 'b-altar', kind: 'altar' as const, x: -2.0, z: -1.8 },
  ],
  boundaryPosts: [
    { id: 'post-west', nameZh: '西泉界石桩', nameEn: 'Western Spring Boundary', x: -13.5, z: 0.5, radius: 7.5 },
    { id: 'post-north', nameZh: '北坡石矿界石桩', nameEn: 'Northern Quarry Boundary', x: -1.5, z: -7.2, radius: 7.5 },
    { id: 'post-east', nameZh: '东谷林地界石桩', nameEn: 'Eastern Grove Boundary', x: 5.5, z: 4.5, radius: 7.5 },
  ] satisfies BoundaryPostBlueprint[],
  neutralLandmarks: [
    { id: 'lostSheep', nameZh: '支线：迷途羔羊林地', nameEn: 'Lost Lambs Grove', x: 13.5, z: -3.5, costWood: 0, costStone: 0 },
    { id: 'ancientWell', nameZh: '支线：迦南古旧水井', nameEn: 'Ancient Canaanite Well', x: -15.5, z: -5.5, costWood: 25, costStone: 15 },
    { id: 'wolfDen', nameZh: '支线：北岭狼穴前哨', nameEn: 'Northern Wolf Den', x: 10.5, z: -11.0, costWood: 0, costStone: 0 },
  ] satisfies NeutralLandmarkBlueprint[],
  resources: [
    { id: 'spring-1', kind: 'water', nameZh: '西侧活水泉', nameEn: 'Western Spring', x: -14.8, z: 2.2, amount: 350 },
    { id: 'spring-2', kind: 'water', nameZh: '山谷清泉', nameEn: 'Valley Spring', x: -12.0, z: -1.8, amount: 300 },
    { id: 'wood-1', kind: 'wood', nameZh: '营南相思林', nameEn: 'Southern Acacia', x: -9.5, z: 8.8, amount: 320 },
    { id: 'wood-2', kind: 'wood', nameZh: '中谷橄榄林', nameEn: 'Central Olive Grove', x: 2.5, z: 8.5, amount: 350 },
    { id: 'wood-3', kind: 'wood', nameZh: '东坡橡树林', nameEn: 'Eastern Oak Woods', x: 12.5, z: 2.5, amount: 350 },
    { id: 'stone-1', kind: 'stone', nameZh: '北坡石灰岩矿', nameEn: 'Northern Limestone Quarry', x: -2.2, z: -8.5, amount: 280 },
    { id: 'stone-2', kind: 'stone', nameZh: '东岭采石场', nameEn: 'Eastern Stone Outcrop', x: 7.2, z: -5.5, amount: 280 },
    { id: 'food-1', kind: 'food', nameZh: '东南牧场草地', nameEn: 'Southeast Pasture', x: 8.5, z: 6.5, amount: 450 },
    { id: 'food-2', kind: 'food', nameZh: '南坡无花果丛', nameEn: 'Wild Fig Bushes', x: -3.5, z: 9.2, amount: 260 },
  ] satisfies ResourceBlueprint[],
  targets: {
    depot: { x: -6.5, z: 3.5 },
    rest: { x: -6.5, z: 4.5 },
    pasture: { x: 9.2, z: 6.5 },
    lot: { x: 9.2, z: 6.2 },
    ridge: { x: 5.5, z: -8.0 },
  },
  actors: [
    {
      id: 'abram',
      name: '亚伯兰',
      role: 'leader',
      tags: ['infantry', 'melee'],
      attackKind: 'melee',
      color: '#2563eb',
      startX: -4.8,
      startZ: 2.5,
      maxHp: 240,
      maxEnergy: 100,
      attack: 22,
      bonusVsBeast: 8,
      bonusVsInfantry: 4,
      meleeArmor: 3,
      rangedArmor: 2,
      attackRange: 1.9,
      speed: 0.25,
      visionRadius: 9.0,
      carryCapacity: 10,
    },
    {
      id: 'sarai',
      name: '撒莱',
      role: 'organizer',
      tags: ['civilian', 'ranged'],
      attackKind: 'ranged',
      color: '#db2777',
      startX: -6.2,
      startZ: 2.8,
      maxHp: 170,
      maxEnergy: 100,
      attack: 10,
      bonusVsBeast: 0,
      bonusVsInfantry: 0,
      meleeArmor: 1,
      rangedArmor: 1,
      attackRange: 4.0,
      speed: 0.23,
      visionRadius: 8.0,
      carryCapacity: 10,
    },
    {
      id: 'eli',
      name: '以利以谢',
      role: 'scout',
      tags: ['cavalry', 'melee'],
      attackKind: 'melee',
      color: '#059669',
      startX: -2.8,
      startZ: 0.8,
      maxHp: 190,
      maxEnergy: 100,
      attack: 18,
      bonusVsBeast: 6,
      bonusVsInfantry: 0,
      meleeArmor: 1,
      rangedArmor: 3,
      attackRange: 1.9,
      speed: 0.28,
      visionRadius: 11.0,
      carryCapacity: 10,
    },
    {
      id: 'asa',
      name: '乌珥',
      role: 'engineer',
      tags: ['civilian', 'melee'],
      attackKind: 'torch',
      color: '#d97706',
      startX: -5.2,
      startZ: 5.5,
      maxHp: 175,
      maxEnergy: 100,
      attack: 14,
      bonusVsBeast: 4,
      bonusVsInfantry: 0,
      meleeArmor: 1,
      rangedArmor: 1,
      attackRange: 1.8,
      speed: 0.24,
      visionRadius: 7.5,
      carryCapacity: 10,
    },
    {
      id: 'nura',
      name: '夏甲',
      role: 'carrier',
      tags: ['civilian'],
      attackKind: 'melee',
      color: '#0891b2',
      startX: -8.8,
      startZ: 2.8,
      maxHp: 140,
      maxEnergy: 100,
      attack: 7,
      bonusVsBeast: 0,
      bonusVsInfantry: 0,
      meleeArmor: 0,
      rangedArmor: 0,
      attackRange: 1.5,
      speed: 0.26,
      visionRadius: 7.0,
      carryCapacity: 15,
    },
    {
      id: 'carrier-1',
      name: '营地搬运工#1',
      role: 'carrier',
      tags: ['civilian'],
      attackKind: 'melee',
      color: '#0284c7',
      startX: -7.8,
      startZ: 5.8,
      maxHp: 125,
      maxEnergy: 100,
      attack: 6,
      bonusVsBeast: 0,
      bonusVsInfantry: 0,
      meleeArmor: 0,
      rangedArmor: 0,
      attackRange: 1.5,
      speed: 0.25,
      visionRadius: 6.5,
      carryCapacity: 10,
    },
    {
      id: 'lot',
      name: '罗得',
      role: 'herdsman',
      tags: ['infantry', 'melee'],
      attackKind: 'melee',
      color: '#b45309',
      startX: 8.8,
      startZ: 6.2,
      maxHp: 185,
      maxEnergy: 100,
      attack: 15,
      bonusVsBeast: 6,
      bonusVsInfantry: 0,
      meleeArmor: 1,
      rangedArmor: 1,
      attackRange: 1.8,
      speed: 0.23,
      visionRadius: 7.5,
      carryCapacity: 10,
    },
  ] satisfies ActorConfig[],
  enemies: [
    {
      id: 'wolf-1',
      kind: 'wolf',
      nameZh: '北坡灰狼',
      nameEn: 'Ridge Grey Wolf',
      tags: ['beast', 'melee'],
      attackKind: 'melee',
      x: 4.5,
      z: -7.5,
      maxHp: 95,
      attack: 11,
      meleeArmor: 0,
      rangedArmor: 0,
      attackRange: 1.5,
      speed: 0.19,
      aggroRange: 5.8,
    },
    {
      id: 'wolf-2',
      kind: 'wolf',
      nameZh: '北坡灰狼',
      nameEn: 'Ridge Grey Wolf',
      tags: ['beast', 'melee'],
      attackKind: 'melee',
      x: 7.8,
      z: -6.8,
      maxHp: 95,
      attack: 11,
      meleeArmor: 0,
      rangedArmor: 0,
      attackRange: 1.5,
      speed: 0.19,
      aggroRange: 5.8,
    },
    {
      id: 'raider-1',
      kind: 'raider',
      nameZh: '荒原投石掠夺者',
      nameEn: 'Wilderness Raider Slinger',
      tags: ['infantry', 'ranged'],
      attackKind: 'ranged',
      x: 13.0,
      z: -6.5,
      maxHp: 85,
      attack: 10,
      meleeArmor: 0,
      rangedArmor: 1,
      attackRange: 5.8,
      speed: 0.18,
      aggroRange: 6.5,
    },
    {
      id: 'alpha-1',
      kind: 'alphaWolf',
      nameZh: '北岭狼王',
      nameEn: 'Northern Ridge Alpha',
      tags: ['beast', 'melee'],
      attackKind: 'melee',
      x: 10.5,
      z: -10.5,
      maxHp: 180,
      attack: 16,
      meleeArmor: 2,
      rangedArmor: 1,
      attackRange: 1.7,
      speed: 0.21,
      aggroRange: 6.8,
    },
  ] satisfies EnemySpawnConfig[],
} as const;
