import fs from 'node:fs/promises';
import path from 'node:path';
const folder=path.resolve('public/models');
const files=(await fs.readdir(folder)).filter(name=>name.endsWith('.glb')).sort();
if(files.length!==14)throw new Error(`Expected 14 GLB assets, found ${files.length}`);
let total=0,estimatedCalls=0;
for(const file of files){
  const b=await fs.readFile(path.join(folder,file));
  if(b.toString('ascii',0,4)!=='glTF'||b.readUInt32LE(4)!==2||b.readUInt32LE(8)!==b.length)throw new Error(`Invalid GLB header: ${file}`);
  const jsonLength=b.readUInt32LE(12),jsonType=b.toString('ascii',16,20);
  if(jsonType!=='JSON')throw new Error(`Missing JSON chunk: ${file}`);
  const gltf=JSON.parse(b.toString('utf8',20,20+jsonLength));
  const triangles=(gltf.meshes??[]).flatMap(m=>m.primitives).reduce((n,p)=>n+Math.floor((gltf.accessors[p.indices??p.attributes.POSITION]?.count??0)/3),0);
  const draws=(gltf.meshes??[]).flatMap(m=>m.primitives).length;
  if(!triangles||!gltf.nodes?.length)throw new Error(`Missing geometry: ${file}`);
  if(file.startsWith('character_')&&triangles>6000)throw new Error(`Character triangle budget exceeded: ${file}: ${triangles}`);
  total+=b.length;
  estimatedCalls+=file==='water_jar.glb'?0:draws*(file==='olive_tree.glb'?2:file==='sheep.glb'?3:1);
  console.log(`${file.padEnd(24)} ${String(triangles).padStart(5)} tris  ${String(draws).padStart(2)} draws  ${Math.round(b.length/1024)} KiB`);
}
estimatedCalls+=17; // ground, ridge, 14 stones, selection ring
if(estimatedCalls>150)throw new Error(`Estimated scene draw-call budget exceeded: ${estimatedCalls}`);
console.log(`Total: ${files.length} assets, ${(total/1024/1024).toFixed(2)} MiB; estimated main-pass scene draws <= ${estimatedCalls} (shadow pass excluded)`);
