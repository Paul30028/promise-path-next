import { useEffect, useRef } from 'react';
import { WORLD_DIMENSIONS } from './config';
import { fogIndex, isVisibleInFog } from './game';
import type { Game } from './game';

const toPctX = (x: number) => ((x + WORLD_DIMENSIONS.halfW) / WORLD_DIMENSIONS.width) * 100;
const toPctY = (z: number) => ((z + WORLD_DIMENSIONS.halfD) / WORLD_DIMENSIONS.depth) * 100;

export default function Minimap({
  game,
  selected,
  cameraPos,
  zoom,
  onFocus,
  onZoomChange,
  onSelectIdleWorker,
  onGoHome,
}: {
  game: Game;
  selected: string[];
  cameraPos: { x: number; z: number };
  zoom: number;
  onFocus: (x: number, z: number) => void;
  onZoomChange: (delta: number) => void;
  onSelectIdleWorker: () => void;
  onGoHome: () => void;
}) {
  const draggingRef = useRef(false);
  const fogCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const prevFogRef = useRef<number[] | null>(null);

  useEffect(() => {
    const canvas = fogCanvasRef.current;
    if (!canvas) return;
    const prev = prevFogRef.current;
    if (prev && prev.length === game.fog.length && prev.every((v, i) => v === game.fog[i])) {
      return;
    }
    prevFogRef.current = game.fog;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { fogCols, fogRows } = WORLD_DIMENSIONS;
    ctx.clearRect(0, 0, fogCols, fogRows);
    for (let row = 0; row < fogRows; row++) {
      for (let col = 0; col < fogCols; col++) {
        const f = game.fog[fogIndex(col, row)] ?? 0;
        if (f === 2) continue;
        ctx.fillStyle = f === 0 ? 'rgba(24, 18, 12, 0.85)' : 'rgba(24, 18, 12, 0.38)';
        ctx.fillRect(col, row, 1, 1);
      }
    }
  }, [game.fog]);

  const dispatchFocus = (clientX: number, clientY: number, el: HTMLDivElement) => {
    const rect = el.getBoundingClientRect();
    const rx = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
    const ry = Math.max(0, Math.min(1, (clientY - rect.top) / rect.height));
    const wx = rx * WORLD_DIMENSIONS.width - WORLD_DIMENSIONS.halfW;
    const wz = ry * WORLD_DIMENSIONS.depth - WORLD_DIMENSIONS.halfD;
    onFocus(wx, wz);
  };

  const viewW = Math.min(90, 34 * zoom);
  const viewH = Math.min(90, 34 * zoom);
  const viewLeft = Math.max(2, Math.min(98 - viewW, toPctX(cameraPos.x) - viewW / 2));
  const viewTop = Math.max(2, Math.min(98 - viewH, toPctY(cameraPos.z) - viewH / 2));

  return (
    <div className="aoe-minimap-panel" aria-label="Tactical Minimap">
      <div className="minimap-side-tools">
        <button type="button" onClick={onGoHome} title="回到主营大帐 (H)" aria-label="Go to Main Tent">⛺</button>
        <button type="button" onClick={onSelectIdleWorker} title="选中空闲工人 (.)" aria-label="Select Idle Worker">⚒️</button>
        <button type="button" onClick={() => onZoomChange(-0.15)} title="放大视野" aria-label="Zoom In">+</button>
        <button type="button" onClick={() => onZoomChange(0.15)} title="缩小视野" aria-label="Zoom Out">−</button>
      </div>
      <div
        className="diamond-minimap"
        onPointerDown={e => {
          e.stopPropagation();
          draggingRef.current = true;
          e.currentTarget.setPointerCapture(e.pointerId);
          dispatchFocus(e.clientX, e.clientY, e.currentTarget);
        }}
        onPointerMove={e => {
          if (!draggingRef.current) return;
          e.stopPropagation();
          dispatchFocus(e.clientX, e.clientY, e.currentTarget);
        }}
        onPointerUp={e => {
          draggingRef.current = false;
          if (e.currentTarget.hasPointerCapture(e.pointerId)) {
            e.currentTarget.releasePointerCapture(e.pointerId);
          }
        }}
      >
        <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="minimap-svg">
          <rect x="0" y="0" width="100" height="100" fill="#8b6f47" />
          {/* Western Oasis */}
          <ellipse cx={toPctX(-14.2)} cy={toPctY(0.4)} rx="11" ry="14" fill="#257ca3" opacity="0.88" />
          {/* Southeast Pasture */}
          <ellipse cx={toPctX(9.2)} cy={toPctY(6.5)} rx="15" ry="15" fill="#628a34" opacity="0.82" />
          {/* Territory circles */}
          {game.territories.map(t => (
            <circle
              key={t.id}
              cx={toPctX(t.x)}
              cy={toPctY(t.z)}
              r={(t.radius / WORLD_DIMENSIONS.width) * 100}
              fill="none"
              stroke="#fbbf24"
              strokeWidth="0.8"
              strokeDasharray="2 1.5"
            />
          ))}
          {/* Resources */}
          {game.resources.map(r =>
            r.amount > 0 ? (
              <circle
                key={r.id}
                cx={toPctX(r.x)}
                cy={toPctY(r.z)}
                r="1.8"
                fill={
                  r.kind === 'water'
                    ? '#38bdf8'
                    : r.kind === 'wood'
                      ? '#65a30d'
                      : r.kind === 'stone'
                        ? '#d6d3d1'
                        : '#facc15'
                }
              />
            ) : null
          )}
          {/* Buildings */}
          {game.buildings.map(b => (
            <rect
              key={b.id}
              x={toPctX(b.x) - 2.4}
              y={toPctY(b.z) - 2.4}
              width="4.8"
              height="4.8"
              fill={b.built ? '#2563eb' : '#fde047'}
              stroke="#fef3c7"
              strokeWidth="0.7"
            />
          ))}
          {/* Visible Enemies */}
          {game.enemies.map(e =>
            e.hp > 0 && isVisibleInFog(game.fog, e.x, e.z) ? (
              <circle
                key={e.id}
                cx={toPctX(e.x)}
                cy={toPctY(e.z)}
                r={e.kind === 'alphaWolf' ? '3.0' : '2.2'}
                fill="#ef4444"
                stroke="#fecaca"
                strokeWidth="0.6"
              />
            ) : null
          )}
          {/* Friendly Units */}
          {game.actors.map(a => {
            const isSel = selected.includes(a.id);
            return (
              <g key={a.id}>
                {isSel && <circle cx={toPctX(a.x)} cy={toPctY(a.z)} r="3.5" fill="none" stroke="#fde047" strokeWidth="1" />}
                <circle
                  cx={toPctX(a.x)}
                  cy={toPctY(a.z)}
                  r="2.1"
                  fill={a.carrying ? '#38bdf8' : a.color}
                  stroke="#fff"
                  strokeWidth="0.5"
                />
              </g>
            );
          })}
          {/* Camera Viewport */}
          <rect x={viewLeft} y={viewTop} width={viewW} height={viewH} fill="none" stroke="#fef3c7" strokeWidth="1.2" />
        </svg>
        <canvas
          ref={fogCanvasRef}
          width={WORLD_DIMENSIONS.fogCols}
          height={WORLD_DIMENSIONS.fogRows}
          style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}
        />
      </div>
    </div>
  );
}
