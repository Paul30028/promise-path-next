import fs from 'node:fs/promises';
import path from 'node:path';
import * as T from 'three';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

// The exporter uses FileReader for its final Blob, even without image textures.
globalThis.FileReader ??= class FileReader {
  result = null;
  onloadend = null;
  onerror = null;
  readAsArrayBuffer(blob) { blob.arrayBuffer().then(value => { this.result = value; this.onloadend?.({ target: this }); }).catch(error => this.onerror?.(error)); }
  readAsDataURL(blob) { blob.arrayBuffer().then(value => { this.result = `data:${blob.type};base64,${Buffer.from(value).toString('base64')}`; this.onloadend?.({ target: this }); }).catch(error => this.onerror?.(error)); }
};

const out = path.resolve('public/models');
const mat = color => new T.MeshStandardMaterial({ color, roughness: .96, metalness: 0, side: T.DoubleSide });
const C = Object.fromEntries(Object.entries({ skin:'#D6A47C', skinDark:'#B9825D', eye:'#262B29', hair:'#3D3029', whiteHair:'#DAD1B8', linen:'#DFCFAC', linenLight:'#EEE0BF', sand:'#C5A879', leather:'#76543C', wood:'#74553A', rope:'#BDA67B', clay:'#AE7152', blue:'#405F7D', red:'#A45E56', brown:'#886645', green:'#73865B', teal:'#568482', copper:'#A8704B', violet:'#776884', foliage:'#78895C', foliage2:'#8B9B68', water:'#73A9A6', shadow:'#382E2A' }).map(([k,v])=>[k,mat(v)]));
function add(parent, geometry, material, name, pos=[0,0,0], scale=[1,1,1], rotation=[0,0,0]) { const m=new T.Mesh(geometry,material); m.name=name; m.position.set(...pos); m.scale.set(...scale); m.rotation.set(...rotation); m.castShadow=true; m.receiveShadow=true; parent.add(m); return m; }
function ball(parent, material, name, pos, scale, seg=12) { return add(parent,new T.SphereGeometry(1,seg,8),material,name,pos,scale); }
function cyl(parent, material, name, top,bottom,height,pos,seg=10,rotation=[0,0,0]) { return add(parent,new T.CylinderGeometry(top,bottom,height,seg),material,name,pos,[1,1,1],rotation); }
function rod(parent, material, name, a,b,r=.035) { const p1=new T.Vector3(...a),p2=new T.Vector3(...b),d=p2.clone().sub(p1); const m=cyl(parent,material,name,r,r,d.length(),p1.clone().add(p2).multiplyScalar(.5).toArray(),8); m.quaternion.setFromUnitVectors(new T.Vector3(0,1,0),d.normalize()); return m; }
function torus(parent,material,name,pos,r=.2,tube=.025,rotation=[Math.PI/2,0,0]) { return add(parent,new T.TorusGeometry(r,tube,6,20),material,name,pos,[1,1,1],rotation); }
function jar(parent, scale=1) { const g=new T.Group(); g.name='jar'; parent.add(g); g.scale.setScalar(scale); const pts=[[0,0],[.17,0],[.22,.07],[.25,.20],[.23,.37],[.15,.49],[.15,.57],[.19,.59]].map(([x,y])=>new T.Vector2(x,y)); add(g,new T.LatheGeometry(pts,16),C.clay,'clay_body'); torus(g,C.clay,'rim',[0,.59,0],.18,.025); torus(g,C.clay,'handle',[.22,.37,0],.13,.026,[0,Math.PI/2,0]); return g; }
function staff(parent, x=.33, height=1.52) { const points=[new T.Vector3(x,.07,.08),new T.Vector3(x+.02,.7,.07),new T.Vector3(x-.01,height-.10,.07),new T.Vector3(x-.10,height+.05,.06),new T.Vector3(x-.18,height-.03,.06)]; add(parent,new T.TubeGeometry(new T.CatmullRomCurve3(points),22,.027,6,false),C.wood,'curved_staff'); }
const profiles={
  abram:{ cloth:C.blue,trim:C.linenLight,hair:C.whiteHair,beard:true,wrap:true,staff:true,cloak:true },
  sarai:{ cloth:C.red,trim:C.linenLight,hair:C.hair,wrap:true,skirt:true,shawl:true },
  lot:{ cloth:C.brown,trim:C.linen,hair:C.hair,beard:true,wrap:true,wrapColor:C.brown,rope:true },
  eli:{ cloth:C.green,trim:C.linen,hair:C.hair,scout:true,pack:true },
  nura:{ cloth:C.teal,trim:C.linenLight,hair:C.hair,wrap:true,jar:true,skirt:true },
  asa:{ cloth:C.copper,trim:C.linen,hair:C.hair,beard:true,hammer:true },
  mara:{ cloth:C.violet,trim:C.linenLight,hair:C.whiteHair,wrap:true,wrapColor:C.violet,skirt:true,staff:true,elder:true },
};
function character(id,p) {
  const root=new T.Group(); root.name=id; root.userData={id,forward:'+Z',heightMeters:1.48};
  // Independent named pivots let the game animate limbs without a heavy rig.
  ball(root,p.cloth,'rounded_tunic',[0,.67,0],[.265,.36,.205],16);
  ball(root,p.cloth,'tunic_hem',[0,.43,0],[p.skirt?.34:.29,.18,.23],16);
  if(p.skirt) cyl(root,p.cloth,'skirt',.22,.34,.41,[0,.41,0],16);
  cyl(root,p.trim,'collar',.20,.19,.07,[0,.99,0],12);
  ball(root,C.skin,'head',[0,1.18,.025],[.28,.27,.245],18);
  ball(root,C.skin,'ear_left',[-.27,1.16,.02],[.045,.075,.04],10);ball(root,C.skin,'ear_right',[.27,1.16,.02],[.045,.075,.04],10);
  if(p.wrap){ const wrap=p.wrapColor??p.trim;ball(root,wrap,'headcloth',[0,1.38,-.025],[.29,.13,.245],16);torus(root,p.trim,'headband',[0,1.34,.015],.266,.025);ball(root,wrap,'hanging_cloth',[-.25,1.06,-.09],[.09,.25,.08]); }
  else ball(root,p.hair,'hair_cap',[0,1.37,-.02],[.25,.095,.21],16);
  if(p.elder) ball(root,C.whiteHair,'side_hair',[.20,1.15,-.03],[.08,.15,.09]);
  for(const sign of [-1,1]) {ball(root,C.skin,`cheek_${sign}`,[sign*.17,1.10,.224],[.075,.055,.030],10);ball(root,p.trim,`eye_white_${sign}`,[sign*.102,1.20,.245],[.048,.055,.018],12);ball(root,C.eye,`eye_${sign}`,[sign*.102,1.20,.263],[.025,.034,.014],10);ball(root,p.hair,`brow_${sign}`,[sign*.102,1.29,.239],[.065,.014,.018],10); }
  ball(root,C.skin,'nose',[0,1.12,.270],[.045,.055,.045],10);
  rod(root,p.hair,'mouth',[-.035,1.055,.272],[.035,1.055,.272],.007);
  if(p.beard){ ball(root,p.hair,'beard',[0,.995,.175],[.16,.115,.13],12); ball(root,p.hair,'moustache',[-.07,1.08,.247],[.07,.025,.026],8); ball(root,p.hair,'moustache_right',[.07,1.08,.247],[.07,.025,.026],8); }
  if(p.cloak||p.shawl){ ball(root,p.cloth,'back_cloak',[0,.71,-.18],[.31,.47,.08],12); ball(root,p.cloth,'shoulder_drape',[p.shawl?-.22:.20,.91,-.03],[.12,.28,.16],12); }
  cyl(root,C.leather,'belt',.25,.25,.055,[0,.54,0],12);
  for(const sign of [-1,1]){
    const arm=new T.Group(); arm.name=sign<0?'arm_left':'arm_right'; arm.position.set(sign*.28,.90,0); root.add(arm);
    ball(arm,p.cloth,'round_sleeve',[sign*.015,-.12,0],[.11,.15,.105],12);
    cyl(arm,C.skin,'forearm',.072,.073,.20,[sign*.025,-.32,.012],9,[0,0,sign*.10]);
    ball(arm,C.skin,'hand',[sign*.03,-.45,.03],[.08,.08,.07],10);
    const leg=new T.Group(); leg.name=sign<0?'leg_left':'leg_right'; leg.position.set(sign*.13,.37,0); root.add(leg);
    cyl(leg,p.trim,'legging',.075,.085,.28,[0,-.16,0],9);
    ball(leg,C.leather,'sandal',[0,-.31,.10],[.12,.055,.18],10);
  }
  if(p.staff) staff(root,p.elder?-.34:.37,p.elder?1.3:1.56);
  if(p.pack){ ball(root,C.leather,'backpack',[0,.75,-.28],[.21,.28,.13],10); torus(root,C.rope,'pack_roll',[0,1.01,-.27],.12,.045,[0,0,0]); }
  if(p.jar){ const j=jar(root,.52); j.position.set(.33,.27,.31); }
  if(p.rope) torus(root,C.rope,'shepherd_rope',[.27,.55,.20],.13,.028,[0,.2,.15]);
  if(p.hammer){ rod(root,C.wood,'hammer_handle',[.34,.24,.18],[.34,.76,.18],.026); add(root,new T.BoxGeometry(.28,.11,.12),C.wood,'hammer_head',[.34,.75,.18]); ball(root,C.leather,'tool_pouch',[-.27,.39,.13],[.12,.15,.075]); }
  if(p.scout) ball(root,C.leather,'map_pouch',[.25,.42,.13],[.11,.12,.06]);
  return root;
}
function tent(ready){const g=new T.Group();g.name=ready?'tent_ready':'tent_frame'; g.userData={footprint:[2.1,1.8],heightMeters:1.28}; const W=1.05,D=.9,H=1.22; for(const z of [-D,D]) rod(g,C.wood,'ridge_support',[0,0,z],[0,H,z],.045); rod(g,C.wood,'ridge',[0,H,-D],[0,H,D],.052); for(const x of [-W,W]) for(const z of [-D,D]){rod(g,C.wood,'stake',[x,0,z],[x,.09,z],.035);rod(g,C.rope,'guy_rope',[0,H,z],[x,.08,z],.012);} if(ready){ const geom=(verts)=>{const q=new T.BufferGeometry();q.setAttribute('position',new T.Float32BufferAttribute(verts,3));q.computeVertexNormals();return q;}; add(g,geom([-W,.05,-D,0,H,-D,-W,.05,D,0,H,-D,0,H,D,-W,.05,D]),C.brown,'left_cloth'); add(g,geom([W,.05,-D,0,H,-D,W,.05,D,0,H,-D,0,H,D,W,.05,D]),C.brown,'right_cloth'); add(g,geom([-W,.05,-D,0,H,-D,W,.05,-D]),C.sand,'back_cloth'); add(g,geom([-W,.05,D,0,H,D,-.23,.05,D]),C.sand,'door_left');add(g,geom([W,.05,D,0,H,D,.23,.05,D]),C.sand,'door_right'); cyl(g,C.rope,'ridge_trim',.035,.035,1.8,[0,H,.0],8,[Math.PI/2,0,0]); }return g;}
function logs(){const g=new T.Group();g.name='wood_bundle';for(let i=0;i<5;i++){const x=(i%3-.9)*.20,y=.11+Math.floor(i/3)*.19; cyl(g,C.wood,'timber',.10,.10,.95,[x,y,0],9,[Math.PI/2,0,0]);}for(const z of [-.30,.30])torus(g,C.rope,'binding',[0,.17,z],.30,.015,[0,0,0]);return g;}
function tree(){const g=new T.Group();g.name='olive_tree';cyl(g,C.wood,'trunk',.12,.18,1.05,[0,.52,0],10); for(const [x,z] of [[-.42,0],[.36,.2],[.1,-.4]]){rod(g,C.wood,'branch',[0,.95,0],[x,1.5,z],.065);ball(g,C.foliage,'leaf_cluster',[x,1.55,z],[.5,.36,.4],12);ball(g,C.foliage2,'leaf_highlight',[x+.08,1.72,z+.04],[.36,.20,.3],10);} return g;}
function sheep(){const g=new T.Group();g.name='sheep';ball(g,C.linenLight,'body',[0,.48,0],[.35,.28,.24],12);for(const x of [-.18,0,.18])for(const z of [-.14,.14])ball(g,C.linenLight,'wool',[x,.67,z],[.15,.14,.14],8);for(const x of [-.22,.22])for(const z of [-.14,.14])cyl(g,C.leather,'leg',.037,.04,.28,[x,.18,z],7);ball(g,C.skinDark,'face',[.37,.47,.04],[.14,.16,.13],10);ball(g,C.eye,'eye',[.49,.51,.1],[.016,.019,.014],8);return g;}
function spring(){const g=new T.Group();g.name='spring';add(g,new T.CylinderGeometry(.8,.83,.035,20),C.water,'water',[0,.02,0]);for(let i=0;i<10;i++){const a=i*Math.PI*2/10;ball(g,C.sand,'rim_stone',[Math.cos(a)*.85,.08,Math.sin(a)*.85],[.16,.09,.14],8);}return g;}
function batchByMaterial(group){
  for(const child of [...group.children])if(child.isGroup)batchByMaterial(child);
  const meshes=group.children.filter(child=>child.isMesh);
  const buckets=new Map();
  for(const mesh of meshes){mesh.updateMatrix();const geometry=mesh.geometry.clone();geometry.applyMatrix4(mesh.matrix);geometry.deleteAttribute('uv');const key=mesh.material.uuid;const bucket=buckets.get(key)??{material:mesh.material,geometries:[]};bucket.geometries.push(geometry);buckets.set(key,bucket);}
  for(const mesh of meshes)group.remove(mesh);
  let i=0;for(const {material,geometries} of buckets.values()){const joined=mergeGeometries(geometries,false);if(!joined)throw new Error(`Could not merge ${group.name}`);const mesh=new T.Mesh(joined,material);mesh.name=`batch_${group.name}_${i++}`;mesh.castShadow=true;mesh.receiveShadow=true;group.add(mesh);}
}
const characters=Object.fromEntries(Object.entries(profiles).map(([id,p])=>{const model=character(id,p);batchByMaterial(model);return [`character_${id}`,model];}));
const props={tent_ready:tent(true),tent_frame:tent(false),water_jar:jar(new T.Group()),wood_bundle:logs(),olive_tree:tree(),sheep:sheep(),spring:spring()};
for(const model of Object.values(props))batchByMaterial(model);
const models={...characters,...props};
// jar() returns a child of an unused Group; its local transform remains at origin.
const exporter=new GLTFExporter();await fs.mkdir(out,{recursive:true});
for(const [name,model] of Object.entries(models)){
  const data=await new Promise((resolve,reject)=>exporter.parse(model,resolve,reject,{binary:true,onlyVisible:true,includeCustomExtensions:false}));
  const file=path.join(out,`${name}.glb`);await fs.writeFile(file,Buffer.from(data));
  console.log(`${name}.glb ${Math.round(data.byteLength/1024)} KiB`);
}
