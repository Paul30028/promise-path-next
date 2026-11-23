"""Build a deterministic, textured Noah's ark diorama; Y is up, metres.
Run with C:/AI/3d-studio-venv/Scripts/python.exe.

Keep Interior_3Decks and its pitch visible from construction stage 2 onward.
For inspection hide Stage2_HullFrontCutaway and Stage3_RoofCutaway;
Stage3_Ramp is independent for flood departure. Meshes contain solid walking
surfaces; the Godot importer/controller must supply collision and visibility.
The preserved v2 envelope has 1.30-1.35 m deck spacing: scale the scene/player
accordingly. Genesis specifies three decks, compartments, pitch, and an upper
light; furnishing and circulation details are an interpretive reconstruction.
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
stages=['Stage1_KeelRibs','Stage2_HullBackEnds','Stage2_HullFrontCutaway',
        'Interior_3Decks','Stage3_RoofCutaway','Stage3_Ramp']
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
S1,S2,FRONT,INTERIOR,S3,RAMP=stages
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
    for y,w in [(.32,1.65),(1.67,4.05),(2.97,4.65)]:
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
                side_patch(left,right,lo,hi,sign,FRONT if sign==1 else S2)
                if lo<PITCH_TOP:
                    side_patch(left,right,lo,min(hi,PITCH_TOP),sign,FRONT if sign==1 else S2,'pitch',.014)
        # Continuous rounded bow and stern courses, including pitch on end faces.
        for t0,t1 in zip(np.linspace(-np.pi/2,np.pi/2,17)[:-1],
                         np.linspace(-np.pi/2,np.pi/2,17)[1:]):
            end_patch(lo,hi,t0+.001,t1-.001,sign,S2)
            if lo<PITCH_TOP:
                end_patch(lo,min(hi,PITCH_TOP),t0+.001,t1-.001,sign,S2,'pitch',.014)
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
            box([(left+right)/2,y,sign*(halfwidth(y)+.05)],[right-left,.09,.13],FRONT if sign==1 else S2)
        ts=np.linspace(-np.pi/2,np.pi/2,25)
        for t0,t1 in zip(ts[:-1],ts[1:]):
            beam(end_point(y,t0,sign,.035),end_point(y,t1,sign,.035),.10,.13,S2)
# Upper side deck shoulders close the shell around the recessed one-cubit band.
for sign in [-1,1]:
    for j in range(4):
        z0=1.82+j*.18;z1=z0+.19
        outer=np.array([[-9.35,3.50-(z0-1.82)*.22,sign*z0],
                        [9.35,3.50-(z0-1.82)*.22,sign*z0],
                        [9.35,3.50-(z1-1.82)*.22,sign*z1],
                        [-9.35,3.50-(z1-1.82)*.22,sign*z1]])
        inner=outer.copy();inner[:,1]-=.07
        plank_patch(outer,inner,FRONT if sign==1 else S2)
        box([0,3.50-(z0-1.82)*.22+.005,sign*z0],[18.7,.015,.016],FRONT if sign==1 else S2,'pitch')
# Short end decks beneath the swept gunwale, with sealed longitudinal seams.
for sign in [-1,1]:
    for z in np.arange(-2.35,2.36,.18):
        length=endradius(3.33)*np.sqrt(max(0,1-(z/2.5)**2))
        box([sign*(SIDE_END+length/2),3.32,z],[length+.04,.085,.172],S2)
for sign in [-1,1]:
    box([0,3.36,sign*2.43],[18.8,.18,.24],FRONT if sign==1 else S2)
    # Dark recess with physical mullions and louvers under the raised roof.
    # Open one-cubit ventilation band: no opaque backing behind the slats.
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
            box([(a+b)/2,y,z],[b-a,.018,.018],FRONT if sign==1 else S2,'pitch')
for x in [-1.1,1.1]:box([x,1.92,2.49],[.21,1.8,.25],S2)
box([0,2.82,2.51],[2.58,.22,.28],S2)
box([0,1.12,2.33],[2.3,.17,.65],S2)
# Portal stays physically open into the boarding landing.
# The ramp follows its actual descending plane; its toe embeds in terrace ground.
start=np.array([0,1.17,2.58]);end=np.array([0,.12,6.35])
for x in [-.88,.88]:beam(start+[x,-.035,0],end+[x,-.035,0],.14,.13,RAMP)
for i in range(29):
    t=(i+.5)/29;p=start*(1-t)+end*t
    m=trimesh.creation.box(extents=[2.02,.10,.134])
    m.apply_transform(trimesh.transformations.rotation_matrix(np.arctan2(start[1]-end[1],end[2]-start[2]),[1,0,0]))
    m.apply_translation(p);add(m,RAMP)
for x in [-.94,.94]:
    for t in np.linspace(0,1,6):
        p=start*(1-t)+end*t+[x,0,0]
        box(p+[0,.42,0],[.10,.86,.10],RAMP)
    for h in [.42,.85]:beam(start+[x,h,0],end+[x,h,0],.10,.10,RAMP)
# Interior deck heights are walking surfaces, not beam centrelines.
DECKS = [(.45, 1.17), (1.80, 2.16), (3.10, 2.27)]
# Plank strips stop at the stairwell; solid faces form collision-ready treads.
for level, (y, width) in enumerate(DECKS):
    for z in np.arange(-width+.09, width, .18):
        spans=[(-9.25,9.25)]
        if abs(z)<.76 and level>0:
            hole=(-4.65,.65) if level==1 else (-.65,4.65)
            spans=[(-9.25,hole[0]),(hole[1],9.25)]
        for left,right in spans:
            box([(left+right)/2,y-.045,z],[right-left,.09,.174],INTERIOR)
    for z in [-width+.12,width-.12]:
        box([0,y-.15,z],[18.5,.20,.20],INTERIOR)
        box([0,y+.008,z],[18.4,.016,.022],INTERIOR,'pitch')
    for x in [-8,-6,-4,4,6,8]:
        # Pillars stay out of the central circulation and boarding bay.
        for sign in [-1,1]:
            z=sign*(width-.20)
            if level<2:
                next_y=DECKS[level+1][0]
                box([x,(y+next_y)/2,z],[.17,next_y-y,.17],INTERIOR)
                peg([x,y+.15,z+.10],INTERIOR)
# Massive full-length keel spine beneath the lower walking planks.
box([0,.30,0],[20,.28,.34],INTERIOR)
# Back-wall stalls on both animal decks: open fronts face the aisle.
for level,(y,width) in enumerate(DECKS[:2]):
    back=-width+.20
    front=-.56 if level==0 else -1.03
    for x in [-8.7,-6.4,-4.1,4.1,6.4,8.7]:
        for h in [.24,.55,.82]:
            box([x,y+h,(back+front)/2],[.10,.075,abs(back-front)],INTERIOR)
        for z in [back,front]:
            box([x,y+.44,z],[.12,.88,.12],INTERIOR)
            peg([x,y+.55,z+.065],INTERIOR)
    for x in [-7.55,-5.25,5.25,7.55]:
        # Slatted fodder cribs with bundled wooden stalks, using the same wood PBR.
        box([x,y+.16,back+.18],[1.25,.10,.32],INTERIOR)
        for dx in np.linspace(-.57,.57,7):
            beam([x+dx,y+.13,back+.32],[x+dx,y+.45,back+.42],.035,.04,INTERIOR)
        box([x,y+.44,back+.42],[1.30,.06,.06],INTERIOR)
        for j in range(8):
            beam([x-.5+j*.14,y+.22,back+.08],
                 [x-.43+j*.14,y+.35,back+.33],.025,.025,INTERIOR)
# Curved inner pitch seams follow each original bilge segment (no flat black walls).
for sign in [-1,1]:
    for (z0,y0),(z1,y1) in zip(profile[:-1],profile[1:]):
        for x in [-8.6,-6.0,-3.4,3.4,6.0,8.6]:
            beam([x,y0+.03,sign*(z0-.135)],
                 [x,y1+.03,sign*(z1-.135)],.028,.025,INTERIOR,'pitch')
# Continuous sloping walking boards, with cleats and handrails.
def walking_ramp(a,b,width=1.22):
    a,b=np.array(a,float),np.array(b,float)
    direction=b-a
    sideways=np.cross(direction,[0,1,0]);sideways/=np.linalg.norm(sideways)
    # Keep the tread width horizontal, even on a sloping run.
    across=sideways*width/2
    outer=np.array([a-across,b-across,b+across,a+across])
    inner=outer-[0,.11,0]
    plank_patch(outer,inner,INTERIOR)
    for side in [-1,1]:
        offset=sideways*side*(width/2-.035)
        for t in np.linspace(0,1,7):
            p=a*(1-t)+b*t+offset
            box(p+[0,.32,0],[.06,.64,.06],INTERIOR)
        beam(a+offset+[0,.64,0],b+offset+[0,.64,0],.06,.06,INTERIOR)
    for t in np.linspace(.05,.95,18):
        p=a*(1-t)+b*t
        beam(p-across+[0,.014,0],p+across+[0,.014,0],.028,.028,INTERIOR)
walking_ramp([-4.6,.45,0],[0,1.8,0])
walking_ramp([0,1.8,0],[4.6,3.1,0])
# Landings bridge the stairwell ends without sealing the atrium.
box([.25,1.755,0],[.50,.09,1.48],INTERIOR)
box([4.85,3.055,0],[.50,.09,1.48],INTERIOR)
box([0,1.155,1.76],[1.9,.09,1.17],INTERIOR)
walking_ramp([.65,1.2,1.65],[2.9,1.8,1.65],.85)
# Middle-deck storage racks against the forward wall, clear of entry and ramps.
for x in [-7.5,-5.5,5.5,7.5]:
    for dx in [-.70,.70]:
        for z in [1.35,1.90]:box([x+dx,2.30,z],[.085,1.0,.085],INTERIOR)
    for y in [1.94,2.30,2.65]:box([x,y,1.63],[1.5,.07,.64],INTERIOR)
# Upper family quarter screens leave a broad centre passage.
for x in [-6.8,6.8]:
    for sign in [-1,1]:
        for z in np.arange(.92,2.1,.17):
            box([x,3.48,sign*z],[.075,.76,.16],INTERIOR)
        box([x,3.90,sign*1.50],[.13,.09,1.32],INTERIOR)
for x in [-8.0,8.0]:
    box([x,3.19,1.47],[1.65,.18,.82],INTERIOR)
    # Bird frames and slender perches beneath the open upper light band.
    for dx in [-.65,.65]:box([x+dx,3.48,-1.50],[.065,.76,.065],INTERIOR)
    for y in [3.38,3.68,3.85]:beam([x-.70,y,-1.50],[x+.70,y,-1.50],.045,.045,INTERIOR)

# Consolidate by stage/material: few draw calls, explicit toggleable parent nodes.
for stage in stages:
    for mat,meshes in parts[stage].items():
        if not meshes:continue
        m=trimesh.util.concatenate(meshes)
        assert np.isfinite(m.vertices).all() and np.isfinite(m.visual.uv).all()
        assert np.all(m.area_faces>1e-10)
        name=stage if mat=='wood' else ('Interior_Bitumen' if stage==INTERIOR else stage+'_Bitumen')
        scene.add_geometry(m,node_name=name+'_Mesh',geom_name=name,parent_node_name=stage)
# Export and round-trip checks keep the node contract explicit.
expected = ['Stage1_KeelRibs_Mesh',
    'Stage2_HullBackEnds_Mesh','Stage2_HullBackEnds_Bitumen_Mesh',
    'Stage2_HullFrontCutaway_Mesh','Stage2_HullFrontCutaway_Bitumen_Mesh',
    'Interior_3Decks_Mesh','Interior_Bitumen_Mesh',
    'Stage3_RoofCutaway_Mesh','Stage3_Ramp_Mesh']
assert abs(scene.bounds[0,1])<1e-7, scene.bounds
assert abs(parts[S1]['wood'][0].bounds[0,1])<1e-8
OUT.parent.mkdir(parents=True,exist_ok=True)
blob=scene.export(file_type='glb')
# Validate before replacing the asset.
import io
check=trimesh.load(io.BytesIO(blob),file_type='glb',force='scene')
assert set(expected)==set(check.graph.nodes_geometry)
triangles=sum(len(m.faces) for m in check.geometry.values())
assert triangles<45000, triangles
for node in expected:
    parent=INTERIOR if node=='Interior_Bitumen_Mesh' else node.removesuffix('_Mesh').removesuffix('_Bitumen')
    assert check.graph.transforms.parents[node]==parent
for mesh in check.geometry.values():
    assert np.isfinite(mesh.vertices).all() and np.all(mesh.area_faces>1e-10)
    uv=mesh.visual.uv
    assert uv is not None and np.isfinite(uv).all()
    t=uv[mesh.faces]
    ab=t[:,1]-t[:,0]; ac=t[:,2]-t[:,0]
    area=np.abs(ab[:,0]*ac[:,1]-ab[:,1]*ac[:,0])
    assert np.all(area>1e-12), 'Collapsed UV triangle'
    assert mesh.visual.material.baseColorTexture is not None
OUT.write_bytes(blob)
print('GLB:',OUT)
print('File size:',len(blob),'bytes')
print('Bounding box XYZ:',check.bounds.tolist())
print('Grounded minimum Y:',check.bounds[0,1])
print('Nodes:',sorted(check.graph.nodes_geometry))
print('Triangles:',triangles)
print('Verified: node parents, embedded PBR textures, finite noncollapsed UVs, nondegenerate faces.')
