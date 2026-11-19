import { Canvas, ThreeEvent, useFrame, useThree } from '@react-three/fiber';
import { useEffect, useMemo, useRef, useState } from 'react';
import * as THREE from 'three';
import { LEVEL1_CONFIG, WORLD_DIMENSIONS } from './config';
import { fogIndex, getBlueprint, isValidPlacement, isVisibleInFog } from './game';
import type {
  Actor,
  BoundaryPostState,
  BuildingKind,
  BuildingState,
  Enemy,
  FlockState,
  Game,
  NeutralLandmarkState,
  Projectile,
  ResourceNode,
  VisualEffect,
} from './game';
import { BuildingModel3D, EnemyModel3D, FlockModel3D, UnitModel3D } from './models3d';
import { getTerrainHeight } from './textures3d';

export type CameraFocusRequest = {
  x: number;
  z: number;
  seq: number;
};

function CameraRig({
  selected,
  actors,
  panOffsetRef,
  focusRequest,
  userDraggedRef,
  zoom,
  onCameraMove,
}: {
  selected: string[];
  actors: Actor[];
  panOffsetRef: React.MutableRefObject<{ x: number; z: number }>;
  focusRequest: CameraFocusRequest;
  userDraggedRef: React.MutableRefObject<boolean>;
  zoom: number;
  onCameraMove?: (x: number, z: number) => void;
}) {
  const { camera, size } = useThree();
  const desiredVec = useRef(new THREE.Vector3());
  const lastFocusSeqRef = useRef<number>(focusRequest.seq);
  const lastSelRef = useRef<string | undefined>(selected[0]);

  useEffect(() => {
    const c = camera as THREE.PerspectiveCamera;
    c.fov = size.height > size.width ? 34 : 30;
    c.updateProjectionMatrix();
  }, [camera, size.width, size.height]);

  useEffect(() => {
    if (focusRequest.seq !== lastFocusSeqRef.current) {
      lastFocusSeqRef.current = focusRequest.seq;
      userDraggedRef.current = false;
      const nx = THREE.MathUtils.clamp(focusRequest.x, -WORLD_DIMENSIONS.cameraClampX, WORLD_DIMENSIONS.cameraClampX);
      const nz = THREE.MathUtils.clamp(focusRequest.z, -WORLD_DIMENSIONS.cameraClampZ, WORLD_DIMENSIONS.cameraClampZ);
      panOffsetRef.current.x = nx;
      panOffsetRef.current.z = nz;
      onCameraMove?.(nx, nz);
    }
  }, [focusRequest, panOffsetRef, userDraggedRef, onCameraMove]);

  useEffect(() => {
    const first = selected[0];
    if (first && first !== lastSelRef.current) {
      lastSelRef.current = first;
      if (!userDraggedRef.current && size.width < 960) {
        const a = actors.find(x => x.id === first);
        if (a) {
          const nx = THREE.MathUtils.clamp(a.x, -WORLD_DIMENSIONS.cameraClampX, WORLD_DIMENSIONS.cameraClampX);
          const nz = THREE.MathUtils.clamp(a.z, -WORLD_DIMENSIONS.cameraClampZ, WORLD_DIMENSIONS.cameraClampZ);
          panOffsetRef.current.x = nx;
          panOffsetRef.current.z = nz;
          onCameraMove?.(nx, nz);
        }
      }
    }
  }, [selected, actors, size.width, panOffsetRef, userDraggedRef, onCameraMove]);

  useFrame((_, delta) => {
    const rate = LEVEL1_CONFIG.numbers.CAMERA_DAMP_RATE ?? 8.0;
    const t = 1.0 - Math.exp(-rate * delta);
    const tx = panOffsetRef.current.x;
    const tz = panOffsetRef.current.z;
    const camHeight = 15.2 * zoom;
    const camZOffset = 14.0 * zoom;
    desiredVec.current.set(tx, camHeight, tz + camZOffset);
    camera.position.lerp(desiredVec.current, t);
    camera.lookAt(tx, 0.15, tz);
  });
  return null;
}

function WorldProgressBar({
  progress,
  y,
  color = '#38bdf8',
  width = 0.9,
}: {
  progress: number;
  y: number;
  color?: string;
  width?: number;
}) {
  const clamped = THREE.MathUtils.clamp(progress, 0.02, 1);
  return (
    <group position={[0, y, 0]} rotation={[-0.38, 0, 0]}>
      <mesh position={[0, 0, -0.005]}>
        <planeGeometry args={[width + 0.06, 0.11]} />
        <meshBasicMaterial color="#18120c" transparent opacity={0.86} side={THREE.DoubleSide} />
      </mesh>
      <mesh position={[-(width * (1 - clamped)) / 2, 0, 0.005]}>
        <planeGeometry args={[width * clamped, 0.07]} />
        <meshBasicMaterial color={color} side={THREE.DoubleSide} />
      </mesh>
    </group>
  );
}

function SmoothFogOfWar({ fog }: { fog: number[] }) {
  const { width, depth, fogCols, fogRows } = WORLD_DIMENSIONS;
  const prevFogRef = useRef<number[] | null>(null);

  const { data, tex } = useMemo(() => {
    const arr = new Uint8Array(fogCols * fogRows * 4);
    const t = new THREE.DataTexture(arr, fogCols, fogRows, THREE.RGBAFormat);
    t.minFilter = THREE.LinearFilter;
    t.magFilter = THREE.LinearFilter;
    t.flipY = true;
    t.needsUpdate = true;
    return { data: arr, tex: t };
  }, [fogCols, fogRows]);

  useEffect(() => () => tex.dispose(), [tex]);

  useEffect(() => {
    const prev = prevFogRef.current;
    if (prev && prev.length === fog.length && prev.every((v, i) => v === fog[i])) {
      return;
    }
    prevFogRef.current = fog;
    for (let row = 0; row < fogRows; row++) {
      for (let col = 0; col < fogCols; col++) {
        const state = fog[fogIndex(col, row)] ?? 0;
        const idx = (row * fogCols + col) * 4;
        data[idx] = 20;
        data[idx + 1] = 15;
        data[idx + 2] = 10;
        data[idx + 3] = state === 2 ? 0 : state === 0 ? 216 : 86;
      }
    }
    tex.needsUpdate = true;
  }, [fog, data, tex, fogCols, fogRows]);

  const fogGeom = useMemo(() => {
    const geom = new THREE.PlaneGeometry(width, depth, 48, 36);
    geom.rotateX(-Math.PI / 2);
    const pos = geom.attributes.position as THREE.BufferAttribute;
    for (let i = 0; i < pos.count; i++) {
      const vx = pos.getX(i);
      const vz = pos.getZ(i);
      pos.setY(i, getTerrainHeight(vx, vz) + 0.16);
    }
    geom.computeVertexNormals();
    return geom;
  }, [width, depth]);

  return (
    <mesh geometry={fogGeom} position={[0, 0, 0]} renderOrder={1}>
      <meshBasicMaterial map={tex} transparent depthWrite={false} />
    </mesh>
  );
}

function ProceduralValleyTerrain({
  buildings,
  territories,
  onPointerDown,
  onPointerMove,
  onPointerUp,
  onRightClickGround,
}: {
  buildings: BuildingState[];
  territories: Game['territories'];
  onPointerDown: (e: ThreeEvent<PointerEvent>) => void;
  onPointerMove: (e: ThreeEvent<PointerEvent>) => void;
  onPointerUp: (e: ThreeEvent<PointerEvent>) => void;
  onRightClickGround: (x: number, z: number) => void;
}) {
  const { width, depth, halfW, halfD } = WORLD_DIMENSIONS;
  const { canvas, ctx, tex } = useMemo(() => {
    const c = document.createElement('canvas');
    c.width = 960;
    c.height = 720;
    const cx = c.getContext('2d')!;
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    return { canvas: c, ctx: cx, tex: t };
  }, []);

  useEffect(() => () => tex.dispose(), [tex]);

  const toPxX = (x: number) => ((x + halfW) / width) * canvas.width;
  const toPxY = (z: number) => ((z + halfD) / depth) * canvas.height;

  const builtCount = buildings.filter(b => b.built).length;
  const terrCount = territories.length;

  useEffect(() => {
    const grad = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
    grad.addColorStop(0, '#8d7554');
    grad.addColorStop(0.45, '#a88757');
    grad.addColorStop(1, '#798b49');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    for (let i = 0; i < 420; i++) {
      const rx = ((i * 73) % 940) + 10;
      const ry = ((i * 137) % 700) + 10;
      const rad = 14 + (i % 26);
      ctx.fillStyle =
        i % 3 === 0
          ? 'rgba(105, 132, 62, 0.18)'
          : i % 3 === 1
            ? 'rgba(210, 178, 124, 0.16)'
            : 'rgba(122, 98, 68, 0.14)';
      ctx.beginPath();
      ctx.arc(rx, ry, rad, 0, Math.PI * 2);
      ctx.fill();
    }

    const ridgeGrad = ctx.createLinearGradient(0, 0, 0, toPxY(-3.2));
    ridgeGrad.addColorStop(0, '#786855');
    ridgeGrad.addColorStop(0.8, '#968267');
    ridgeGrad.addColorStop(1, 'rgba(150, 130, 103, 0)');
    ctx.fillStyle = ridgeGrad;
    ctx.fillRect(0, 0, canvas.width, toPxY(-3.2));

    const pastGrad = ctx.createRadialGradient(toPxX(9.2), toPxY(6.5), 20, toPxX(9.2), toPxY(6.5), 185);
    pastGrad.addColorStop(0, 'rgba(98, 138, 52, 0.78)');
    pastGrad.addColorStop(1, 'rgba(98, 138, 52, 0)');
    ctx.fillStyle = pastGrad;
    ctx.beginPath();
    ctx.arc(toPxX(9.2), toPxY(6.5), 185, 0, Math.PI * 2);
    ctx.fill();

    const oasisGrad = ctx.createRadialGradient(toPxX(-14.2), toPxY(0.4), 20, toPxX(-14.2), toPxY(0.4), 145);
    oasisGrad.addColorStop(0, 'rgba(78, 124, 54, 0.85)');
    oasisGrad.addColorStop(1, 'rgba(78, 124, 54, 0)');
    ctx.fillStyle = oasisGrad;
    ctx.beginPath();
    ctx.arc(toPxX(-14.2), toPxY(0.4), 145, 0, Math.PI * 2);
    ctx.fill();

    for (const [wx, wz, wr] of [
      [-14.8, 2.2, 42],
      [-12.0, -1.8, 34],
    ]) {
      ctx.fillStyle = '#d6c19a';
      ctx.beginPath();
      ctx.arc(toPxX(wx), toPxY(wz), wr + 6, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#257ca3';
      ctx.beginPath();
      ctx.arc(toPxX(wx), toPxY(wz), wr, 0, Math.PI * 2);
      ctx.fill();
    }

    const main = buildings.find(b => b.kind === 'mainTent') ?? { x: -6.5, z: 3.5 };
    ctx.strokeStyle = 'rgba(204, 169, 114, 0.85)';
    ctx.lineCap = 'round';
    ctx.lineWidth = 22;
    for (const b of buildings) {
      if (!b.built || (b.x === main.x && b.z === main.z)) continue;
      ctx.beginPath();
      ctx.moveTo(toPxX(main.x), toPxY(main.z));
      ctx.lineTo(toPxX(b.x), toPxY(b.z));
      ctx.stroke();
    }

    ctx.strokeStyle = 'rgba(251, 191, 36, 0.55)';
    ctx.lineWidth = 3;
    ctx.setLineDash([10, 7]);
    for (const t of territories) {
      ctx.beginPath();
      ctx.arc(toPxX(t.x), toPxY(t.z), (t.radius / width) * canvas.width, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.setLineDash([]);

    tex.needsUpdate = true;
  }, [builtCount, terrCount, buildings, territories, canvas, ctx, tex, width, depth, halfW, halfD]);

  const terrainGeom = useMemo(() => {
    const segX = 64;
    const segZ = 48;
    const geom = new THREE.PlaneGeometry(width, depth, segX, segZ);
    geom.rotateX(-Math.PI / 2);
    const pos = geom.attributes.position as THREE.BufferAttribute;
    for (let i = 0; i < pos.count; i++) {
      const vx = pos.getX(i);
      const vz = pos.getZ(i);
      pos.setY(i, getTerrainHeight(vx, vz));
    }
    geom.computeVertexNormals();
    return geom;
  }, [width, depth]);

  return (
    <group>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.4, 0]} receiveShadow>
        <planeGeometry args={[width + 32, depth + 24]} />
        <meshStandardMaterial color="#8c6f48" roughness={0.96} />
      </mesh>
      <mesh
        geometry={terrainGeom}
        position={[0, 0, 0]}
        receiveShadow
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onContextMenu={e => {
          e.stopPropagation();
          e.nativeEvent.preventDefault();
          onRightClickGround(Math.round(e.point.x * 2) / 2, Math.round(e.point.z * 2) / 2);
        }}
      >
        <meshStandardMaterial map={tex} roughness={0.92} />
      </mesh>
    </group>
  );
}

function PlacementGhost3D({
  kind,
  x,
  z,
  valid,
}: {
  kind: BuildingKind;
  x: number;
  z: number;
  valid: boolean;
}) {
  const color = valid ? '#22c55e' : '#ef4444';
  const dummyBldg: BuildingState = {
    id: 'ghost',
    kind,
    nameZh: '',
    nameEn: '',
    x,
    z,
    hp: 100,
    maxHp: 100,
    started: true,
    built: true,
    progress: 1,
    visionRadius: 6,
    attackCd: 0,
  };
  const gy = getTerrainHeight(x, z);
  return (
    <group position={[x, gy + 0.03, z]}>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.01, 0]}>
        <ringGeometry args={[1.35, 1.58, 32]} />
        <meshBasicMaterial color={color} transparent opacity={0.9} side={THREE.DoubleSide} />
      </mesh>
      <BuildingModel3D b={dummyBldg} food={100} water={100} wood={100} stone={100} />
    </group>
  );
}

function BuildingNode3D({
  b,
  game,
  supervised,
  hasBrazierPerk,
  onSelectBuilding,
  onRightClickBuilding,
}: {
  b: BuildingState;
  game: Game;
  supervised: boolean;
  hasBrazierPerk: boolean;
  onSelectBuilding: (b: BuildingState) => void;
  onRightClickBuilding: (b: BuildingState) => void;
}) {
  const bp = getBlueprint(b.kind);
  const gy = getTerrainHeight(b.x, b.z);
  return (
    <group
      position={[b.x, gy, b.z]}
      onClick={e => {
        e.stopPropagation();
        onSelectBuilding(b);
      }}
      onContextMenu={e => {
        e.stopPropagation();
        e.nativeEvent.preventDefault();
        onRightClickBuilding(b);
      }}
    >
      {supervised && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.015, 0]}>
          <ringGeometry args={[1.65, 1.85, 32]} />
          <meshBasicMaterial color="#fde047" transparent opacity={0.85} depthWrite={false} side={THREE.DoubleSide} />
        </mesh>
      )}
      {b.kind === 'watchtower' && b.built && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.012, 0]}>
          <ringGeometry
            args={[
              (bp.attackRange ?? 8.5) + (hasBrazierPerk ? 2.5 : 0) - 0.1,
              (bp.attackRange ?? 8.5) + (hasBrazierPerk ? 2.5 : 0),
              40,
            ]}
          />
          <meshBasicMaterial color="#fbbf24" transparent opacity={0.22} depthWrite={false} side={THREE.DoubleSide} />
        </mesh>
      )}
      <BuildingModel3D b={b} food={game.food} water={game.water} wood={game.wood} stone={game.stone} />
      {!b.built && <WorldProgressBar progress={b.progress} y={2.45} color="#f59e0b" width={1.35} />}
    </group>
  );
}

function ResourceNodeMesh({
  node,
  onClickResource,
}: {
  node: ResourceNode;
  onClickResource: (node: ResourceNode) => void;
}) {
  if (node.amount <= 0) return null;
  const color =
    node.kind === 'water'
      ? '#38bdf8'
      : node.kind === 'wood'
        ? '#65a30d'
        : node.kind === 'stone'
          ? '#a8a29e'
          : '#eab308';
  const gy = getTerrainHeight(node.x, node.z);

  return (
    <group
      position={[node.x, gy, node.z]}
      onClick={e => {
        e.stopPropagation();
        onClickResource(node);
      }}
      onContextMenu={e => {
        e.stopPropagation();
        e.nativeEvent.preventDefault();
        onClickResource(node);
      }}
    >
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.015, 0]}>
        <ringGeometry args={[1.05, 1.22, 24]} />
        <meshBasicMaterial color={color} transparent opacity={0.62} depthWrite={false} side={THREE.DoubleSide} />
      </mesh>
      {node.kind === 'wood' &&
        [
          [0, 0],
          [-0.58, 0.42],
          [0.58, -0.35],
        ].map(([ox, oz], idx) => (
          <group key={idx} position={[ox, 0, oz]}>
            <mesh position={[0, 0.45, 0]} castShadow>
              <cylinderGeometry args={[0.09, 0.14, 0.9, 7]} />
              <meshStandardMaterial color="#5c3a21" roughness={0.95} />
            </mesh>
            <mesh position={[0, 1.08, 0]} castShadow>
              <dodecahedronGeometry args={[0.54, 1]} />
              <meshStandardMaterial color="#4d7c2b" roughness={0.86} />
            </mesh>
          </group>
        ))}
      {node.kind === 'stone' &&
        [
          [0, 0, 0.55],
          [-0.48, 0.34, 0.38],
          [0.46, -0.3, 0.42],
        ].map(([ox, oz, r], idx) => (
          <mesh key={idx} position={[ox, r * 0.6, oz]} castShadow receiveShadow>
            <dodecahedronGeometry args={[r, 0]} />
            <meshStandardMaterial color="#b8b0a4" roughness={0.92} />
          </mesh>
        ))}
      {node.kind === 'food' &&
        [
          [-0.42, 0.22],
          [0.36, -0.25],
          [0.12, 0.48],
        ].map(([ox, oz], idx) => (
          <group key={idx} position={[ox, 0, oz]}>
            <mesh position={[0, 0.22, 0]} castShadow>
              <sphereGeometry args={[0.22, 10, 8]} />
              <meshStandardMaterial color="#f5f0e6" roughness={0.9} />
            </mesh>
            <mesh position={[0.18, 0.28, 0]} castShadow>
              <sphereGeometry args={[0.1, 8, 8]} />
              <meshStandardMaterial color="#3d3126" roughness={0.85} />
            </mesh>
          </group>
        ))}
    </group>
  );
}

function BoundaryAndLandmarksMesh({
  posts,
  landmarks,
  onExpandPost,
  onInteractLandmark,
}: {
  posts: BoundaryPostState[];
  landmarks: NeutralLandmarkState[];
  onExpandPost: (p: BoundaryPostState) => void;
  onInteractLandmark: (l: NeutralLandmarkState) => void;
}) {
  return (
    <group>
      {posts.map(p => {
        const gy = getTerrainHeight(p.x, p.z);
        return (
          <group
            key={p.id}
            position={[p.x, gy, p.z]}
            onClick={e => {
              e.stopPropagation();
              onExpandPost(p);
            }}
            onContextMenu={e => {
              e.stopPropagation();
              e.nativeEvent.preventDefault();
              onExpandPost(p);
            }}
          >
            <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.015, 0]}>
              <ringGeometry args={[0.7, 0.88, 20]} />
              <meshBasicMaterial color={p.claimed ? '#22c55e' : '#fbbf24'} transparent opacity={0.8} depthWrite={false} side={THREE.DoubleSide} />
            </mesh>
            <mesh position={[0, 0.45, 0]} castShadow>
              <cylinderGeometry args={[0.14, 0.18, 0.9, 6]} />
              <meshStandardMaterial color={p.claimed ? '#eab308' : '#78716c'} roughness={0.85} />
            </mesh>
            {p.progress > 0 && !p.claimed && <WorldProgressBar progress={p.progress} y={1.15} color="#fbbf24" width={0.9} />}
          </group>
        );
      })}
      {landmarks.map(l => {
        const gy = getTerrainHeight(l.x, l.z);
        return (
          <group
            key={l.id}
            position={[l.x, gy, l.z]}
            onClick={e => {
              e.stopPropagation();
              onInteractLandmark(l);
            }}
            onContextMenu={e => {
              e.stopPropagation();
              e.nativeEvent.preventDefault();
              onInteractLandmark(l);
            }}
          >
            <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.015, 0]}>
              <ringGeometry args={[1.0, 1.2, 24]} />
              <meshBasicMaterial color={l.completed ? '#22c55e' : '#38bdf8'} transparent opacity={0.82} depthWrite={false} side={THREE.DoubleSide} />
            </mesh>
            <mesh position={[0, 0.35, 0]} castShadow>
              <cylinderGeometry args={[0.55, 0.65, 0.7, 10]} />
              <meshStandardMaterial color={l.completed ? '#0284c7' : '#78716c'} roughness={0.9} />
            </mesh>
            {l.progress > 0 && !l.completed && <WorldProgressBar progress={l.progress} y={1.2} color="#38bdf8" width={1.0} />}
          </group>
        );
      })}
    </group>
  );
}

function UnitNode3D({
  actor,
  selected,
  paused,
  onSelect,
}: {
  actor: Actor;
  selected: boolean;
  paused: boolean;
  onSelect: (e: ThreeEvent<MouseEvent>) => void;
}) {
  const gy = getTerrainHeight(actor.x, actor.z);
  return (
    <group
      position={[actor.x, gy, actor.z]}
      onClick={e => {
        e.stopPropagation();
        onSelect(e);
      }}
    >
      {selected && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.018, 0]}>
          <ringGeometry args={[0.46, 0.60, 28]} />
          <meshBasicMaterial color="#fde047" depthWrite={false} side={THREE.DoubleSide} />
        </mesh>
      )}
      {actor.hornBuffTicks > 0 && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.022, 0]}>
          <ringGeometry args={[0.64, 0.75, 24]} />
          <meshBasicMaterial color="#38bdf8" transparent opacity={0.78} depthWrite={false} side={THREE.DoubleSide} />
        </mesh>
      )}
      <UnitModel3D actor={actor} paused={paused} />
      <WorldProgressBar progress={actor.hp / actor.maxHp} y={1.85} color="#22c55e" width={0.78} />
      {actor.activity === 'working' && actor.workProgress > 0 && (
        <WorldProgressBar progress={actor.workProgress} y={2.02} color="#fbbf24" width={0.84} />
      )}
    </group>
  );
}

function EnemyNode3D({ enemy, onAttack }: { enemy: Enemy; onAttack: (e: Enemy) => void }) {
  if (enemy.hp <= 0) return null;
  const gy = getTerrainHeight(enemy.x, enemy.z);
  return (
    <group
      position={[enemy.x, gy, enemy.z]}
      onClick={e => {
        e.stopPropagation();
        onAttack(enemy);
      }}
      onContextMenu={e => {
        e.stopPropagation();
        e.nativeEvent.preventDefault();
        onAttack(enemy);
      }}
    >
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.015, 0]}>
        <ringGeometry args={[0.52, 0.68, 24]} />
        <meshBasicMaterial color={enemy.stunTicks > 0 ? '#38bdf8' : '#ef4444'} transparent opacity={0.8} depthWrite={false} side={THREE.DoubleSide} />
      </mesh>
      <EnemyModel3D enemy={enemy} />
      <WorldProgressBar progress={enemy.hp / enemy.maxHp} y={1.45} color="#ef4444" width={0.86} />
    </group>
  );
}

function FlockNode3D({
  flock,
  selected,
  paused,
  onSelectFlock,
}: {
  flock: FlockState;
  selected: boolean;
  paused: boolean;
  onSelectFlock: (id: string) => void;
}) {
  const gy = getTerrainHeight(flock.x, flock.z);
  return (
    <group
      position={[flock.x, gy, flock.z]}
      onClick={e => {
        e.stopPropagation();
        if (flock.owner === 'abram') onSelectFlock(flock.id);
      }}
    >
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, 0]}>
        <ringGeometry args={[1.15, 1.32, 28]} />
        <meshBasicMaterial
          color={selected ? '#fde047' : flock.owner === 'abram' ? '#60a5fa' : '#f59e0b'}
          transparent
          opacity={selected ? 0.95 : 0.45}
          depthWrite={false}
          side={THREE.DoubleSide}
        />
      </mesh>
      <FlockModel3D flock={flock} paused={paused} />
    </group>
  );
}

function CombatProjectilesAndEffects({
  projectiles,
  effects,
}: {
  projectiles: Projectile[];
  effects: VisualEffect[];
}) {
  return (
    <group>
      {projectiles.map(p => {
        const px = THREE.MathUtils.lerp(p.fromX, p.toX, p.progress);
        const pz = THREE.MathUtils.lerp(p.fromZ, p.toZ, p.progress);
        const startY = getTerrainHeight(p.fromX, p.fromZ) + 1.8;
        const targetY = getTerrainHeight(p.toX, p.toZ) + 0.6;
        const py = THREE.MathUtils.lerp(startY, targetY, p.progress) + Math.sin(p.progress * Math.PI) * 1.3;
        return (
          <mesh key={p.id} position={[px, py, pz]}>
            <sphereGeometry args={[0.14, 8, 8]} />
            <meshBasicMaterial color={p.color} />
          </mesh>
        );
      })}
      {effects.map(ef => {
        const alpha = ef.ttl / ef.maxTtl;
        const color =
          ef.kind === 'horn' ? '#fde047' : ef.kind === 'brace' ? '#38bdf8' : ef.kind === 'claim' ? '#22c55e' : '#f87171';
        const ey = getTerrainHeight(ef.x, ef.z) + 0.04;
        return (
          <mesh key={ef.id} rotation={[-Math.PI / 2, 0, 0]} position={[ef.x, ey, ef.z]}>
            <ringGeometry args={[ef.radius * (1 - alpha * 0.35), ef.radius, 36]} />
            <meshBasicMaterial color={color} transparent opacity={alpha * 0.78} depthWrite={false} side={THREE.DoubleSide} />
          </mesh>
        );
      })}
    </group>
  );
}

function WorldScene({
  game,
  selected,
  selectedFlockId,
  placementKind,
  onSelectUnit,
  onSelectFlock,
  onMoveOrder,
  onPlaceBuilding,
  onGather,
  onAttack,
  onSelectBuilding,
  onRightClickBuilding,
  onExpandPost,
  onInteractLandmark,
  panOffsetRef,
  userDraggedRef,
  onCameraMove,
}: {
  game: Game;
  selected: string[];
  selectedFlockId: string | null;
  placementKind: BuildingKind | null;
  onSelectUnit: (id: string, additive: boolean) => void;
  onSelectFlock: (id: string) => void;
  onMoveOrder: (x: number, z: number) => void;
  onPlaceBuilding: (kind: BuildingKind, x: number, z: number) => void;
  onGather: (node: ResourceNode) => void;
  onAttack: (enemy: Enemy) => void;
  onSelectBuilding: (b: BuildingState) => void;
  onRightClickBuilding: (b: BuildingState) => void;
  onExpandPost: (p: BoundaryPostState) => void;
  onInteractLandmark: (l: NeutralLandmarkState) => void;
  panOffsetRef: React.MutableRefObject<{ x: number; z: number }>;
  userDraggedRef: React.MutableRefObject<boolean>;
  onCameraMove?: (x: number, z: number) => void;
}) {
  const [hoverWorld, setHoverWorld] = useState<{ x: number; z: number }>({ x: -3.5, z: 2.0 });
  const pointerLast = useRef<{ x: number; y: number } | null>(null);
  const dragDist = useRef(0);

  const onPointerDown = (e: ThreeEvent<PointerEvent>) => {
    if (e.button === 2) return;
    pointerLast.current = { x: e.clientX, y: e.clientY };
    dragDist.current = 0;
  };

  const onPointerMove = (e: ThreeEvent<PointerEvent>) => {
    if (placementKind) {
      const gx = Math.round(e.point.x * 2) / 2;
      const gz = Math.round(e.point.z * 2) / 2;
      setHoverWorld(prev => (prev.x === gx && prev.z === gz ? prev : { x: gx, z: gz }));
    }
    if (!pointerLast.current) return;
    const dx = e.clientX - pointerLast.current.x;
    const dy = e.clientY - pointerLast.current.y;
    dragDist.current += Math.hypot(dx, dy);
    if (dragDist.current > 10) {
      userDraggedRef.current = true;
      const nx = THREE.MathUtils.clamp(
        panOffsetRef.current.x - dx * 0.025,
        -WORLD_DIMENSIONS.cameraClampX,
        WORLD_DIMENSIONS.cameraClampX
      );
      const nz = THREE.MathUtils.clamp(
        panOffsetRef.current.z - dy * 0.025,
        -WORLD_DIMENSIONS.cameraClampZ,
        WORLD_DIMENSIONS.cameraClampZ
      );
      panOffsetRef.current.x = nx;
      panOffsetRef.current.z = nz;
      onCameraMove?.(nx, nz);
    }
    pointerLast.current = { x: e.clientX, y: e.clientY };
  };

  const onPointerUp = (e: ThreeEvent<PointerEvent>) => {
    if (e.button === 2) return;
    const moved = dragDist.current;
    pointerLast.current = null;
    dragDist.current = 0;
    if (moved <= 10) {
      const gx = Math.round(e.point.x * 2) / 2;
      const gz = Math.round(e.point.z * 2) / 2;
      if (placementKind) {
        onPlaceBuilding(placementKind, gx, gz);
      } else {
        onMoveOrder(gx, gz);
      }
    }
  };

  const sarai = game.actors.find(a => a.id === 'sarai');
  const hasBrazierPerk = game.perks.includes('twinBrazier');
  const ghostValid = placementKind ? isValidPlacement(game, placementKind, hoverWorld.x, hoverWorld.z).valid : false;

  return (
    <>
      <color attach="background" args={['#755c3b']} />
      <hemisphereLight args={['#fff6e0', '#6e5233', 0.95]} />
      <directionalLight
        castShadow
        position={[14, 24, 12]}
        intensity={2.2}
        color="#fff4db"
        shadow-mapSize={[1024, 1024]}
        shadow-camera-left={-26}
        shadow-camera-right={26}
        shadow-camera-top={22}
        shadow-camera-bottom={-22}
      />
      <ProceduralValleyTerrain
        buildings={game.buildings}
        territories={game.territories}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onRightClickGround={onMoveOrder}
      />
      <BoundaryAndLandmarksMesh
        posts={game.boundaryPosts}
        landmarks={game.landmarks}
        onExpandPost={onExpandPost}
        onInteractLandmark={onInteractLandmark}
      />
      {game.resources.map(n => (
        <ResourceNodeMesh key={n.id} node={n} onClickResource={onGather} />
      ))}
      {game.buildings.map(b => (
        <BuildingNode3D
          key={b.id}
          b={b}
          game={game}
          supervised={sarai?.supervisingBuildingId === b.id}
          hasBrazierPerk={hasBrazierPerk}
          onSelectBuilding={onSelectBuilding}
          onRightClickBuilding={onRightClickBuilding}
        />
      ))}
      {placementKind && (
        <PlacementGhost3D kind={placementKind} x={hoverWorld.x} z={hoverWorld.z} valid={ghostValid} />
      )}
      {game.enemies.map(e =>
        isVisibleInFog(game.fog, e.x, e.z) ? (
          <EnemyNode3D key={e.id} enemy={e} onAttack={onAttack} />
        ) : null
      )}
      {(game.flocks ?? []).map(f =>
        isVisibleInFog(game.fog, f.x, f.z) ? (
          <FlockNode3D
            key={f.id}
            flock={f}
            selected={selectedFlockId === f.id}
            paused={game.paused}
            onSelectFlock={onSelectFlock}
          />
        ) : null
      )}
      {game.actors.map(a => (
        <UnitNode3D
          key={a.id}
          actor={a}
          selected={selected.includes(a.id)}
          paused={game.paused}
          onSelect={ev => onSelectUnit(a.id, ev.shiftKey)}
        />
      ))}
      <CombatProjectilesAndEffects projectiles={game.projectiles} effects={game.effects} />
      <SmoothFogOfWar fog={game.fog} />
    </>
  );
}

export default function World(props: {
  game: Game;
  selected: string[];
  selectedFlockId: string | null;
  placementKind: BuildingKind | null;
  onSelectUnit: (id: string, additive: boolean) => void;
  onSelectFlock: (id: string) => void;
  onMoveOrder: (x: number, z: number) => void;
  onPlaceBuilding: (kind: BuildingKind, x: number, z: number) => void;
  onGather: (node: ResourceNode) => void;
  onAttack: (enemy: Enemy) => void;
  onSelectBuilding: (b: BuildingState) => void;
  onRightClickBuilding: (b: BuildingState) => void;
  onExpandPost: (p: BoundaryPostState) => void;
  onInteractLandmark: (l: NeutralLandmarkState) => void;
  focusRequest: CameraFocusRequest;
  zoom?: number;
  onCameraMove?: (x: number, z: number) => void;
}) {
  const panOffsetRef = useRef<{ x: number; z: number }>({ x: -4.5, z: 2.0 });
  const userDraggedRef = useRef<boolean>(false);

  return (
    <Canvas
      shadows
      dpr={[1, 1.25]}
      camera={{ position: [-4.5, 15.2, 16.0], fov: 30 }}
      gl={{ antialias: true, powerPreference: 'high-performance' }}
    >
      <CameraRig
        selected={props.selected}
        actors={props.game.actors}
        panOffsetRef={panOffsetRef}
        focusRequest={props.focusRequest}
        userDraggedRef={userDraggedRef}
        zoom={props.zoom ?? 1}
        onCameraMove={props.onCameraMove}
      />
      <WorldScene {...props} panOffsetRef={panOffsetRef} userDraggedRef={userDraggedRef} />
    </Canvas>
  );
}
