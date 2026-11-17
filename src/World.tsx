import { Canvas, ThreeEvent, useFrame, useLoader, useThree } from '@react-three/fiber';
import { useEffect, useMemo, useRef } from 'react';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import * as THREE from 'three';
import type { Game } from './game';
import { targets } from './game';

const modelUrl = (name: string) => `/models/${name}.glb`;
function makeGroundTexture() {
  const size=128, pixels=new Uint8Array(size*size*4);
  let seed=1217;
  const random=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
  for(let i=0;i<size*size;i++){const shade=(random()-.5)*15;pixels[i*4]=Math.round(208+shade);pixels[i*4+1]=Math.round(183+shade);pixels[i*4+2]=Math.round(140+shade*.85);pixels[i*4+3]=255;}
  const texture=new THREE.DataTexture(pixels,size,size,THREE.RGBAFormat);
  texture.colorSpace=THREE.SRGBColorSpace;texture.wrapS=texture.wrapT=THREE.RepeatWrapping;texture.repeat.set(3,3);texture.magFilter=THREE.LinearFilter;texture.minFilter=THREE.LinearMipmapLinearFilter;texture.generateMipmaps=true;texture.needsUpdate=true;
  return texture;
}
function setModelShadows(scene:THREE.Object3D) { scene.traverse(child=>{if((child as THREE.Mesh).isMesh){child.castShadow=true;child.receiveShadow=true;}});return scene; }
function Grass() {
  const grass=useMemo(()=>{
    const mesh=new THREE.InstancedMesh(new THREE.ConeGeometry(.07,.09,4),new THREE.MeshStandardMaterial({color:'#ffffff',roughness:1,side:THREE.DoubleSide}),75);
    const dummy=new THREE.Object3D();let seed=443;
    const random=()=>{seed=(seed*1664525+1013904223)>>>0;return seed/4294967296;};
    for(let i=0;i<75;i++){let x=(random()-.5)*18,z=(random()-.5)*14;if(Math.abs(x)<2.2&&Math.abs(z)<2.4){x+=x<0?-2.4:2.4;}const scale=.55+random()*.9;dummy.position.set(x,.04*scale,z);dummy.rotation.y=random()*Math.PI*2;dummy.scale.set(scale,scale,scale);dummy.updateMatrix();mesh.setMatrixAt(i,dummy.matrix);mesh.setColorAt(i,new THREE.Color(i%3===0?'#b4ae76':'#8fa36b'));}mesh.instanceMatrix.needsUpdate=true;mesh.raycast=()=>{};return mesh;
  },[]);
  useEffect(()=>()=>{grass.geometry.dispose();(grass.material as THREE.Material).dispose();},[grass]);
  return <primitive object={grass}/>;
}
function CameraRig({game,selected}:{game:Game;selected:string[]}){
  const {camera,size}=useThree();
  useEffect(()=>{const c=camera as THREE.PerspectiveCamera;c.fov=size.width<600?29:38;c.updateProjectionMatrix();},[camera,size.width]);
  useFrame((_,delta)=>{const mobile=size.width<600;const actor=game.actors.find(a=>a.id===selected[0]);const x=mobile?(actor?.x??0):0,z=mobile?(actor?.z??0):0;const desired=new THREE.Vector3(x+8,11,z+11);camera.position.lerp(desired,Math.min(1,delta*5));camera.lookAt(x,0,z);});
  return null;
}
function Model({ name, position=[0,0,0], scale=1, rotation=0 }: { name:string; position?:[number,number,number]; scale?:number; rotation?:number }) {
  const gltf=useLoader(GLTFLoader,modelUrl(name));
  const scene=useMemo(()=>setModelShadows(gltf.scene.clone(true)),[gltf.scene]);
  return <primitive object={scene} position={position} scale={scale} rotation-y={rotation}/>;
}
function Person({ id, x, z, selected, moving, onClick }: { id:string; x:number; z:number; selected:boolean; moving:boolean; onClick:()=>void }) {
  const gltf=useLoader(GLTFLoader,modelUrl(`character_${id}`));
  const scene=useMemo(()=>setModelShadows(gltf.scene.clone(true)),[gltf.scene]);
  const root=useRef<THREE.Group>(null);
  useFrame(({clock})=>{
    if(!root.current)return;
    const phase=clock.elapsedTime*8+id.charCodeAt(0);
    root.current.position.y=moving?Math.sin(phase*2)*.018:0;
    const swing=moving?Math.sin(phase)*.30:0;
    const armL=scene.getObjectByName('arm_left'); const armR=scene.getObjectByName('arm_right');
    const legL=scene.getObjectByName('leg_left'); const legR=scene.getObjectByName('leg_right');
    if(armL)armL.rotation.x=swing;if(armR)armR.rotation.x=-swing;
    if(legL)legL.rotation.x=-swing;if(legR)legR.rotation.x=swing;
  });
  return <group position={[x,0,z]} onClick={e=>{e.stopPropagation();onClick();}}>
    {selected && <mesh rotation={[-Math.PI/2,0,0]} position={[0,.025,0]}><ringGeometry args={[.38,.46,32]}/><meshBasicMaterial color="#f7d773" side={THREE.DoubleSide}/></mesh>}
    <group ref={root}><primitive object={scene}/></group>
  </group>;
}
function WorldObjects({ game, selected, select, move }: { game:Game; selected:string[]; select:(id:string)=>void; move:(x:number,z:number)=>void }) {
  const stones=useMemo(()=>Array.from({length:14},(_,i)=>({x:Math.sin(i*12.6)*7.4,z:Math.cos(i*9.7)*5.8,s:.12+(i%4)*.06})),[]);
  const groundTexture=useMemo(makeGroundTexture,[]);
  useEffect(()=>()=>groundTexture.dispose(),[groundTexture]);
  const groundClick=(e:ThreeEvent<MouseEvent>)=>{e.stopPropagation();move(Math.round(e.point.x*2)/2,Math.round(e.point.z*2)/2);};
  return <>
    <ambientLight intensity={1.1}/><directionalLight position={[-4,10,4]} intensity={2.3} castShadow shadow-mapSize-width={1024} shadow-mapSize-height={1024} shadow-camera-left={-12} shadow-camera-right={12} shadow-camera-top={10} shadow-camera-bottom={-10} shadow-camera-near={.1} shadow-camera-far={35} shadow-bias={-.0003}/>
    <color attach="background" args={['#c8d8cf']}/>
    <mesh rotation={[-Math.PI/2,0,0]} receiveShadow onClick={groundClick}><planeGeometry args={[19,15]}/><meshStandardMaterial map={groundTexture} roughness={1}/></mesh>
    <Grass/>
    <mesh position={[6,.35,4]} castShadow><coneGeometry args={[2.3,.7,6]}/><meshStandardMaterial color="#ab9572" roughness={1}/></mesh>
    {stones.map((p,i)=><mesh key={i} position={[p.x,p.s*.35,p.z]} castShadow><dodecahedronGeometry args={[p.s]}/><meshStandardMaterial color={i%3?'#aaa18d':'#877d68'} roughness={1}/></mesh>)}
    <Model name="spring" position={[targets.spring.x,0,targets.spring.z]}/>
    <Model name="tent_ready" position={[-3,0,-3.5]}/>
    <Model name={game.tents>0?'tent_ready':'tent_frame'} position={[targets.tent.x,0,targets.tent.z]}/>
    <Model name="wood_bundle" position={[targets.wood.x,0,targets.wood.z]}/>
    {[[-7,-3],[4,-5]].map(([x,z],i)=><Model key={i} name="olive_tree" position={[x,0,z]} rotation={i*.8}/>)}
    {[[-4,-1],[-4.6,-.6],[-3.8,-.35]].map(([x,z],i)=><Model key={i} name="sheep" position={[x,0,z]} rotation={i*.6}/>)}
    {game.actors.map(a=><Person key={a.id} id={a.id} x={a.x} z={a.z} moving={a.queue.length>0&&!game.paused} selected={selected.includes(a.id)} onClick={()=>select(a.id)}/>)}
    {game.encounter==='active' && <mesh position={[targets.threat.x,.3,targets.threat.z]} castShadow><boxGeometry args={[.75,.45,.4]}/><meshStandardMaterial color="#5a5144"/></mesh>}
  </>;
}
export default function World(props:{game:Game;selected:string[];select:(id:string)=>void;move:(x:number,z:number)=>void}){
  return <Canvas shadows dpr={[1,1.5]} camera={{position:[8,11,11],fov:38}} gl={{antialias:true,powerPreference:'high-performance'}}><CameraRig game={props.game} selected={props.selected}/><WorldObjects {...props}/></Canvas>;
}
