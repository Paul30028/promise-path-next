import { useFrame } from '@react-three/fiber';
import { useMemo, useRef } from 'react';
import * as THREE from 'three';
import type { Actor, BuildingState, Enemy, FlockState } from './game';
import { createDrapedTentGeometry, getSharedMaterials } from './textures3d';

/**
 * 3.5-4.5 Head-Tall Light-Realistic Miniature 3D Articulated Unit Model (Zero 2D Slicing!)
 * Built with hierarchical 3D limbs (head, torso, Tunic skirt, left/right arms, left/right legs, role tools/weapons)
 * and real-time 3D procedural animation (walking stride, tool swinging, spear bracing, sling whirling, cargo hauling).
 */
export function UnitModel3D({
  actor,
  paused,
}: {
  actor: Actor;
  paused: boolean;
}) {
  const rootRef = useRef<THREE.Group>(null);
  const torsoRef = useRef<THREE.Group>(null);
  const leftLegRef = useRef<THREE.Group>(null);
  const rightLegRef = useRef<THREE.Group>(null);
  const leftArmRef = useRef<THREE.Group>(null);
  const rightArmRef = useRef<THREE.Group>(null);
  const slingLoopRef = useRef<THREE.Group>(null);

  const isMoving = !paused && (actor.activity === 'moving' || actor.activity === 'returning');
  const isWorking = !paused && actor.activity === 'working';
  const isFighting = !paused && actor.activity === 'fighting';

  useFrame(({ clock }) => {
    const t = clock.elapsedTime;
    const seed = actor.id.charCodeAt(0) * 1.17 + actor.id.length * 0.7;

    if (torsoRef.current) {
      if (isMoving) {
        torsoRef.current.position.y = 0.62 + Math.abs(Math.sin(t * 10 + seed)) * 0.05;
        torsoRef.current.rotation.x = 0.08;
      } else if (isWorking) {
        torsoRef.current.position.y = 0.62;
        torsoRef.current.rotation.x = 0.18 + Math.sin(t * 11 + seed) * 0.16;
      } else if (isFighting) {
        torsoRef.current.position.y = 0.60;
        torsoRef.current.rotation.x = 0.14;
      } else {
        torsoRef.current.position.y = 0.62 + Math.sin(t * 2.4 + seed) * 0.015;
        torsoRef.current.rotation.x = 0;
      }
    }

    // 3D Leg Walking Stride
    if (leftLegRef.current && rightLegRef.current) {
      if (isMoving) {
        const stride = Math.sin(t * 10 + seed) * 0.55;
        leftLegRef.current.rotation.x = stride;
        rightLegRef.current.rotation.x = -stride;
      } else if (isFighting && actor.role === 'spearman') {
        // Wide brace lunge stance
        leftLegRef.current.rotation.x = -0.35;
        rightLegRef.current.rotation.x = 0.35;
      } else {
        leftLegRef.current.rotation.x = 0;
        rightLegRef.current.rotation.x = 0;
      }
    }

    // 3D Arm & Weapon Articulation
    if (leftArmRef.current && rightArmRef.current) {
      if (actor.carrying) {
        // Both arms raised forward holding cargo
        leftArmRef.current.rotation.x = -0.85;
        rightArmRef.current.rotation.x = -0.85;
      } else if (isWorking) {
        // Rhythmic hammering / chopping / scooping
        leftArmRef.current.rotation.x = -0.35;
        rightArmRef.current.rotation.x = -0.75 + Math.sin(t * 11 + seed) * 0.75;
      } else if (isFighting) {
        if (actor.role === 'spearman') {
          // Spear thrust & brace
          leftArmRef.current.rotation.x = -0.55;
          rightArmRef.current.rotation.x = -0.65 + Math.sin(t * 13 + seed) * 0.45;
        } else if (actor.role === 'slinger') {
          leftArmRef.current.rotation.x = -0.3;
          rightArmRef.current.rotation.x = -2.4;
          if (slingLoopRef.current) {
            slingLoopRef.current.rotation.y = t * 18;
          }
        } else {
          leftArmRef.current.rotation.x = -0.45;
          rightArmRef.current.rotation.x = -0.7 + Math.sin(t * 12 + seed) * 0.65;
        }
      } else if (isMoving) {
        const armSwing = Math.sin(t * 10 + seed) * 0.42;
        leftArmRef.current.rotation.x = -armSwing;
        rightArmRef.current.rotation.x = armSwing;
      } else {
        leftArmRef.current.rotation.x = 0;
        rightArmRef.current.rotation.x = -0.15;
      }
    }
  });

  // Palette per role (4-head-tall miniature proportions: total height ~ 1.65u, head = 0.36u)
  const isFemale = actor.id === 'sarai' || actor.id === 'nura' || actor.id.startsWith('carrier-');
  const tunicColor =
    actor.id === 'abram'
      ? '#efe6d5'
      : actor.id === 'sarai'
        ? '#881337'
        : actor.id === 'lot'
          ? '#d97706'
          : actor.role === 'spearman'
            ? '#78472a'
            : actor.role === 'slinger'
              ? '#c2a878'
              : actor.role === 'engineer'
                ? '#92400e'
                : '#e5d7be';

  const sashColor =
    actor.id === 'lot'
      ? '#b45309'
      : actor.id === 'sarai' || actor.id === 'abram' || actor.role === 'spearman' || actor.role === 'scout'
        ? '#1d4ed8' // Tekhelet covenant blue
        : '#9a3412';

  // Rotate 3D unit to face movement direction cleanly
  const rotY = actor.facing >= 0 ? Math.PI * 0.22 : -Math.PI * 0.28;

  return (
    <group ref={rootRef} rotation={[0, rotY, 0]}>
      {/* Left & Right Legs + Sandals (y: 0..0.52) */}
      <group ref={leftLegRef} position={[-0.12, 0.48, 0]}>
        <mesh position={[0, -0.22, 0]} castShadow>
          <cylinderGeometry args={[0.075, 0.065, 0.44, 10]} />
          <meshStandardMaterial color="#c69065" roughness={0.8} />
        </mesh>
        <mesh position={[0, -0.44, 0.03]} castShadow>
          <boxGeometry args={[0.14, 0.07, 0.22]} />
          <meshStandardMaterial color="#4a2e18" roughness={0.9} />
        </mesh>
      </group>

      <group ref={rightLegRef} position={[0.12, 0.48, 0]}>
        <mesh position={[0, -0.22, 0]} castShadow>
          <cylinderGeometry args={[0.075, 0.065, 0.44, 10]} />
          <meshStandardMaterial color="#c69065" roughness={0.8} />
        </mesh>
        <mesh position={[0, -0.44, 0.03]} castShadow>
          <boxGeometry args={[0.14, 0.07, 0.22]} />
          <meshStandardMaterial color="#4a2e18" roughness={0.9} />
        </mesh>
      </group>

      {/* Upper Body & Tunic Skirt (pivots at hip y = 0.62) */}
      <group ref={torsoRef} position={[0, 0.62, 0]}>
        {/* Lower Linen Tunic / Kilt with Tekhelet border */}
        <mesh position={[0, -0.10, 0]} castShadow>
          <cylinderGeometry args={[0.20, 0.28, 0.42, 14]} />
          <meshStandardMaterial color="#ebe0c9" roughness={0.88} />
        </mesh>
        <mesh position={[0, -0.27, 0]} castShadow>
          <cylinderGeometry args={[0.265, 0.285, 0.07, 14]} />
          <meshStandardMaterial color={sashColor} roughness={0.8} />
        </mesh>

        {/* Torso / Cuirass */}
        <mesh position={[0, 0.26, 0]} castShadow>
          <cylinderGeometry args={[0.23, 0.19, 0.48, 14]} />
          <meshStandardMaterial color={tunicColor} roughness={0.82} />
        </mesh>

        {/* Tekhelet Blue / Crimson Diagonal Sash or Belt */}
        <mesh position={[0, 0.06, 0]} castShadow>
          <cylinderGeometry args={[0.205, 0.205, 0.10, 14]} />
          <meshStandardMaterial color={sashColor} roughness={0.75} />
        </mesh>

        {/* Head & Hair & Bronze Fillet (4-head-tall ratio: head center at +0.68 above hip = 1.30u total) */}
        <group position={[0, 0.68, 0]}>
          {/* Face / Skull */}
          <mesh castShadow>
            <sphereGeometry args={[0.18, 16, 14]} />
            <meshStandardMaterial color="#d49e73" roughness={0.75} />
          </mesh>
          {/* Eyes */}
          <mesh position={[-0.065, 0.03, 0.155]}>
            <sphereGeometry args={[0.024, 8, 8]} />
            <meshBasicMaterial color="#1c1917" />
          </mesh>
          <mesh position={[0.065, 0.03, 0.155]}>
            <sphereGeometry args={[0.024, 8, 8]} />
            <meshBasicMaterial color="#1c1917" />
          </mesh>

          {/* Hair / Beard / Headscarf */}
          {isFemale ? (
            // Draped Levantine Headveil / Shawl (NOT Arabic Keffiyeh+Agal)
            <mesh position={[0, 0.01, -0.03]} castShadow>
              <sphereGeometry args={[0.195, 14, 12]} />
              <meshStandardMaterial color={actor.id === 'sarai' ? '#1e3a8a' : '#d6c7ae'} roughness={0.85} />
            </mesh>
          ) : (
            <>
              {/* Wavy Dark Hair Cap */}
              <mesh position={[0, 0.05, -0.02]} castShadow>
                <sphereGeometry args={[0.186, 14, 10]} />
                <meshStandardMaterial color={actor.id === 'abram' ? '#78716c' : '#292018'} roughness={0.9} />
              </mesh>
              {/* Full Canaanite Beard */}
              {actor.role !== 'slinger' && (
                <mesh position={[0, -0.08, 0.08]} castShadow>
                  <sphereGeometry args={[0.135, 12, 10]} />
                  <meshStandardMaterial color={actor.id === 'abram' ? '#a8a29e' : '#292018'} roughness={0.92} />
                </mesh>
              )}
              {/* Ancient Judean Bronze Headband / Fillet */}
              <mesh position={[0, 0.08, 0]} rotation={[Math.PI / 2, 0, 0]}>
                <torusGeometry args={[0.175, 0.022, 8, 20]} />
                <meshStandardMaterial color="#d97706" metalness={0.6} roughness={0.35} />
              </mesh>
            </>
          )}
        </group>

        {/* Left Arm + Shield / Scroll */}
        <group ref={leftArmRef} position={[-0.27, 0.42, 0]}>
          <mesh position={[0, -0.18, 0]} castShadow>
            <cylinderGeometry args={[0.065, 0.055, 0.38, 10]} />
            <meshStandardMaterial color="#c69065" roughness={0.8} />
          </mesh>
          {/* Eliezer or Spearman Round Bronze Buckler Shield */}
          {(actor.role === 'scout' || actor.role === 'spearman') && (
            <mesh position={[-0.08, -0.22, 0.10]} rotation={[0, Math.PI / 2, 0]} castShadow>
              <cylinderGeometry args={[0.26, 0.26, 0.04, 18]} />
              <meshStandardMaterial color="#b45309" metalness={0.55} roughness={0.38} />
            </mesh>
          )}
          {/* Sarai's Administrative Papyrus Scroll */}
          {actor.id === 'sarai' && (
            <mesh position={[0.04, -0.32, 0.12]} rotation={[0, 0, Math.PI / 2]} castShadow>
              <cylinderGeometry args={[0.045, 0.045, 0.28, 10]} />
              <meshStandardMaterial color="#fde68a" roughness={0.7} />
            </mesh>
          )}
          {/* Ur's Surveying Boundary Stake */}
          {actor.role === 'engineer' && (
            <mesh position={[0, -0.15, 0.14]} castShadow>
              <cylinderGeometry args={[0.035, 0.025, 1.15, 8]} />
              <meshStandardMaterial color="#b45309" roughness={0.85} />
            </mesh>
          )}
        </group>

        {/* Right Arm + Role Weapon / Tool */}
        <group ref={rightArmRef} position={[0.27, 0.42, 0]}>
          <mesh position={[0, -0.18, 0]} castShadow>
            <cylinderGeometry args={[0.065, 0.055, 0.38, 10]} />
            <meshStandardMaterial color="#c69065" roughness={0.8} />
          </mesh>

          {/* Abram or Lot Shepherd Crook Staff */}
          {(actor.role === 'leader' || actor.role === 'herdsman') && (
            <group position={[0.04, -0.20, 0.14]}>
              <mesh position={[0, 0.15, 0]} castShadow>
                <cylinderGeometry args={[0.028, 0.028, 1.35, 8]} />
                <meshStandardMaterial color="#78350f" roughness={0.88} />
              </mesh>
              <mesh position={[0, 0.82, 0.06]} rotation={[0, Math.PI / 2, 0]} castShadow>
                <torusGeometry args={[0.08, 0.026, 8, 14, Math.PI * 1.3]} />
                <meshStandardMaterial color="#78350f" roughness={0.88} />
              </mesh>
            </group>
          )}

          {/* Spearman or Scout Long Bronze-Tipped Spear */}
          {(actor.role === 'spearman' || actor.role === 'scout') && (
            <group position={[0.04, -0.28, 0.22]} rotation={[Math.PI * 0.38, 0, 0]}>
              <mesh castShadow>
                <cylinderGeometry args={[0.026, 0.026, 1.65, 8]} />
                <meshStandardMaterial color="#713f12" roughness={0.88} />
              </mesh>
              <mesh position={[0, 0.92, 0]} castShadow>
                <coneGeometry args={[0.065, 0.26, 6]} />
                <meshStandardMaterial color="#f59e0b" metalness={0.65} roughness={0.3} />
              </mesh>
            </group>
          )}

          {/* Engineer Stone Mallet */}
          {actor.role === 'engineer' && (
            <group position={[0.04, -0.34, 0.14]} rotation={[Math.PI * 0.4, 0, 0]}>
              <mesh castShadow>
                <cylinderGeometry args={[0.025, 0.025, 0.48, 8]} />
                <meshStandardMaterial color="#78350f" roughness={0.9} />
              </mesh>
              <mesh position={[0, 0.24, 0]} castShadow>
                <boxGeometry args={[0.16, 0.14, 0.26]} />
                <meshStandardMaterial color="#a8a29e" roughness={0.85} />
              </mesh>
            </group>
          )}

          {/* Slinger Whirling Leather Sling */}
          {actor.role === 'slinger' && (
            <group ref={slingLoopRef} position={[0.04, -0.36, 0]}>
              <mesh position={[0, 0, 0.22]} rotation={[Math.PI / 2, 0, 0]}>
                <cylinderGeometry args={[0.014, 0.014, 0.44, 6]} />
                <meshStandardMaterial color="#78350f" />
              </mesh>
              <mesh position={[0, 0, 0.45]} castShadow>
                <sphereGeometry args={[0.075, 8, 8]} />
                <meshStandardMaterial color="#d6d3d1" roughness={0.8} />
              </mesh>
            </group>
          )}
        </group>

        {/* Carried 3D Resource Cargo in Front of Chest */}
        {actor.carrying && (
          <group position={[0, 0.18, 0.34]}>
            {actor.carrying.kind === 'water' && (
              <group>
                <mesh castShadow>
                  <cylinderGeometry args={[0.12, 0.16, 0.36, 12]} />
                  <meshStandardMaterial color="#b45309" roughness={0.7} />
                </mesh>
                <mesh position={[0, 0.19, 0]}>
                  <cylinderGeometry args={[0.09, 0.10, 0.04, 12]} />
                  <meshBasicMaterial color="#38bdf8" />
                </mesh>
              </group>
            )}
            {actor.carrying.kind === 'wood' && (
              <group rotation={[0, 0, Math.PI / 2]}>
                <mesh position={[0, 0, -0.05]} castShadow>
                  <cylinderGeometry args={[0.07, 0.07, 0.56, 8]} />
                  <meshStandardMaterial color="#713f12" roughness={0.9} />
                </mesh>
                <mesh position={[0, 0, 0.06]} castShadow>
                  <cylinderGeometry args={[0.065, 0.065, 0.54, 8]} />
                  <meshStandardMaterial color="#854d0e" roughness={0.9} />
                </mesh>
              </group>
            )}
            {actor.carrying.kind === 'stone' && (
              <mesh castShadow>
                <dodecahedronGeometry args={[0.19, 0]} />
                <meshStandardMaterial color="#d6d3d1" roughness={0.9} />
              </mesh>
            )}
            {actor.carrying.kind === 'food' && (
              <mesh castShadow>
                <sphereGeometry args={[0.18, 10, 10]} />
                <meshStandardMaterial color="#eab308" roughness={0.85} />
              </mesh>
            )}
          </group>
        )}
      </group>
    </group>
  );
}

/**
 * 3D Articulated Wolf / Raider Model (Zero 2D Slicing!)
 */
export function EnemyModel3D({ enemy }: { enemy: Enemy }) {
  const groupRef = useRef<THREE.Group>(null);
  const leg1 = useRef<THREE.Mesh>(null);
  const leg2 = useRef<THREE.Mesh>(null);

  useFrame(({ clock }) => {
    const t = clock.elapsedTime * 11 + enemy.homeX;
    if (leg1.current && leg2.current && enemy.stunTicks === 0) {
      leg1.current.rotation.x = Math.sin(t) * 0.4;
      leg2.current.rotation.x = -Math.sin(t) * 0.4;
    }
  });

  if (enemy.kind === 'raider') {
    const fakeActor: Actor = {
      id: enemy.id,
      name: enemy.nameZh,
      role: 'slinger',
      tags: enemy.tags,
      attackKind: 'ranged',
      color: '#dc2626',
      x: enemy.x,
      z: enemy.z,
      hp: enemy.hp,
      maxHp: enemy.maxHp,
      energy: 100,
      maxEnergy: 100,
      attack: enemy.attack,
      bonusVsBeast: 0,
      bonusVsInfantry: 0,
      meleeArmor: enemy.meleeArmor,
      rangedArmor: enemy.rangedArmor,
      attackRange: enemy.attackRange,
      speed: enemy.speed,
      visionRadius: 6,
      carryCapacity: 0,
      attackCd: enemy.attackCd,
      braceCd: 0,
      hornBuffTicks: 0,
      activity: 'fighting',
      workProgress: 0,
      workTicks: 0,
      carrying: null,
      facing: enemy.facing,
      queue: [],
    };
    return <UnitModel3D actor={fakeActor} paused={enemy.stunTicks > 0} />;
  }

  const s = enemy.kind === 'alphaWolf' ? 1.32 : 1.0;
  const fur = enemy.kind === 'alphaWolf' ? '#3f3b37' : '#6b655e';
  const rotY = enemy.facing >= 0 ? Math.PI * 0.5 : -Math.PI * 0.5;

  return (
    <group ref={groupRef} scale={s} rotation={[0, rotY, 0]}>
      {/* Wolf Torso */}
      <mesh position={[0, 0.42, 0]} rotation={[Math.PI / 2, 0, 0]} castShadow>
        <cylinderGeometry args={[0.18, 0.21, 0.78, 10]} />
        <meshStandardMaterial color={fur} roughness={0.92} />
      </mesh>
      {/* Wolf Head & Snout */}
      <group position={[0, 0.58, 0.44]}>
        <mesh castShadow>
          <sphereGeometry args={[0.17, 10, 10]} />
          <meshStandardMaterial color={fur} roughness={0.9} />
        </mesh>
        <mesh position={[0, -0.03, 0.16]} rotation={[Math.PI / 2, 0, 0]} castShadow>
          <coneGeometry args={[0.09, 0.24, 8]} />
          <meshStandardMaterial color="#292524" roughness={0.9} />
        </mesh>
        {/* Glowing predator eyes */}
        <mesh position={[-0.07, 0.04, 0.13]}>
          <sphereGeometry args={[0.025, 6, 6]} />
          <meshBasicMaterial color="#ef4444" />
        </mesh>
        <mesh position={[0.07, 0.04, 0.13]}>
          <sphereGeometry args={[0.025, 6, 6]} />
          <meshBasicMaterial color="#ef4444" />
        </mesh>
      </group>
      {/* Tail */}
      <mesh position={[0, 0.46, -0.45]} rotation={[-0.6, 0, 0]} castShadow>
        <coneGeometry args={[0.07, 0.36, 7]} />
        <meshStandardMaterial color={fur} roughness={0.92} />
      </mesh>
      {/* Legs */}
      <mesh ref={leg1} position={[-0.12, 0.2, 0.24]} castShadow>
        <cylinderGeometry args={[0.045, 0.035, 0.4, 8]} />
        <meshStandardMaterial color={fur} roughness={0.9} />
      </mesh>
      <mesh ref={leg2} position={[0.12, 0.2, 0.24]} castShadow>
        <cylinderGeometry args={[0.045, 0.035, 0.4, 8]} />
        <meshStandardMaterial color={fur} roughness={0.9} />
      </mesh>
      <mesh position={[-0.12, 0.2, -0.24]} castShadow>
        <cylinderGeometry args={[0.045, 0.035, 0.4, 8]} />
        <meshStandardMaterial color={fur} roughness={0.9} />
      </mesh>
      <mesh position={[0.12, 0.2, -0.24]} castShadow>
        <cylinderGeometry args={[0.045, 0.035, 0.4, 8]} />
        <meshStandardMaterial color={fur} roughness={0.9} />
      </mesh>
    </group>
  );
}

/**
 * 3D Living Pastoral Sheep Flock Model (Animated grazing wool sheep + owner banner stake)
 */
export function FlockModel3D({ flock, paused }: { flock: FlockState; paused: boolean }) {
  const groupRef = useRef<THREE.Group>(null);
  useFrame(({ clock }) => {
    if (!groupRef.current || paused) return;
    const t = clock.elapsedTime;
    groupRef.current.children.forEach((child, idx) => {
      if (idx === 0) return; // skip banner stake
      child.position.y = Math.abs(Math.sin(t * 2.2 + idx * 1.1)) * 0.04;
    });
  });

  const count = Math.min(8, Math.max(2, Math.ceil(flock.sheepCount / 1.5)));
  const woolColor = flock.owner === 'abram' ? '#f5efe2' : '#e7dcc8';
  const bannerColor = flock.owner === 'abram' ? '#1d4ed8' : '#b45309';

  return (
    <group ref={groupRef}>
      {/* Shepherd Clan Marker Stake */}
      <group position={[0, 0, 0]}>
        <mesh position={[0, 0.52, 0]} castShadow>
          <cylinderGeometry args={[0.03, 0.04, 1.05, 6]} />
          <meshStandardMaterial color="#6e4323" roughness={0.9} />
        </mesh>
        <mesh position={[0.16, 0.88, 0]} castShadow>
          <boxGeometry args={[0.28, 0.18, 0.03]} />
          <meshStandardMaterial color={bannerColor} roughness={0.8} />
        </mesh>
      </group>
      {Array.from({ length: count }).map((_, i) => {
        const ang = (i / count) * Math.PI * 2;
        const rad = 0.68 + (i % 2) * 0.34;
        const sx = Math.cos(ang) * rad;
        const sz = Math.sin(ang) * rad;
        return (
          <group key={i} position={[sx, 0, sz]} rotation={[0, -ang + Math.PI / 2, 0]}>
            <mesh position={[0, 0.24, 0]} castShadow>
              <sphereGeometry args={[0.21, 10, 8]} />
              <meshStandardMaterial color={woolColor} roughness={0.95} />
            </mesh>
            <mesh position={[0, 0.26, 0.18]}>
              <sphereGeometry args={[0.09, 8, 8]} />
              <meshStandardMaterial color="#3f342a" roughness={0.9} />
            </mesh>
            {[
              [-0.09, 0.1, 0.09],
              [0.09, 0.1, 0.09],
              [-0.09, 0.1, -0.09],
              [0.09, 0.1, -0.09],
            ].map(([lx, ly, lz], j) => (
              <mesh key={j} position={[lx, ly, lz]}>
                <cylinderGeometry args={[0.025, 0.02, 0.2, 6]} />
                <meshStandardMaterial color="#292524" roughness={0.9} />
              </mesh>
            ))}
          </group>
        );
      })}
    </group>
  );
}

let cachedTentRoofs: { mainTentRoof: THREE.BufferGeometry; healTentRoof: THREE.BufferGeometry } | null = null;
function getTentRoofs() {
  if (!cachedTentRoofs) {
    cachedTentRoofs = {
      mainTentRoof: createDrapedTentGeometry(3.4, 2.5, 2.38, 1.48),
      healTentRoof: createDrapedTentGeometry(2.3, 2.0, 2.15, 1.42),
    };
  }
  return cachedTentRoofs;
}

/**
 * True 3D Multi-Stage Ancient Hebrew Architectural Models (Zero 2D Slicing!)
 * Supports smooth stage-by-stage construction scaffolding (progress: 0..1) and real 3D cast shadows.
 */
export function BuildingModel3D({
  b,
  food,
  water,
  wood,
  stone,
}: {
  b: BuildingState;
  food: number;
  water: number;
  wood: number;
  stone: number;
}) {
  const flameRef = useRef<THREE.Mesh>(null);
  const mats = useMemo(() => getSharedMaterials(), []);
  const { mainTentRoof, healTentRoof } = useMemo(() => getTentRoofs(), []);

  useFrame(({ clock }) => {
    if (flameRef.current) {
      const s = 1 + Math.sin(clock.elapsedTime * 8) * 0.16;
      flameRef.current.scale.set(s, 1 + Math.cos(clock.elapsedTime * 7) * 0.22, s);
    }
  });

  const prog = b.built ? 1 : Math.max(0.2, b.progress);

  // 1. Main Patriarch Tent (Town Center: dry-stone courtyard + 6 timber posts + draped goat-hair pavilion + Tekhelet banners + hearth)
  if (b.kind === 'mainTent') {
    return (
      <group>
        {/* Stone foundation courtyard plinth */}
        <mesh position={[0, 0.08, 0]} receiveShadow castShadow material={mats.limestone}>
          <cylinderGeometry args={[2.1, 2.25, 0.16, 16]} />
        </mesh>
        {/* Low dry-stone courtyard perimeter wall */}
        {[
          [-1.55, 0.22, 0, 0.24, 0.34, 2.5],
          [1.55, 0.22, 0, 0.24, 0.34, 2.5],
          [0, 0.22, -1.45, 3.1, 0.34, 0.24],
        ].map(([x, y, z, w, h, d], idx) => (
          <mesh key={idx} position={[x, y, z]} castShadow receiveShadow material={mats.limestone}>
            <boxGeometry args={[w, h, d]} />
          </mesh>
        ))}
        {/* 6 Cedar Timber Posts */}
        {[
          [-1.25, -1.0],
          [0, -1.0],
          [1.25, -1.0],
          [-1.25, 0.55],
          [0, 0.55],
          [1.25, 0.55],
        ].map(([px, pz], idx) => (
          <mesh key={idx} position={[px, 0.85, pz]} castShadow material={mats.cedarWood}>
            <cylinderGeometry args={[0.08, 0.10, 1.55, 8]} />
          </mesh>
        ))}
        {/* Draped Dark Goat-Hair Pavilion Canopy */}
        <mesh position={[0, 0, -0.22]} geometry={mainTentRoof} material={mats.goatHairCloth} castShadow />
        {/* Tekhelet Blue Covenant Tapestry Front Banners */}
        <mesh position={[-0.95, 1.05, 0.58]} castShadow material={mats.tekheletTapestry}>
          <boxGeometry args={[0.52, 0.72, 0.04]} />
        </mesh>
        <mesh position={[0.95, 1.05, 0.58]} castShadow material={mats.tekheletTapestry}>
          <boxGeometry args={[0.52, 0.72, 0.04]} />
        </mesh>
        {/* Courtyard Stone Hearth & Live Fire */}
        <mesh position={[0, 0.2, 1.05]} castShadow>
          <cylinderGeometry args={[0.42, 0.48, 0.18, 12]} />
          <meshStandardMaterial color="#78716c" roughness={0.92} />
        </mesh>
        <mesh ref={flameRef} position={[0, 0.46, 1.05]}>
          <coneGeometry args={[0.24, 0.48, 8]} />
          <meshBasicMaterial color="#fb923c" />
        </mesh>
      </group>
    );
  }

  // 2. Twelve-Stone Covenant Altar (12 unhewn boulders + central wood offering fire + incense smoke)
  if (b.kind === 'altar') {
    return (
      <group>
        <mesh position={[0, 0.06, 0]} receiveShadow>
          <cylinderGeometry args={[1.55, 1.7, 0.12, 16]} />
          <meshStandardMaterial color="#9c886b" roughness={0.95} />
        </mesh>
        {/* Sacred Covenant Ring of Divine Favor */}
        <mesh position={[0, 0.08, 0]} rotation={[-Math.PI / 2, 0, 0]}>
          <ringGeometry args={[1.75, 1.95, 32]} />
          <meshBasicMaterial color="#fbbf24" transparent opacity={0.6} />
        </mesh>
        {Array.from({ length: 12 }).map((_, i) => {
          const ang = (i / 12) * Math.PI * 2;
          const rx = Math.cos(ang) * 1.15;
          const rz = Math.sin(ang) * 1.15;
          return (
            <mesh key={i} position={[rx, 0.34, rz]} rotation={[0.1 * (i % 3), ang, 0]} castShadow receiveShadow>
              <dodecahedronGeometry args={[0.32, 0]} />
              <meshStandardMaterial color="#bfb39f" roughness={0.92} />
            </mesh>
          );
        })}
        <mesh position={[0, 0.22, 0]} castShadow>
          <cylinderGeometry args={[0.48, 0.55, 0.24, 10]} />
          <meshStandardMaterial color="#5c3a21" roughness={0.9} />
        </mesh>
        <mesh ref={flameRef} position={[0, 0.62, 0]}>
          <coneGeometry args={[0.34, 0.72, 8]} />
          <meshBasicMaterial color="#f59e0b" />
        </mesh>
        {/* Sacred Incense Smoke Column */}
        <mesh position={[0, 1.18, 0]}>
          <cylinderGeometry args={[0.14, 0.28, 0.85, 8]} />
          <meshStandardMaterial color="#fef3c7" transparent opacity={0.35} roughness={1.0} />
        </mesh>
      </group>
    );
  }

  // 2b. Healing Sanctuary Tent (Herbal Balm & Rapid Medical Recovery)
  if (b.kind === 'healingTent') {
    return (
      <group scale={[1, prog, 1]}>
        {/* Limestone Foundation Platform */}
        <mesh position={[0, 0.08, 0]} receiveShadow castShadow material={mats.limestone}>
          <boxGeometry args={[2.3, 0.16, 2.0]} />
        </mesh>
        {/* Soothing green/amber restorative floor circle */}
        <mesh position={[0, 0.17, 0]} rotation={[-Math.PI / 2, 0, 0]}>
          <ringGeometry args={[0.3, 0.85, 24]} />
          <meshBasicMaterial color="#22c55e" transparent opacity={0.4} />
        </mesh>
        {/* 4 Cedar Corner Timber Posts */}
        {[
          [-0.95, -0.8],
          [0.95, -0.8],
          [-0.95, 0.8],
          [0.95, 0.8],
        ].map(([px, pz], idx) => (
          <mesh key={idx} position={[px, 0.82, pz]} castShadow material={mats.cedarWood}>
            <cylinderGeometry args={[0.07, 0.08, 1.48, 8]} />
          </mesh>
        ))}
        {/* Draped Cream & Olive Linen Healing Canopy */}
        <mesh position={[0, 0, 0]} geometry={healTentRoof} material={mats.healingCloth} castShadow />
        {/* Bronze Washing & Cleansing Basin on Stone Pedestal */}
        <group position={[-0.45, 0.22, 0.42]}>
          <mesh castShadow material={mats.limestone}>
            <cylinderGeometry args={[0.22, 0.26, 0.36, 12]} />
          </mesh>
          <mesh position={[0, 0.26, 0]} castShadow material={mats.bronze}>
            <cylinderGeometry args={[0.32, 0.22, 0.18, 14]} />
          </mesh>
          <mesh position={[0, 0.32, 0]} rotation={[-Math.PI / 2, 0, 0]}>
            <circleGeometry args={[0.26, 12]} />
            <meshBasicMaterial color="#38bdf8" />
          </mesh>
        </group>
        {/* Drying Herb Racks with Fragrant Myrrh & Hyssop Bundles */}
        <group position={[0.62, 0.55, 0.1]}>
          <mesh castShadow>
            <boxGeometry args={[0.1, 0.95, 0.82]} />
            <meshStandardMaterial color="#854d0e" roughness={0.9} />
          </mesh>
          {[-0.22, 0, 0.22].map((zPos, idx) => (
            <mesh key={idx} position={[0.08, 0.18 - idx * 0.2, zPos]} castShadow>
              <coneGeometry args={[0.09, 0.24, 6]} />
              <meshStandardMaterial color="#3f6212" roughness={0.85} />
            </mesh>
          ))}
        </group>
      </group>
    );
  }

  // 3. Cistern House / Olive Landmark (Woven A-frame tent + circular masonry stone water well + amphorae)
  if (b.kind === 'house' || b.kind === 'landmarkOlive') {
    const scale = b.kind === 'landmarkOlive' ? 1.25 : 1.0;
    return (
      <group scale={[scale, scale * prog, scale]}>
        {/* A-Frame Nomad Tent */}
        <mesh position={[0.25, 0.72, -0.35]} rotation={[0, Math.PI / 4, 0]} castShadow receiveShadow>
          <coneGeometry args={[1.25, 1.44, 4]} />
          <meshStandardMaterial color={b.kind === 'landmarkOlive' ? '#365314' : '#4a3728'} roughness={0.9} />
        </mesh>
        {/* Circular Stone Water Cistern / Well in front */}
        <group position={[-0.45, 0, 0.55]}>
          <mesh position={[0, 0.26, 0]} castShadow receiveShadow>
            <cylinderGeometry args={[0.68, 0.74, 0.52, 14]} />
            <meshStandardMaterial color="#b5a68f" roughness={0.92} />
          </mesh>
          <mesh position={[0, 0.53, 0]} rotation={[-Math.PI / 2, 0, 0]}>
            <circleGeometry args={[0.56, 16]} />
            <meshBasicMaterial color="#0284c7" />
          </mesh>
        </group>
        {/* Terracotta Amphorae */}
        <mesh position={[-0.95, 0.28, -0.05]} castShadow>
          <cylinderGeometry args={[0.14, 0.19, 0.48, 10]} />
          <meshStandardMaterial color="#b45309" roughness={0.75} />
        </mesh>
      </group>
    );
  }

  // 4. Supply Depot & Lumber Camp (Thatched timber shed + dynamic water jars, wood logs, stone blocks & food sacks)
  if (b.kind === 'depot') {
    const jarCount = Math.min(5, Math.max(1, Math.ceil(water / 35)));
    const logCount = Math.min(6, Math.max(1, Math.ceil(wood / 35)));
    const stoneCount = Math.min(4, Math.max(1, Math.ceil(stone / 30)));
    return (
      <group scale={[1, prog, 1]}>
        <mesh position={[0, 0.06, 0]} receiveShadow castShadow>
          <boxGeometry args={[2.5, 0.12, 1.9]} />
          <meshStandardMaterial color="#9c7e54" roughness={0.95} />
        </mesh>
        {/* 4 Shed Posts & Thatched Roof */}
        {[
          [-1.0, -0.7],
          [0.2, -0.7],
          [-1.0, 0.7],
          [0.2, 0.7],
        ].map(([px, pz], idx) => (
          <mesh key={idx} position={[px, 0.68, pz]} castShadow>
            <cylinderGeometry args={[0.07, 0.08, 1.25, 8]} />
            <meshStandardMaterial color="#6e4323" roughness={0.9} />
          </mesh>
        ))}
        <mesh position={[-0.4, 1.38, 0]} rotation={[0.12, 0, 0]} castShadow>
          <boxGeometry args={[1.55, 0.14, 1.75]} />
          <meshStandardMaterial color="#bfa065" roughness={0.92} />
        </mesh>
        {/* Terracotta Water Jars */}
        {Array.from({ length: jarCount }).map((_, i) => (
          <mesh key={`j-${i}`} position={[-0.85 + (i % 3) * 0.38, 0.32, -0.3 + Math.floor(i / 3) * 0.42]} castShadow>
            <cylinderGeometry args={[0.11, 0.14, 0.38, 10]} />
            <meshStandardMaterial color="#b45309" roughness={0.75} />
          </mesh>
        ))}
        {/* Stacked Acacia Logs */}
        {Array.from({ length: logCount }).map((_, i) => (
          <mesh
            key={`l-${i}`}
            position={[0.72, 0.22 + Math.floor(i / 2) * 0.16, -0.35 + (i % 2) * 0.24]}
            rotation={[0, 0, Math.PI / 2]}
            castShadow
          >
            <cylinderGeometry args={[0.085, 0.085, 0.82, 8]} />
            <meshStandardMaterial color="#5c361a" roughness={0.92} />
          </mesh>
        ))}
        {/* Cut Stone Blocks & Food Sacks */}
        {Array.from({ length: stoneCount }).map((_, i) => (
          <mesh key={`s-${i}`} position={[0.55 + (i % 2) * 0.34, 0.22, 0.48]} castShadow>
            <boxGeometry args={[0.28, 0.24, 0.28]} />
            <meshStandardMaterial color="#d6d3d1" roughness={0.9} />
          </mesh>
        ))}
        {food > 0 && (
          <mesh position={[-0.25, 0.24, 0.55]} castShadow>
            <sphereGeometry args={[0.2, 10, 8]} />
            <meshStandardMaterial color="#eab308" roughness={0.85} />
          </mesh>
        )}
      </group>
    );
  }

  // 5. Stone-Timber Watchtower (Battered limestone masonry base + 4 timber posts + crenellated deck + ladder + brazier)
  if (b.kind === 'watchtower') {
    return (
      <group>
        {/* Battered Limestone Base Plinth */}
        <mesh position={[0, 0.55 * prog, 0]} castShadow receiveShadow>
          <cylinderGeometry args={[0.82, 1.15, 1.1 * prog, 4]} />
          <meshStandardMaterial color="#b5a48b" roughness={0.94} />
        </mesh>
        {/* 4 Heavy Timber Corner Pillars */}
        {prog > 0.35 &&
          [
            [-0.48, -0.48],
            [0.48, -0.48],
            [-0.48, 0.48],
            [0.48, 0.48],
          ].map(([px, pz], idx) => (
            <mesh key={idx} position={[px, 1.1 + 0.55 * prog, pz]} castShadow>
              <cylinderGeometry args={[0.075, 0.085, 1.15 * prog, 8]} />
              <meshStandardMaterial color="#6e3f22" roughness={0.9} />
            </mesh>
          ))}
        {/* Elevated Watch Platform & Crenellated Parapet */}
        {prog > 0.65 && (
          <group position={[0, 2.15 * prog, 0]}>
            <mesh castShadow receiveShadow>
              <boxGeometry args={[1.32, 0.16, 1.32]} />
              <meshStandardMaterial color="#8a5a36" roughness={0.88} />
            </mesh>
            {[
              [0, 0.22, 0.6],
              [0, 0.22, -0.6],
              [0.6, 0.22, 0],
              [-0.6, 0.22, 0],
            ].map(([bx, by, bz], idx) => (
              <mesh
                key={idx}
                position={[bx, by, bz]}
                castShadow
              >
                <boxGeometry args={idx < 2 ? [1.32, 0.32, 0.1] : [0.1, 0.32, 1.32]} />
                <meshStandardMaterial color="#78472a" roughness={0.9} />
              </mesh>
            ))}
            {/* Tekhelet Blue Watch Banner */}
            <mesh position={[0.35, -0.35, 0.66]} castShadow>
              <boxGeometry args={[0.36, 0.58, 0.04]} />
              <meshStandardMaterial color="#1d4ed8" roughness={0.8} />
            </mesh>
          </group>
        )}
        {/* Signal Brazier & Live Fire when Built */}
        {b.built && (
          <group position={[0, 2.45, 0]}>
            <mesh castShadow>
              <cylinderGeometry args={[0.24, 0.16, 0.2, 10]} />
              <meshStandardMaterial color="#44403c" roughness={0.8} />
            </mesh>
            <mesh ref={flameRef} position={[0, 0.32, 0]}>
              <coneGeometry args={[0.2, 0.45, 8]} />
              <meshBasicMaterial color="#fb923c" />
            </mesh>
          </group>
        )}
      </group>
    );
  }

  // 6. House Guard Barracks / Military Landmark (War pavilion + spear rack + bronze shield rack + training dummy)
  return (
    <group scale={[b.kind === 'landmarkEncampment' ? 1.25 : 1, prog, b.kind === 'landmarkEncampment' ? 1.25 : 1]}>
      <mesh position={[0, 0.06, 0]} receiveShadow>
        <boxGeometry args={[2.6, 0.12, 2.0]} />
        <meshStandardMaterial color="#9e825a" roughness={0.95} />
      </mesh>
      <mesh position={[0, 0.92, -0.25]} rotation={[0, Math.PI / 4, 0]} castShadow receiveShadow>
        <coneGeometry args={[1.65, 1.55, 4]} />
        <meshStandardMaterial color={b.kind === 'landmarkEncampment' ? '#7c2d12' : '#443020'} roughness={0.9} />
      </mesh>
      {/* Bronze Shield Rack */}
      <group position={[0.85, 0.38, 0.55]}>
        {[0, 0.34].map((ox, i) => (
          <mesh key={i} position={[ox - 0.17, 0, 0]} rotation={[0.2, 0, 0]} castShadow>
            <cylinderGeometry args={[0.22, 0.22, 0.05, 14]} />
            <meshStandardMaterial color="#d97706" metalness={0.6} roughness={0.35} />
          </mesh>
        ))}
      </group>
      {/* Spear Rack */}
      <group position={[-0.85, 0.55, 0.55]}>
        {[-0.2, 0, 0.2].map((ox, i) => (
          <mesh key={i} position={[ox, 0, 0]} castShadow>
            <cylinderGeometry args={[0.025, 0.025, 1.1, 6]} />
            <meshStandardMaterial color="#78350f" />
          </mesh>
        ))}
      </group>
      {/* Straw Training Dummy */}
      <group position={[0, 0.45, 0.72]}>
        <mesh castShadow>
          <cylinderGeometry args={[0.14, 0.12, 0.65, 8]} />
          <meshStandardMaterial color="#eab308" roughness={0.9} />
        </mesh>
        <mesh position={[0, 0.42, 0]} castShadow>
          <sphereGeometry args={[0.13, 8, 8]} />
          <meshStandardMaterial color="#eab308" roughness={0.9} />
        </mesh>
      </group>
    </group>
  );
}
