import { Canvas, ThreeEvent } from '@react-three/fiber';
import { useMemo } from 'react';
import * as THREE from 'three';
import type { Game } from './game';
import { targets } from './game';

function Person({ x, z, color, selected, onClick }: { x:number; z:number; color:string; selected:boolean; onClick:()=>void }) {
  return <group position={[x,0,z]} onClick={e => { e.stopPropagation(); onClick(); }}>
    {selected && <mesh rotation={[-Math.PI/2,0,0]} position={[0,.03,0]}><ringGeometry args={[.42,.53,32]}/><meshBasicMaterial color="#f6dc80" side={THREE.DoubleSide}/></mesh>}
    <mesh position={[0,.42,0]} castShadow><cylinderGeometry args={[.25,.31,.7,12]}/><meshStandardMaterial color={color} roughness={1}/></mesh>
    <mesh position={[0,.91,0]} castShadow><sphereGeometry args={[.28,16,12]}/><meshStandardMaterial color="#d5a477" roughness={1}/></mesh>
    <mesh position={[0,1.14,0]} castShadow><sphereGeometry args={[.3,16,8,0,Math.PI*2,0,Math.PI*.42]}/><meshStandardMaterial color="#5a4031" roughness={1}/></mesh>
    <mesh position={[-.08,.95,.255]}><sphereGeometry args={[.018,8,8]}/><meshBasicMaterial color="#272722"/></mesh><mesh position={[.08,.95,.255]}><sphereGeometry args={[.018,8,8]}/><meshBasicMaterial color="#272722"/></mesh>
  </group>;
}
function Tent({ x, z, ready }: { x:number; z:number; ready:boolean }) { return <group position={[x,0,z]}>
  <mesh position={[0,.52,0]} castShadow><coneGeometry args={[1.15,1.2,4]}/><meshStandardMaterial color={ready?'#c69b67':'#806e55'} roughness={1} transparent={!ready} opacity={ready?1:.4}/></mesh>
  <mesh position={[0,.04,0]} receiveShadow><cylinderGeometry args={[1.1,1.1,.08,4]}/><meshStandardMaterial color="#6f5a42"/></mesh>
  </group>; }
function WorldObjects({ game, selected, select, move }: { game:Game; selected:string[]; select:(id:string)=>void; move:(x:number,z:number)=>void }) {
  const stones = useMemo(() => Array.from({length:22},(_,i) => ({ x: Math.sin(i*12.6)*7.4, z: Math.cos(i*9.7)*5.8, s:.12+(i%4)*.06 })),[]);
  const groundClick = (e:ThreeEvent<MouseEvent>) => { e.stopPropagation(); move(Math.round(e.point.x*2)/2, Math.round(e.point.z*2)/2); };
  return <>
    <ambientLight intensity={1.2}/><directionalLight position={[-4,10,4]} intensity={2.2} castShadow shadow-mapSize-width={1024} shadow-mapSize-height={1024}/>
    <color attach="background" args={['#c8d8cf']}/>
    <mesh rotation={[-Math.PI/2,0,0]} receiveShadow onClick={groundClick}><planeGeometry args={[19,15]}/><meshStandardMaterial color="#d7bc8d" roughness={1}/></mesh>
    <mesh position={[-6,.015,2.2]} rotation={[-Math.PI/2,0,0]}><circleGeometry args={[1.7,32]}/><meshStandardMaterial color="#7eaaa3" roughness={.4}/></mesh>
    <mesh position={[6,.35,4]} castShadow><coneGeometry args={[2.3,.7,6]}/><meshStandardMaterial color="#ab9572" roughness={1}/></mesh>
    {stones.map((p,i)=><mesh key={i} position={[p.x,p.s*.35,p.z]} castShadow><dodecahedronGeometry args={[p.s]}/><meshStandardMaterial color={i%3?'#aaa18d':'#877d68'} roughness={1}/></mesh>)}
    {[[-7,-3],[-6,-4],[4,-5],[7,-4]].map(([x,z],i)=><group key={i} position={[x,0,z]}><mesh position={[0,.5,0]} castShadow><cylinderGeometry args={[.1,.16,1,8]}/><meshStandardMaterial color="#735636"/></mesh><mesh position={[0,1.2,0]} castShadow><sphereGeometry args={[.65,10,8]}/><meshStandardMaterial color="#758b5c" roughness={1}/></mesh></group>)}
    <Tent x={targets.tent.x} z={targets.tent.z} ready={game.tents>0}/><Tent x={-3} z={-3.5} ready/>
    <group position={[targets.wood.x,0,targets.wood.z]}>{[0,1,2].map(i=><mesh key={i} position={[i*.25,.15,i*.14]} rotation={[0,0,Math.PI/2]} castShadow><cylinderGeometry args={[.09,.09,1.1,8]}/><meshStandardMaterial color="#785936"/></mesh>)}</group>
    {game.actors.map(a=><Person key={a.id} x={a.x} z={a.z} color={a.color} selected={selected.includes(a.id)} onClick={()=>select(a.id)}/>)}
    {game.encounter==='active' && <mesh position={[targets.threat.x,.3,targets.threat.z]} castShadow><boxGeometry args={[.75,.45,.4]}/><meshStandardMaterial color="#5a5144"/></mesh>}
  </>;
}
export default function World(props: { game:Game; selected:string[]; select:(id:string)=>void; move:(x:number,z:number)=>void }) { return <Canvas shadows dpr={[1,1.5]} camera={{position:[11,14,14],fov:42}} gl={{antialias:true,powerPreference:'high-performance'}}><WorldObjects {...props}/></Canvas>; }
