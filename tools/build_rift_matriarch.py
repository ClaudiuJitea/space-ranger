"""Blender reference rebuild: RIFT Alpha Matriarch quadrupedal biomechanical predator."""
import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
ns={'__name__':'beast_helpers','__file__':str(ROOT/'tools/build_apex_vanguard.py')}
exec(compile(Path(ns['__file__']).read_text(),ns['__file__'],'exec'),ns)
p,material,sphere,socket,rod,tube=[ns[k] for k in ['p','material','sphere','socket','rod','tube']]

def shell(root,name,sections,mat):
    verts=[];faces=[];n=25
    for z,y,rx,ry in sections:
        for i in range(n):
            a=-2.38+i/(n-1)*4.76
            verts.append(p((math.sin(a)*rx,y+math.cos(a)*ry+.018*math.cos(a*3),z+.055*math.cos(a*2)+.025*math.sin(a*3))))
    for j in range(len(sections)-1):
        for i in range(n-1):faces.append((j*n+i,j*n+i+1,(j+1)*n+i+1,(j+1)*n+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.parent=root;mesh.materials.append(mat)
    for f in mesh.polygons:f.use_smooth=True
    mod=obj.modifiers.new('Forged curved carapace thickness','SOLIDIFY');mod.thickness=.035
    mod=obj.modifiers.new('Rounded organic edges','BEVEL');mod.width=.018;mod.segments=3
    return obj

def talon(root,name,points,radii,mat):
    verts=[];faces=[];n=12
    for j,co in enumerate(points):
        tangent=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)])).normalized()
        u=tangent.cross(Vector((0,1,0)))
        if u.length<.01:u=tangent.cross(Vector((1,0,0)))
        u.normalize();v=tangent.cross(u).normalized()
        for i in range(n):verts.append(p(Vector(co)+radii[j]*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))))
    for j in range(len(points)-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    faces.extend([tuple(reversed(range(n))),tuple(range((len(points)-1)*n,len(points)*n))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(o);o.parent=root;mesh.materials.append(mat)
    for f in mesh.polygons:f.use_smooth=True
    return o

def build():
    previous=bpy.data.scenes.get('CampaignBoss_Rift_Matriarch')
    if previous: previous.name='CampaignBoss_Rift_Matriarch_Draft'
    scene=bpy.data.scenes.new('CampaignBoss_Rift_Matriarch');bpy.context.window.scene=scene
    root=socket(None,'Rift_Matriarch_Root',(0,0,0));root.rotation_euler.z=-math.pi/2
    ivory=material('MATRIARCH warm ivory ceramic',(.62,.60,.49),.28,.53)
    import numpy as np
    rng=np.random.default_rng(128);n=512
    grain=.92+rng.random((n,n))*.12
    rgba=np.ones((n,n,4),dtype=np.float32);rgba[:,:,:3]=grain[:,:,None]*np.array([.66,.64,.55])
    image=bpy.data.images.new('Matriarch fine ceramic grain',width=n,height=n);image.pixels.foreach_set(rgba.ravel());image.pack()
    tree=ivory.node_tree;tex=tree.nodes.new('ShaderNodeTexImage');tex.image=image;tree.links.new(tex.outputs['Color'],tree.nodes.get('Principled BSDF').inputs['Base Color'])
    rim=material('MATRIARCH aged carapace edges',(.33,.34,.28),.45,.58)
    dark=material('MATRIARCH woven tendon graphite',(.025,.035,.041),.3,.63)
    steel=material('MATRIARCH brushed biomechanical steel',(.055,.075,.085),.75,.52)
    claw=material('MATRIARCH tungsten talons',(.33,.38,.39),.86,.32)
    red=material('MATRIARCH exposed ruby spine',(.65,.007,.025),.32,.33,1.8)
    # Long load-bearing thorax and smaller raised rear pelvis.
    torso=socket(root,'ColossusTorso',(0,-.35,0))
    sphere(torso,'Muscular forward thorax',(0,-.08,.40),(.58,.46,1.03),dark)
    sphere(torso,'Tapered abdominal undersuit',(0,-.27,-.72),(.41,.33,.79),dark)
    for j,(z,w,h) in enumerate([(.80,.78,.63),(.19,.69,.67),(-.40,.60,.62),(-.96,.50,.50),(-1.37,.44,.42)]):
        shell(torso,'Overlapping sculpted dorsal carapace %d'%j,[(z+.30,0,w*.88,h*.86),(z+.12,0,w,h),(z-.15,-.02,w*.93,h*.93),(z-.31,-.06,w*.90,h*.87)],ivory)
        # Spine chambers remain exposed above the shell, alternating ceramic vertebra guards.
        sphere(torso,'Exposed red spinal chamber %d'%j,(0,h+.06,z),(.16,.16,.27),red)
        for side in [-1,1]:
            talon(torso,'Swept dorsal vertebra hook',[(side*.22,h-.05,z-.10),(side*.30,h+.22,z-.24),(side*.31,h+.34,z-.38)],[.10,.07,.005],ivory)
            tube(torso,'Lateral rib tendon',[(side*w*.91,-.04,z+.17),(side*w,-.21,z),(side*w*.82,-.41,z-.14)],.038,steel)
    socket(torso,'CoreSocket_Matriarch',(0,.80,.0))
    # Long skull points forward horizontally; eyes are recessed in the lateral brow.
    head=socket(torso,'ColossusHead',(0,-.14,1.05))
    sphere(head,'Predator skull pressure seal',(0,0,.35),(.29,.23,.66),dark)
    shell(head,'Swept cranial crown',[(0,.08,.31,.26),(.25,.07,.47,.34),(.58,.02,.38,.27),(.90,-.04,.23,.16),(1.10,-.08,.16,.12)],ivory)
    for side in [-1,1]:
        sphere(head,'Inset red predator eye',(side*.416,.12,.39),(.033,.045,.13),red)
        talon(head,'Raised eye brow ridge',[(side*.44,.18,.16),(side*.46,.21,.39),(side*.31,.15,.70)],[.065,.07,.025],ivory)
        talon(head,'Backward swept skull horn',[(side*.29,.25,.03),(side*.34,.51,-.15),(side*.24,.63,-.43)],[.12,.075,.005],ivory)
        tube(head,'Jaw hydraulic tendon',[(side*.34,-.09,.20),(side*.32,-.22,.47),(side*.20,-.26,.88)],.045,steel)
        for j in range(6):
            z=.36+j*.11
            talon(head,'Upper interlocking fang',[(side*(.29-j*.023),-.14,z),(side*(.27-j*.022),-.28,z+.045)],[.035,.002],claw)
    shell(head,'Lower predator jaw',[(.26,-.36,.25,.085),(.55,-.34,.27,.09),(.84,-.29,.19,.075),(1.06,-.24,.11,.045)],rim)
    # Heavy forelimbs and smaller digitigrade hind legs, with real curved finger silhouettes.
    for side,suffix in [(-1,'L'),(1,'R')]:
        arm=socket(torso,'ColossusArm_'+suffix,(side*.65,-.16,.72))
        elbow=(side*.25,-.87,-.22);wrist=(side*.16,-1.83,.42)
        rod(arm,'Forelimb tendon upper',(0,0,0),elbow,.20,dark)
        rod(arm,'Forelimb tendon lower',elbow,wrist,.155,dark)
        sphere(arm,'Elbow swivel',elbow,(.20,.20,.20),steel)
        # Curved armour panels are oriented along the anatomical limb, not front-facing slabs.
        cap=shell(arm,'Curved forward shoulder hood',[(.31,0,.28,.31),(.10,.035,.37,.36),(-.22,-.04,.29,.26)],ivory)
        upper=shell(arm,'Broad upper forelimb carapace',[(.36,0,.24,.23),(.10,0,.32,.30),(-.26,-.01,.28,.28),(-.57,-.05,.18,.19)],ivory)
        upper_direction=Vector(elbow).normalized()
        upper.location=p(Vector(elbow)*.5+upper_direction*.105)
        upper.rotation_mode='QUATERNION';upper.rotation_quaternion=Vector(p(upper_direction)).to_track_quat('-Y','Z')
        fore=shell(arm,'Long tapered forearm carapace',[(.30,0,.22,.20),(.04,0,.28,.25),(-.43,-.025,.20,.19),(-.65,-.05,.10,.10)],ivory)
        fore_direction=(Vector(wrist)-Vector(elbow)).normalized()
        fore.location=p((Vector(elbow)+Vector(wrist))*.5+fore_direction*.175)
        fore.rotation_mode='QUATERNION';fore.rotation_quaternion=Vector(p(fore_direction)).to_track_quat('-Y','Z')
        rod(arm,'Forearm exposed hydraulic piston',(side*.12,-.83,.33),(side*.11,-1.74,.59),.045,claw)
        sphere(arm,'Articulated talon palm',wrist,(.24,.17,.27),dark)
        for digit in range(3):
            x=wrist[0]+(digit-1)*.16
            talon(arm,'Long curved foreclaw',[(x,-1.79,.57),(x,-1.90,.79),(x,-2.02,.98),(x,-2.05,1.09)],[.072,.055,.027,.003],claw)
        # Forearm vent sockets preserve the real combat projectile origins.
        socket(arm,'Muzzle'+('Left' if side<0 else 'Right')+'_Matriarch',(side*.22,-1.10,.40))
        leg=socket(root,'ColossusLeg_'+suffix,(side*.53,-.85,-1.22))
        knee=(side*.16,-.69,.26);hock=(side*.13,-1.34,-.17)
        sphere(leg,'Muscular digitigrade thigh',(side*.10,-.28,.08),(.24,.40,.28),dark)
        rod(leg,'Rear upper tendon',(0,0,0),knee,.18,dark)
        rod(leg,'Rear hock actuator',knee,hock,.12,steel)
        cap=shell(leg,'Rear curved thigh guard',[(.37,0,.21,.23),(.10,.02,.34,.36),(-.21,-.08,.23,.24)],ivory);cap.location=p((side*.07,-.32,.02));cap.rotation_euler.x=math.pi/2
        sphere(leg,'Rear grounded palm',(side*.13,-1.59,.09),(.19,.15,.28),dark)
        for digit in range(3):
            x=side*.13+(digit-1)*.12
            talon(leg,'Rear grounded claw',[(x,-1.55,.21),(x,-1.69,.43),(x,-1.73,.58)],[.055,.035,.002],claw)
    tail=socket(root,'ColossusTail',(0,-.69,-1.57))
    for j in range(10):
        z=-j*.24;y=.035*j+.008*j*j
        sphere(tail,'Segmented tail tendon',(0,y,z),(.135-j*.009,.13-j*.008,.18),dark)
        shell(tail,'Overlapping tail vertebra',[(z+.13,y,.17-j*.011,.14-j*.010),(z,y,.19-j*.012,.17-j*.012),(z-.12,y+.025,.13-j*.008,.12-j*.008)],ivory if j%2 else rim)
    tube(tail,'Continuous flexible tail tendon',[(0,.035*j+.008*j*j,-j*.24) for j in range(10)]+[(0,1.04,-2.24)],.065,dark)
    talon(tail,'Swept tail sting',[(0,1.04,-2.24),(0,1.32,-2.49),(0,1.40,-2.77)],[.11,.065,.003],claw)
    # Physical boots/claws touch the existing arena floor at root Y -2.6.
    for o in list(scene.objects):
        if o.type=='MESH':
            bpy.context.view_layer.objects.active=o;o.select_set(True)
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    # Merge each moving body part by material to avoid hundreds of draw calls.
    for o in list(scene.objects):
        if o.type=='CURVE':
            bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
    groups={}
    for o in scene.objects:
        if o.type=='MESH':groups.setdefault((o.parent.name,o.data.materials[0].name),[]).append(o)
    for key,objects in groups.items():
        for o in objects:
            bpy.context.view_layer.objects.active=o
            for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/campaign_bosses/warden.glb'),export_format='GLB',use_active_scene=True,export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/models/campaign_bosses/campaign_boss_workbench.blend'))
    print('RIFT MATRIARCH EXPORTED')
if __name__=='__main__':build()
