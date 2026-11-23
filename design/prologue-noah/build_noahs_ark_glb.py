"""Build a deterministic, textured Noah's ark diorama; Y is up, metres.
Run with C:/AI/3d-studio-venv/Scripts/python.exe.
"""
from pathlib import Path
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
    board=RNG.uniform(-14,14,16)[y//32]
    seams=np.where(y%32<2,-25,0)
    # Fine longitudinal fibres, wandering checks and subdued oval knots.
    fibres=2*np.sin(y*3.1+np.sin(x*.012)*4)
    checks=np.where((np.sin(y*.21+np.sin(x*.015))>.985)&(x%137<95),-18,0)
    knots=np.zeros_like(grain)
    for kx,ky in [(90,85),(310,213),(410,401)]:
        radius=np.sqrt(((x-kx)/2.8)**2+((y-ky)*1.7)**2)
        knots+=np.exp(-radius/13)*(np.sin(radius*.9)*9-9)
    val=grain*4+fibres+noise+board+seams+checks+knots
    base=np.array([113,77,44] if not pitch else [42,31,24])
    rgb=np.clip(base+val[:,:,None]*(1 if not pitch else .35),0,255).astype('uint8')
    return Image.fromarray(rgb,'RGB')
wood=PBRMaterial(name='Weathered_Cypress',baseColorTexture=texture(),roughnessFactor=.88,metallicFactor=0)
pitch=PBRMaterial(name='Weathered_Bitumen',baseColorTexture=texture(True),roughnessFactor=.88,metallicFactor=0)
scene=trimesh.Scene(base_frame='NoahsArk')
stages=['Stage1_KeelRibs','Stage2_HullPlanks','Stage3_PitchRoofRamp']
parts={s:{'wood':[],'pitch':[]} for s in stages}
for s in stages: scene.graph.update(frame_to=s,frame_from='NoahsArk',matrix=np.eye(4))

def add(mesh,stage,mat='wood'):
    mesh.remove_unreferenced_vertices()
    assert np.all(mesh.area_faces>1e-10)
    if mesh.volume<0: mesh.invert()
    # Per-face UV vertices avoid wrapped interpolation and give every face clean normals.
    v=mesh.vertices[mesh.faces].reshape(-1,3)
    n=np.repeat(mesh.face_normals,3,axis=0)
    uv=np.empty((len(v),2))
    # A deterministic UV offset per member varies board tone without extra draw calls.
    offset=RNG.uniform(0,1,2)
    for i,normal in enumerate(mesh.face_normals):
        axes=[a for a in range(3) if a!=np.argmax(np.abs(normal))]
        # Grain follows long X members; vertical faces use their own local plane.
        uv[3*i:3*i+3]=v[3*i:3*i+3][:,axes]/np.array([3.2,1.25])+offset
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
# Grounded barge: a broad keel and gently rounded bilge, never exposed legs.
# Coordinates are (half breadth Z, height Y); the keel sits at Y=0.
profile=np.array([[.36,.10],[.92,.25],[1.55,.56],[2.04,1.0],
                  [2.32,1.48],[2.46,2.08],[2.50,2.70],[2.50,3.33]])
def halfwidth(y):return float(np.interp(y,profile[:,1],profile[:,0]))
def endradius(y):return float(np.interp(y,[.10,.56,1.48,2.70,3.33],[.38,.80,1.35,1.64,1.72]))
# Rounded ends maintain a long, monumental, blunt outline in plan.
SIDE_END=9.30
PITCH_TOP=.10+(3.33-.10)*.35
box([0,.12,0],[19.8,.24,.68],S1)
for x in np.linspace(-9.0,9.0,8):
    for sign in [-1,1]:
        # Low stacked rough-hewn chocks nest under the belly; no tall uprights.
        box([x,.075,sign*.79],[.80,.15,1.12],S1)
        beam([x,.22,sign*.64],[x,.41,sign*1.12],.53,.22,S1)
for x in np.linspace(-9.22,9.22,15):
    # Leave the boarding bay clear of ribs and transverse beams.
    if abs(x)<1.12:continue
    for sign in [-1,1]:
        for (z0,y0),(z1,y1) in zip(profile[:-1],profile[1:]):
            beam([x,y0+.12,sign*max(.22,z0-.15)],
                 [x,y1+.08,sign*(z1-.15)],.22,.24,S1)
        for y,z in [(1.0,2.04),(2.08,2.46),(3.22,2.5)]:
            peg([x,y,sign*(z-.025)],S1)
    for y,w in [(.86,3.25),(1.82,4.45),(2.8,4.65)]:
        box([x,y,0],[.22,.19,w],S1)
# Closed eight-corner plank patch with consistent outward normals.
FACES=[[0,1,2],[0,2,3],[4,6,5],[4,7,6],[0,4,5],[0,5,1],
       [1,5,6],[1,6,2],[2,6,7],[2,7,3],[3,7,4],[3,4,0]]
def plank_patch(outer,inner,stage,mat='wood'):
    m=trimesh.Trimesh(np.vstack([outer,inner]),FACES,process=True)
    m.fix_normals();add(m,stage,mat)
def side_patch(a,b,lo,hi,sign,stage,mat='wood',offset=0):
    outer=np.array([[a,lo,sign*(halfwidth(lo)+offset)],
                    [b,lo,sign*(halfwidth(lo)+offset)],
                    [b,hi,sign*(halfwidth(hi)+offset)],
                    [a,hi,sign*(halfwidth(hi)+offset)]])
    inner=outer.copy();inner[:,2]-=sign*(.12 if mat=='wood' else .012)
    plank_patch(outer,inner,stage,mat)
def end_point(y,t,sign,offset=0):
    # Both ends curl outward as the planking rises, without a ship's pointed bow.
    return np.array([sign*(SIDE_END+(endradius(y)+offset)*np.cos(t)),
                     y,(halfwidth(y)+offset)*np.sin(t)])
def end_patch(lo,hi,t0,t1,sign,stage,mat='wood',offset=0):
    outer=np.array([end_point(lo,t0,sign,offset),end_point(lo,t1,sign,offset),
                    end_point(hi,t1,sign,offset),end_point(hi,t0,sign,offset)])
    inner=outer.copy()
    inner[:,0]-=sign*.10*np.cos([t0,t1,t1,t0])
    inner[:,2]-=.10*np.sin([t0,t1,t1,t0])
    plank_patch(outer,inner,stage,mat)
# Close the belly against the heavy keel, instead of an open warehouse floor.
box([0,.12,0],[19.4,.12,.76],S2)
for row in range(17):
    lo=.10+row*.19;hi=min(lo+.181,3.33)
    for sign in [-1,1]:
        # Stagger scarf joints from one course to the next.
        edges=sorted(set([-SIDE_END,SIDE_END]+[float(v) for v in
            np.arange(-SIDE_END+(.9 if row%2 else 2.1),SIDE_END,2.65)]))
        for xa,xb in zip(edges[:-1],edges[1:]):
            intervals=[(xa+.004,xb-.004)]
            if sign==1 and lo<2.72 and hi>1.13:
                intervals=[(a,b) for a,b in [(xa+.004,min(xb-.004,-1.02)),
                           (max(xa+.004,1.02),xb-.004)] if b-a>.015]
            for left,right in intervals:
                side_patch(left,right,lo,hi,sign,S2)
                if lo<PITCH_TOP:
                    side_patch(left,right,lo,min(hi,PITCH_TOP),sign,S3,'pitch',.014)
        # Continuous rounded bow and stern courses, including pitch on end faces.
        for t0,t1 in zip(np.linspace(-np.pi/2,np.pi/2,17)[:-1],
                         np.linspace(-np.pi/2,np.pi/2,17)[1:]):
            end_patch(lo,hi,t0+.001,t1-.001,sign,S2)
            if lo<PITCH_TOP:
                end_patch(lo,min(hi,PITCH_TOP),t0+.001,t1-.001,sign,S3,'pitch',.014)
# End-posts follow the rising end grain in short joined lengths.
for sign in [-1,1]:
    ys=[.12,.4,.8,1.3,1.9,2.5,3.2,3.65]
    for y0,y1 in zip(ys[:-1],ys[1:]):
        beam(end_point(y0,0,sign,.035),end_point(y1,0,sign,.035),.27,.28,S2)
    box([sign*(SIDE_END+endradius(3.33)+.035),3.68,0],[.40,.17,.39],S2)
    for y in [.55,1.1,2.0,2.8,3.4]:
        # Transverse wooden end-grain tenons, rather than metal bolts.
        box([sign*(SIDE_END+endradius(y)+.18),y,0],[.065,.075,.12],S2)
# Curved gunwales and modest external rub strakes articulate the shell.
for y in [1.40,2.50,3.34]:
    for sign in [-1,1]:
        spans=[(-SIDE_END,-1.12),(1.12,SIDE_END)] if y<2.72 else [(-SIDE_END,SIDE_END)]
        if sign==-1:spans=[(-SIDE_END,SIDE_END)]
        for left,right in spans:
            box([(left+right)/2,y,sign*(halfwidth(y)+.05)],[right-left,.09,.13],S2)
        ts=np.linspace(-np.pi/2,np.pi/2,25)
        for t0,t1 in zip(ts[:-1],ts[1:]):
            beam(end_point(y,t0,sign,.035),end_point(y,t1,sign,.035),.10,.13,S2)
# Three deck ledges and a few landing boards remain legible at construction stage 2.
for y,w in [(.88,3.25),(1.83,4.45),(2.78,4.65)]:
    for sign in [-1,1]:
        box([0,y,sign*w/2],[18.6,.16,.18],S2)
        box([0,y+.085,sign*(w/2-.08)],[18.6,.016,.018],S2,'pitch')
# Upper side deck shoulders close the shell around the recessed one-cubit band.
for sign in [-1,1]:
    for j in range(4):
        z0=1.82+j*.18;z1=z0+.19
        outer=np.array([[-9.35,3.50-(z0-1.82)*.22,sign*z0],
                        [9.35,3.50-(z0-1.82)*.22,sign*z0],
                        [9.35,3.50-(z1-1.82)*.22,sign*z1],
                        [-9.35,3.50-(z1-1.82)*.22,sign*z1]])
        inner=outer.copy();inner[:,1]-=.07
        plank_patch(outer,inner,S2)
        box([0,3.50-(z0-1.82)*.22+.005,sign*z0],[18.7,.015,.016],S2,'pitch')
# Short end decks beneath the swept gunwale, with sealed longitudinal seams.
for sign in [-1,1]:
    for z in np.arange(-2.35,2.36,.18):
        length=endradius(3.33)*np.sqrt(max(0,1-(z/2.5)**2))
        box([sign*(SIDE_END+length/2),3.32,z],[length+.04,.085,.172],S2)
for sign in [-1,1]:
    box([0,3.36,sign*2.43],[18.8,.18,.24],S2)
    # Dark recess with physical mullions and louvers under the raised roof.
    box([0,3.74,sign*1.82],[18.25,.46,.08],S2,'pitch')
    for x in np.linspace(-9.05,9.05,29):box([x,3.76,sign*1.90],[.13,.50,.15],S2)
    for y in [3.57,3.70,3.83]:box([0,y,sign*1.88],[18.2,.035,.05],S2)
    for j in range(11):
        z=j*.19+.04;y=4.5-z*.255
        for k in range(12):
            x=-9.45+(k+.5)*1.575+(0.03 if j%2 else 0)
            m=trimesh.creation.box(extents=[1.565,.085,.225])
            m.apply_transform(trimesh.transformations.rotation_matrix(sign*.25,[1,0,0]))
            m.apply_translation([x,y,sign*z]);add(m,S3)
    for x in np.linspace(-9.2,9.2,15):beam([x,4.49,0],[x,3.96,sign*2.09],.13,.14,S3)
beam([-9.55,4.53,0],[9.55,4.53,0],.14,.14,S3)
for x in [-9.32,9.32]:
    box([x,3.73,0],[.15,.62,3.68],S3)
    beam([x,4.49,0],[x,3.96,2.08],.16,.15,S3)
    beam([x,4.49,0],[x,3.96,-2.08],.16,.15,S3)
    # Closed gable infill above the end wall.
    verts=[[x-.075,4.00,-1.98],[x-.075,4.50,0],[x-.075,4.00,1.98],
           [x+.075,4.00,-1.98],[x+.075,4.50,0],[x+.075,4.00,1.98]]
    g=trimesh.Trimesh(verts,[[0,2,1],[3,4,5],[0,1,4],[0,4,3],
        [1,2,5],[1,5,4],[2,0,3],[2,3,5]],process=True)
    g.fix_normals();add(g,S3)
# Caulk course lines; side doorway has deep jambs, lintel and a visible interior.
for sign in [-1,1]:
    for y in np.arange(.49,3.25,.38):
        z=sign*(halfwidth(y)+.022)
        for a,b in ([(-9.3,-1.1),(1.1,9.3)] if sign==1 and 1.1<y<2.8 else [(-9.3,9.3)]):
            box([(a+b)/2,y,z],[b-a,.018,.018],S3,'pitch')
for x in [-1.1,1.1]:box([x,1.92,2.49],[.21,1.8,.25],S3)
box([0,2.82,2.51],[2.58,.22,.28],S3)
box([0,1.12,2.33],[2.3,.17,.65],S3)
box([0,1.93,1.78],[1.99,1.5,.05],S3,'pitch')
# The ramp follows its actual descending plane; its toe embeds in terrace ground.
start=np.array([0,1.17,2.58]);end=np.array([0,-.22,6.35])
for x in [-.88,.88]:beam(start+[x,-.035,0],end+[x,-.035,0],.14,.13,S3)
for i in range(29):
    t=(i+.5)/29;p=start*(1-t)+end*t
    m=trimesh.creation.box(extents=[2.02,.10,.134])
    m.apply_transform(trimesh.transformations.rotation_matrix(np.arctan2(start[1]-end[1],end[2]-start[2]),[1,0,0]))
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
# Hull and cribbing remain grounded; only the ramp toe may embed below Y=0.
assert -.6 <= scene.bounds[0,1] <= 0,scene.bounds
assert min(m.bounds[0,1] for m in parts[S1]['wood']) >= -1e-8, [(i,m.bounds.tolist()) for i,m in enumerate(parts[S1]['wood']) if m.bounds[0,1]<-1e-8]
assert abs(parts[S1]['wood'][0].bounds[0,1])<1e-8
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_bytes(scene.export(file_type='glb'))
check=trimesh.load(OUT,force='scene')
assert all(s in check.graph.nodes for s in stages)
expected=['Stage1_KeelRibs_Mesh','Stage2_HullPlanks_Mesh',
          'Stage2_HullPlanks_Bitumen_Mesh','Stage3_PitchRoofRamp_Mesh',
          'Stage3_PitchRoofRamp_Bitumen_Mesh']
assert set(expected)==set(check.graph.nodes_geometry)
for name in expected:
    assert check.graph.transforms.parents[name] == name.split('_Mesh')[0].replace('_Bitumen','')
for mesh in check.geometry.values():
    assert np.all(mesh.area_faces>1e-10)
    assert mesh.visual.uv is not None and np.isfinite(mesh.visual.uv).all()
print('GLB:',OUT)
print('File size:',OUT.stat().st_size,'bytes')
print('Bounding box XYZ (metres):',check.bounds.tolist())
print('Extents XYZ:',check.extents.tolist(),'(includes deployed +Z ramp)')
print('Lowest Y (embedded ramp toe):',check.bounds[0,1])
print('Stage1 grounded keel Y:',check.geometry[S1].bounds[0,1])
print('Pitch band top Y:',PITCH_TOP)
print('Nodes:',sorted(check.graph.nodes))
print('Geometries:',sorted(check.geometry))
print('Triangles:',sum(len(m.faces) for m in check.geometry.values()))
print('Verified: three stage parents, embedded PBR textures, finite UVs, no degenerate triangles.')
