import { getTerrainHeight, LEVEL1_CONFIG, PERKS, WORLD_DIMENSIONS } from './config';
import type {
  AttackKind,
  BuildingBlueprint,
  BuildingKind,
  LevelPhase,
  OrderKind,
  PartingChoice,
  PerkId,
  ResourceKind,
  Role,
  UnitTag,
} from './config';

export type {
  AttackKind,
  BuildingBlueprint,
  BuildingKind,
  LevelPhase,
  OrderKind,
  PartingChoice,
  PerkId,
  ResourceKind,
  Role,
  UnitTag,
};

export type Order = {
  kind: OrderKind;
  x: number;
  z: number;
  label: string;
  targetId?: string;
};

export type ActorActivity = 'idle' | 'moving' | 'working' | 'returning' | 'fighting' | 'supervising' | 'rest';
export type CarryingPayload = { kind: ResourceKind; amount: number; sourceId: string } | null;

export type Actor = {
  id: string;
  name: string;
  role: Role;
  tags: UnitTag[];
  attackKind: AttackKind;
  color: string;
  x: number;
  z: number;
  hp: number;
  maxHp: number;
  energy: number;
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
  attackCd: number;
  braceCd: number;
  hornBuffTicks: number;
  supervisingBuildingId?: string;
  activity: ActorActivity;
  workProgress: number;
  workTicks: number;
  carrying: CarryingPayload;
  facing: number;
  queue: Order[];
};

export type BuildingState = {
  id: string;
  kind: BuildingKind;
  nameZh: string;
  nameEn: string;
  x: number;
  z: number;
  hp: number;
  maxHp: number;
  started: boolean;
  built: boolean;
  progress: number;
  visionRadius: number;
  attackCd: number;
};

export type TerritoryCircle = {
  id: string;
  x: number;
  z: number;
  radius: number;
};

export type BoundaryPostState = {
  id: string;
  nameZh: string;
  nameEn: string;
  x: number;
  z: number;
  radius: number;
  claimed: boolean;
  progress: number;
};

export type NeutralLandmarkState = {
  id: 'lostSheep' | 'ancientWell' | 'wolfDen';
  nameZh: string;
  nameEn: string;
  x: number;
  z: number;
  costWood: number;
  costStone: number;
  completed: boolean;
  progress: number;
};

export type ResourceNode = {
  id: string;
  kind: ResourceKind;
  nameZh: string;
  nameEn: string;
  x: number;
  z: number;
  amount: number;
  maxAmount: number;
};

export type Enemy = {
  id: string;
  kind: 'wolf' | 'alphaWolf' | 'raider';
  nameZh: string;
  nameEn: string;
  tags: UnitTag[];
  attackKind: AttackKind;
  x: number;
  z: number;
  homeX: number;
  homeZ: number;
  hp: number;
  maxHp: number;
  pendingDamage: number;
  attack: number;
  meleeArmor: number;
  rangedArmor: number;
  attackRange: number;
  speed: number;
  aggroRange: number;
  attackCd: number;
  stunTicks: number;
  facing: number;
};

export type Projectile = {
  id: string;
  fromX: number;
  fromZ: number;
  toX: number;
  toZ: number;
  targetEnemyId: string;
  damage: number;
  progress: number;
  color: string;
};

export type VisualEffect = {
  id: string;
  kind: 'horn' | 'brace' | 'hit' | 'claim' | 'heal' | 'supervise';
  x: number;
  z: number;
  radius: number;
  ttl: number;
  maxTtl: number;
};

export type ChapterSummary = {
  completedChapter: number;
  partingChoice: PartingChoice;
  escortedByCompanion: boolean;
  logisticsTier: 'low' | 'mid' | 'high';
  remainingFood: number;
  remainingWater: number;
  remainingWood: number;
  remainingStone: number;
  harmony: number;
};

export type FlockState = {
  id: string;
  owner: 'abram' | 'lot';
  nameZh: string;
  nameEn: string;
  x: number;
  z: number;
  targetX?: number;
  targetZ?: number;
  sheepCount: number;
};

export type Game = {
  schemaVersion: number;
  tickCount: number;
  age: 1 | 2;
  actors: Actor[];
  buildings: BuildingState[];
  territories: TerritoryCircle[];
  boundaryPosts: BoundaryPostState[];
  landmarks: NeutralLandmarkState[];
  resources: ResourceNode[];
  flocks: FlockState[];
  enemies: Enemy[];
  projectiles: Projectile[];
  effects: VisualEffect[];
  fog: number[];
  food: number;
  water: number;
  wood: number;
  stone: number;
  popCap: number;
  trust: number;
  friction: number;
  day: number;
  hornCooldown: number;
  divineFavorTicks: number;
  sacrificesPerformed: number;
  perks: PerkId[];
  pendingPerkChoices: number;
  phase: LevelPhase;
  escortDone: boolean;
  paused: boolean;
  ending?: string;
  summary?: ChapterSummary;
  log: string[];
};

export const targets = LEVEL1_CONFIG.targets;
const SAVE_KEY = 'promise-path-next-save-v5';
const SUMMARY_KEY = 'promise-path-campaign-summary-v1';

export function fogIndex(col: number, row: number): number {
  return row * WORLD_DIMENSIONS.fogCols + col;
}

export function worldToFog(x: number, z: number): { col: number; row: number } {
  const { width, depth, halfW, halfD, fogCols, fogRows } = WORLD_DIMENSIONS;
  const col = Math.max(0, Math.min(fogCols - 1, Math.floor(((x + halfW) / width) * fogCols)));
  const row = Math.max(0, Math.min(fogRows - 1, Math.floor(((z + halfD) / depth) * fogRows)));
  return { col, row };
}

export function isVisibleInFog(fog: number[], x: number, z: number): boolean {
  const { col, row } = worldToFog(x, z);
  return fog[fogIndex(col, row)] === 2;
}

export function isInTerritory(territories: TerritoryCircle[], x: number, z: number): boolean {
  return territories.some(t => Math.hypot(x - t.x, z - t.z) <= t.radius);
}

export function getBlueprint(kind: BuildingKind): BuildingBlueprint {
  return LEVEL1_CONFIG.buildingBlueprints.find(b => b.kind === kind)!;
}

export function computePopCap(buildings: BuildingState[]): number {
  let cap = 0;
  for (const b of buildings) {
    if (!b.built) continue;
    const bp = getBlueprint(b.kind);
    if (bp.popBonus) cap += bp.popBonus;
  }
  return Math.max(LEVEL1_CONFIG.numbers.BASE_POP_CAP, cap);
}

function computeFog(
  prevFog: number[],
  actors: Actor[],
  buildings: BuildingState[],
  landmarks: NeutralLandmarkState[],
  perks: PerkId[]
): number[] {
  const { width, depth, halfW, halfD, fogCols, fogRows } = WORLD_DIMENSIONS;
  const next = prevFog.map(v => (v === 2 ? 1 : v));
  const cellW = width / fogCols;
  const cellD = depth / fogRows;
  const hasBrazierPerk = perks.includes('twinBrazier');

  const reveal = (wx: number, wz: number, radius: number) => {
    const r2 = radius * radius;
    for (let row = 0; row < fogRows; row++) {
      const cz = -halfD + (row + 0.5) * cellD;
      const dz = cz - wz;
      if (dz * dz > r2) continue;
      for (let col = 0; col < fogCols; col++) {
        const cx = -halfW + (col + 0.5) * cellW;
        const dx = cx - wx;
        if (dx * dx + dz * dz <= r2) {
          next[fogIndex(col, row)] = 2;
        }
      }
    }
  };

  for (const a of actors) {
    if (a.hp > 0) reveal(a.x, a.z, a.visionRadius);
  }
  for (const b of buildings) {
    if (b.built || b.started) {
      const extra = b.kind === 'watchtower' && hasBrazierPerk ? 2.5 : 0;
      reveal(b.x, b.z, (b.built ? b.visionRadius : 5.0) + extra);
    }
  }
  for (const lm of landmarks) {
    if (lm.completed) reveal(lm.x, lm.z, 7.5);
  }
  return next;
}

export function newGame(): Game {
  const { numbers, actors, initialBuildings, boundaryPosts, neutralLandmarks, resources, enemies, schemaVersion } =
    LEVEL1_CONFIG;

  const initActors: Actor[] = actors.map(a => ({
    id: a.id,
    name: a.name,
    role: a.role,
    tags: [...a.tags],
    attackKind: a.attackKind,
    color: a.color,
    x: a.startX,
    z: a.startZ,
    hp: a.maxHp,
    maxHp: a.maxHp,
    energy: a.maxEnergy,
    maxEnergy: a.maxEnergy,
    attack: a.attack,
    bonusVsBeast: a.bonusVsBeast,
    bonusVsInfantry: a.bonusVsInfantry,
    meleeArmor: a.meleeArmor,
    rangedArmor: a.rangedArmor,
    attackRange: a.attackRange,
    speed: a.speed,
    visionRadius: a.visionRadius,
    carryCapacity: a.carryCapacity,
    attackCd: 0,
    braceCd: 0,
    hornBuffTicks: 0,
    activity: 'idle',
    workProgress: 0,
    workTicks: 0,
    carrying: null,
    facing: 1,
    queue: [],
  }));

  const initBuildings: BuildingState[] = initialBuildings.map(ib => {
    const bp = getBlueprint(ib.kind);
    return {
      id: ib.id,
      kind: ib.kind,
      nameZh: bp.nameZh,
      nameEn: bp.nameEn,
      x: ib.x,
      z: ib.z,
      hp: bp.maxHp,
      maxHp: bp.maxHp,
      started: true,
      built: true,
      progress: 1,
      visionRadius: bp.visionRadius,
      attackCd: 0,
    };
  });

  const initTerritories: TerritoryCircle[] = [
    { id: 'terr-main', x: -6.5, z: 3.5, radius: numbers.INITIAL_TERRITORY_RADIUS },
  ];

  const initPosts: BoundaryPostState[] = boundaryPosts.map(p => ({
    ...p,
    claimed: false,
    progress: 0,
  }));

  const initLandmarks: NeutralLandmarkState[] = neutralLandmarks.map(l => ({
    ...l,
    completed: false,
    progress: 0,
  }));

  const initResources: ResourceNode[] = resources.map(r => ({
    ...r,
    maxAmount: r.amount,
  }));

  const initEnemies: Enemy[] = enemies.map(e => ({
    id: e.id,
    kind: e.kind,
    nameZh: e.nameZh,
    nameEn: e.nameEn,
    tags: [...e.tags],
    attackKind: e.attackKind,
    x: e.x,
    z: e.z,
    homeX: e.x,
    homeZ: e.z,
    hp: e.maxHp,
    maxHp: e.maxHp,
    pendingDamage: 0,
    attack: e.attack,
    meleeArmor: e.meleeArmor,
    rangedArmor: e.rangedArmor,
    attackRange: e.attackRange,
    speed: e.speed,
    aggroRange: e.aggroRange,
    attackCd: 0,
    stunTicks: 0,
    facing: -1,
  }));

  const initFlocks: FlockState[] = (LEVEL1_CONFIG.flocks ?? []).map(f => ({
    id: f.id,
    owner: f.owner,
    nameZh: f.nameZh,
    nameEn: f.nameEn,
    x: f.x,
    z: f.z,
    sheepCount: f.sheepCount,
  }));

  const emptyFog = new Array<number>(WORLD_DIMENSIONS.fogCols * WORLD_DIMENSIONS.fogRows).fill(0);
  const fog = computeFog(emptyFog, initActors, initBuildings, initLandmarks, []);

  return {
    schemaVersion,
    tickCount: 0,
    age: 1,
    actors: initActors,
    buildings: initBuildings,
    territories: initTerritories,
    boundaryPosts: initPosts,
    landmarks: initLandmarks,
    resources: initResources,
    flocks: initFlocks,
    enemies: initEnemies,
    projectiles: [],
    effects: [],
    fog,
    food: numbers.INITIAL_FOOD,
    water: numbers.INITIAL_WATER,
    wood: numbers.INITIAL_WOOD,
    stone: numbers.INITIAL_STONE,
    popCap: computePopCap(initBuildings),
    trust: 3,
    friction: 18,
    day: 1,
    hornCooldown: 0,
    divineFavorTicks: 0,
    sacrificesPerformed: 0,
    perks: [],
    pendingPerkChoices: 0,
    phase: 'act1_camp',
    escortDone: false,
    paused: false,
    log: ['【第一幕：重返筑坛之地】在领土内自由选址建造「伐木货栈」与「副帐房舍」，派乌珥插界石扩地，派撒莱督工提速！'],
  };
}

export function hasSavedGame(): boolean {
  try { return localStorage.getItem(SAVE_KEY) !== null; } catch { return false; }
}

export function loadGame(): Game {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return newGame();
    const data = JSON.parse(raw) as Partial<Game>;
    if (
      data.schemaVersion !== LEVEL1_CONFIG.schemaVersion ||
      !Array.isArray(data.actors) ||
      !Array.isArray(data.buildings) ||
      !Array.isArray(data.territories) ||
      !Array.isArray(data.fog) ||
      data.fog.length !== WORLD_DIMENSIONS.fogCols * WORLD_DIMENSIONS.fogRows ||
      !Number.isFinite(data.food) ||
      !Number.isFinite(data.water) ||
      !Number.isFinite(data.wood) ||
      !Number.isFinite(data.stone)
    ) {
      return newGame();
    }
    return {
      ...(data as Game),
      flocks: Array.isArray(data.flocks)
        ? data.flocks
        : (LEVEL1_CONFIG.flocks ?? []).map(f => ({ ...f })),
      divineFavorTicks: data.divineFavorTicks ?? 0,
      sacrificesPerformed: data.sacrificesPerformed ?? 0,
    };
  } catch {
    return newGame();
  }
}

export function saveGame(game: Game): boolean {
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(game));
    if (game.summary) {
      localStorage.setItem(SUMMARY_KEY, JSON.stringify(game.summary));
    }
    return true;
  } catch {
    return false;
  }
}

export function order(kind: OrderKind, label: string, x: number, z: number, targetId?: string): Order {
  return { kind, label, x, z, targetId };
}

export function pushLog(game: Game, line: string): Game {
  return { ...game, log: [line, ...game.log].slice(0, 9) };
}

/**
 * Validate free-form building placement (territory-and-building/design.md Rule 2)
 */
export function isValidPlacement(
  game: Game,
  kind: BuildingKind,
  x: number,
  z: number
): { valid: boolean; reasonZh: string; reasonEn: string } {
  const bp = getBlueprint(kind);
  if (!isInTerritory(game.territories, x, z)) {
    return { valid: false, reasonZh: '超出本方领土（请派工程先驱乌珥插界石扩地）', reasonEn: 'Outside territory (expand with Engineer Ur)' };
  }
  if (x < -12.5 && z > -3.5 && z < 4.0) {
    return { valid: false, reasonZh: '不可在活水泉池内建造', reasonEn: 'Cannot build in spring pool' };
  }
  const minSep = LEVEL1_CONFIG.numbers.MIN_BUILDING_SEPARATION;
  for (const b of game.buildings) {
    if (Math.hypot(b.x - x, b.z - z) < minSep) {
      return { valid: false, reasonZh: '与其他建筑间距不足', reasonEn: 'Too close to another building' };
    }
  }
  if (bp.isAge2Landmark && game.buildings.some(b => getBlueprint(b.kind).isAge2Landmark)) {
    return { valid: false, reasonZh: '时代Ⅱ地标限选一座建造', reasonEn: 'Only one Age II Landmark allowed' };
  }
  if (
    game.food < bp.costFood ||
    game.water < bp.costWater ||
    game.wood < bp.costWood ||
    game.stone < bp.costStone
  ) {
    return { valid: false, reasonZh: '营地资源不足', reasonEn: 'Insufficient resources' };
  }
  return { valid: true, reasonZh: '可在此处落锤建造', reasonEn: 'Valid placement' };
}

/**
 * Free-form building placement (AoE Placement Ghost -> Foundation)
 */
export function placeBuilding(
  game: Game,
  kind: BuildingKind,
  x: number,
  z: number,
  actorIds: string[]
): Game {
  const check = isValidPlacement(game, kind, x, z);
  if (!check.valid) return pushLog(game, `无法建造：${check.reasonZh}`);

  const bp = getBlueprint(kind);
  const newId = `b-${kind}-${game.tickCount}-${game.buildings.length}`;
  const newBldg: BuildingState = {
    id: newId,
    kind,
    nameZh: bp.nameZh,
    nameEn: bp.nameEn,
    x,
    z,
    hp: bp.maxHp,
    maxHp: bp.maxHp,
    started: true,
    built: false,
    progress: 0.04,
    visionRadius: bp.visionRadius,
    attackCd: 0,
  };

  const candidateBuilders = game.actors.filter(
    a => actorIds.includes(a.id) && (a.role === 'engineer' || a.role === 'carrier' || a.role === 'leader')
  );
  const builderIds = candidateBuilders.length
    ? candidateBuilders.map(a => a.id)
    : [game.actors.find(a => a.role === 'engineer' || a.role === 'carrier')?.id ?? 'asa'];

  const actors = game.actors.map(a =>
    builderIds.includes(a.id)
      ? {
          ...a,
          carrying: null,
          supervisingBuildingId: undefined,
          activity: 'moving' as const,
          workTicks: 0,
          workProgress: 0,
          queue: [order('build', `建造${bp.nameZh}`, x, z, newId)],
        }
      : a
  );

  return pushLog(
    {
      ...game,
      food: game.food - bp.costFood,
      water: game.water - bp.costWater,
      wood: game.wood - bp.costWood,
      stone: game.stone - bp.costStone,
      buildings: [...game.buildings, newBldg],
      actors,
      paused: false,
    },
    `已在 (${x.toFixed(1)}, ${z.toFixed(1)}) 奠基「${bp.nameZh}」，工程队正前往施工！`
  );
}

/**
 * Recruit a new Camp Carrier at Main Tent (carrier-logistics/design.md Rule 3)
 */
export function recruitCarrier(game: Game): Game {
  const cost = LEVEL1_CONFIG.numbers.CARRIER_RECRUIT_COST_FOOD;
  if (game.actors.length >= game.popCap) {
    return pushLog(game, '人口已达上限！请先建造「副帐与蓄水石井」扩充人口。');
  }
  if (game.food < cost) {
    return pushLog(game, `招募营地搬运工需 ${cost} 粮草。`);
  }
  const main = game.buildings.find(b => b.kind === 'mainTent')!;
  const tmpl = LEVEL1_CONFIG.unitTemplates.carrier;
  const idx = game.actors.filter(a => a.role === 'carrier').length + 1;
  const newCarrier: Actor = {
    id: `carrier-${game.tickCount}-${idx}`,
    name: `营地搬运工#${idx}`,
    role: 'carrier',
    tags: ['civilian'],
    attackKind: 'melee',
    color: '#0284c7',
    x: main.x + 1.2,
    z: main.z + 0.9,
    hp: tmpl.maxHp,
    maxHp: tmpl.maxHp,
    energy: 100,
    maxEnergy: 100,
    attack: tmpl.attack,
    bonusVsBeast: 0,
    bonusVsInfantry: 0,
    meleeArmor: 0,
    rangedArmor: 0,
    attackRange: tmpl.attackRange,
    speed: tmpl.speed,
    visionRadius: tmpl.visionRadius,
    carryCapacity: tmpl.carryCapacity,
    attackCd: 0,
    braceCd: 0,
    hornBuffTicks: 0,
    activity: 'idle',
    workProgress: 0,
    workTicks: 0,
    carrying: null,
    facing: 1,
    queue: [],
  };

  return pushLog(
    { ...game, food: game.food - cost, actors: [...game.actors, newCarrier] },
    `已招募「${newCarrier.name}」，可派往山泉或树林建立自动物流！`
  );
}

/**
 * Workforce Dilemma: Convert an existing Carrier into a House Spearman or Slinger at Barracks
 */
export function trainMilitary(game: Game, role: 'spearman' | 'slinger'): Game {
  const barracks = game.buildings.find(b => (b.kind === 'barracks' || b.kind === 'landmarkEncampment') && b.built);
  if (!barracks) {
    return pushLog(game, '请先建造「家丁备战哨营」或军事地标，方可转职训练家丁部队。');
  }
  const carriers = game.actors.filter(a => a.role === 'carrier' && a.hp > 0);
  if (carriers.length <= 1) {
    return pushLog(game, '防死锁保护：营地至少需保留 1 名搬运工维持物流，请先在主帐招募搬运工！');
  }
  const tmpl = LEVEL1_CONFIG.unitTemplates[role];
  if (game.food < tmpl.costFood || game.wood < tmpl.costWood) {
    return pushLog(game, `训练${tmpl.nameZh}需 ${tmpl.costFood} 粮草、${tmpl.costWood} 木料。`);
  }

  // Pick a non-Hagar carrier first so named character Hagar stays carrier as long as possible
  const convertTarget = carriers.find(c => c.id !== 'nura') ?? carriers[0];
  const count = game.actors.filter(a => a.role === role).length + 1;
  const spearBonus = role === 'spearman' && game.perks.includes('bronzeSpear') ? 4 : 0;

  const actors = game.actors.map(a =>
    a.id === convertTarget.id
      ? {
          ...a,
          id: `${role}-${game.tickCount}-${count}`,
          name: `${tmpl.nameZh}#${count}`,
          role,
          tags: (role === 'spearman' ? ['infantry', 'melee'] : ['infantry', 'ranged']) as UnitTag[],
          attackKind: (role === 'spearman' ? 'melee' : 'ranged') as AttackKind,
          color: role === 'spearman' ? '#1d4ed8' : '#7c3aed',
          x: barracks.x + 1.0,
          z: barracks.z - 0.8,
          hp: tmpl.maxHp,
          maxHp: tmpl.maxHp,
          attack: tmpl.attack + spearBonus,
          bonusVsBeast: tmpl.bonusVsBeast,
          bonusVsInfantry: tmpl.bonusVsInfantry,
          meleeArmor: tmpl.meleeArmor,
          rangedArmor: tmpl.rangedArmor,
          attackRange: tmpl.attackRange,
          speed: tmpl.speed,
          visionRadius: tmpl.visionRadius,
          carryCapacity: tmpl.carryCapacity,
          carrying: null,
          activity: 'idle' as const,
          queue: [],
        }
      : a
  );

  return pushLog(
    {
      ...game,
      food: game.food - tmpl.costFood,
      wood: game.wood - tmpl.costWood,
      actors,
    },
    `${convertTarget.name} 已在哨营披甲转职为「${tmpl.nameZh}#${count}」！`
  );
}

/**
 * Sarai Matriarch Supervise (carrier-logistics/design.md Rule 5)
 */
export function assignSupervise(game: Game, buildingId: string): Game {
  const b = game.buildings.find(x => x.id === buildingId);
  if (!b) return game;
  const actors = game.actors.map(a =>
    a.id === 'sarai'
      ? {
          ...a,
          carrying: null,
          supervisingBuildingId: buildingId,
          activity: 'moving' as const,
          queue: [order('supervise', `督工${b.nameZh}`, b.x + 1.1, b.z + 0.6, buildingId)],
        }
      : a
  );
  return pushLog({ ...game, actors, paused: false }, `已派主母撒莱前往「${b.nameZh}」督工统筹！`);
}

/**
 * Abram's Watchman Horn Aura (combat-and-counters/design.md Rule 3)
 */
export function blowHorn(game: Game): Game {
  if (game.hornCooldown > 0) {
    return pushLog(game, '守望号角尚在冷却中。');
  }
  const abram = game.actors.find(a => a.id === 'abram');
  if (!abram) return game;
  const { HORN_AURA_COOLDOWN_TICKS, HORN_AURA_DURATION_TICKS } = LEVEL1_CONFIG.numbers;
  const actors = game.actors.map(a =>
    Math.hypot(a.x - abram.x, a.z - abram.z) <= 7.5
      ? { ...a, hornBuffTicks: HORN_AURA_DURATION_TICKS }
      : a
  );
  const effect: VisualEffect = {
    id: `horn-${game.tickCount}`,
    kind: 'horn',
    x: abram.x,
    z: abram.z,
    radius: 7.5,
    ttl: 12,
    maxTtl: 12,
  };
  return pushLog(
    {
      ...game,
      hornCooldown: HORN_AURA_COOLDOWN_TICKS,
      actors,
      effects: [...game.effects, effect],
    },
    '亚伯兰吹响「守望号角」！周围家丁双甲 +2、移速提升 15%！'
  );
}

/**
 * Select a Crucible Mid-Match Covenant Perk (bethel-campaign/design.md Rule 3)
 */
export function choosePerk(game: Game, perkId: PerkId): Game {
  if (game.pendingPerkChoices <= 0 || game.perks.includes(perkId)) return game;
  const perk = PERKS.find(p => p.id === perkId)!;
  const actors =
    perkId === 'bronzeSpear'
      ? game.actors.map(a => (a.role === 'spearman' ? { ...a, attack: a.attack + 4 } : a))
      : game.actors;

  return pushLog(
    {
      ...game,
      actors,
      perks: [...game.perks, perkId],
      pendingPerkChoices: Math.max(0, game.pendingPerkChoices - 1),
    },
    `已颁布圣约策令：【${perk.nameZh}】— ${perk.descZh}！`
  );
}

/**
 * AoE4 Dual-Armor + Tag Bonus + High Ground Damage Formula (combat-and-counters/design.md Rule 1)
 */
export function computeCombatDamage(
  attacker: {
    attack: number;
    attackKind: AttackKind;
    bonusVsBeast: number;
    bonusVsInfantry: number;
    x?: number;
    z: number;
  },
  target: { tags: UnitTag[]; meleeArmor: number; rangedArmor: number; x?: number; z: number }
): number {
  let bonus = 0;
  if (target.tags.includes('beast') || target.tags.includes('cavalry')) bonus += attacker.bonusVsBeast;
  if (target.tags.includes('infantry')) bonus += attacker.bonusVsInfantry;
  const armor = attacker.attackKind === 'ranged' ? target.rangedArmor : target.meleeArmor;
  const hasTerrainCoords = attacker.x !== undefined && target.x !== undefined;
  const isHighGround = hasTerrainCoords
    ? getTerrainHeight(attacker.x!, attacker.z) - getTerrainHeight(target.x!, target.z) >=
      LEVEL1_CONFIG.numbers.HIGH_GROUND_HEIGHT_DIFF
    : attacker.z < -4.0 && target.z >= -4.0;
  const highGround = isHighGround ? LEVEL1_CONFIG.numbers.HIGH_GROUND_MULT : 1.0;
  return Math.max(1, Math.round((attacker.attack + bonus - armor) * highGround));
}

export function moveFlock(game: Game, flockId: string, x: number, z: number): Game {
  const { clampX, clampZ } = WORLD_DIMENSIONS;
  const tx = THREE.clamp(x, -clampX, clampX);
  const tz = THREE.clamp(z, -clampZ, clampZ);
  const flocks = (game.flocks ?? []).map(f =>
    f.id === flockId ? { ...f, targetX: tx, targetZ: tz } : f
  );
  return pushLog(
    { ...game, paused: false, flocks },
    '驱赶羊群前往新草场放牧，避开两家牧人争抢！'
  );
}

export function performSacrifice(game: Game): Game {
  const { numbers } = LEVEL1_CONFIG;
  const altar = game.buildings.find(b => b.kind === 'altar' && b.built);
  if (!altar) {
    return pushLog(game, '【献祭受阻】必须先保有未凿原石筑成的十二石立约祭坛！');
  }
  const foodCost = numbers.SACRIFICE_COST_FOOD;
  const woodCost = numbers.SACRIFICE_COST_WOOD;
  if (game.food < foodCost || game.wood < woodCost) {
    return pushLog(game, `【祭物不足】感恩献祭需要奉献纯洁羊羔（粮草 ${foodCost}）与香柏木柴（木材 ${woodCost}）！`);
  }

  const abram = game.actors.find(a => a.id === 'abram');
  const abramNearAltar = abram && Math.hypot(abram.x - altar.x, abram.z - altar.z) <= numbers.ALTAR_PRAY_RADIUS;
  if (!abramNearAltar) {
    return pushLog(game, '【筑坛求告】族长亚伯兰必须亲赴伯特利原石坛前主持圣约祈求！');
  }

  const newFood = game.food - foodCost + numbers.SACRIFICE_BLESSING_FOOD;
  const newWood = game.wood - woodCost;
  const newFriction = Math.max(0, game.friction - numbers.SACRIFICE_FRICTION_REDUCTION);
  const favorTicks = numbers.SACRIFICE_FAVOR_TICKS;

  const effects: VisualEffect[] = [
    ...game.effects,
    {
      id: `sac-fire-${game.tickCount}`,
      kind: 'heal',
      x: altar.x,
      z: altar.z,
      radius: 4.5,
      ttl: 60,
      maxTtl: 60,
    },
    {
      id: `sac-smoke-${game.tickCount}`,
      kind: 'supervise',
      x: altar.x,
      z: altar.z,
      radius: 3.5,
      ttl: 80,
      maxTtl: 80,
    },
  ];

  const note = `【创世记 13:4 筑坛求告】亚伯兰在伯特利原石坛前献祭求告耶和华的名！草场争端平息（摩擦 -${numbers.SACRIFICE_FRICTION_REDUCTION}），牧群蒙福（+${numbers.SACRIFICE_BLESSING_FOOD} 粮草），全军获得「神圣恩眷」（移速+15%，护甲+${numbers.SACRIFICE_ARMOR_BONUS}）！`;

  return {
    ...game,
    food: newFood,
    wood: newWood,
    friction: newFriction,
    trust: game.trust + 2,
    divineFavorTicks: favorTicks,
    sacrificesPerformed: (game.sacrificesPerformed ?? 0) + 1,
    effects,
    log: [note, ...game.log.slice(0, 39)],
  };
}

export function resolveParting(game: Game, choice: PartingChoice, escortWithCompanion: boolean): Game {
  if (game.phase !== 'act4_parting' || game.ending) return game;
  const { PARTING_SHARE_WATER_COST, PARTING_GIFT_WOOD_COST } = LEVEL1_CONFIG.numbers;
  let food = game.food;
  let water = game.water;
  let wood = game.wood;
  let trust = game.trust;
  let escortDone = false;
  let ending = '';

  if (choice === 'share') {
    if (water < PARTING_SHARE_WATER_COST) return pushLog(game, `饮水不足 ${PARTING_SHARE_WATER_COST}，无法共饮上泉。`);
    water -= PARTING_SHARE_WATER_COST;
    trust += 2;
    escortDone = escortWithCompanion;
    if (escortDone) trust += 1;
    ending =
      '亚伯兰对罗得说「你我不可相争」，两家共饮上泉后和睦分群。罗得举目先选了约旦河全平原东迁，亚伯兰留在迦南得蒙土地与后裔应许（创 13:8–17）。';
  } else if (choice === 'gift') {
    if (wood < PARTING_GIFT_WOOD_COST) return pushLog(game, `木料不足 ${PARTING_GIFT_WOOD_COST}，无法赠材助迁。`);
    wood -= PARTING_GIFT_WOOD_COST;
    trust += 3;
    escortDone = escortWithCompanion;
    ending =
      '亚伯兰赠予备用木料并派乌珥护送渡口，罗得先选约旦河平原东迁，两家守住骨肉深情，亚伯兰在伯特利与幔利再蒙应许。';
  } else {
    food = Math.max(0, food - 30);
    trust += 1;
    ending = '两家牧人急装分道以止息纷争，途中损耗 30 粮草，罗得先选约旦河平原东迁，亚伯兰留在迦南。';
  }

  const totalScore = food + water + wood + game.stone;
  const logisticsTier: ChapterSummary['logisticsTier'] =
    totalScore >= 320 ? 'high' : totalScore >= 180 ? 'mid' : 'low';

  const summary: ChapterSummary = {
    completedChapter: 1,
    partingChoice: choice,
    escortedByCompanion: escortDone,
    logisticsTier,
    remainingFood: food,
    remainingWater: water,
    remainingWood: wood,
    remainingStone: game.stone,
    harmony: trust,
  };

  const revealedFog = new Array<number>(WORLD_DIMENSIONS.fogCols * WORLD_DIMENSIONS.fogRows).fill(2);

  return pushLog(
    {
      ...game,
      food,
      water,
      wood,
      trust,
      escortDone,
      fog: revealedFog,
      phase: 'resolved',
      paused: true,
      ending,
      summary,
    },
    `${ending} 「耶和华对亚伯兰说：从你所在的地方，你举目向东西南北观看；凡你所看见的一切地，我都要赐给你和你的后裔，直到永远。」（创 13:14–15）`
  );
}

/**
 * Deterministic RTS Tick:
 * - Carrier nearest drop-off routing & road speed boost (+30%) & Sarai Supervise (+25% yield / +50% speed)
 * - Engineer boundary post expansion & neutral landmark repair
 * - Multi-worker building construction + Altar aura (+20%) + Age II Landmark evolution
 * - Watchtower & Slinger Anti-Overkill pendingDamage targeting + Spearman Brace + Boids separation
 */
export function tick(game: Game): Game {
  if (game.paused || game.ending) return game;

  const { numbers } = LEVEL1_CONFIG;
  let food = game.food;
  let water = game.water;
  let wood = game.wood;
  let stone = game.stone;
  let trust = game.trust;
  let friction = game.friction;
  let age = game.age;
  let phase = game.phase;
  let pendingPerkChoices = game.pendingPerkChoices;
  let divineFavorTicks = Math.max(0, (game.divineFavorTicks ?? 0) - 1);
  let sacrificesPerformed = game.sacrificesPerformed ?? 0;
  const notes: string[] = [];

  const hasAqueductPerk = game.perks.includes('livingAqueduct');
  const hasBrazierPerk = game.perks.includes('twinBrazier');
  const hasSpearPerk = game.perks.includes('bronzeSpear');

  // Passive Landmark / Ancient Well generation
  const oliveBuilt = game.buildings.some(b => b.kind === 'landmarkOlive' && b.built);
  if (oliveBuilt && game.tickCount % 40 === 0 && game.tickCount > 0) {
    food += 8;
    water += 5;
  }
  const wellRepaired = game.landmarks.find(l => l.id === 'ancientWell')?.completed ?? false;
  if (wellRepaired && game.tickCount % 8 === 0 && game.tickCount > 0) {
    water += 1;
  }

  let buildings = game.buildings.map(b => ({
    ...b,
    attackCd: Math.max(0, b.attackCd - 1),
  }));
  let territories = [...game.territories];
  let boundaryPosts = game.boundaryPosts.map(p => ({ ...p }));
  let landmarks = game.landmarks.map(l => ({ ...l }));
  let resources = game.resources.map(r => ({ ...r }));
  let enemies = game.enemies.map(e => ({
    ...e,
    attackCd: Math.max(0, e.attackCd - 1),
    stunTicks: Math.max(0, e.stunTicks - 1),
  }));

  // Check which building Sarai is actively supervising
  const sarai = game.actors.find(a => a.id === 'sarai');
  const supervisedBuildingId =
    sarai &&
    sarai.supervisingBuildingId &&
    buildings.some(
      b => b.id === sarai.supervisingBuildingId && Math.hypot(b.x - sarai.x, b.z - sarai.z) <= 2.2
    )
      ? sarai.supervisingBuildingId
      : undefined;

  // Advance projectiles & apply damage on arrival (releasing pendingDamage)
  const projectiles: Projectile[] = [];
  for (const p of game.projectiles) {
    const nextProg = p.progress + 0.35;
    if (nextProg < 1) {
      projectiles.push({ ...p, progress: nextProg });
    } else {
      const target = enemies.find(e => e.id === p.targetEnemyId);
      if (target) {
        target.pendingDamage = Math.max(0, target.pendingDamage - p.damage);
        if (target.hp > 0) {
          target.hp = Math.max(0, target.hp - p.damage);
          if (target.hp === 0) notes.push(`远程火力击倒了${target.nameZh}！`);
        }
      }
    }
  }

  const effects: VisualEffect[] = game.effects
    .map(ef => ({ ...ef, ttl: ef.ttl - 1 }))
    .filter(ef => ef.ttl > 0);

  // Watchtower auto-defense with Anti-Overkill Pending Damage distribution
  const towerBp = getBlueprint('watchtower');
  for (const b of buildings) {
    if (b.kind !== 'watchtower' || !b.built || b.attackCd > 0) continue;
    const range = (towerBp.attackRange ?? 8.5) + (hasBrazierPerk ? 2.5 : 0);
    const inRange = enemies.filter(e => e.hp > 0 && Math.hypot(e.x - b.x, e.z - b.z) <= range);
    if (!inRange.length) continue;

    // Anti-Overkill: prioritize targets that are NOT already doomed by in-flight projectiles
    const candidates = inRange.filter(e => e.hp - e.pendingDamage > 0);
    const chosen = (candidates.length ? candidates : inRange)[0];
    const shots = hasBrazierPerk ? 2 : 1;
    b.attackCd = towerBp.attackCooldown ?? 10;

    for (let s = 0; s < shots; s++) {
      const tEnemy = candidates[s] ?? chosen;
      const dmg = computeCombatDamage(
        { attack: towerBp.attackDamage ?? 18, attackKind: 'ranged', bonusVsBeast: 4, bonusVsInfantry: 2, z: b.z },
        tEnemy
      );
      tEnemy.pendingDamage += dmg;
      projectiles.push({
        id: `tarr-${game.tickCount}-${b.id}-${s}`,
        fromX: b.x,
        fromZ: b.z,
        toX: tEnemy.x,
        toZ: tEnemy.z,
        targetEnemyId: tEnemy.id,
        damage: dmg,
        progress: 0.1,
        color: '#fb923c',
      });
    }
  }

  // Helper: check if position is near a camp road connecting Main Tent to any built building
  const mainTent = buildings.find(b => b.kind === 'mainTent')!;
  const isOnRoad = (x: number, z: number): boolean => {
    for (const b of buildings) {
      if (!b.built || b.id === mainTent.id) continue;
      const vx = b.x - mainTent.x;
      const vz = b.z - mainTent.z;
      const len2 = vx * vx + vz * vz;
      if (len2 < 0.1) continue;
      const t = Math.max(0, Math.min(1, ((x - mainTent.x) * vx + (z - mainTent.z) * vz) / len2));
      const px = mainTent.x + t * vx;
      const pz = mainTent.z + t * vz;
      if (Math.hypot(x - px, z - pz) <= 1.35) return true;
    }
    return false;
  };

  // Find nearest built drop-off building
  const findNearestDropOff = (x: number, z: number): BuildingState => {
    const dropOffs = buildings.filter(b => b.built && getBlueprint(b.kind).isDropOff);
    return (
      dropOffs.sort((u, v) => Math.hypot(u.x - x, u.z - z) - Math.hypot(v.x - x, v.z - z))[0] ?? mainTent
    );
  };

  const stepTowards = (
    actor: Actor,
    tx: number,
    tz: number,
    radius: number,
    allActors: Actor[]
  ): { arrived: boolean; x: number; z: number; facing: number } => {
    const dx = tx - actor.x;
    const dz = tz - actor.z;
    const dist = Math.hypot(dx, dz);
    const facing = Math.abs(dx) > 0.02 ? (dx >= 0 ? 1 : -1) : actor.facing;
    if (dist <= radius) return { arrived: true, x: actor.x, z: actor.z, facing };

    let mult = 1.0;
    if ((game.divineFavorTicks ?? 0) > 0) mult *= numbers.SACRIFICE_SPEED_MULT;
    if (actor.hornBuffTicks > 0) mult *= 1.15;
    if ((actor.role === 'carrier' || actor.carrying) && isOnRoad(actor.x, actor.z)) {
      mult *= numbers.ROAD_SPEED_MULT * (hasAqueductPerk ? 1.15 : 1.0);
    }

    // Soft Boids Separation to prevent unit overlap / melee traffic jams (combat-and-counters Rule 4)
    let sepX = 0;
    let sepZ = 0;
    for (const other of allActors) {
      if (other.id === actor.id || other.hp <= 0) continue;
      const odx = actor.x - other.x;
      const odz = actor.z - other.z;
      const odist = Math.hypot(odx, odz);
      if (odist > 0.001 && odist < 0.72) {
        const push = ((0.72 - odist) / 0.72) * 0.07;
        sepX += (odx / odist) * push;
        sepZ += (odz / odist) * push;
      }
    }

    const step = Math.min(actor.speed * mult, dist);
    const nx = THREE.clamp(actor.x + (dx / dist) * step + sepX, -WORLD_DIMENSIONS.clampX, WORLD_DIMENSIONS.clampX);
    const nz = THREE.clamp(actor.z + (dz / dist) * step + sepZ, -WORLD_DIMENSIONS.clampZ, WORLD_DIMENSIONS.clampZ);
    return { arrived: false, x: nx, z: nz, facing };
  };

  let freeSpearmenToSpawn = 0;

  const actors = game.actors.map((raw, actorIdx) => {
    const a: Actor = {
      ...raw,
      attackCd: Math.max(0, raw.attackCd - 1),
      braceCd: Math.max(0, raw.braceCd - 1),
      hornBuffTicks: Math.max(0, raw.hornBuffTicks - 1),
    };
    if (a.hp <= 0) return a;

    // 1. Carrier returning goods to nearest Drop-Off building (carrier-logistics Rule 1 & 2)
    if (a.carrying) {
      const drop = findNearestDropOff(a.x, a.z);
      const m = stepTowards(a, drop.x, drop.z, 1.15, game.actors);
      if (!m.arrived) {
        return { ...a, x: m.x, z: m.z, facing: m.facing, activity: 'returning' as const, workProgress: 0 };
      }
      let yieldMult = hasAqueductPerk ? 1.35 : 1.0;
      if (supervisedBuildingId === drop.id) {
        yieldMult *= numbers.SARAI_SUPERVISE_YIELD_MULT;
      }
      const finalAmount = Math.ceil(a.carrying.amount * yieldMult);
      if (a.carrying.kind === 'food') food += finalAmount;
      else if (a.carrying.kind === 'water') water += finalAmount;
      else if (a.carrying.kind === 'wood') wood += finalAmount;
      else if (a.carrying.kind === 'stone') stone += finalAmount;

      friction = Math.min(100, friction + 1);
      notes.push(`${a.name} 向「${drop.nameZh}」交纳了 ${finalAmount} ${a.carrying.kind === 'water' ? '饮水' : a.carrying.kind === 'wood' ? '木料' : a.carrying.kind === 'stone' ? '石料' : '粮草'}。`);

      const src = resources.find(r => r.id === a.carrying?.sourceId);
      if (src && src.amount > 0 && a.queue.length === 0) {
        return {
          ...a,
          carrying: null,
          activity: 'moving' as const,
          workProgress: 0,
          workTicks: 0,
          queue: [order('gather', `采集${src.nameZh}`, src.x, src.z, src.id)],
        };
      }
      return { ...a, carrying: null, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
    }

    // 2. Idle auto-combat or supervision or healing sanctuary rest
    if (a.queue.length === 0) {
      if (a.supervisingBuildingId && supervisedBuildingId === a.supervisingBuildingId) {
        return { ...a, activity: 'supervising' as const, workProgress: 1 };
      }

      // Check nearby healing tent
      const nearHealingTent = buildings.some(
        b => b.kind === 'healingTent' && b.built && Math.hypot(a.x - b.x, a.z - b.z) <= (numbers.HEALING_TENT_AURA_RADIUS ?? 6.0)
      );
      if (nearHealingTent && a.hp < a.maxHp) {
        const healAmt = numbers.HEALING_TENT_HP_RATE ?? 1;
        const nextHp = Math.min(a.maxHp, a.hp + healAmt);
        if (game.tickCount % 6 === 0) {
          effects.push({
            id: `ht-heal-${a.id}-${game.tickCount}`,
            kind: 'heal',
            x: a.x,
            z: a.z,
            radius: 2.2,
            ttl: 20,
            maxTtl: 20,
          });
        }
        return { ...a, hp: nextHp, activity: 'rest' as const };
      }

      const inRangeEnemies = enemies.filter(
        e => e.hp > 0 && Math.hypot(e.x - a.x, e.z - a.z) <= a.attackRange + 2.8
      );
      if (inRangeEnemies.length && a.role !== 'carrier') {
        const nonDoomed = inRangeEnemies.filter(e => e.hp - e.pendingDamage > 0);
        const targetEnemy = (nonDoomed.length ? nonDoomed : inRangeEnemies)[0];
        const dist = Math.hypot(targetEnemy.x - a.x, targetEnemy.z - a.z);
        if (dist > a.attackRange) {
          // Boids arc surround slot around enemy
          const slotAngle = (actorIdx * 1.57) % (Math.PI * 2);
          const sx = targetEnemy.x + Math.cos(slotAngle) * (a.attackRange * 0.8);
          const sz = targetEnemy.z + Math.sin(slotAngle) * (a.attackRange * 0.8);
          const m = stepTowards(a, sx, sz, 0.35, game.actors);
          return { ...a, x: m.x, z: m.z, facing: m.facing, activity: 'fighting' as const };
        }
        if (a.attackCd === 0) {
          let dmg = computeCombatDamage(a, targetEnemy);
          // Spearman Brace anti-charge mechanic (combat-and-counters Rule 2)
          if (a.role === 'spearman' && a.braceCd === 0 && targetEnemy.tags.includes('beast')) {
            dmg *= 2;
            targetEnemy.stunTicks = hasSpearPerk ? 10 : numbers.BRACE_STUN_TICKS;
            a.braceCd = 45;
            effects.push({ id: `brace-${game.tickCount}-${a.id}`, kind: 'brace', x: targetEnemy.x, z: targetEnemy.z, radius: 1.2, ttl: 6, maxTtl: 6 });
            notes.push(`${a.name} 触发【架枪反冲锋】，重创并震晕${targetEnemy.nameZh}！`);
          }
          if (a.attackKind === 'ranged') {
            targetEnemy.pendingDamage += dmg;
            projectiles.push({
              id: `slg-${game.tickCount}-${a.id}`,
              fromX: a.x,
              fromZ: a.z,
              toX: targetEnemy.x,
              toZ: targetEnemy.z,
              targetEnemyId: targetEnemy.id,
              damage: dmg,
              progress: 0.15,
              color: '#e7e5e4',
            });
          } else {
            targetEnemy.hp = Math.max(0, targetEnemy.hp - dmg);
            effects.push({ id: `hit-${game.tickCount}-${a.id}`, kind: 'hit', x: targetEnemy.x, z: targetEnemy.z, radius: 0.7, ttl: 4, maxTtl: 4 });
            if (targetEnemy.hp === 0) notes.push(`${a.name} 击杀了${targetEnemy.nameZh}！`);
          }
          return { ...a, attackCd: 8, activity: 'fighting' as const, facing: targetEnemy.x >= a.x ? 1 : -1 };
        }
        return { ...a, activity: 'fighting' as const };
      }
      return { ...a, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
    }

    const [task, ...rest] = a.queue;

    // 3. Explicit attack / attackMove order
    if (task.kind === 'attack' || task.kind === 'attackMove') {
      const targetEnemy =
        (task.targetId ? enemies.find(e => e.id === task.targetId && e.hp > 0) : undefined) ??
        enemies.find(e => e.hp > 0 && Math.hypot(e.x - a.x, e.z - a.z) <= Math.max(5.5, a.attackRange + 1.5));

      if (targetEnemy) {
        const dist = Math.hypot(targetEnemy.x - a.x, targetEnemy.z - a.z);
        if (dist > a.attackRange) {
          const slotAngle = (actorIdx * 1.35) % (Math.PI * 2);
          const sx = targetEnemy.x + Math.cos(slotAngle) * Math.min(1.35, a.attackRange * 0.82);
          const sz = targetEnemy.z + Math.sin(slotAngle) * Math.min(1.35, a.attackRange * 0.82);
          const m = stepTowards(a, sx, sz, 0.35, game.actors);
          return { ...a, x: m.x, z: m.z, facing: m.facing, activity: 'fighting' as const };
        }
        if (a.attackCd === 0) {
          let dmg = computeCombatDamage(a, targetEnemy);
          if (a.role === 'spearman' && a.braceCd === 0 && targetEnemy.tags.includes('beast')) {
            dmg *= 2;
            targetEnemy.stunTicks = hasSpearPerk ? 10 : numbers.BRACE_STUN_TICKS;
            a.braceCd = 45;
            effects.push({ id: `brace-${game.tickCount}-${a.id}`, kind: 'brace', x: targetEnemy.x, z: targetEnemy.z, radius: 1.2, ttl: 6, maxTtl: 6 });
          }
          if (a.attackKind === 'ranged') {
            targetEnemy.pendingDamage += dmg;
            projectiles.push({
              id: `slg-${game.tickCount}-${a.id}`,
              fromX: a.x,
              fromZ: a.z,
              toX: targetEnemy.x,
              toZ: targetEnemy.z,
              targetEnemyId: targetEnemy.id,
              damage: dmg,
              progress: 0.15,
              color: '#e7e5e4',
            });
          } else {
            targetEnemy.hp = Math.max(0, targetEnemy.hp - dmg);
            effects.push({ id: `hit-${game.tickCount}-${a.id}`, kind: 'hit', x: targetEnemy.x, z: targetEnemy.z, radius: 0.7, ttl: 4, maxTtl: 4 });
            if (targetEnemy.hp === 0) {
              notes.push(`${a.name} 消灭了${targetEnemy.nameZh}！`);
              if (targetEnemy.id === 'alpha-1') {
                const den = landmarks.find(l => l.id === 'wolfDen');
                if (den && !den.completed) {
                  den.completed = true;
                  den.progress = 1;
                  stone += 50;
                  trust += 2;
                  pendingPerkChoices++;
                  notes.push('【支线完成：捣毁北岭狼穴】缴获 +50 石料、和睦 +2，并解锁 1 项圣约策令！');
                }
              }
            }
          }
          return { ...a, attackCd: 8, activity: 'fighting' as const, facing: targetEnemy.x >= a.x ? 1 : -1 };
        }
        return { ...a, activity: 'fighting' as const };
      }
      if (task.kind === 'attack') {
        return { ...a, queue: rest, activity: 'idle' as const };
      }
    }

    const arriveRadius = task.kind === 'build' ? 1.45 : 1.05;
    const moveRes = stepTowards(a, task.x, task.z, arriveRadius, game.actors);
    if (!moveRes.arrived) {
      return {
        ...a,
        x: moveRes.x,
        z: moveRes.z,
        facing: moveRes.facing,
        activity: 'moving' as const,
        workProgress: 0,
        workTicks: 0,
      };
    }

    if (task.kind === 'move' || task.kind === 'attackMove') {
      return { ...a, queue: rest, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
    }

    if (task.kind === 'supervise') {
      return { ...a, queue: rest, activity: 'supervising' as const, workProgress: 1 };
    }

    // 4. Gather resource node -> enter returning state with carried cargo
    if (task.kind === 'gather') {
      const node = resources.find(r => r.id === task.targetId);
      if (!node || node.amount <= 0) {
        return { ...a, queue: rest, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
      }
      const nextTicks = a.workTicks + 1;
      const total = numbers.GATHER_CHANNEL_TICKS;
      if (nextTicks < total) {
        return { ...a, activity: 'working' as const, workTicks: nextTicks, workProgress: nextTicks / total };
      }
      const take = Math.min(a.carryCapacity, node.amount);
      node.amount -= take;
      return {
        ...a,
        queue: rest,
        activity: 'returning' as const,
        workTicks: 0,
        workProgress: 0,
        carrying: { kind: node.kind, amount: take, sourceId: node.id },
      };
    }

    // 5. Engineer Boundary Post Expansion (territory-and-building Rule 1)
    if (task.kind === 'expand') {
      const post = boundaryPosts.find(p => p.id === task.targetId);
      if (!post || post.claimed) {
        return { ...a, queue: rest, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
      }
      const nextProg = Math.min(1, post.progress + 1 / numbers.ENGINEER_SURVEY_TICKS);
      post.progress = nextProg;
      if (nextProg < 1) {
        return { ...a, activity: 'working' as const, workProgress: nextProg, workTicks: a.workTicks + 1 };
      }
      post.claimed = true;
      territories.push({ id: `terr-${post.id}`, x: post.x, z: post.z, radius: post.radius });
      effects.push({ id: `claim-${game.tickCount}`, kind: 'claim', x: post.x, z: post.z, radius: post.radius, ttl: 14, maxTtl: 14 });
      notes.push(`${a.name} 敲立了「${post.nameZh}」，本方领土已扩张！`);
      return { ...a, queue: rest, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
    }

    // 6. Neutral Landmark / Side Objective interaction (bethel-campaign Rule 2)
    if (task.kind === 'repairLandmark') {
      const lm = landmarks.find(l => l.id === task.targetId);
      if (!lm || lm.completed) {
        return { ...a, queue: rest, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
      }
      if (lm.progress === 0 && (lm.costWood > 0 || lm.costStone > 0)) {
        if (wood < lm.costWood || stone < lm.costStone) {
          notes.push(`修复「${lm.nameZh}」需 ${lm.costWood} 木料、${lm.costStone} 石料。`);
          return { ...a, queue: rest, activity: 'idle' as const };
        }
        wood -= lm.costWood;
        stone -= lm.costStone;
      }
      const nextProg = Math.min(1, lm.progress + 1 / 14);
      lm.progress = nextProg;
      if (nextProg < 1) {
        return { ...a, activity: 'working' as const, workProgress: nextProg, workTicks: a.workTicks + 1 };
      }
      lm.completed = true;
      pendingPerkChoices++;
      if (lm.id === 'lostSheep') {
        food += numbers.SIDE_QUEST_SHEEP_REWARD;
        notes.push(`【支线完成：寻回迷途羔羊】获得 +${numbers.SIDE_QUEST_SHEEP_REWARD} 粮草与 1 项圣约策令！`);
      } else if (lm.id === 'ancientWell') {
        notes.push('【支线完成：修复迦南古井】活水涌流（持续自动产水），并获得 1 项圣约策令！');
      }
      return { ...a, queue: rest, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
    }

    // 7. Build structure (with Altar aura +20% & Sarai supervise +50%)
    if (task.kind === 'build') {
      const bIdx = buildings.findIndex(b => b.id === task.targetId);
      const b = buildings[bIdx];
      if (!b || b.built) {
        return { ...a, queue: rest, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
      }
      const bp = getBlueprint(b.kind);
      const altar = buildings.find(x => x.kind === 'altar');
      const nearAltar = altar && Math.hypot(b.x - altar.x, b.z - altar.z) <= numbers.ALTAR_AURA_RADIUS;
      const supervised = supervisedBuildingId === b.id;
      const rateMult = (nearAltar ? numbers.ALTAR_BUILD_MULT : 1.0) * (supervised ? numbers.SARAI_SUPERVISE_TRAIN_MULT : 1.0);
      const nextProg = Math.min(1, b.progress + rateMult / Math.max(1, bp.buildTicks));
      buildings[bIdx] = { ...b, progress: nextProg, built: nextProg >= 1 };

      if (nextProg >= 1) {
        trust++;
        notes.push(`${a.name} 建成了「${b.nameZh}」！`);
        if (bp.isAge2Landmark) {
          age = 2;
          pendingPerkChoices++;
          notes.unshift(`【时代晋升：进入伯特利立约期】地标「${b.nameZh}」落成，解锁 1 项圣约策令！`);
          if (b.kind === 'landmarkEncampment') {
            freeSpearmenToSpawn += 2;
          }
        }
        return { ...a, queue: rest, activity: 'idle' as const, workProgress: 0, workTicks: 0 };
      }
      return { ...a, activity: 'working' as const, workProgress: nextProg, workTicks: a.workTicks + 1 };
    }

    if (task.kind === 'mediate') {
      const nextTicks = a.workTicks + 1;
      if (nextTicks < 10) {
        return { ...a, activity: 'working' as const, workTicks: nextTicks, workProgress: nextTicks / 10 };
      }
      friction = Math.max(0, friction - 22);
      trust++;
      notes.push(`${a.name} 调解两家牧人，草场拥挤摩擦降至 ${friction}%。`);
      return { ...a, queue: rest, activity: 'idle' as const, workTicks: 0, workProgress: 0 };
    }

    if (task.kind === 'talk') {
      const livingEnemies = enemies.filter(e => e.hp > 0).length;
      if (livingEnemies > 0 && friction < numbers.FRICTION_THRESHOLD_ACT4) {
        notes.push(`北岭尚有 ${livingEnemies} 处威胁（或待草场摩擦积聚），请先肃清北岭再与罗得商议分地。`);
        return { ...a, queue: rest, activity: 'idle' as const };
      }
      phase = 'act4_parting';
      notes.push('亚伯兰走向罗得提出「你我不可相争」之礼让分地（创 13:8–18）。');
      return { ...a, queue: rest, activity: 'idle' as const };
    }

    if (task.kind === 'rest') {
      const nextHp = Math.min(a.maxHp, a.hp + numbers.REST_HEAL_RATE);
      if (a.workTicks % 6 === 0) {
        effects.push({
          id: `rest-heal-${a.id}-${game.tickCount}`,
          kind: 'heal',
          x: a.x,
          z: a.z,
          radius: 2.2,
          ttl: 18,
          maxTtl: 18,
        });
      }
      if (nextHp >= a.maxHp) {
        notes.push(`${a.name} 完全康复，重返待命状态！`);
        return { ...a, hp: a.maxHp, queue: rest, activity: 'idle' as const, workTicks: 0, workProgress: 0 };
      }
      return { ...a, hp: nextHp, activity: 'rest' as const, workTicks: a.workTicks + 1, workProgress: nextHp / a.maxHp };
    }

    if (task.kind === 'sacrifice') {
      const altar = buildings.find(b => b.kind === 'altar' && b.built);
      if (!altar) {
        notes.push('未找到十二石祭坛。');
        return { ...a, queue: rest, activity: 'idle' as const };
      }
      const dist = Math.hypot(a.x - altar.x, a.z - altar.z);
      if (dist > 2.5) {
        const m = stepTowards(a, altar.x, altar.z, 2.2, game.actors);
        return { ...a, x: m.x, z: m.z, facing: m.facing, activity: 'moving' as const };
      }
      const foodCost = numbers.SACRIFICE_COST_FOOD;
      const woodCost = numbers.SACRIFICE_COST_WOOD;
      if (food >= foodCost && wood >= woodCost) {
        food = food - foodCost + numbers.SACRIFICE_BLESSING_FOOD;
        wood -= woodCost;
        friction = Math.max(0, friction - numbers.SACRIFICE_FRICTION_REDUCTION);
        trust += 2;
        divineFavorTicks = numbers.SACRIFICE_FAVOR_TICKS;
        sacrificesPerformed++;
        effects.push({
          id: `sac-${game.tickCount}-${a.id}`,
          kind: 'heal',
          x: altar.x,
          z: altar.z,
          radius: 4.5,
          ttl: 60,
          maxTtl: 60,
        });
        notes.unshift(`【创世记 13:4 筑坛求告】亚伯兰在伯特利原石坛前献祭求告主名，全军获神圣恩眷（移速+15%，护甲+${numbers.SACRIFICE_ARMOR_BONUS}）！`);
      } else {
        notes.push(`祭物不足（需粮草 ${foodCost}、木料 ${woodCost}）。`);
      }
      return { ...a, queue: rest, activity: 'idle' as const, workTicks: 0, workProgress: 0 };
    }

    return a;
  });

  // Spawn free Spearmen if Military Landmark just finished
  const finalActors = [...actors];
  if (freeSpearmenToSpawn > 0) {
    const tmpl = LEVEL1_CONFIG.unitTemplates.spearman;
    const main = buildings[0];
    for (let i = 0; i < freeSpearmenToSpawn; i++) {
      finalActors.push({
        id: `spearman-free-${game.tickCount}-${i}`,
        name: `家丁矛兵#${finalActors.filter(x => x.role === 'spearman').length + 1}`,
        role: 'spearman',
        tags: ['infantry', 'melee'],
        attackKind: 'melee',
        color: '#1d4ed8',
        x: main.x + 1.5 + i * 0.9,
        z: main.z - 1.0,
        hp: tmpl.maxHp,
        maxHp: tmpl.maxHp,
        energy: 100,
        maxEnergy: 100,
        attack: tmpl.attack + (hasSpearPerk ? 4 : 0),
        bonusVsBeast: tmpl.bonusVsBeast,
        bonusVsInfantry: 0,
        meleeArmor: tmpl.meleeArmor,
        rangedArmor: tmpl.rangedArmor,
        attackRange: tmpl.attackRange,
        speed: tmpl.speed,
        visionRadius: tmpl.visionRadius,
        carryCapacity: tmpl.carryCapacity,
        attackCd: 0,
        braceCd: 0,
        hornBuffTicks: 0,
        activity: 'idle',
        workProgress: 0,
        workTicks: 0,
        carrying: null,
        facing: 1,
        queue: [],
      });
    }
  }

  // Update enemies (respect stunTicks from Spearman Brace)
  for (const e of enemies) {
    if (e.hp <= 0 || e.stunTicks > 0) continue;
    const nearest = finalActors
      .filter(a => a.hp > 0)
      .sort((u, v) => Math.hypot(u.x - e.x, u.z - e.z) - Math.hypot(v.x - e.x, v.z - e.z))[0];

    if (nearest && Math.hypot(nearest.x - e.x, nearest.z - e.z) <= e.aggroRange) {
      const dist = Math.hypot(nearest.x - e.x, nearest.z - e.z);
      if (dist > e.attackRange) {
        const dx = nearest.x - e.x;
        const dz = nearest.z - e.z;
        const step = Math.min(e.speed, dist);
        e.x += (dx / dist) * step;
        e.z += (dz / dist) * step;
        e.facing = dx >= 0 ? 1 : -1;
      } else if (e.attackCd === 0) {
        e.attackCd = 11;
        const divineArmorBonus = divineFavorTicks > 0 ? numbers.SACRIFICE_ARMOR_BONUS : 0;
        const targetArmor = {
          tags: nearest.tags,
          meleeArmor: nearest.meleeArmor + (nearest.hornBuffTicks > 0 ? 2 : 0) + divineArmorBonus,
          rangedArmor: nearest.rangedArmor + (nearest.hornBuffTicks > 0 ? 2 : 0) + divineArmorBonus,
          x: nearest.x,
          z: nearest.z,
        };
        const dmg = computeCombatDamage(
          { attack: e.attack, attackKind: e.attackKind, bonusVsBeast: 0, bonusVsInfantry: 0, x: e.x, z: e.z },
          targetArmor
        );
        nearest.hp = Math.max(20, nearest.hp - dmg);
      }
    }
  }

  // Living Flocks Simulation (Grazing, Breeding, Pasture Overlap Friction)
  const flocks: FlockState[] = (game.flocks ?? []).map(f => {
    let nx = f.x;
    let nz = f.z;
    let tx = f.targetX;
    let tz = f.targetZ;
    if (tx !== undefined && tz !== undefined) {
      const dx = tx - f.x;
      const dz = tz - f.z;
      const d = Math.hypot(dx, dz);
      if (d <= 0.35) {
        tx = undefined;
        tz = undefined;
      } else {
        const step = Math.min(0.14, d);
        nx += (dx / d) * step;
        nz += (dz / d) * step;
      }
    }
    let nextSheep = f.sheepCount;
    if (
      game.tickCount > 0 &&
      game.tickCount % numbers.FLOCK_BREED_INTERVAL_TICKS === 0 &&
      nextSheep < numbers.FLOCK_MAX_SHEEP &&
      water >= numbers.FLOCK_WATER_COST_PER_BREED
    ) {
      water -= numbers.FLOCK_WATER_COST_PER_BREED;
      nextSheep += 1;
      if (f.owner === 'abram') {
        notes.push(`【牧群繁盛】${f.nameZh}添了新羔羊（现 ${nextSheep} 只），产粮提升但也更易与罗得牧人争草场！`);
      }
    }
    return { ...f, x: nx, z: nz, targetX: tx, targetZ: tz, sheepCount: nextSheep };
  });

  if (game.tickCount > 0 && game.tickCount % numbers.FLOCK_GRAZE_INTERVAL_TICKS === 0) {
    const abramFlock = flocks.find(f => f.owner === 'abram');
    const lotFlock = flocks.find(f => f.owner === 'lot');
    if (abramFlock) {
      food += Math.max(1, Math.round(abramFlock.sheepCount * numbers.FLOCK_FOOD_PER_SHEEP));
    }
    if (abramFlock && lotFlock) {
      const flockDist = Math.hypot(abramFlock.x - lotFlock.x, abramFlock.z - lotFlock.z);
      if (flockDist <= numbers.FLOCK_OVERLAP_DIST) {
        friction = Math.min(100, friction + numbers.FLOCK_OVERLAP_FRICTION);
        if (game.tickCount % (numbers.FLOCK_GRAZE_INTERVAL_TICKS * 5) === 0) {
          notes.push('【创 13:7 牧人相争】两家羊群草场重叠，争抢水草导致摩擦升高！请将羊群驱往远处空草场。');
        }
      }
    }
  }

  // Campaign Act Transitions (bethel-campaign Rule 1)
  const hasDepotOrHouse = buildings.some(b => (b.kind === 'depot' || b.kind === 'house') && b.built);
  const livingEnemies = enemies.filter(e => e.hp > 0).length;
  if (phase === 'act1_camp' && hasDepotOrHouse) {
    phase = 'act2_expand';
    notes.unshift('【进入第二幕：界石与地标】后勤初立！派乌珥敲击界石扩地，或建造二选一时代Ⅱ地标晋升「伯特利立约期」。');
  } else if (phase === 'act2_expand' && (age === 2 || livingEnemies < LEVEL1_CONFIG.enemies.length)) {
    phase = 'act3_defense';
    notes.unshift('【进入第三幕：北岭护群会战】招募家丁矛兵与投石手，配合高地瞭望箭塔肃清北岭敌群！');
  } else if ((phase === 'act2_expand' || phase === 'act3_defense') && livingEnemies === 0) {
    notes.unshift('【北岭威胁已全部肃清】现在可派亚伯兰前往东南牧场点击「与罗得议事」，完成创世记 13 章礼让分地！');
  }

  const fog = computeFog(game.fog, finalActors, buildings, landmarks, game.perks);

  return {
    ...game,
    tickCount: game.tickCount + 1,
    age,
    actors: finalActors,
    buildings,
    territories,
    boundaryPosts,
    landmarks,
    resources,
    flocks,
    enemies,
    projectiles,
    effects,
    fog,
    food,
    water,
    wood,
    stone,
    popCap: computePopCap(buildings),
    trust,
    friction,
    hornCooldown: Math.max(0, game.hornCooldown - 1),
    divineFavorTicks,
    sacrificesPerformed,
    pendingPerkChoices,
    phase,
    paused: phase === 'act4_parting' ? true : game.paused,
    log: [...notes.reverse(), ...game.log].slice(0, 9),
  };
}

// Minimal Math helper inside pure game module
const THREE = {
  clamp: (v: number, min: number, max: number) => Math.max(min, Math.min(max, v)),
};
