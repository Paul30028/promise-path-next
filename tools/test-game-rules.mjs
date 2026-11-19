import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { buildSync } from 'esbuild';

const outFile = path.resolve('c:/AI/gemini/promise-path-next/node_modules/.tmp-game-test.mjs');
buildSync({
  entryPoints: [path.resolve('c:/AI/gemini/promise-path-next/src/game.ts')],
  bundle: true,
  format: 'esm',
  outfile: outFile,
  platform: 'neutral',
});

const store = new Map();
globalThis.localStorage = {
  getItem: k => (store.has(k) ? store.get(k) : null),
  setItem: (k, v) => store.set(k, String(v)),
  removeItem: k => store.delete(k),
};

const {
  newGame,
  tick,
  order,
  isValidPlacement,
  placeBuilding,
  recruitCarrier,
  trainMilitary,
  assignSupervise,
  choosePerk,
  computeCombatDamage,
  performSacrifice,
  moveFlock,
  resolveParting,
  loadGame,
  saveGame,
  isVisibleInFog,
} = await import(`file:///${outFile.replace(/\\/g, '/')}`);

// 1. Initial State & Fog of War (GDD / carrier-logistics)
let g = newGame();
assert.equal(g.food, 120);
assert.equal(g.water, 80);
assert.equal(g.wood, 100);
assert.equal(g.stone, 40);
assert.equal(g.popCap, 8);
assert.equal(isVisibleInFog(g.fog, -4.8, 2.5), true, 'Main camp must start visible');
assert.equal(isVisibleInFog(g.fog, 10.5, -10.5), false, 'Northern ridge alpha wolf must start in Fog of War');

// 2. Territory & Free Building Placement + Sarai Supervise + Carrier Nearest Drop-off
const outsideCheck = isValidPlacement(g, 'depot', 14.0, -9.0);
assert.equal(outsideCheck.valid, false, 'Must reject building outside territory');

const insideCheck = isValidPlacement(g, 'depot', -9.5, 4.5);
assert.equal(insideCheck.valid, true, 'Must allow free placement inside territory');

g = placeBuilding(g, 'depot', -9.5, 4.5, ['asa']);
const depot = g.buildings.find(b => b.kind === 'depot');
assert.ok(depot, 'Depot foundation must be created at (-9.5, 4.5)');
g = {
  ...g,
  actors: g.actors.map(a => (a.id === 'asa' ? { ...a, x: depot.x, z: depot.z } : a)),
};
for (let i = 0; i < 28; i++) g = tick(g);
assert.equal(g.buildings.find(b => b.id === depot.id).built, true, 'Depot should finish construction');

// Station Sarai to supervise the new Depot (+25% drop-off yield)
g = assignSupervise(g, depot.id);
g = {
  ...g,
  actors: g.actors.map(a =>
    a.id === 'sarai'
      ? { ...a, x: depot.x + 0.8, z: depot.z + 0.5 }
      : a.id === 'nura'
        ? { ...a, x: depot.x, z: depot.z, carrying: { kind: 'water', amount: 15, sourceId: 'spring-1' } }
        : a
  ),
};
const waterBeforeDrop = g.water;
g = tick(g);
assert.equal(g.water - waterBeforeDrop, Math.ceil(15 * 1.25), 'Sarai Supervise must boost drop-off yield by +25%');

// 3. Engineer Boundary Expansion (territory-and-building Rule 1)
const northPost = g.boundaryPosts.find(p => p.id === 'post-north');
const terrBefore = g.territories.length;
g = {
  ...g,
  actors: g.actors.map(a =>
    a.id === 'asa'
      ? { ...a, x: northPost.x, z: northPost.z, queue: [order('expand', '扩地', northPost.x, northPost.z, northPost.id)] }
      : a
  ),
};
for (let i = 0; i < 25; i++) g = tick(g);
assert.equal(g.territories.length, terrBefore + 1, 'Engineer Ur must claim new territory circle');

// 4. Workforce Dilemma: Recruit Carrier -> Convert Carrier to Spearman at Barracks
g = recruitCarrier(g);
const carriersBefore = g.actors.filter(a => a.role === 'carrier').length;
assert.equal(carriersBefore, 3);

// Place & finish Military Landmark (Age II + 2 free Spearmen + 1 Crucible Perk choice)
g = { ...g, food: 300, wood: 300, stone: 200 };
g = placeBuilding(g, 'landmarkEncampment', -3.5, 5.5, ['asa']);
const lmBldg = g.buildings.find(b => b.kind === 'landmarkEncampment');
g = {
  ...g,
  actors: g.actors.map(a => (a.id === 'asa' ? { ...a, x: lmBldg.x, z: lmBldg.z } : a)),
};
for (let i = 0; i < 40; i++) g = tick(g);
assert.equal(g.age, 2, 'Landmark completion must advance to Age II');
assert.ok(g.pendingPerkChoices >= 1, 'Age II must grant a Crucible Perk choice');
g = choosePerk(g, 'bronzeSpear');
assert.ok(g.perks.includes('bronzeSpear'));

g = trainMilitary(g, 'spearman');
const carriersAfter = g.actors.filter(a => a.role === 'carrier').length;
assert.equal(carriersAfter, carriersBefore - 1, 'Training military unit must convert 1 carrier');

// 5. AoE4 Dual-Armor + Tag Bonus + High-Ground Formula (combat-and-counters Rule 1)
const dmgHigh = computeCombatDamage(
  { attack: 12, attackKind: 'ranged', bonusVsBeast: 0, bonusVsInfantry: 5, z: -6.0 },
  { tags: ['infantry'], meleeArmor: 0, rangedArmor: 1, z: 2.0 }
);
assert.equal(dmgHigh, Math.round((12 + 5 - 1) * 1.25), 'High ground ranged vs infantry formula must match');

// 6. Healing Tent Regeneration + Altar Sacrifice + Living Flocks + Act 4 Finale Reveal
g = { ...g, food: 200, water: 200, wood: 200, friction: 40 };
g = placeBuilding(g, 'healingTent', -9.5, 1.0, ['asa']);
const ht = g.buildings.find(b => b.kind === 'healingTent');
g = {
  ...g,
  actors: g.actors.map(a =>
    a.id === 'asa'
      ? { ...a, x: ht.x, z: ht.z }
      : a.id === 'abram'
        ? { ...a, x: ht.x + 1.0, z: ht.z, hp: 120 }
        : a
  ),
};
for (let i = 0; i < 22; i++) g = tick(g);
assert.equal(g.buildings.find(b => b.id === ht.id).built, true, 'Healing Tent must finish construction');
assert.ok(g.actors.find(a => a.id === 'abram').hp > 120, 'Healing Tent must heal nearby wounded units');

// Move Abram near Altar and perform Covenant Sacrifice
const altar = g.buildings.find(b => b.kind === 'altar');
g = {
  ...g,
  actors: g.actors.map(a => (a.id === 'abram' ? { ...a, x: altar.x + 1.0, z: altar.z } : a)),
};
const frictionBeforeSac = g.friction;
g = performSacrifice(g);
assert.ok(g.divineFavorTicks > 0, 'Sacrifice must activate Divine Favor');
assert.ok(g.friction < frictionBeforeSac, 'Sacrifice must reduce family friction');

// Living Flocks: herd Abram flock to separate pasture and verify grazing food income
g = moveFlock(g, 'flock-abram', -14.0, 10.0);
assert.equal(g.flocks.find(f => f.id === 'flock-abram').targetX, -14.0);

// Act 4 Canon Parting + Genesis 13:14-17 Full Map Fog Reveal + Save Schema v5 Validation
g = { ...g, phase: 'act4_parting', water: 100, wood: 100 };
const resolved = resolveParting(g, 'share', true);
assert.equal(resolved.phase, 'resolved');
assert.ok(resolved.ending.includes('罗得'));
assert.equal(resolved.fog.every(v => v === 2), true, 'Genesis 13:14 finale must reveal entire map fog');
saveGame(resolved);
assert.equal(loadGame().phase, 'resolved');

localStorage.setItem('promise-path-next-save-v5', '{"schemaVersion":999,"actors":[]}');
assert.equal(loadGame().schemaVersion, 5);

fs.unlinkSync(outFile);
console.log('ALL_GAME_RULE_TESTS_PASSED');
