"""Reference-directed first boss: armoured rotary-gun trooper with twin thrusters.
Build in Blender through MCP. Source retains the other campaign boss scenes.
Godot Y up, camera +Z, gun points -X; mesh units are metres.
"""
import bpy, math
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/campaign_bosses'
base={'__name__':'boss_helpers','__file__':str(ROOT/'tools/build_campaign_bosses.py')}
exec(compile(Path(base['__file__']).read_text(),base['__file__'],'exec'),base)
p,material,box,sphere,cylinder,torus,plate,socket,finish=[base[k] for k in ['p','material','box','sphere','cylinder','torus','plate','socket','finish']]

def rod(root,name,a,b,radius,mat):
    middle=(Vector(a)+Vector(b))*.5
    o=cylinder(root,name,middle,radius,(Vector(b)-Vector(a)).length,mat,axis='Y')
    o.rotation_mode='QUATERNION';o.rotation_quaternion=(Vector(p(b))-Vector(p(a))).to_track_quat('Z','Y')
    return o

def tube(root,name,points,radius,mat):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=2
    spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
    for v,co in zip(spline.bezier_points,points):
        v.co=p(co);v.handle_left_type='AUTO';v.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,curve);bpy.context.scene.collection.objects.link(o);o.parent=root;curve.materials.append(mat)
    return o

def loft(root,name,sections,mat,edge=.025):
    # Rounded chamfered sections, front at +Z; designed cross-sections give curved armor.
    contour=[(-.64,1),(.64,1),(1,.62),(1,-.55),(.60,-1),(-.60,-1),(-1,-.55),(-1,.62)]
    verts=[]
    for cx,y,cz,rx,rz in sections:
        verts.extend([p((cx+x*rx,y,cz+z*rz)) for x,z in contour])
    n=8;faces=[tuple(reversed(range(n)))]
    for ring in range(len(sections)-1):
        for i in range(n):
            faces.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i))
    faces.append(tuple(range((len(sections)-1)*n,len(sections)*n)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(o);finish(o,root,mat,edge)
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    return o

def materials():
    mats={
      'armor':material('VANGUARD worn graphite armor',(.14,.18,.18),.72,.43),
      'plate':material('VANGUARD dark shoulder ceramic',(.075,.095,.105),.58,.46),
      'steel':material('VANGUARD exposed brushed steel',(.32,.37,.38),.86,.32),
      'dark':material('VANGUARD carbon undersuit',(.015,.024,.03),.15,.72),
      'bore':material('VANGUARD blued tungsten',(.025,.045,.055),.88,.31),
      'brass':material('VANGUARD ammunition brass',(.37,.24,.095),.8,.40),
      'mark':material('VANGUARD faded service markings',(.47,.48,.42),.4,.60),
      'red':material('VANGUARD red sensor',(.75,.009,.012),.2,.28,2.0),
      'blue':material('VANGUARD thruster ion blue',(.03,.55,1),.1,.23,3.0)}
    # Embedded UV wear and roughness maps, deterministic scuffs with restrained contrast.
    rng=np.random.default_rng(419);n=1024
    grit=rng.random((n,n)).astype(np.float32)
    wear=np.clip(.90+(grit-.5)*.1,0,1)
    for _ in range(2300):
        x,y=rng.integers(0,n,2);length=int(rng.integers(2,35))
        wear[y:y+1,x:min(n,x+length)]=rng.uniform(1.05,1.55)
    for key,col in [('armor',(.34,.39,.39)),('plate',(.22,.25,.27)),('steel',(.55,.60,.62))]:
        rgba=np.ones((n,n,4),dtype=np.float32);rgba[:,:,:3]=np.clip(wear[:,:,None]*np.array(col),0,1)
        tex=bpy.data.images.new('Vanguard_'+key+'_albedo',width=n,height=n);tex.pixels.foreach_set(rgba.ravel());tex.pack()
        tree=mats[key].node_tree;node=tree.nodes.new('ShaderNodeTexImage');node.image=tex;tree.links.new(node.outputs['Color'],tree.nodes.get('Principled BSDF').inputs['Base Color'])
    return mats

def build():
    name='CampaignBoss_apex_vanguard'
    if name in bpy.data.scenes:raise RuntimeError('Scene exists: '+name)
    scene=bpy.data.scenes.new(name);bpy.context.window.scene=scene
    root=bpy.data.objects.new('Apex_Vanguard_Root',None);scene.collection.objects.link(root)
    m=materials()
    # Human proportions, segmented armored torso and a broad asymmetric stance.
    torso=socket(root,'VanguardTorso',(0,.05,0))
    sphere(torso,'Woven pressure suit abdomen',(0,.15,0),(.59,.65,.34),m['dark'])
    for i in range(4):
        loft(torso,'Flexible abdominal armor',[(0,-.35+i*.16,.09,.40,.34),(0,-.26+i*.16,.09,.44,.35)],m['plate'],.016)
    loft(torso,'Sculpted cuirass',[(0,.35,-.015,.56,.38),(0,.85,-.01,.87,.43),(0,1.25,-.03,.81,.39),(0,1.39,-.02,.58,.34)],m['armor'],.04)
    plate(torso,'Left pectoral overlapping plate',[(-.79,1.20),(-.27,1.29),(-.12,1.04),(-.15,.68),(-.64,.62),(-.86,.91)],.45,.095,m['plate'])
    plate(torso,'Right pectoral overlapping plate',[(.26,1.29),(.76,1.16),(.86,.89),(.63,.58),(.14,.68),(.1,1.04)],.45,.095,m['plate'])
    plate(torso,'Chamfered sternum keel',[(-.17,1.31),(.16,1.31),(.25,.72),(0,.48),(-.23,.72)],.49,.11,m['armor'])
    plate(torso,'Left cuirass edge', [(-.84,.91),(-.72,.76),(-.62,.65),(-.18,.67),(-.18,.63),(-.66,.58),(-.81,.72)],.516,.028,m['steel'])
    plate(torso,'Right cuirass edge',[(.81,.89),(.72,.70),(.59,.59),(.16,.66),(.16,.63),(.62,.54),(.78,.67)],.516,.028,m['steel'])
    for side in [-1,1]:
        for i in range(3):
            box(torso,'Intercostal armored ribs',(side*.53,.15+i*.14,.34),(.30,.09,.08),m['steel'],.014,rot=side*.14)
        for x,y in [(side*.64,1.1),(side*.67,.75)]:
            cylinder(torso,'Cuirass recessed bolt',(x,y,.51),.028,.024,m['steel'])
        box(torso,'Chest faded IFF stripe',(side*.58,1.0,.516),(.16,.035,.012),m['mark'],.003)
        sphere(torso,'Collar shoulder seal',(side*.54,1.25,-.02),(.19,.18,.26),m['dark'])
    cylinder(torso,'Raised neck gasket',(0,1.40,0),.24,.18,m['dark'],axis='Y')
    torus(torso,'Armored collar',(0,1.37,.02),.30,.035,m['steel'],tilt=math.pi/2)
    # Angular enclosed helmet with cheek flanges, split red optics and respirator grille.
    head=socket(torso,'VanguardHead',(0,1.57,.015))
    loft(head,'Contoured helmet shell',[(0,-.13,-.02,.25,.27),(0,.10,-.04,.37,.32),(0,.42,-.05,.36,.32),(0,.57,-.06,.23,.22)],m['armor'],.025)
    plate(head,'Visor recessed cavity',[(-.31,.29),(-.23,.41),(.25,.40),(.33,.27),(.23,.10),(-.24,.11)],.297,.04,m['bore'])
    plate(head,'Left ruby visor',[(-.27,.28),(-.035,.245),(-.045,.17),(-.23,.20)],.324,.012,m['red'])
    plate(head,'Right ruby visor',[(.035,.245),(.27,.28),(.23,.20),(.045,.17)],.324,.012,m['red'])
    plate(head,'Forehead central ridge',[(-.10,.58),(.12,.56),(.17,.36),(.06,.23),(-.09,.28),(-.17,.40)],.295,.11,m['plate'])
    plate(head,'Armored nasal bridge',[(-.058,.28),(.058,.28),(.1,.07),(0,-.04),(-.1,.07)],.36,.065,m['steel'])
    for side in [-1,1]:
        plate(head,'Flared helmet jaw',[(side*.30,.18),(side*.38,.10),(side*.29,-.17),(side*.12,-.21),(side*.13,.015)],.26,.14,m['plate'])
        cylinder(head,'Helmet comm receiver',(side*.36,.24,.0),.10,.09,m['dark'],axis='X')
        plate(head,'Cheek machined highlight',[(side*.31,.1),(side*.26,-.10),(side*.17,-.15),(side*.19,-.09)],.344,.02,m['steel'])
    for i in range(5):
        box(head,'Respirator grille',((i-2)*.037,-.11,.34),(.018,.13,.025),m['dark'],.004)
    box(head,'Helmet rank etching',(.12,.45,.38),(.055,.022,.007),m['mark'],.001)
    # Pelvis armor, utility belt and hip pouches, no blocky toy joints.
    loft(root,'Armored pelvic girdle',[(0,-.7,-.04,.52,.3),(0,-.38,-.03,.63,.33),(0,-.28,-.03,.54,.34)],m['dark'],.035)
    plate(root,'Pelvic protective apron',[(-.42,-.37),(.44,-.36),(.32,-.73),(0,-.93),(-.30,-.74)],.32,.10,m['armor'])
    for side in [-1,1]:
        box(root,'Utility belt pouch',(side*.55,-.40,.18),(.23,.34,.30),m['plate'],.035)
        box(root,'Belt pouch clasp',(side*.55,-.34,.34),(.09,.08,.026),m['steel'],.009)
    # Broad stance: posed anatomy with layered thigh, kneecap, calf and armored boot.
    for side in [-1,1]:
        hip=(side*.43,-.62,0)
        leg=socket(root,'VanguardLeg_'+('L' if side<0 else 'R'),hip)
        kx=side*.26;ky=-.75;kz=.13 if side<0 else -.03
        ankle=(side*.55,-1.77,kz-.07)
        sphere(leg,'Thigh undersuit',(side*.10,-.40,.03),(.29,.55,.28),m['dark'])
        loft(leg,'Tapered thigh armor',[(side*.02,-.06,.02,.28,.28),(side*.12,-.30,.01,.34,.30),(kx,-.63,kz,.27,.25)],m['armor'],.035)
        plate(leg,'Thigh inset shield',[(side*.02-side*.18,-.13),(side*.02+side*.20,-.10),(kx+side*.20,-.54),(kx-side*.16,-.57)],.30,.07,m['plate'])
        sphere(leg,'Recessed knee joint',(kx,ky,kz),(.23,.24,.23),m['dark'])
        loft(leg,'Kneecap impact shell',[(kx,ky-.18,kz+.10,.17,.23),(kx,ky+.03,kz+.14,.27,.27),(kx,ky+.19,kz+.08,.21,.23)],m['plate'],.025)
        box(leg,'Knee wear edge',(kx,ky+.035,kz+.41),(.28,.035,.02),m['steel'],.005)
        rod(leg,'Tibial structural spine',(kx,ky-.08,kz),(ankle[0],ankle[1],ankle[2]),.14,m['dark'])
        loft(leg,'Sculpted shin armor',[(ankle[0],-1.73,kz-.05,.22,.23),(side*.45,-1.47,kz,.26,.26),(kx,ky-.18,kz,.22,.24)],m['armor'],.03)
        plate(leg,'Shin forward ridge',[(kx-side*.05,ky-.25),(kx+side*.075,ky-.28),(ankle[0]+side*.10,-1.63),(ankle[0]-side*.05,-1.63)],kz+.29,.055,m['plate'])
        rod(leg,'Calf chrome actuator',(kx-side*.20,ky-.20,kz+.04),(ankle[0]-side*.20,-1.61,kz+.04),.032,m['steel'])
        for j in range(3):
            box(leg,'Ankle flexible gaiter',(ankle[0],-1.72-j*.04,kz),(.38,.025,.41),m['dark'],.005)
        loft(leg,'Armored grounded boot',[(ankle[0],-1.98,.12+kz,.31,.43),(ankle[0],-1.91,.14+kz,.34,.49),(ankle[0],-1.75,.09+kz,.24,.32)],m['plate'],.04)
        box(leg,'Boot steel toe cap',(ankle[0],-1.86,kz+.50),(.47,.14,.11),m['armor'],.04)
        for j in range(3):
            box(leg,'Boot traction cleat',(ankle[0],-1.975,kz-.12+j*.23),(.56,.035,.09),m['dark'],.008)
    # Left arm holds the gun; the right gauntlet forms a lowered fist.
    for side in [-1,1]:
        arm=socket(torso,'VanguardArm_'+('L' if side<0 else 'R'),(side*.85,1.09,0))
        sphere(arm,'Shoulder servo',(side*.04,-.08,0),(.23,.26,.26),m['dark'])
        loft(arm,'Curved layered pauldron',[(side*.04,.25,0,.22,.30),(side*.09,.13,.0,.38,.40),(side*.10,-.13,.015,.40,.40),(side*.13,-.27,.02,.30,.34)],m['plate'],.045)
        plate(arm,'Shoulder armored lip',[(side*.10-side*.30,.06),(side*.10+side*.28,.08),(side*.13+side*.27,-.19),(side*.13-side*.25,-.22)],.40,.045,m['steel'])
        upper_end=(side*.22,-.69,.10)
        rod(arm,'Upper arm muscle sleeve',(side*.12,-.23,.02),upper_end,.18,m['dark'])
        loft(arm,'Upper arm armor',[(side*.14,-.23,.02,.23,.24),(side*.20,-.5,.08,.23,.22),(side*.22,-.66,.1,.17,.18)],m['armor'],.028)
        sphere(arm,'Elbow joint',upper_end,(.19,.19,.20),m['dark'])
        # Both wrists in front of body; left closer to trigger group.
        wrist=(.32 if side>0 else .15,-1.13,.30 if side>0 else .65)
        rod(arm,'Forearm pressure sleeve',upper_end,wrist,.16,m['dark'])
        rod(arm,'Forearm armor gauntlet',(upper_end[0],upper_end[1]-.12,upper_end[2]+.1),(wrist[0],wrist[1]+.10,wrist[2]-.07),.23,m['armor'])
        sphere(arm,'Armored glove',wrist,(.19,.18,.16),m['plate'])
        for i in range(4):
            box(arm,'Gauntlet finger plate',(wrist[0]+(i-1.5)*.065,wrist[1]-.09,wrist[2]+.13),(.051,.16,.045),m['steel'],.009)
    # Rotary cannon integrated into the hands; long sleeved barrels point towards approach.
    gun=socket(torso,'VanguardGun',(-.8,-.09,.72))
    box(gun,'Rotary gun receiver',(.20,0,0),(.80,.38,.42),m['plate'],.06)
    cylinder(gun,'Rotary motor housing',(-.35,0,0),.26,.54,m['armor'],axis='X')
    box(gun,'Receiver top rail',(.0,.21,0),(.75,.055,.17),m['steel'],.012)
    for i in range(6):
        a=i*math.tau/6;y=math.cos(a)*.155;z=math.sin(a)*.155
        cylinder(gun,'Six tungsten barrels',(-1.09,y,z),.057,1.03,m['bore'],axis='X')
        cylinder(gun,'Machined muzzle bore',(-1.62,y,z),.071,.052,m['steel'],axis='X')
        cylinder(gun,'Deep dark bore',(-1.65,y,z),.042,.012,m['dark'],axis='X')
    for x in [-.63,-1.37]:
        cylinder(gun,'Rotary retaining collar',(x,0,0),.235,.07,m['plate'],axis='X')
    cylinder(gun,'Central rotary spindle',(-1.09,0,0),.063,1.12,m['steel'],axis='X')
    for i in range(4):
        box(gun,'Motor cooling slat',(-.29+i*.11,.12,.257),(.045,.22,.025),m['dark'],.006)
    rod(gun,'Forward carry handle',(-.43,.39,-.03),(.06,.39,-.03),.035,m['dark'])
    rod(gun,'Handle front bracket',(-.43,.21,-.03),(-.43,.39,-.03),.04,m['steel'])
    rod(gun,'Handle back bracket',(.06,.21,-.03),(.06,.39,-.03),.04,m['steel'])
    box(gun,'Trigger grip',(.30,-.29,-.04),(.14,.32,.16),m['dark'],.025)
    cylinder(gun,'Ammo drum',(.30,-.03,-.35),.29,.36,m['plate'])
    torus(gun,'Ammo drum stamped rim',(.30,-.03,-.55),.235,.025,m['steel'])
    socket(gun,'MuzzleLeft_Vanguard',(-1.70,.0,.0))
    socket(gun,'MuzzleRight_Vanguard',(-1.70,.1,.0))
    # Belt-fed chain sweeps from receiver to hip with individual brass cartridges.
    for i in range(18):
        t=i/17;angle=math.pi*t
        x=-.52-.52*math.sin(angle);y=-.04-.82*math.sin(angle);z=.75-.4*t
        cylinder(torso,'Linked brass ammunition',(x,y,z),.045,.19,m['brass'],axis='Y')
        box(torso,'Steel ammo chain link',(x,y+.025,z),(.11,.034,.12),m['dark'],.008)
    # Tall twin rear thrusters with layered armor, vents and blue exhaust sockets.
    for side in [-1,1]:
        pack=socket(torso,'VanguardThruster_'+('L' if side<0 else 'R'),(side*.9,1.05,-.47))
        loft(pack,'Thruster armored nacelle',[(0,-.67,0,.24,.24),(0,-.48,0,.33,.31),(0,.88,0,.31,.32),(0,1.06,0,.23,.26)],m['plate'],.045)
        box(pack,'Thruster outer spine',(side*.24,.15,.03),(.12,1.4,.29),m['armor'],.035)
        for i in range(7):
            box(pack,'Thruster cooling vents',(side*.29,-.30+i*.15,.21),(.11,.065,.14),m['steel'],.008)
        plate(pack,'Thruster sloping cap',[(-.25,.86),(-.16,1.10),(.19,1.04),(.28,.88)],.31,.08,m['armor'])
        cylinder(pack,'Thruster nozzle',(0,-.71,.0),.18,.30,m['bore'],axis='Y')
        cylinder(pack,'Nozzle armored lip',(0,-.87,0),.23,.09,m['steel'],axis='Y')
        cylinder(pack,'Blue ion chamber',(0,-.92,0),.145,.024,m['blue'],axis='Y')
        socket(pack,'ThrusterSocket_'+('L' if side<0 else 'R'),(0,-.96,0))
        for i in range(3):
            box(pack,'Faded pack service stencil',(side*.02,.58-i*.075,.33),(.13,.025,.01),m['mark'],.002)
    tube(torso,'Backpack service hose',[(-.6,.82,-.67),(-.97,.7,-.66),(-.91,.21,-.45),(-.53,.05,-.21)],.045,m['dark'])
    tube(torso,'Arm hydraulic hose',[(-.77,1.04,-.15),(-1.14,.75,-.19),(-1.13,.38,.1),(-.91,.22,.30)],.027,m['steel'])
    socket(torso,'CoreSocket_Vanguard',(0,.8,.58))
    # UV unwrap so embedded worn surfaces export correctly.
    for o in root.children_recursive:
        if o.type=='MESH':
            bpy.context.view_layer.objects.active=o;o.select_set(True)
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    return root

def export():
    scene=bpy.data.scenes['CampaignBoss_apex_vanguard'];bpy.context.window.scene=scene
    root=bpy.data.objects['Apex_Vanguard_Root'];OUT.mkdir(exist_ok=True,parents=True)
    # Combine geometry by material within movable groups to keep runtime draw calls reasonable.
    for o in list(root.children_recursive):
        if o.type=='CURVE':
            bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
    groups={}
    for o in root.children_recursive:
        if o.type=='MESH':
            groups.setdefault((o.parent.name,o.data.materials[0].name),[]).append(o)
    for (parent,mat),objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        # Apply bevels before joining; retain authored local pivots.
        for o in objects:
            bpy.context.view_layer.objects.active=o
            for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name=parent+'__'+mat
    bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
    for o in root.children_recursive:o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/'apex.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_animations=False,export_yup=True,export_lights=False,export_cameras=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'campaign_boss_workbench.blend'))
    deps=bpy.context.evaluated_depsgraph_get();triangles=0
    for o in root.children_recursive:
        if o.type=='MESH':
            e=o.evaluated_get(deps);mesh=e.to_mesh();mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles);e.to_mesh_clear()
    print('VANGUARD EXPORTED',len(root.children_recursive),'nodes',triangles,'triangles')

if __name__=='__main__':build();export()
