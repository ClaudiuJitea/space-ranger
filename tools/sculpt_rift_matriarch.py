"""Reference sculpt: irregular, ridged carapace patches and forward-heavy biomechanics."""
import bpy,math,random
from pathlib import Path
from mathutils import Vector
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
ns={'__file__':str(ROOT/'tools/build_rift_matriarch.py'),'__name__':'sculpt_helpers'}
exec(compile(Path(ns['__file__']).read_text(),ns['__file__'],'exec'),ns)
p,material,sphere,socket,rod,tube,talon=[ns[k] for k in ['p','material','sphere','socket','rod','tube','talon']]
rand=random.Random(714)

def patch(root,name,outline,normal,bulge,mat):
    contour=[Vector(c) for c in outline];center=sum(contour,Vector())/len(contour);normal=Vector(normal).normalized()
    verts=[p(center+normal*bulge)];faces=[];n=len(contour)
    for ring,t in enumerate([.24,.52,.80,1.0]):
        for i,c in enumerate(contour):
            co=center.lerp(c,t)+normal*(bulge*(1-t*t)+.012*math.sin(i*2.3)*math.sin(math.pi*t))
            verts.append(p(co))
    for i in range(n):faces.append((0,1+i,1+(i+1)%n))
    for ring in range(3):
        a=1+ring*n;b=a+n
        for i in range(n):faces.append((a+i,b+i,b+(i+1)%n,a+(i+1)%n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(o);o.parent=root;mesh.materials.append(mat)
    # Real plate thickness, softly cut edges and broad sculpted ridges.
    mod=o.modifiers.new('Carapace thickness','SOLIDIFY');mod.thickness=.045
    mod=o.modifiers.new('Worn plate bevel','BEVEL');mod.width=.012;mod.segments=3
    for f in mesh.polygons:f.use_smooth=True
    return o

def build():
    old=bpy.data.scenes.get('CampaignBoss_Rift_Matriarch')
    if old:old.name='CampaignBoss_Matriarch_Previous'
    scene=bpy.data.scenes.new('CampaignBoss_Rift_Matriarch');bpy.context.window.scene=scene
    root=socket(None,'Rift_Matriarch_Sculpt_Root',(0,0,0));root.rotation_euler.z=-math.pi/2
    bone=material('MATRIARCH sculpted weathered bone',(.45,.43,.34),.08,.73)
    black=material('MATRIARCH sculpted woven tendons',(.016,.025,.031),.35,.62)
    steel=material('MATRIARCH sculpted oily actuators',(.055,.079,.087),.78,.42)
    edge=material('MATRIARCH sculpted dark cutting edges',(.18,.22,.23),.85,.37)
    red=material('MATRIARCH sculpted crimson reactors',(.40,.004,.015),.18,.43,1.1)
    gum=material('MATRIARCH sculpted jaw cavities',(.065,.008,.016),.05,.70)
    # Embedded albedo, roughness and tangent-space grain maps. Restrained fine fissures.
    n=1024;gen=np.random.default_rng(714);yy,xx=np.mgrid[:n,:n]
    mottled=.87+.09*np.sin(xx*.021)*np.cos(yy*.017)+(gen.random((n,n))-.5)*.11
    rgba=np.ones((n,n,4),dtype=np.float32);rgba[:,:,:3]=mottled[:,:,None]*np.array([.64,.61,.51])
    for _ in range(160):
        x,y=gen.integers(20,n-20,2);length=int(gen.integers(5,50))
        for k in range(length):
            px=int(x+k*.37+math.sin(k*.31)*2);py=int(y+k)
            if px<n and py<n:rgba[py,px,:3]*=.48
    image=bpy.data.images.new('Matriarch sculpt mottled bone albedo',width=n,height=n);image.pixels.foreach_set(rgba.ravel());image.pack()
    tree=bone.node_tree;bs=tree.nodes.get('Principled BSDF');tex=tree.nodes.new('ShaderNodeTexImage');tex.image=image;tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    normal=np.ones((n,n,4),dtype=np.float32);normal[:,:,0:2]=.5+(gen.random((n,n,2))-.5)*.10;normal[:,:,2]=1
    image=bpy.data.images.new('Matriarch sculpt bone micro normal',width=n,height=n);image.pixels.foreach_set(normal.ravel());image.pack();image.colorspace_settings.name='Non-Color'
    tex=tree.nodes.new('ShaderNodeTexImage');tex.image=image;node=tree.nodes.new('ShaderNodeNormalMap');node.inputs['Strength'].default_value=.45;tree.links.new(tex.outputs['Color'],node.inputs['Color']);tree.links.new(node.outputs['Normal'],bs.inputs['Normal'])
    torso=socket(root,'ColossusTorso',(0,-.25,0))
    sphere(torso,'Forward load bearing thorax',(0,.03,.43),(.61,.58,.86),black)
    sphere(torso,'Narrow exposed abdominal tendons',(0,-.54,-.59),(.40,.36,.74),black)
    sphere(torso,'Raised hind pelvis',(0,-.40,-1.22),(.43,.40,.44),black)
    # Each asymmetrical plate is a separate anatomical mass, never a cylindrical band.
    for side in [-1,1]:
        def points(poly):return [(side*x,y,z) for x,y,z in poly]
        patch(torso,'Swept forward scapula',points([(.29,.72,.82),(.60,.79,.48),(.88,.40,.38),(.86,-.04,.74),(.59,-.25,1.14),(.29,.11,1.26)]),(side*.8,.3,.1),.12,bone)
        patch(torso,'Large irregular rib shield',points([(.69,.39,.40),(.82,.24,.14),(.78,-.19,-.22),(.55,-.55,-.20),(.40,-.63,.22),(.61,-.19,.64)]),(side,0,0),.16,bone)
        patch(torso,'Upper posterior thorax blade',points([(.32,.52,.26),(.61,.58,-.10),(.67,.24,-.49),(.41,-.02,-.56),(.35,.17,-.08)]),(side*.7,.6,0),.11,bone)
        patch(torso,'Separate pelvic crest',points([(.20,.08,-.95),(.48,.15,-1.19),(.62,-.23,-1.47),(.46,-.59,-1.63),(.28,-.67,-1.18)]),(side,0,0),.13,bone)
        for j in range(4):
            z=.08-j*.19
            tube(torso,'Intercostal exposed tendon',[(side*.51,-.27,z),(side*.48,-.46,z-.07),(side*.33,-.60,z-.11)],.029,steel)
        tube(torso,'Crimson lateral nerve',[(side*.66,.12,.48),(side*.64,-.16,.1),(side*.46,-.36,-.3),(side*.40,-.42,-.79)],.020,red)
        talon(torso,'Rearward hooked shoulder crest',[(side*.66,.60,.66),(side*.88,.91,.45),(side*.98,.89,.17)],[.14,.095,.002],bone)
    for j in range(7):
        z=.77-j*.30;y=.71-.045*j-.013*j*j
        sphere(torso,'Exposed elongated reactor lobe',(0,y+.03,z),(.18,.17,.195),red)
        for side in [-1,1]:
            talon(torso,'Blade shaped spinal vertebra',[(side*.20,y-.07,z+.09),(side*.29,y+.17,z-.02),(side*.26,y+.26,z-.20)],[.11,.076,.003],bone)
            tube(torso,'Black reactor retainer',[(side*.12,y-.10,z+.15),(side*.22,y,z),(side*.14,y+.02,z-.17)],.024,steel)
    socket(torso,'CoreSocket_Matriarch',(0,.83,.47))
    head=socket(torso,'ColossusHead',(0,.22,1.02))
    sphere(head,'Mechanical cranial underskull',(0,.03,.31),(.235,.195,.44),black)
    patch(head,'Ridged wedge cranial crown',[(-.29,.11,.02),(-.26,.29,.24),(-.10,.33,.56),(0,.17,.88),(.13,.25,.65),(.29,.20,.24),(.27,.04,-.05)],(0,1,0),.08,bone)
    talon(head,'Continuous ridged cranial bone',[(0,.05,-.03),(0,.11,.17),(0,.09,.40),(0,.0,.67),(0,-.015,.81)],[.18,.25,.21,.13,.055],bone)
    for side in [-1,1]:
        pts=lambda poly:[(side*x,y,z) for x,y,z in poly]
        patch(head,'Overlapping orbital skull guard',pts([(.17,.27,.08),(.34,.22,.19),(.34,.12,.47),(.17,.02,.65),(.17,.13,.31)]),(side,.25,0),.055,bone)
        tube(head,'Narrow recessed ruby eye',[(side*.337,.084,.17),(side*.354,.074,.29),(side*.315,.046,.42)],.018,red)
        patch(head,'Serrated cheek armour',pts([(.30,.034,.10),(.36,-.05,.20),(.25,-.25,.57),(.14,-.21,.75),(.19,-.01,.48)]),(side,0,0),.055,bone)
        talon(head,'Backward skull crown hook',[(side*.20,.21,.04),(side*.28,.43,-.13),(side*.18,.49,-.34)],[.095,.065,.002],bone)
        rod(head,'Jaw hinge actuator',(side*.29,-.12,.03),(side*.19,-.28,.35),.038,steel)
    patch(head,'Angular split nasal plate',[(-.15,.14,.58),(-.08,.19,.80),(0,.08,.98),(.13,.10,.86),(.17,.03,.64)],(0,.3,1),.035,bone)
    sphere(head,'Dark open mouth cavity',(0,-.16,.61),(.19,.10,.34),gum)
    patch(head,'Pointed lower jaw',[(-.21,-.23,.21),(-.17,-.32,.48),(-.08,-.26,.84),(0,-.21,.97),(.17,-.25,.66),(.22,-.20,.25)],(0,-1,0),.045,bone)
    for side in [-1,1]:
        for j in range(7):
            z=.35+j*.072;x=side*(.187-j*.011)
            talon(head,'Irregular upper skeletal fang',[(x,-.07,z),(x*.9,-.21-(.045 if j in [1,4] else 0),z+.025)],[.026,.002],bone)
            talon(head,'Lower interlocking tooth',[(x,-.25,z+.035),(x,-.14,z+.048)],[.021,.002],edge)
    # Massive forearm guards and long hooked metacarpal claws.
    for side,suffix in [(-1,'L'),(1,'R')]:
        arm=socket(torso,'ColossusArm_'+suffix,(side*.66,-.18,.76))
        elbow=(side*.23,-.93,-.26);wrist=(side*.30,-1.77,.31)
        rod(arm,'Forearm upper woven tendon',(0,0,0),elbow,.14,black)
        rod(arm,'Forearm lower woven tendon',elbow,wrist,.13,black)
        for y,z,r in [(0,0,.20),(-.93,-.26,.17)]:
            o=ns['ns']['cylinder'](arm,'Recessed rotary servo',(side*.20,y,z),r,.09,steel,axis='X')
        q=lambda poly:[(side*x,y,z) for x,y,z in poly]
        patch(arm,'Large pointed shoulder mantlet',q([(-.19,.13,.19),(.12,.30,.22),(.42,.12,.07),(.38,-.37,-.19),(.22,-.67,-.36),(-.02,-.48,-.17)]),(side,.3,0),.20,bone)
        patch(arm,'Heavy irregular foreclaw bracer',q([(.20,-.82,-.49),(.40,-.95,-.28),(.52,-1.44,.22),(.40,-1.90,.47),(.15,-1.88,.23),(.05,-1.33,-.27)]),(side,0,0),.16,bone)
        patch(arm,'Forward serrated gauntlet blade',q([(.0,-1.02,.01),(.30,-1.16,.25),(.45,-1.70,.61),(.19,-1.95,.45),(-.09,-1.62,.24)]),(0,0,1),.15,bone)
        fore_direction=(Vector(wrist)-Vector(elbow)).normalized()
        talon(arm,'Solid tapered gauntlet cortex',[Vector(elbow)+fore_direction*.23,Vector(elbow)+fore_direction*.48,Vector(wrist)-fore_direction*.08],[.18,.27,.19],bone)
        for k in range(3):
            x=side*.30+(k-1)*.16
            sphere(arm,'Individual talon knuckle',(x,-1.79,.42),(.082,.105,.12),steel)
            talon(arm,'Long hooked foreclaw',[(x,-1.77,.44),(x,-1.85,.73),(x,-2.02,.99),(x,-2.12,1.16),(x,-2.10,1.25)],[.092,.078,.050,.019,.001],edge)
            talon(arm,'Foreclaw ivory proximal sheath',[(x,-1.77,.44),(x,-1.85,.73),(x,-1.97,.91)],[.103,.086,.038],bone)
        for k in range(3):
            rod(arm,'Forearm exposed piston', (side*(.06+k*.10),-.87,-.22),(side*(.13+k*.10),-1.66,.22),.024,steel)
        socket(arm,'Muzzle'+('Left' if side<0 else 'Right')+'_Matriarch',(side*.24,-1.12,.20))
        leg=socket(root,'ColossusLeg_'+suffix,(side*.52,-.92,-1.18))
        knee=(side*.14,-.55,.34);hock=(side*.10,-1.16,-.09)
        sphere(leg,'Muscular rear thigh',(side*.08,-.20,.10),(.17,.29,.22),black)
        rod(leg,'Rear structural knee tendon',(0,0,0),knee,.17,black)
        rod(leg,'Digitigrade rear hock',knee,hock,.105,steel)
        q=lambda poly:[(side*x,y,z) for x,y,z in poly]
        patch(leg,'Irregular sculpted haunch shield',q([(-.07,.08,.04),(.24,.05,.10),(.40,-.24,.25),(.29,-.58,.47),(.09,-.66,.27),(-.10,-.26,-.10)]),(side,0,.1),.13,bone)
        patch(leg,'Rear knee spur',q([(.11,-.46,.40),(.26,-.56,.48),(.21,-.88,.27),(.02,-.76,.20)]),(side,0,.3),.07,bone)
        for k in range(3):
            x=side*.10+(k-1)*.12
            talon(leg,'Rear hooked ground claw',[(x,-1.37,.11),(x,-1.52,.34),(x,-1.66,.60)],[.067,.050,.002],edge)
    tail=socket(root,'ColossusTail',(0,-.60,-1.57))
    points=[(0,j*.024+j*j*.005,-j*.205) for j in range(12)]
    tube(tail,'Continuous segmented tail tendon',points,.070,black)
    for j,(x,y,z) in enumerate(points[:-1]):
        r=.15-j*.008
        patch(tail,'Angular tail vertebral guard',[(-r,y,z+.09),(-r*.8,y+r,z),(-r*.45,y+r*.8,z-.14),(r*.5,y+r*.8,z-.15),(r,y,z-.035),(r*.8,y-.05,z+.07)],(0,1,0),.025,bone)
    talon(tail,'Curved rear tail sting',[points[-2],points[-1],(0,1.0,-2.50)],[.090,.050,.001],edge)
    # Normals, UVs and material batching retain independently animated body sections.
    for o in list(scene.objects):
        if o.type=='CURVE':
            bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
    groups={}
    for o in list(scene.objects):
        if o.type!='MESH':continue
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
        groups.setdefault((o.parent.name,o.data.materials[0].name),[]).append(o)
    for key,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/campaign_bosses/warden.glb'),export_format='GLB',use_active_scene=True,export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/models/campaign_bosses/campaign_boss_workbench.blend'))
    print('SCULPTED MATRIARCH EXPORTED')
if __name__=='__main__':build()
