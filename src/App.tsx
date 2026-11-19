import { useCallback, useEffect, useState } from 'react';
import Minimap from './Minimap';
import World from './World';
import type { CameraFocusRequest } from './World';
import { CAMPAIGN_STONES, LEVEL1_CONFIG, PERKS } from './config';
import {
  assignSupervise,
  blowHorn,
  choosePerk,
  getBlueprint,
  hasSavedGame,
  loadGame,
  moveFlock,
  newGame,
  order,
  placeBuilding,
  performSacrifice,
  pushLog,
  recruitCarrier,
  resolveParting,
  saveGame,
  targets,
  tick,
  trainMilitary,
} from './game';
import type {
  BoundaryPostState,
  BuildingKind,
  BuildingState,
  Enemy,
  Game,
  NeutralLandmarkState,
  Order,
  ResourceNode,
  Role,
} from './game';
import { actorNames, copy, loadLanguage, localizeLog, saveLanguage } from './i18n';
import type { CopyKey, Language } from './i18n';

const ROLE_LABELS_ZH: Record<Role, string> = {
  leader: '族长英雄',
  organizer: '主母督工',
  herdsman: '东营牧长',
  scout: '大马色斥候',
  engineer: '工程先驱',
  carrier: '营地搬运工',
  spearman: '家丁矛兵',
  slinger: '家丁投石手',
};

const ROLE_LABELS_EN: Record<Role, string> = {
  leader: 'Patriarch',
  organizer: 'Matriarch',
  herdsman: 'Herdsman',
  scout: 'Scout',
  engineer: 'Engineer',
  carrier: 'Carrier',
  spearman: 'Spearman',
  slinger: 'Slinger',
};

/**
 * Pure Code-Native AoE Heraldic SVG Emblem (Zero Sliced PNGs!)
 */
function AoEEmblem({ kind }: { kind: Role | BuildingKind | 'horn' | 'expand' | 'supervise' | 'talk' }) {
  return (
    <svg viewBox="0 0 36 36" className="aoe-svg-icon" aria-hidden="true">
      <rect x="2" y="2" width="32" height="32" rx="6" fill="#3a2918" stroke="#c59f59" strokeWidth="1.8" />
      {(kind === 'house' || kind === 'mainTent') && (
        <path d="M7 26 L18 10 L29 26 Z M14 26 L18 19 L22 26 Z" fill="#d97706" stroke="#fde68a" strokeWidth="1.2" />
      )}
      {kind === 'depot' && (
        <g fill="#b45309" stroke="#fde68a" strokeWidth="1.2">
          <rect x="8" y="12" width="20" height="4" />
          <rect x="10" y="18" width="6" height="9" rx="2" />
          <rect x="20" y="18" width="6" height="9" rx="2" />
        </g>
      )}
      {kind === 'watchtower' && (
        <path d="M12 28 L14 13 L22 13 L24 28 Z M11 10 L25 10 L25 13 L11 13 Z" fill="#a8a29e" stroke="#fbbf24" strokeWidth="1.2" />
      )}
      {(kind === 'barracks' || kind === 'landmarkEncampment') && (
        <g stroke="#fde68a" strokeWidth="1.8" fill="none">
          <path d="M10 26 L26 10 M26 26 L10 10" />
          <circle cx="18" cy="18" r="6" fill="#92400e" />
        </g>
      )}
      {kind === 'healingTent' && (
        <g stroke="#86efac" strokeWidth="1.6" fill="none">
          <path d="M8 26 L18 10 L28 26 Z" fill="#14532d" />
          <path d="M18 16 V24 M14 20 H22" stroke="#22c55e" strokeWidth="2.2" />
        </g>
      )}
      {kind === 'altar' && (
        <g fill="#f59e0b" stroke="#fde68a" strokeWidth="1.2">
          <rect x="9" y="21" width="18" height="6" rx="1.5" />
          <path d="M14 21 Q18 11 22 21 Z" fill="#ef4444" />
        </g>
      )}
      {kind === 'landmarkOlive' && (
        <g fill="#65a30d" stroke="#fde68a" strokeWidth="1.2">
          <circle cx="18" cy="14" r="6" />
          <rect x="16" y="20" width="4" height="8" fill="#78350f" />
        </g>
      )}
      {kind === 'carrier' && (
        <path d="M14 11 H22 L24 19 C24 24 21 27 18 27 C15 27 12 24 12 19 Z" fill="#0284c7" stroke="#bae6fd" strokeWidth="1.3" />
      )}
      {kind === 'spearman' && (
        <g stroke="#fde047" strokeWidth="2">
          <line x1="10" y1="27" x2="25" y2="10" />
          <polygon points="26,8 21,11 24,14" fill="#fde047" />
        </g>
      )}
      {kind === 'slinger' && (
        <g stroke="#e7e5e4" strokeWidth="1.8" fill="none">
          <path d="M10 25 Q18 8 26 16" />
          <circle cx="25" cy="16" r="3.5" fill="#d6d3d1" />
        </g>
      )}
      {(kind === 'engineer' || kind === 'expand') && (
        <g fill="#d97706" stroke="#fde68a" strokeWidth="1.2">
          <rect x="11" y="10" width="14" height="7" rx="1.5" />
          <rect x="16" y="17" width="4" height="11" />
        </g>
      )}
      {(kind === 'organizer' || kind === 'supervise') && (
        <g fill="#db2777" stroke="#fbcfe8" strokeWidth="1.3">
          <rect x="11" y="10" width="14" height="16" rx="2" />
          <line x1="14" y1="15" x2="22" y2="15" />
          <line x1="14" y1="20" x2="22" y2="20" />
        </g>
      )}
      {(kind === 'leader' || kind === 'horn') && (
        <path d="M12 27 V14 C12 10 18 10 18 14 M15 21 H25 L28 17 V25 L25 21" fill="none" stroke="#fde047" strokeWidth="2" />
      )}
      {kind === 'scout' && (
        <circle cx="18" cy="18" r="8" fill="#059669" stroke="#fde68a" strokeWidth="2" />
      )}
      {(kind === 'herdsman' || kind === 'talk') && (
        <path d="M15 27 V13 C15 9 22 9 22 13 C22 16 18 16 18 16" fill="none" stroke="#f59e0b" strokeWidth="2.2" />
      )}
    </svg>
  );
}

export default function App() {
  const [game, setGame] = useState<Game>(loadGame);
  const [selected, setSelected] = useState<string[]>(['abram']);
  const [selectedFlockId, setSelectedFlockId] = useState<string | null>(null);
  const [commandTab, setCommandTab] = useState<'build' | 'orders'>('build');
  const [placementKind, setPlacementKind] = useState<BuildingKind | null>(null);
  const [panel, setPanel] = useState<'story' | 'help' | 'map' | null>(() => (hasSavedGame() ? null : 'story'));
  const [escortOption, setEscortOption] = useState<boolean>(true);
  const [language, setLanguage] = useState<Language>(loadLanguage);
  const [focusRequest, setFocusRequest] = useState<CameraFocusRequest>({ x: -4.5, z: 2.0, seq: 0 });
  const [zoom, setZoom] = useState<number>(1);
  const [cameraPos, setCameraPos] = useState<{ x: number; z: number }>({ x: -4.5, z: 2.0 });
  const [mobileDrawer, setMobileDrawer] = useState<'build' | 'squad'>('build');

  const t = (key: CopyKey) => copy[language][key];

  useEffect(() => {
    saveLanguage(language);
    document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
    document.title = `${copy[language].title} · Age of Empires × The Settlers 3D`;
  }, [language]);

  useEffect(() => {
    const id = window.setInterval(() => {
      if (document.hidden) return;
      setGame(g => tick(g));
    }, LEVEL1_CONFIG.tickMs);
    return () => window.clearInterval(id);
  }, []);

  useEffect(() => {
    const id = window.setTimeout(() => {
      saveGame(game);
    }, 600);
    return () => window.clearTimeout(id);
  }, [game]);

  const handleZoomChange = useCallback((delta: number) => {
    setZoom(z => Math.max(0.55, Math.min(1.65, Number((z + delta).toFixed(2)))));
  }, []);

  const handleCameraMove = useCallback((x: number, z: number) => {
    setCameraPos({ x, z });
  }, []);

  const flyTo = useCallback((x: number, z: number) => {
    setFocusRequest(prev => ({ x, z, seq: prev.seq + 1 }));
  }, []);

  const handleSelectUnit = useCallback((id: string, additive: boolean) => {
    setPlacementKind(null);
    setSelectedFlockId(null);
    setSelected(prev => {
      if (!additive) return [id];
      return prev.includes(id) ? (prev.length > 1 ? prev.filter(x => x !== id) : prev) : [...prev, id];
    });
  }, []);

  const handleSelectFlock = useCallback((flockId: string) => {
    setPlacementKind(null);
    setSelectedFlockId(flockId);
  }, []);

  const handleMoveOrder = useCallback(
    (x: number, z: number) => {
      if (selectedFlockId) {
        setGame(g => moveFlock(g, selectedFlockId, x, z));
        return;
      }
      const spacing = LEVEL1_CONFIG.numbers.FORMATION_SPACING ?? 1.15;
      setGame(g => {
        if (!selected.length) return pushLog(g, copy[language].noActor);
        const cols = Math.ceil(Math.sqrt(selected.length));
        return {
          ...g,
          paused: false,
          actors: g.actors.map(a => {
            const idx = selected.indexOf(a.id);
            if (idx === -1) return a;
            const col = idx % cols;
            const row = Math.floor(idx / cols);
            const ox = (col - (cols - 1) / 2) * spacing;
            const oz = row * spacing;
            return {
              ...a,
              carrying: null,
              supervisingBuildingId: undefined,
              activity: 'moving',
              workTicks: 0,
              workProgress: 0,
              queue: [order('move', '列阵行军', x + ox, z + oz)],
            };
          }),
        };
      });
    },
    [selected, selectedFlockId, language]
  );

  const assignOrder = useCallback(
    (item: Order, targetActorIds?: string[]) => {
      setPlacementKind(null);
      const ids = targetActorIds && targetActorIds.length ? targetActorIds : selected;
      setGame(g => {
        if (!ids.length) return pushLog(g, copy[language].noActor);
        return {
          ...g,
          paused: false,
          actors: g.actors.map(a =>
            ids.includes(a.id)
              ? {
                  ...a,
                  carrying: null,
                  supervisingBuildingId: item.kind === 'supervise' ? item.targetId : undefined,
                  activity: 'moving',
                  workTicks: 0,
                  workProgress: 0,
                  queue: [item],
                }
              : a
          ),
        };
      });
    },
    [selected, selectedFlockId, language]
  );

  const handlePlaceBuilding = useCallback(
    (kind: BuildingKind, x: number, z: number) => {
      setGame(g => placeBuilding(g, kind, x, z, selected));
      setPlacementKind(null);
    },
    [selected]
  );

  const handleGather = useCallback(
    (node: ResourceNode) => {
      const carriers = game.actors.filter(a => selected.includes(a.id) && (a.role === 'carrier' || a.role === 'engineer'));
      const ids = carriers.length ? carriers.map(a => a.id) : selected;
      assignOrder(order('gather', `采集${node.nameZh}`, node.x, node.z, node.id), ids);
    },
    [assignOrder, game.actors, selected]
  );

  const handleAttack = useCallback(
    (enemy: Enemy) => {
      assignOrder(order('attack', `讨伐${enemy.nameZh}`, enemy.x, enemy.z, enemy.id));
    },
    [assignOrder]
  );

  const handleSelectBuilding = useCallback(
    (b: BuildingState) => {
      if (placementKind) return;
      if (!b.built) {
        assignOrder(order('build', `协同建造${b.nameZh}`, b.x, b.z, b.id));
        return;
      }
      if (selected.includes('sarai') && selected.length === 1) {
        setGame(g => assignSupervise(g, b.id));
        return;
      }
      flyTo(b.x, b.z);
    },
    [placementKind, assignOrder, selected, flyTo]
  );

  const handleRightClickBuilding = useCallback(
    (b: BuildingState) => {
      if (!b.built) {
        assignOrder(order('build', `协同建造${b.nameZh}`, b.x, b.z, b.id));
      } else if (b.kind === 'healingTent') {
        assignOrder(order('rest', `前往${b.nameZh}疗伤`, b.x, b.z, b.id));
      } else if (b.kind === 'altar' && selected.includes('abram')) {
        assignOrder(order('sacrifice', '筑坛献祭求告', b.x, b.z, b.id), ['abram']);
      } else if (selected.includes('sarai')) {
        setGame(g => assignSupervise(g, b.id));
      } else {
        assignOrder(order('move', `集结至${b.nameZh}`, b.x + 1.2, b.z + 1.0));
      }
    },
    [assignOrder, selected]
  );

  const handleExpandPost = useCallback(
    (p: BoundaryPostState) => {
      if (p.claimed) {
        flyTo(p.x, p.z);
        return;
      }
      const eng = game.actors.find(a => a.role === 'engineer');
      const ids = eng ? [eng.id] : selected;
      assignOrder(order('expand', `扩界${p.nameZh}`, p.x, p.z, p.id), ids);
      setSelected(ids);
    },
    [assignOrder, flyTo, game.actors, selected]
  );

  const handleInteractLandmark = useCallback(
    (l: NeutralLandmarkState) => {
      if (l.completed) {
        flyTo(l.x, l.z);
        return;
      }
      if (l.id === 'wolfDen') {
        assignOrder(order('attackMove', `进剿${l.nameZh}`, l.x, l.z));
        return;
      }
      const worker =
        l.id === 'lostSheep'
          ? game.actors.find(a => a.role === 'scout')
          : game.actors.find(a => a.role === 'engineer');
      const ids = worker ? [worker.id] : selected;
      assignOrder(order('repairLandmark', `探索${l.nameZh}`, l.x, l.z, l.id), ids);
      setSelected(ids);
    },
    [assignOrder, flyTo, game.actors, selected]
  );

  const handleSelectIdleWorker = useCallback(() => {
    const idleWorkers = game.actors.filter(
      a => (a.role === 'carrier' || a.role === 'engineer') && a.activity === 'idle' && a.queue.length === 0
    );
    if (!idleWorkers.length) {
      setGame(g => pushLog(g, '当前所有工程先驱与营地搬运工均在忙碌中！'));
      return;
    }
    const next = idleWorkers[0];
    setSelected([next.id]);
    flyTo(next.x, next.z);
  }, [game.actors, flyTo]);

  const handleGoHome = useCallback(() => {
    const main = game.buildings.find(b => b.kind === 'mainTent');
    if (main) flyTo(main.x, main.z);
  }, [game.buildings, flyTo]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (panel || game.phase === 'act4_parting') return;
      if (e.key === 'Escape') {
        setPlacementKind(null);
      } else if (e.code === 'Space') {
        e.preventDefault();
        setGame(g => ({ ...g, paused: !g.paused }));
      } else if (e.key.toUpperCase() === 'H') {
        handleGoHome();
      } else if (e.key === '.') {
        handleSelectIdleWorker();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [panel, game.phase, handleGoHome, handleSelectIdleWorker]);

  const restart = () => {
    if (!window.confirm(t('restartConfirm'))) return;
    const fresh = newGame();
    saveGame(fresh);
    setGame(fresh);
    setSelected(['abram']);
    setPlacementKind(null);
    flyTo(-4.5, 2.0);
  };

  const lead = game.actors.find(a => a.id === selected[0]) ?? game.actors[0];
  const livingEnemies = game.enemies.filter(e => e.hp > 0).length;
  const idleWorkerCount = game.actors.filter(
    a => (a.role === 'carrier' || a.role === 'engineer') && a.activity === 'idle' && a.queue.length === 0
  ).length;
  const age2Started = game.buildings.some(b => getBlueprint(b.kind).isAge2Landmark);

  const roleGroups = (['leader', 'organizer', 'scout', 'engineer', 'spearman', 'slinger', 'carrier', 'herdsman'] as Role[])
    .map(r => ({
      role: r,
      units: game.actors.filter(a => a.role === r && a.hp > 0),
    }))
    .filter(g => g.units.length > 0);

  const actText =
    game.phase === 'resolved'
      ? (language === 'zh' ? '圣约石 #02 已点亮！创 13 礼让分地完成。' : 'Stone #02 Lit! Gen 13 Parting Complete.')
      : game.phase === 'act1_camp'
        ? (language === 'zh' ? '第一幕：在左下选「伐木货栈」与「副帐房舍」自由落址建造，建立搬运物流' : 'Act I: Place Supply Depot & Cistern House inside territory')
        : game.phase === 'act2_expand'
          ? (language === 'zh' ? '第二幕：派乌珥敲击界石扩地至石矿/山泉，建造时代Ⅱ地标晋升' : 'Act II: Expand boundary posts with Ur & build Age II Landmark')
          : livingEnemies > 0
            ? (language === 'zh' ? `第三幕：造哨营与瞭望箭塔，转职矛兵/投石手肃清北岭敌群（剩 ${livingEnemies}）` : `Act III: Clear Northern Ridge Enemies (${livingEnemies} left)`)
            : (language === 'zh' ? '第四幕：北岭已靖！点击左下「与罗得议事」完成创世记 13:8–18 分地' : 'Act IV: Speak with Lot to resolve Genesis 13:8-18');

  return (
    <main className={`aoe-v5-shell ${language === 'en' ? 'lang-en' : ''}`}>
      {/* Full-Screen Pure 3D Battlefield (Zero Sliced 2D Images!) */}
      <div className="battlefield-canvas" onWheel={e => handleZoomChange(e.deltaY > 0 ? 0.08 : -0.08)}>
        <World
          game={game}
          selected={selected}
          selectedFlockId={selectedFlockId}
          placementKind={placementKind}
          onSelectUnit={handleSelectUnit}
          onSelectFlock={handleSelectFlock}
          onMoveOrder={handleMoveOrder}
          onPlaceBuilding={handlePlaceBuilding}
          onGather={handleGather}
          onAttack={handleAttack}
          onSelectBuilding={handleSelectBuilding}
          onRightClickBuilding={handleRightClickBuilding}
          onExpandPost={handleExpandPost}
          onInteractLandmark={handleInteractLandmark}
          focusRequest={focusRequest}
          zoom={zoom}
          onCameraMove={handleCameraMove}
        />
      </div>

      {/* Top AoE Bronze & Parchment Resource Bar */}
      <header className="aoe-top-bar">
        <div className="aoe-title-cell">
          <span className="age-badge">{game.age === 1 ? (language === 'zh' ? '时代Ⅰ 游牧' : 'Age I') : (language === 'zh' ? '时代Ⅱ 立约' : 'Age II')}</span>
          <strong>{language === 'zh' ? '伯特利与艾城 — 创世记 13' : 'Bethel & Ai — Genesis 13'}</strong>
        </div>

        <div className="aoe-res-strip" aria-label="Resources">
          <div className="res-item" title="粮草 (Food)"><span>🌾</span><b>{game.food}</b></div>
          <div className="res-item" title="饮水 (Water)"><span>💧</span><b>{game.water}</b></div>
          <div className="res-item" title="石料 (Stone)"><span>🪨</span><b>{game.stone}</b></div>
          <div className="res-item" title="木料 (Wood)"><span>🪵</span><b>{game.wood}</b></div>
          <div className="res-item" title="家族和睦 (Harmony)"><span>🔥</span><b>{game.trust}</b></div>
          <div className="res-item" title="人口 (Population)"><span>👥</span><b>{game.actors.length} / {game.popCap}</b></div>
          <button
            type="button"
            className={`idle-worker-pill ${idleWorkerCount > 0 ? 'alert' : ''}`}
            onClick={handleSelectIdleWorker}
            title="定位空闲搬运工/工程先驱 (.)"
          >
            ⚒️ {language === 'zh' ? '空闲' : 'Idle'} {idleWorkerCount}
          </button>
        </div>

        <div className="aoe-top-controls">
          {game.divineFavorTicks > 0 && (
            <span className="aoe-divine-badge" title="神圣恩眷：全军移速+15%，护甲+2">
              ✨ {language === 'zh' ? '神圣恩眷' : 'Divine Favor'} {Math.ceil(game.divineFavorTicks / 8)}s
            </span>
          )}
          <button type="button" onClick={() => setPanel('map')}>{t('mapButton')}</button>
          <button type="button" onClick={() => setGame(g => ({ ...g, paused: !g.paused }))}>
            {game.paused ? '▶' : '⏸'}
          </button>
          <button type="button" onClick={() => setLanguage(language === 'zh' ? 'en' : 'zh')}>
            {language === 'zh' ? 'EN' : '中'}
          </button>
          <button type="button" onClick={restart}>{t('restart')}</button>
          <button type="button" onClick={() => setPanel('help')}>?</button>
        </div>
      </header>

      {/* Top-Left Compact Campaign Objective & Side Quests Banner */}
      <aside className="aoe-quest-box">
        <div className="quest-main">
          <b>{actText}</b>
          {placementKind && (
            <span className="placement-hint">
              {language === 'zh'
                ? `正在选址【${getBlueprint(placementKind).nameZh}】：点击绿圈空地落锤（Esc取消）`
                : `Placing ${getBlueprint(placementKind).nameEn}: Tap green ground`}
            </span>
          )}
        </div>
        <div className="side-quests-row">
          {game.landmarks.map(l => (
            <button
              key={l.id}
              type="button"
              className={`sq-pill ${l.completed ? 'done' : ''}`}
              onClick={() => handleInteractLandmark(l)}
            >
              {l.completed ? '✓ ' : '◎ '}
              {language === 'zh' ? l.nameZh : l.nameEn}
            </button>
          ))}
        </div>
        <div className="quest-log-line" role="status">{localizeLog(game.log[0], language)}</div>
      </aside>

      {/* Mobile Portrait Drawer Switcher */}
      <div className="mobile-drawer-tabs">
        <button type="button" className={mobileDrawer === 'build' ? 'active' : ''} onClick={() => setMobileDrawer('build')}>
          {language === 'zh' ? '建造与征召 (3×4)' : 'Build & Train'}
        </button>
        <button type="button" className={mobileDrawer === 'squad' ? 'active' : ''} onClick={() => setMobileDrawer('squad')}>
          {language === 'zh' ? `已选编队 (${selected.length})` : `Squad (${selected.length})`}
        </button>
      </div>

      {/* Bottom 3-Section AoE Command HUD (100% Vector SVG Icons, Zero Sliced Sprites!) */}
      <footer className="aoe-bottom-hud">
        <div className={`aoe-build-wrap ${mobileDrawer === 'squad' ? 'hide-mobile' : ''}`}>
          <div className="aoe-cmd-tabs" role="tablist">
            <button
              type="button"
              role="tab"
              aria-selected={commandTab === 'build'}
              className={commandTab === 'build' ? 'active' : ''}
              onClick={() => setCommandTab('build')}
            >
              {language === 'zh' ? '营造建造' : 'Build'}
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={commandTab === 'orders'}
              className={commandTab === 'orders' ? 'active' : ''}
              onClick={() => setCommandTab('orders')}
            >
              {language === 'zh' ? '征召与圣约' : 'Train & Rite'}
            </button>
          </div>
          <section className="aoe-build-grid" aria-label="Build and Command Grid">
            {commandTab === 'build' ? (
              <>
                <button
                  type="button"
                  className={placementKind === 'house' ? 'active' : ''}
                  onClick={() => setPlacementKind(k => (k === 'house' ? null : 'house'))}
                >
                  <AoEEmblem kind="house" />
                  <b>{language === 'zh' ? '副帐房舍' : 'House'}</b>
                  <small>40木 · +4人口</small>
                </button>

                <button
                  type="button"
                  className={placementKind === 'depot' ? 'active' : ''}
                  onClick={() => setPlacementKind(k => (k === 'depot' ? null : 'depot'))}
                >
                  <AoEEmblem kind="depot" />
                  <b>{language === 'zh' ? '伐木货栈' : 'Storehouse'}</b>
                  <small>50木 · 就近交货</small>
                </button>

                <button
                  type="button"
                  className={placementKind === 'watchtower' ? 'active' : ''}
                  onClick={() => setPlacementKind(k => (k === 'watchtower' ? null : 'watchtower'))}
                >
                  <AoEEmblem kind="watchtower" />
                  <b>{language === 'zh' ? '瞭望箭塔' : 'Watchtower'}</b>
                  <small>40木 35石</small>
                </button>

                <button
                  type="button"
                  className={placementKind === 'barracks' ? 'active' : ''}
                  onClick={() => setPlacementKind(k => (k === 'barracks' ? null : 'barracks'))}
                >
                  <AoEEmblem kind="barracks" />
                  <b>{language === 'zh' ? '家丁哨营' : 'Barracks'}</b>
                  <small>80木 20石</small>
                </button>

                <button
                  type="button"
                  className={placementKind === 'healingTent' ? 'active' : ''}
                  onClick={() => setPlacementKind(k => (k === 'healingTent' ? null : 'healingTent'))}
                >
                  <AoEEmblem kind="healingTent" />
                  <b>{language === 'zh' ? '医治帐篷' : 'Healing Tent'}</b>
                  <small>45木 25水·急救</small>
                </button>

                <button
                  type="button"
                  disabled={age2Started}
                  className={placementKind === 'landmarkOlive' ? 'active' : ''}
                  onClick={() => setPlacementKind(k => (k === 'landmarkOlive' ? null : 'landmarkOlive'))}
                >
                  <AoEEmblem kind="landmarkOlive" />
                  <b>{language === 'zh' ? '橄榄庄园' : 'Olive Terrace'}</b>
                  <small>时代Ⅱ经济地标</small>
                </button>

                <button
                  type="button"
                  disabled={age2Started}
                  className={placementKind === 'landmarkEncampment' ? 'active' : ''}
                  onClick={() => setPlacementKind(k => (k === 'landmarkEncampment' ? null : 'landmarkEncampment'))}
                >
                  <AoEEmblem kind="landmarkEncampment" />
                  <b>{language === 'zh' ? '备战营垒' : 'War Redoubt'}</b>
                  <small>时代Ⅱ军事地标</small>
                </button>
              </>
            ) : (
              <>
                <button type="button" onClick={() => setGame(g => recruitCarrier(g))}>
                  <AoEEmblem kind="carrier" />
                  <b>{language === 'zh' ? '招搬运工' : 'Train Carrier'}</b>
                  <small>50粮 · 扩物流</small>
                </button>

                <button type="button" onClick={() => setGame(g => trainMilitary(g, 'spearman'))}>
                  <AoEEmblem kind="spearman" />
                  <b>{language === 'zh' ? '训家丁矛兵' : 'Spearman'}</b>
                  <small>40粮25木·转1工</small>
                </button>

                <button type="button" onClick={() => setGame(g => trainMilitary(g, 'slinger'))}>
                  <AoEEmblem kind="slinger" />
                  <b>{language === 'zh' ? '训投石手' : 'Slinger'}</b>
                  <small>35粮30木·转1工</small>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    const post = game.boundaryPosts.find(p => !p.claimed);
                    if (post) handleExpandPost(post);
                  }}
                >
                  <AoEEmblem kind="expand" />
                  <b>{language === 'zh' ? '乌珥扩地' : 'Expand Border'}</b>
                  <small>敲立界石桩</small>
                </button>

                <button
                  type="button"
                  onClick={() => {
                    const targetB =
                      game.buildings.find(b => b.kind === 'depot' && b.built) ??
                      game.buildings.find(b => b.kind === 'mainTent')!;
                    setGame(g => assignSupervise(g, targetB.id));
                  }}
                >
                  <AoEEmblem kind="supervise" />
                  <b>{language === 'zh' ? '撒莱督工' : 'Supervise'}</b>
                  <small>+25%入库/+50%速</small>
                </button>

                <button
                  type="button"
                  className={game.divineFavorTicks > 0 ? 'active' : 'gold-highlight'}
                  onClick={() => setGame(g => performSacrifice(g))}
                >
                  <AoEEmblem kind="altar" />
                  <b>{language === 'zh' ? '筑坛献祭' : 'Sacrifice'}</b>
                  <small>{game.divineFavorTicks > 0 ? `恩眷中 ${Math.ceil(game.divineFavorTicks / 8)}s` : '30粮20木·止争端'}</small>
                </button>

                {livingEnemies > 0 && game.friction < LEVEL1_CONFIG.numbers.FRICTION_THRESHOLD_ACT4 ? (
                  <button type="button" disabled={game.hornCooldown > 0} onClick={() => setGame(g => blowHorn(g))}>
                    <AoEEmblem kind="horn" />
                    <b>{language === 'zh' ? '守望号角' : 'Rally Horn'}</b>
                    <small>{game.hornCooldown > 0 ? `${Math.ceil(game.hornCooldown / 8)}s` : '双甲+2 移速+15%'}</small>
                  </button>
                ) : (
                  <button
                    type="button"
                    className="gold-highlight"
                    onClick={() => assignOrder(order('talk', '与罗得议事', targets.lot.x, targets.lot.z), ['abram'])}
                  >
                    <AoEEmblem kind="talk" />
                    <b>{language === 'zh' ? '与罗得议事' : 'Speak to Lot'}</b>
                    <small>创13 礼让分地</small>
                  </button>
                )}
              </>
            )}
          </section>
        </div>

        {/* Center: Selected Leader Emblem & Grouped Squad Cards */}
        <section className={`aoe-selected-panel ${mobileDrawer === 'build' ? 'hide-mobile' : ''}`} aria-label="Selected Units">
          <div className="lead-portrait-box">
            <AoEEmblem kind={lead.role} />
            <div className="lead-meta">
              <b>{actorNames[lead.id]?.[language] ?? lead.name}</b>
              <small>{language === 'zh' ? ROLE_LABELS_ZH[lead.role] : ROLE_LABELS_EN[lead.role]}</small>
              <span>⚔️{lead.attack} 🛡️{lead.meleeArmor}/{lead.rangedArmor}</span>
            </div>
          </div>

          <div className="squad-matrix-wrap">
            <div className="matrix-header">
              <span>
                {language === 'zh'
                  ? `当前编队 (${selected.length} / 全营 ${game.actors.length})`
                  : `Selected Units (${selected.length})`}
              </span>
              <div className="quick-group-btns">
                <button
                  type="button"
                  onClick={() =>
                    setSelected(
                      game.actors
                        .filter(a => a.role === 'leader' || a.role === 'scout' || a.role === 'spearman' || a.role === 'slinger')
                        .map(a => a.id)
                    )
                  }
                >
                  {language === 'zh' ? '全选战兵' : 'All Military'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    const waterNode = game.resources.find(r => r.kind === 'water' && r.amount > 0);
                    if (waterNode) handleGather(waterNode);
                  }}
                >
                  {language === 'zh' ? '派去汲水' : 'Gather Water'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    const woodNode = game.resources.find(r => r.kind === 'wood' && r.amount > 0);
                    if (woodNode) handleGather(woodNode);
                  }}
                >
                  {language === 'zh' ? '派去伐木' : 'Gather Wood'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    const stoneNode = game.resources.find(r => r.kind === 'stone' && r.amount > 0);
                    if (stoneNode) handleGather(stoneNode);
                  }}
                >
                  {language === 'zh' ? '派去采石' : 'Gather Stone'}
                </button>
              </div>
            </div>

            <div className="unit-cards-row">
              {roleGroups.map(grp => {
                const sample = grp.units[0];
                const isGroupSelected = grp.units.some(u => selected.includes(u.id));
                const avgHpPct =
                  (grp.units.reduce((acc, u) => acc + u.hp / u.maxHp, 0) / grp.units.length) * 100;
                return (
                  <button
                    key={grp.role}
                    type="button"
                    className={`aoe-unit-card ${isGroupSelected ? 'selected' : ''}`}
                    onClick={() => {
                      setSelected(grp.units.map(u => u.id));
                      flyTo(sample.x, sample.z);
                    }}
                  >
                    <AoEEmblem kind={grp.role} />
                    <span className="unit-count-badge">{grp.units.length}</span>
                    <small>{language === 'zh' ? ROLE_LABELS_ZH[grp.role] : ROLE_LABELS_EN[grp.role]}</small>
                    <div className="unit-hp-bar"><i style={{ width: `${avgHpPct}%` }} /></div>
                  </button>
                );
              })}
            </div>
          </div>
        </section>

        {/* Right: 45-Degree Isometric Diamond Minimap */}
        <Minimap
          game={game}
          selected={selected}
          cameraPos={cameraPos}
          zoom={zoom}
          onFocus={flyTo}
          onZoomChange={handleZoomChange}
          onSelectIdleWorker={handleSelectIdleWorker}
          onGoHome={handleGoHome}
        />
      </footer>

      {game.pendingPerkChoices > 0 && (
        <div className="overlay">
          <div className="dialog">
            <span className="eyebrow">
              {language === 'zh' ? '圣约恩典 · 局内三选一策令 (Crucible Perk)' : 'Covenant Grace · Choose 1 Perk'}
            </span>
            <h2>{language === 'zh' ? '选择一项营地永久强化' : 'Choose a Permanent Camp Blessing'}</h2>
            <div className="choice">
              {PERKS.map(p => {
                const taken = game.perks.includes(p.id);
                return (
                  <button key={p.id} type="button" disabled={taken} onClick={() => setGame(g => choosePerk(g, p.id))}>
                    <b>{taken ? '✓ ' : '✦ '}{language === 'zh' ? p.nameZh : p.nameEn}</b>
                    <small>{language === 'zh' ? p.descZh : p.descEn}</small>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {panel === 'story' && (
        <div className="overlay">
          <div className="dialog">
            <span className="eyebrow">{t('storyIntro')}</span>
            <h2>{t('arrival')}</h2>
            <p>{t('arrivalBody')}</p>
            <p className="note">
              {language === 'zh'
                ? 'v5.0 纯 3D 帝国时代 × 工人物语实机规范（零2D贴纸切片）：① 所有角色、矛兵、投石手与 6 大建筑均为 3.5–4.5 头身纯 3D 关节与建筑模型，带真实 3D 肢体动作与 45° 实时阴影；② 左下 3×4 面板选建筑后在领土内自由选址落锤；③ 搬运工自动往返就近货栈，哨营将搬运工转职为架枪矛兵与高地投石手。'
                : 'v5.0 Pure 3D AoE × Settlers (Zero 2D slicing): All units and buildings are articulated 3D miniature models with real cast shadows.'}
            </p>
            <button type="button" className="dialog-primary" onClick={() => setPanel(null)}>{t('begin')}</button>
          </div>
        </div>
      )}

      {panel === 'help' && (
        <div className="overlay" onClick={() => setPanel(null)}>
          <div className="dialog" onClick={e => e.stopPropagation()}>
            <button type="button" className="close" onClick={() => setPanel(null)}>×</button>
            <h2>{t('help')}</h2>
            <p>1. <b>纯 3D 微缩建筑与自由选址</b>：在左下 `3×4` 面板点选建筑，点击领土内空地即可奠基；搬运工手抱 3D 陶罐/原木/石块沿土路自动送往最近货栈（道路移速 `+30%`）。</p>
            <p>2. <b>工程扩地与主母督工</b>：点击「乌珥扩地」敲立界石可将北坡石矿与西泉并入领土；点击「撒莱督工」驻扎货栈可令单次入库量 `+25%`。</p>
            <p>3. <b>双护甲克制与智能分火</b>：哨营将搬运工转职为**家丁矛兵**（双手 3D 青铜长矛架枪反冲锋）或**投石手**（高地 `+25%` 伤害 + 弹道预扣血防过量集火）。</p>
            <button type="button" className="dialog-primary" onClick={() => setPanel(null)}>{t('close')}</button>
          </div>
        </div>
      )}

      {panel === 'map' && (
        <div className="overlay" onClick={() => setPanel(null)}>
          <div className="dialog dialog-wide" onClick={e => e.stopPropagation()}>
            <button type="button" className="close" onClick={() => setPanel(null)}>×</button>
            <span className="eyebrow">{t('mapTitle')}</span>
            <h2>{t('camp')}</h2>
            <div className="stones-grid">
              {CAMPAIGN_STONES.map(s => {
                const isLit = s.index === 2 && game.phase === 'resolved';
                const statusClass = isLit ? 'lit' : s.status;
                return (
                  <div key={s.id} className={`stone-card ${statusClass}`}>
                    <div className="stone-num">#{String(s.index).padStart(2, '0')} · {s.ref}</div>
                    <b>{language === 'zh' ? s.titleZh : s.titleEn}</b>
                    <small>{language === 'zh' ? s.eraZh : s.eraEn}</small>
                  </div>
                );
              })}
            </div>
            <p className="note">{t('mapNote')}</p>
          </div>
        </div>
      )}

      {game.phase === 'act4_parting' && !game.ending && (
        <div className="overlay">
          <div className="dialog">
            <span className="eyebrow">{t('choiceRef')}</span>
            <h2>{t('dispute')}</h2>
            <p>{t('disputeBody')}</p>
            <label className="escort-check">
              <input type="checkbox" checked={escortOption} onChange={e => setEscortOption(e.target.checked)} />
              <span>{t('escortToggle')}</span>
            </label>
            <div className="choice">
              <button
                type="button"
                disabled={game.water < LEVEL1_CONFIG.numbers.PARTING_SHARE_WATER_COST}
                onClick={() => setGame(g => resolveParting(g, 'share', escortOption))}
              >
                <b>{t('share')}</b>
                <small>饮水 −40 · 和睦 +2 · 羊群完好</small>
              </button>
              <button
                type="button"
                disabled={game.wood < LEVEL1_CONFIG.numbers.PARTING_GIFT_WOOD_COST}
                onClick={() => setGame(g => resolveParting(g, 'gift', escortOption))}
              >
                <b>{t('gift')}</b>
                <small>木料 −50 · 和睦 +3 · 骨肉情深</small>
              </button>
              <button type="button" onClick={() => setGame(g => resolveParting(g, 'separate', escortOption))}>
                <b>{t('separate')}</b>
                <small>粮草 −30 · 和睦 +1 · 零门槛保底</small>
              </button>
            </div>
            <p className="note">{t('adaptationNote')}</p>
          </div>
        </div>
      )}
    </main>
  );
}
