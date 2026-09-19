"""Reference-directed Nightglass Colossus: fractured stone/ceramic over a furnace machine.
Godot metres/Y up; camera +Z. Independent editable Blender scene; exports warden.glb.
"""
import bpy, math, random
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/models/campaign_bosses'
helpers={'__name__':'vanguard_helpers','__file__':str(ROOT/'tools/build_apex_vanguard.py')}
exec(compile(Path(helpers['__file__']).read_text(),helpers['__file__'],'exec'),helpers)
p,material,box,sphere,cylinder,plate,socket,rod,tube=[helpers[k] for k in ['p','material','box','sphere','cylinder','plate','socket','rod','tube']]
rng=random.Random(712)

def shard(root,name,outline,z,thickness,mat):
    n=len(outline);cx=sum(a for a,b in outline)/n;cy=sum(b for a,b in outline)/n
    verts=[p((x,y,z-thickness*.5)) for x,y in outline]+[p((x,y,z+thickness*.3+rng.uniform(-.035,.035))) for x,y in outline]
    verts.append(p((cx,cy,z+thickness*.60)))
    faces=[tuple(reversed(range(n)))]+[(n+i,n+(i+1)%n,2*n) for i in range(n)]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.parent=root;mesh.materials.append(mat)
    bevel=obj.modifiers.new('Chipped machined edges','BEVEL');bevel.width=.018;bevel.segments=2
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
    return obj

def spike(root,name,a,b,radius,mat):
    obj=cylinder(root,name,(Vector(a)+Vector(b))*.5,radius,(Vector(b)-Vector(a)).length,mat,axis='Y',top=.012)
    obj.rotation_mode='QUATERNION';obj.rotation_quaternion=(Vector(p(b))-Vector(p(a))).to_track_quat('Z','Y')
    return obj

def materials():
    mats={'bone':material('COLOSSUS fractured pale carapace',(.65,.66,.60),.12,.78),
          'edge':material('COLOSSUS fresh stone fracture',(.42,.44,.40),.12,.8),
          'dark':material('COLOSSUS obsidian pressure suit',(.018,.025,.027),.3,.66),
          'steel':material('COLOSSUS blackened steel actuators',(.09,.13,.14),.8,.36),
          'chrome':material('COLOSSUS scarred piston rods',(.33,.37,.37),.88,.3),
          'lava':material('COLOSSUS furnace red',(1,.015,.002),.2,.37,2.0),
          'hot':material('COLOSSUS molten gold',(1,.18,.006),.15,.34,2.5)}
    # Crack texture with rough stone grain and branching cellular fractures.
    n=768;gen=np.random.default_rng(712);yy,xx=np.mgrid[0:n,0:n].astype(np.float32)/n
    first=np.full((n,n),np.inf,dtype=np.float32);second=first.copy()
    for x,y in gen.random((65,2)):
        distance=(xx-x)**2+(yy-y)**2
        second=np.minimum(second,np.maximum(first,distance));first=np.minimum(first,distance)
    cracks=(second-first)<.00030
    grain=gen.random((n,n));base=.73+(grain-.5)*.13
    base[cracks]=.025+(grain[cracks])*.06
    rgba=np.ones((n,n,4),dtype=np.float32)
    rgba[:,:,:3]=base[:,:,None]*np.array([1,.99,.92])
    image=bpy.data.images.new('Colossus_Fractured_Carapace',width=n,height=n);image.pixels.foreach_set(rgba.ravel());image.pack()
    nodes=mats['bone'].node_tree;tex=nodes.nodes.new('ShaderNodeTexImage');tex.image=image;nodes.links.new(tex.outputs['Color'],nodes.nodes.get('Principled BSDF').inputs['Base Color'])
    return mats

def build():
    name='CampaignBoss_nightglass_colossus'
    if name in bpy.data.scenes:raise RuntimeError('Scene already exists')
    scene=bpy.data.scenes.new(name);bpy.context.window.scene=scene
    root=socket(None,'Nightglass_Colossus_Root',(0,0,0));m=materials()
    torso=socket(root,'ColossusTorso',(0,.1,0))
    sphere(torso,'Hunched obsidian thorax',(0,.85,-.12),(1.13,1.05,.70),m['dark'])
    sphere(torso,'Core slag mantle',(0,1.39,.05),(.69,.73,.64),m['dark'])
    sphere(torso,'Furnace body',(0,1.34,.38),(.51,.66,.29),m['lava'])
    sphere(torso,'Molten core',(0,1.52,.50),(.29,.45,.12),m['hot'])
    # Flame-shaped raised fissures and jagged spinal crown around an open reactor.
    for i in range(9):
        x=(i-4)*.125
        points=[(x,.75,.64),(x+rng.uniform(-.12,.12),1.08,.67),(x-rng.uniform(.03,.13),1.42,.65),(x+rng.uniform(-.07,.1),1.85,.46),(x*.75,2.04,.28)]
        tube(torso,'Raised molten spinal fissure',points,.025 if i%2 else .042,m['hot'] if i%3==0 else m['lava'])
    for side in [-1,1]:
        shard(torso,'Splintered reactor rim',[(side*.23,1.91),(side*.39,2.30),(side*.65,1.85),(side*.94,1.51),(side*.68,1.19),(side*.40,1.46)],.42,.24,m['bone'])
        spike(torso,'Reactor crown shard',(side*.50,1.81,.02),(side*.61,2.43,.12),.17,m['edge'])
        shard(torso,'Broken chest outer cuirass',[(side*.43,1.34),(side*.98,1.60),(side*1.25,1.03),(side*1.15,.50),(side*.69,.23),(side*.38,.68)],.72,.27,m['bone'])
        shard(torso,'Overlapping breast splinter',[(side*.32,1.11),(side*.72,1.34),(side*.81,.75),(side*.53,.45),(side*.25,.72)],.92,.16,m['bone'])
        for j in range(3):
            shard(torso,'Lower rib fragments',[(side*(.30+j*.18),.35-j*.17),(side*(.63+j*.13),.40-j*.16),(side*(.73+j*.1),.17-j*.15),(side*(.37+j*.18),.02-j*.15)],.52,.15,m['edge'])
        tube(torso,'Exposed rib furnace vein',[(side*.22,.68,.87),(side*.50,.45,.80),(side*.69,.14,.57),(side*.51,-.13,.48)],.026,m['lava'])
    # Wolf-like armoured death mask projecting from the hunch.
    head=socket(torso,'ColossusHead',(0,.63,1.03))
    sphere(head,'Predator cranial seal',(0,.03,0),(.48,.40,.38),m['dark'])
    shard(head,'Left fractured brow',[(-.50,.29),(-.30,.58),(-.04,.43),(-.10,.13),(-.43,-.03),(-.57,.10)],.27,.20,m['bone'])
    shard(head,'Right fractured brow',[(.04,.43),(.31,.55),(.53,.24),(.51,.02),(.14,.10)],.27,.20,m['bone'])
    shard(head,'Spear shaped muzzle',[(-.26,.13),(-.13,.27),(.18,.22),(.33,-.04),(.13,-.56),(-.05,-.67),(-.30,-.20)],.54,.29,m['bone'])
    for side in [-1,1]:
        plate(head,'Burning recessed eye',[(side*.14,.16),(side*.41,.19),(side*.34,.075),(side*.13,.045)],.435,.028,m['lava'])
        spike(head,'Swept cranial horn',(side*.40,.29,-.06),(side*.65,.94,-.25),.17,m['bone'])
        shard(head,'Fractured jaw blade',[(side*.38,-.05),(side*.49,-.14),(side*.31,-.53),(side*.20,-.62),(side*.23,-.25)],.28,.14,m['edge'])
        for j in range(3):
            spike(head,'Blackened fang',(side*(.12+j*.085),-.28-j*.07,.59),(side*(.09+j*.065),-.49-j*.085,.62),.041,m['dark'])
    # Massive asymmetric mechanical arms and layered broken pauldrons.
    for side in [-1,1]:
        arm=socket(torso,'ColossusArm_'+('L' if side<0 else 'R'),(side*1.04,.94,.04))
        sphere(arm,'Shoulder armored tendon',(side*.13,-.17,-.01),(.40,.43,.39),m['dark'])
        for j in range(3):
            x=side*(.08+j*.13)
            shard(arm,'Jagged shoulder shell',[(x-side*.36,.22-j*.14),(x+side*.17,.40-j*.1),(x+side*.55,.20-j*.13),(x+side*.47,-.35-j*.17),(x-side*.15,-.31-j*.10)],.29+j*.08,.25,m['bone'])
        spike(arm,'Shoulder siege spike',(side*.26,.25,.0),(side*.65,.79,.0),.22,m['bone'])
        elbow=(side*.59,-.82,.11)
        rod(arm,'Arm pressure cylinder',(side*.12,-.36,.02),elbow,.21,m['steel'])
        rod(arm,'Exposed bicep hydraulic',(side*.31,-.32,.35),(elbow[0]+side*.12,elbow[1],.38),.065,m['chrome'])
        sphere(arm,'Elbow hinge',elbow,(.26,.27,.27),m['dark'])
        cylinder(arm,'Elbow bearing',(elbow[0],elbow[1],.40),.22,.11,m['chrome'])
        wrist=(side*.70,-1.86,.40)
        rod(arm,'Forearm mechanical spine',elbow,wrist,.25,m['steel'])
        shard(arm,'Oversized fractured forearm',[(side*.40,-.73),(side*.90,-.76),(side*1.05,-1.10),(side*.95,-1.76),(side*.49,-1.90),(side*.36,-1.47)],.51,.31,m['bone'])
        shard(arm,'Forearm outer splinter',[(side*.87,-.95),(side*1.22,-1.26),(side*1.1,-1.42),(side*.89,-1.74),(side*.73,-1.52)],.40,.20,m['edge'])
        tube(arm,'Arm furnace breach',[(side*.46,-.82,.73),(side*.61,-1.06,.78),(side*.52,-1.31,.72),(side*.73,-1.51,.70)],.018,m['lava'])
        sphere(arm,'Armored knuckle glove',wrist,(.29,.28,.27),m['dark'])
        for j in range(4):
            x=wrist[0]+(j-1.5)*.12
            box(arm,'Forged knuckle',(x,-1.93,.63),(.1,.25,.15),m['steel'],.022)
            spike(arm,'Curved siege claw',(x,-2.02,.69),(x-side*.03,-2.20,.56),.06,m['dark'])
        socket(arm,'MuzzleLeft_Colossus' if side<0 else 'MuzzleRight_Colossus',(side*.65,-1.1,.78))
    # Heavy crouched legs, hydraulic ankles and split ground claws.
    sphere(root,'Pelvic tendon mass',(0,-.61,-.16),(.60,.49,.38),m['dark'])
    for side in [-1,1]:
        leg=socket(root,'ColossusLeg_'+('L' if side<0 else 'R'),(side*.48,-.62,-.05))
        knee=(side*.34,-.77,.31);ankle=(side*.50,-1.80,.17)
        rod(leg,'Massive thigh linkage',(0,0,0),knee,.30,m['steel'])
        shard(leg,'Thigh fractured guard',[(-.22,-.05),(.25,.10),(side*.52,-.27),(side*.54,-.68),(side*.15,-.76),(-.15,-.45)],.37,.25,m['bone'])
        sphere(leg,'Deep knee socket',knee,(.27,.29,.27),m['dark'])
        shard(leg,'Knee fractured shield',[(knee[0]-.29,-.52),(knee[0]+.26,-.55),(knee[0]+.32,-.85),(knee[0],-1.07),(knee[0]-.31,-.90)],.63,.22,m['bone'])
        rod(leg,'Shin steel spar',knee,ankle,.19,m['steel'])
        rod(leg,'Shin chrome piston',(knee[0]-side*.19,-.9,.40),(ankle[0]-side*.2,-1.66,.33),.045,m['chrome'])
        shard(leg,'Large cracked tibial armor',[(knee[0]-.25,-.88),(knee[0]+.24,-.91),(ankle[0]+.27,-1.29),(ankle[0]+.22,-1.82),(ankle[0]-.20,-1.90),(knee[0]-.28,-1.22)],.50,.30,m['bone'])
        for j in [-1,1]:
            x=ankle[0]+j*.16
            shard(leg,'Grounded split talon',[(x-.15,-1.73),(x+.15,-1.73),(x+.17,-1.97),(x-.18,-1.98)],.43,.40,m['dark'])
            shard(leg,'Claw striking edge',[(x-.16,-1.91),(x+.16,-1.91),(x+.17,-1.97),(x-.18,-1.98)],.66,.055,m['edge'])
        tube(leg,'Knee molten fissure',[(knee[0],-.51,.77),(knee[0]-.08,-.77,.79),(knee[0]+.09,-.92,.75)],.016,m['lava'])
    socket(torso,'CoreSocket_Colossus',(0,1.51,.80))
    return root

def export():
    scene=bpy.data.scenes['CampaignBoss_nightglass_colossus'];bpy.context.window.scene=scene
    root=bpy.data.objects['Nightglass_Colossus_Root']
    for o in list(root.children_recursive):
        if o.type=='CURVE':
            bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
    groups={}
    for o in root.children_recursive:
        if o.type=='MESH':groups.setdefault((o.parent.name,o.data.materials[0].name),[]).append(o)
    for key,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            o.select_set(True);bpy.context.view_layer.objects.active=o
            for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        if len(objects)>1:bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
        bpy.context.view_layer.objects.active=objects[0];objects[0].name=key[0]+'__'+key[1]
    bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
    for o in root.children_recursive:o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/'warden.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_animations=False,export_yup=True,export_lights=False,export_cameras=False)
    image=bpy.data.images.load(str(OUT/'reference_nightglass_colossus.png'));image.pack()
    ref=bpy.data.objects.new('Reference_NightglassColossus',None);scene.collection.objects.link(ref);ref.empty_display_type='IMAGE';ref.data=image;ref.empty_display_size=5;ref.location=(6,0,0);ref.rotation_euler.x=math.pi/2
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'campaign_boss_workbench.blend'))
    print('COLOSSUS EXPORTED',len(root.children_recursive),'nodes')

if __name__=='__main__':build();export()
