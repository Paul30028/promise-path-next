"""Build a deterministic, textured Noah's ark diorama; Y is up, metres.
Run with C:/AI/3d-studio-venv/Scripts/python.exe.
"""
from pathlib import Path
import io
import numpy as np
from PIL import Image
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.visual.texture import TextureVisuals

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'godot-pilot/assets/models/BLD_NoahsArk.glb'
RNG = np.random.default_rng(61416)

def texture(pitch=False):
    y,x=np.mgrid[:512,:512]
    grain=(np.sin(y*.65+np.sin(x*.025)*2)+.5*np.sin(y*2.1+x*.018))
    noise=RNG.normal(0,2.4,(512,512))
    board=RNG.uniform(-10,10,16)[y//32]
    seams=np.where(y%32<2,-25,0)
    val=grain*4+noise+board+seams
    base=np.array([113,77,44] if not pitch else [42,31,24])
    rgb=np.clip(base+val[:,:,None]*(1 if not pitch else .35),0,255).astype('uint8')
    return Image.fromarray(rgb,'RGB')
wood=PBRMaterial(name='Weathered_Cypress',baseColorTexture=texture(),roughnessFactor=.88,metallicFactor=0)
pitch=PBRMaterial(name='Weathered_Bitumen',baseColorTexture=texture(True),roughnessFactor=.68,metallicFactor=0)
scene=trimesh.Scene(base_frame='NoahsArk')
stages=['Stage1_KeelRibs','Stage2_HullPlanks','Stage3_PitchRoofRamp']
parts={s:{'wood':[],'pitch':[]} for s in stages}
for s in stages: scene.graph.update(frame_to=s,frame_from='NoahsArk',matrix=np.eye(4))

def add(mesh,stage,mat='wood'):
    mesh.vertices[:,1] = np.maximum(mesh.vertices[:,1], 0.0)
    mesh.remove_unreferenced_vertices()
    assert np.all(mesh.area_faces>1e-10)
    if mesh.volume<0: mesh.invert()
    # Per-face UV vertices avoid wrapped interpolation and give every face clean normals.
    v=mesh.vertices[mesh.faces].reshape(-1,3)
    n=np.repeat(mesh.face_normals,3,axis=0)
    uv=np.empty((len(v),2))
    for i,normal in enumerate(mesh.face_normals):
        axes=[a for a in range(3) if a!=np.argmax(np.abs(normal))]
        # Grain follows long X members; vertical faces use their own local plane.
        uv[3*i:3*i+3]=v[3*i:3*i+3][:,axes]/np.array([3.2,1.25])
    m=trimesh.Trimesh(v,np.arange(len(v)).reshape(-1,3),process=False)
    m.vertex_normals=n
    m.visual=TextureVisuals(uv=uv,material=wood if mat=='wood' else pitch)
    parts[stage][mat].append(m)

def box(center,size,stage,mat='wood'):
    m=trimesh.creation.box(extents=size);m.apply_translation(center);add(m,stage,mat)

def beam(a,b,width,depth,stage,mat='wood'):
    a,b=np.array(a,float),np.array(b,float)
    m=trimesh.creation.box(extents=[width,depth,np.linalg.norm(b-a)])
    m.apply_transform(trimesh.geometry.align_vectors([0,0,1],b-a));m.apply_translation((a+b)/2)
    add(m,stage,mat)

def peg(center,stage):
    m=trimesh.creation.cylinder(radius=.047,height=.09,sections=8)
    m.apply_translation(center);add(m,stage)
S1,S2,S3=stages
# The broad, blunt barge has a round chine, without a pointed nautical prow.
profile=np.array([[0,.25],[.65,.38],[1.35,.72],[1.95,1.2],[2.32,1.85],[2.48,2.55],[2.5,3.35]]) # z,y
box([0,.14,0],[21.65,.28,.42],S1)
for x in np.linspace(-9.8,9.8,8):
    for z in [-.75,.75]:box([x,.12,z],[.66,.24,.65],S1)
for x in np.linspace(-10.55,10.55,15):
    for sign in [-1,1]:
        for (z0,y0),(z1,y1) in zip(profile[:-1],profile[1:]):
            beam([x,y0,sign*z0],[x,y1,sign*z1],.20,.23,S1)
        for y,z in [(1.2,1.95),(2.55,2.48),(3.28,2.5)]:peg([x,y,sign*(z+.13)],S1)
    for y,w in [(.86,2.9),(1.82,4.5),(2.8,4.9)]:box([x,y,0],[.19,.18,w],S1)
    for sign in [-1,1]:beam([x,.03,sign*2.38],[x,1.25,sign*1.95],.18,.18,S1)
# Hull courses are individually closed prisms with small shadow gaps.
def halfwidth(y):return np.interp(y,profile[:,1],profile[:,0])
for row in range(16):
    lo=.28+row*.19;hi=lo+.179
    za,zb=halfwidth(lo),halfwidth(hi)
    for sign in [-1,1]:
        for j in range(7):
            xa=-10.87+j*3.105;xb=min(xa+3.09,10.87)
            # Leave a true boarding aperture, with a sill at 1.15 m.
            intervals=[(xa,xb)]
            if sign==1 and lo<2.72 and hi>1.13:
                intervals=[(a,b) for a,b in [(xa,min(xb,-1.02)),(max(xa,1.02),xb)] if b-a>.015]
            for a,b in intervals:
                verts=[[a,lo,sign*za],[b,lo,sign*za],[b,hi,sign*zb],[a,hi,sign*zb]]
                verts+= [[v[0],v[1],v[2]-sign*.12] for v in verts]
                faces=[[0,1,2],[0,2,3],[4,6,5],[4,7,6],[0,4,5],[0,5,1],[1,5,6],[1,6,2],[2,6,7],[2,7,3],[3,7,4],[3,4,0]]
                m=trimesh.Trimesh(verts,faces,process=True);m.fix_normals();add(m,S2)
                if row<5:
                    # Thin coating outside the existing lower planks retains course relief.
                    q=m.copy();q.vertices[:,2]+=sign*.014;add(q,S3,'pitch')
    for x in [-10.91,10.91]:box([x,(lo+hi)/2,0],[.16,hi-lo,max(.18,2*za)],S2)
for y,w in [(.88,2.9),(1.83,4.5),(2.78,4.9)]:
    for sign in [-1,1]:box([0,y,sign*w/2],[21.4,.16,.16],S2)
for sign in [-1,1]:
    box([0,3.36,sign*2.43],[21.8,.18,.24],S2)
    # Dark recess with physical mullions and louvers under the raised roof.
    box([0,3.74,sign*1.82],[20.5,.53,.08],S2,'pitch')
    for x in np.linspace(-10.15,10.15,31):box([x,3.76,sign*1.90],[.13,.62,.15],S2)
    for y in [3.57,3.70,3.83]:box([0,y,sign*1.88],[20.4,.035,.05],S2)
    # Lower roof shoulders, and upper shallow gable, made from overlapping boards.
    for j in range(5):
        z0=1.78+j*.16;z1=z0+.19
        beam([-10.8,3.56-(z0-1.78)*.32,sign*z0],[10.8,3.56-(z0-1.78)*.32,sign*z0],.18,.055,S3)
    for j in range(11):
        z=j*.19+.04;y=4.5-z*.255
        for k in range(12):
            x=-10.5+(k+.5)*1.75+(0.03 if j%2 else 0)
            m=trimesh.creation.box(extents=[1.736,.06,.215])
            m.apply_transform(trimesh.transformations.rotation_matrix(sign*.25,[1,0,0]))
            m.apply_translation([x,y,sign*z]);add(m,S3)
    for x in np.linspace(-10.35,10.35,15):beam([x,4.49,0],[x,3.96,sign*2.09],.13,.14,S3)
beam([-10.7,4.53,0],[10.7,4.53,0],.14,.14,S3)
for x in [-10.52,10.52]:
    box([x,3.73,0],[.15,.62,3.68],S3)
    beam([x,4.49,0],[x,3.96,2.08],.16,.15,S3)
    beam([x,4.49,0],[x,3.96,-2.08],.16,.15,S3)
# Caulk course lines; side doorway has deep jambs, lintel and a visible interior.
for sign in [-1,1]:
    for y in np.arange(.49,3.25,.38):
        z=sign*(halfwidth(y)+.022)
        for a,b in ([(-10.8,-1.1),(1.1,10.8)] if sign==1 and 1.1<y<2.8 else [(-10.8,10.8)]):
            box([(a+b)/2,y,z],[b-a,.018,.018],S3,'pitch')
for x in [-1.1,1.1]:box([x,1.92,2.49],[.21,1.8,.25],S3)
box([0,2.82,2.51],[2.58,.22,.28],S3)
box([0,1.12,2.33],[2.3,.17,.65],S3)
box([0,1.93,1.78],[1.99,1.5,.05],S3,'pitch')
# Ramp end faces and rail feet are trimmed above ground; lowest corner is exactly Y=0.
start=np.array([0,1.17,2.58]);end=np.array([0,.10,5.55])
for x in [-.88,.88]:beam(start+[x,-.035,0],end+[x,-.035,0],.14,.13,S3)
for i in range(23):
    t=(i+.5)/23;p=start*(1-t)+end*t
    m=trimesh.creation.box(extents=[2.02,.10,.134])
    m.apply_transform(trimesh.transformations.rotation_matrix(-np.arctan2(1.07,2.97),[1,0,0]))
    m.apply_translation(p);add(m,S3)
for x in [-.94,.94]:
    for t in np.linspace(0,1,6):
        p=start*(1-t)+end*t+[x,0,0]
        box(p+[0,.42,0],[.10,.86,.10],S3)
    for h in [.42,.85]:beam(start+[x,h,0],end+[x,h,0],.10,.10,S3)
# Consolidate by stage/material: few draw calls, explicit toggleable parent nodes.
for stage in stages:
    for mat,meshes in parts[stage].items():
        if not meshes:continue
        m=trimesh.util.concatenate(meshes)
        assert np.isfinite(m.vertices).all() and np.isfinite(m.visual.uv).all()
        assert np.all(m.area_faces>1e-10)
        name=stage if mat=='wood' else stage+'_Bitumen'
        scene.add_geometry(m,node_name=name+'_Mesh',geom_name=name,parent_node_name=stage)
# Guard against tiny accumulated numerical error at the ground plane.
assert abs(scene.bounds[0,1])<1e-6,scene.bounds
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_bytes(scene.export(file_type='glb'))
check=trimesh.load(OUT,force='scene')
assert all(s in check.graph.nodes for s in stages)
for mesh in check.geometry.values():
    assert np.all(mesh.area_faces>1e-10)
    assert mesh.visual.uv is not None and np.isfinite(mesh.visual.uv).all()
print('GLB:',OUT)
print('File size:',OUT.stat().st_size,'bytes')
print('Bounding box XYZ (metres):',check.bounds.tolist())
print('Extents XYZ:',check.extents.tolist(),'(includes deployed +Z ramp)')
print('Ground Y:',check.bounds[0,1])
print('Nodes:',sorted(check.graph.nodes))
print('Geometries:',sorted(check.geometry))
print('Triangles:',sum(len(m.faces) for m in check.geometry.values()))
print('Verified: three stage parents, embedded PBR textures, finite UVs, no degenerate triangles.')
