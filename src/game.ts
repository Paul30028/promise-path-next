export type Role = 'leader' | 'organizer' | 'herdsman' | 'scout' | 'carrier' | 'builder' | 'elder';
export type Actor = { id: string; name: string; role: Role; color: string; x: number; z: number; energy: number; load: number; queue: Order[] };
export type Order = { kind: 'move' | 'water' | 'timber' | 'build' | 'talk' | 'scout' | 'defend' | 'torch' | 'retreat'; x: number; z: number; label: string };
export type Game = { version: 1; actors: Actor[]; water: number; timber: number; tents: number; trust: number; herd: number; day: number; paused: boolean; story: 'arrival' | 'dispute' | 'resolved'; encounter: 'hidden' | 'active' | 'ended'; ending?: string; log: string[] };
export const targets = { spring: { x: -5, z: 2 }, wood: { x: 5, z: -3 }, tent: { x: 1, z: 2 }, tentWork: { x: 2.15, z: 2.75 }, ridge: { x: 6, z: 4 }, lot: { x: -1.5, z: -1 }, threat: { x: 6.5, z: 2.2 } };
const actor = (id: string, name: string, role: Role, color: string, x: number, z: number): Actor => ({ id, name, role, color, x, z, energy: 100, load: 0, queue: [] });
export function newGame(): Game { return { version: 1, actors: [actor('abram','亚伯兰','leader','#304d70',-2,1),actor('sarai','撒莱','organizer','#b76962',-3,0),actor('lot','罗得','herdsman','#856340',-1.5,-1),actor('eli','以利','scout','#7b8b5c',0,0),actor('nura','努拉','carrier','#568484',-3,2),actor('asa','亚撒','builder','#a66b42',1,1),actor('mara','玛拉','elder','#775f86',-2,-2)], water: 4, timber: 1, tents: 0, trust: 2, herd: 6, day: 1, paused: true, story: 'arrival', encounter: 'hidden', log: ['营地抵达丘陵边。先查看水源、木料与牧道，再安排劳作。'] }; }
const SAVE = 'promise-path-next-save-v1';
export function hasSavedGame(): boolean { try { return localStorage.getItem(SAVE)!==null; } catch { return false; } }
export function loadGame(): Game { try { const raw = localStorage.getItem(SAVE); if (!raw) return newGame(); const data = JSON.parse(raw) as Game; if (data.version !== 1 || !Array.isArray(data.actors) || data.actors.length !== 7 || !Number.isFinite(data.water) || !Number.isFinite(data.timber)) return newGame(); return data; } catch { return newGame(); } }
export function saveGame(game: Game): boolean { try { localStorage.setItem(SAVE, JSON.stringify(game)); return true; } catch { return false; } }
export function order(kind: Order['kind'], label: string, x: number, z: number): Order { return { kind, label, x, z }; }
export function pushLog(game: Game, line: string): Game { return { ...game, log: [line, ...game.log].slice(0, 9) }; }
export function tick(game: Game): Game {
  if (game.paused || game.ending) return game;
  if (game.actors.every(a => a.queue.length === 0 || a.energy <= 0)) return game;
  let water = game.water, timber = game.timber, tents = game.tents, trust = game.trust, herd = game.herd, story = game.story, encounter = game.encounter;
  let discovered = false;
  const notes: string[] = [];
  const actors = game.actors.map(a => {
    if (!a.queue.length || a.energy <= 0) return a;
    const [task, ...rest] = a.queue;
    const dx = task.x - a.x, dz = task.z - a.z, distance = Math.hypot(dx,dz);
    if (distance > .25) { const step = Math.min(.16,distance); return { ...a, x: a.x + dx / distance * step, z: a.z + dz / distance * step, energy: Math.max(0,a.energy - .11) }; }
    let next = { ...a, queue: rest, energy: Math.max(0,a.energy - 2) };
    if (task.kind === 'water') { const gained = a.role === 'carrier' ? 3 : 2; water += gained; notes.push(`${a.name} 从泉边带回 ${gained} 份水。`); }
    if (task.kind === 'timber') { timber += 2; notes.push(`${a.name} 收集了 2 捆可用木料。`); }
    if (task.kind === 'build') { if (timber >= 2 && water >= 1) { timber -= 2; water -= 1; tents++; notes.push(`${a.name} 搭起一座帐棚，耗费 2 木料、1 水。`); } else notes.push('材料不足，施工未完成。'); }
    if (task.kind === 'talk') { if (tents < 1 || encounter !== 'ended') notes.push('先搭起帐棚并处理羊群危险，再与罗得商谈。'); else if (story === 'arrival') { story = 'dispute'; notes.push('罗得的牧人与营地牧人争执。请决定怎样准备分开牧放。'); } else notes.push('罗得望向两条不同的路，等待你的决定。'); }
    if (task.kind === 'scout') { if (encounter === 'hidden') { encounter = 'active'; discovered = true; notes.push('侦察者发现野兽接近羊群。行动暂停，请选一张情境战术卡。'); } else notes.push('山脊可看见泉水与较安全的高地。'); }
    if (task.kind === 'defend') { if (encounter === 'active') { encounter = 'ended'; if (a.role === 'scout' || a.role === 'leader') { notes.push(`${a.name} 利用地形和警戒队形驱离野兽，羊群保住了。`); trust++; } else { herd = Math.max(0,herd-1); notes.push(`${a.name} 勉强赶走野兽，一只羊走失。`); } } }
    if (task.kind === 'torch' && encounter === 'active') { if (timber >= 1) { timber--; encounter = 'ended'; trust++; notes.push(`${a.name} 点燃备用木料，借火光安全驱离野兽。木料 −1，信任 +1。`); } else notes.push('没有可用木料，火把行动失败。'); }
    if (task.kind === 'retreat' && encounter === 'active') { if (water >= 1) { encounter = 'ended'; water--; notes.push(`${a.name} 带羊群绕到高地。羊群无损，额外消耗 1 份水。`); } else notes.push('缺少饮水，无法转移羊群。'); }
    return next;
  });
  return { ...game, actors, water, timber, tents, trust, herd, story, encounter, paused: discovered ? true : game.paused, log: [...notes.reverse(), ...game.log].slice(0,9) };
}
