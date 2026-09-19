"""Reference-based enemy assets. Run inside Blender via MCP, one build at a time."""
import bpy, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector

OUT = Path('/home/clau/Godot/games/space-ranger/assets/models/reference_enemies')
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW = Path('/home/clau/Godot/games/space-ranger/tools/blender_previews/reference_enemies')
PREVIEW.mkdir(parents=True, exist_ok=True)
M = {}

def setup():
    # UV texture is packed into the blend and embedded in every exported GLB.
    rng = np.random.default_rng(932)
    n = 1024
    grit = rng.random((n,n)).astype(np.float32)
    wear = np.full((n,n), .92, dtype=np.float32) + (grit-.5)*.10
    for _ in range(1500):
        x,y = rng.integers(0,n,2); length = int(rng.integers(2,45))
        wear[y:y+1,x:min(n,x+length)] = rng.uniform(.20,.62)
    for _ in range(1200):
        x,y = rng.integers(0,n,2); d = int(rng.integers(1,6))
        wear[y:min(n,y+d),x:min(n,x+d)] = rng.uniform(.25,.65)
    pixels = np.ones((n,n,4),dtype=np.float32)
    pixels[:,:,:3] = wear[:,:,None]
    im = bpy.data.images.new('SR_ArmorWear_1024',width=n,height=n)
    im.pixels.foreach_set(pixels.ravel()); im.pack()
    for name,color,metal,rough in [('ceramic',(.66,.62,.52),.62,.43),('dark',(.045,.052,.058),.8,.36),('steel',(.26,.29,.31),.9,.29),('edge',(.48,.49,.46),.85,.3),('rubber',(.012,.016,.02),.1,.65),('brass',(.43,.24,.065),.8,.3)]:
        mat=bpy.data.materials.new('REF_'+name); mat.use_nodes=True
        bs=mat.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value=(*color,1)
        bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
        if name in ['ceramic','dark','steel']:
            # Precolored images keep the wear visible in glTF without shader baking.
            tex=bpy.data.images.new('SR_'+name+'_Wear',width=n,height=n)
            rgba=pixels.copy(); rgba[:,:,:3]*=np.array(color)
            tex.pixels.foreach_set(rgba.ravel()); tex.pack()
            node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=tex
            mat.node_tree.links.new(node.outputs['Color'],bs.inputs['Base Color'])
        M[name]=mat
    for name,col in [('red',(.5,.001,.004)),('orange',(.7,.12,.002)),('violet',(.20,.003,.7))]:
        mat=bpy.data.materials.new('REF_'+name); mat.use_nodes=True
        bs=mat.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*col,1)
        bs.inputs['Emission Color'].default_value=(*col,1); bs.inputs['Emission Strength'].default_value=1.1
        bs.inputs['Metallic'].default_value=.25; bs.inputs['Roughness'].default_value=.23; M[name]=mat
    bpy.context.scene.render.engine='CYCLES'
    bpy.context.scene.cycles.samples=32
    bpy.context.scene.render.resolution_x=1400; bpy.context.scene.render.resolution_y=1000
    bpy.context.scene.render.resolution_percentage=100
    bpy.context.scene.world.color=(.12,.12,.12)
    bpy.context.scene.view_settings.view_transform='AgX'

def root(name):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); return o

def finish(o,name,mat,parent,bevel=0):
    o.name=name; o.parent=parent; o.data.materials.append(M[mat])
    if bevel:
        b=o.modifiers.new('Machined edge radii','BEVEL'); b.width=bevel; b.segments=3
        b=o.modifiers.new('Face weighted normals','WEIGHTED_NORMAL'); b.keep_sharp=True
    if o.type=='MESH':
        for p in o.data.polygons: p.use_smooth = len(p.vertices)==4 and 'ring' in name.lower()
    return o

def box(p,name,loc,size,mat='dark',rot=(0,0,0),bevel=.015):
    bpy.ops.mesh.primitive_cube_add(location=loc,rotation=rot)
    o=bpy.context.object; o.scale=Vector(size)/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,p,bevel)

def cyl(p,name,loc,r,depth,mat='steel',axis=(0,0,1),vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc)
    o=bpy.context.object; o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    for poly in o.data.polygons: poly.use_smooth=len(poly.vertices)==4
    return finish(o,name,mat,p,.006)

def ring(p,name,loc,r,thickness,mat='edge',axis=(0,0,1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=thickness,major_segments=32,minor_segments=8,location=loc)
    o=bpy.context.object; o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    for poly in o.data.polygons: poly.use_smooth=True
    return finish(o,name,mat,p)

def link(p,name,a,b,r=.025,mat='steel'):
    a,b=Vector(a),Vector(b); return cyl(p,name,(a+b)/2,r,(b-a).length,mat,b-a)

def plate(p,name,outline,y,depth,mat='ceramic'):
    # Extruded bespoke silhouette, expressed as X/Z profile.
    verts=[(x,y+side*depth/2,z) for side in [-1,1] for x,z in outline]; n=len(outline)
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o)
    finish(o,name,mat,p,.012)
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.025); bpy.ops.object.mode_set(mode='OBJECT'); o.select_set(False)
    return o

def cable(p,name,points,mat='rubber',r=.015):
    curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='3D'; curve.bevel_depth=r; curve.bevel_resolution=2
    s=curve.splines.new('BEZIER'); s.bezier_points.add(len(points)-1)
    for v,co in zip(s.bezier_points,points): v.co=co; v.handle_left_type='AUTO'; v.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,curve); bpy.context.collection.objects.link(o); o.parent=p; curve.materials.append(M[mat]); return o

def bolts(p,loc,r,axis=(0,0,1),count=8):
    # For horizontal or vertical circular faces.
    loc=Vector(loc); axis=Vector(axis).normalized(); u=axis.cross(Vector((0,0,1)))
    if u.length<.1: u=Vector((1,0,0))
    u.normalize(); v=axis.cross(u)
    for i in range(count):
        a=2*math.pi*i/count; co=loc+r*(u*math.cos(a)+v*math.sin(a))
        cyl(p,'Hex fastener',co,.014,.012,'steel',axis,6)

def vent(p,x,y,z,w,h,color='red',count=5):
    box(p,'Recessed heat exchanger',(x,y,z),(w,.06,h),'rubber')
    for i in range(count):
        xx=x-w*.38+i*w*.76/(count-1)
        box(p,'Luminous cooling channel',(xx,y-.033,z),(.015,.012,h*.77),color,bevel=.003)
        box(p,'Cooling fin',(xx+.021,y-.041,z),(.02,.02,h*.88),'steel',bevel=.003)

def barrel(p,x,y,z,length,r,color):
    # +X facing, actual recessed bore with concentric machined rings.
    cyl(p,'Cannon breech',(x-length/2,y,z),r*1.3,length*.55,'dark',(1,0,0))
    cyl(p,'Cannon tube',(x-length*.25,y,z),r*.66,length*.6,'steel',(1,0,0))
    for t in [.06,.22,.4,.58]: ring(p,'Barrel collar',(x-length*t,y,z),r*.78,.012,'edge',(1,0,0))
    cyl(p,'Deep black muzzle bore',(x-.038,y,z),r*.79,.022,'rubber',(1,0,0))
    ring(p,'Hollow muzzle rim',(x,y,z),r,.021,'edge',(1,0,0))
    ring(p,'Plasma bore ring',(x-.02,y,z),r*.65,.008,color,(1,0,0))
    box(p,'Barrel armored rail',(x-length*.32,y,z+r*.92),(length*.65,r*.8,.055),'dark')
    box(p,'Barrel energy strip',(x-length*.32,y-r*.65,z+r*.9),(length*.55,.009,.018),color,bevel=.003)

def build_crawler():
    p=root('RIFT_Crawler');
    box(p,'Spinal drive chassis',(-.12,0,.49),(.86,.36,.24),'dark',bevel=.07)
    for x in [-.42,-.23,-.04,.15]:
        cyl(p,'Segmented vertebra',(x,0,.53),.155,.12,'steel',(1,0,0))
        ring(p,'Red spinal power ring',(x+.052,0,.53),.156,.012,'red',(1,0,0))
        plate(p,'Swept dorsal blade',[(x-.065,.64),(x-.10,.78),(x-.005,.84),(x+.10,.70),(x+.08,.62)],0,.07)
        box(p,'Dorsal warning strip',(x,0,.755),(.025,.079,.085),'red',rot=(0,-.35,0),bevel=.003)
    plate(p,'Predator upper skull',[(.19,.61),(.38,.70),(.58,.65),(.82,.44),(.63,.48),(.35,.51)],0,.29)
    for s in [-1,1]:
        y=s*.15
        plate(p,'Blade jaw',[(.37,.47),(.63,.39),(.76,.23),(.53,.32),(.37,.35)],y,.05,'steel')
        cyl(p,'Eye bezel',(.58,y+s*.015,.48),.073,.025,'dark',(0,s,0))
        ring(p,'Eye lens ring',(.58,y+s*.036,.48),.055,.008,'edge',(0,s,0))
        cyl(p,'Red optical lens',(.58,y+s*.042,.48),.046,.013,'red',(0,s,0))
        cable(p,'Exposed red power cable',[(-.4,s*.19,.57),(-.08,s*.24,.48),(.32,s*.19,.48)],'red',.009)
        for rear in [True,False]:
            x=-.43 if rear else .17
            hip=(x,s*.20,.51); knee=(x-.13 if rear else x+.15,s*.30,.29); ankle=(x-.08 if rear else x+.35,s*.34,.07)
            leg=root(('Rear' if rear else 'Front')+('_near' if s==-1 else '_far')); leg.parent=p
            for co,rr in [(hip,.089),(knee,.065),(ankle,.038)]:
                cyl(leg,'Articulated joint',co,rr,.075,'dark',(0,1,0))
                ring(leg,'Joint bearing ring',(co[0],co[1]+s*.045,co[2]),rr*.76,.009,'steel',(0,1,0))
                cyl(leg,'Joint axle',(co[0],co[1]+s*.05,co[2]),rr*.38,.016,'steel',(0,1,0))
            link(leg,'Upper actuator',hip,knee,.039,'dark'); link(leg,'Lower piston',knee,ankle,.022,'steel')
            a=Vector(hip); b=Vector(knee); mid=(a+b)/2
            box(leg,'Upper leg ceramic shield',mid,(.095,.093,.20),'ceramic',rot=(0,-.4 if rear else .45,0),bevel=.025)
            mid=(Vector(knee)+Vector(ankle))/2
            box(leg,'Shin armor',mid,(.06,.08,.14),'ceramic',rot=(0,.2 if rear else .65,0))
            link(leg,'Hydraulic return',Vector(hip)+Vector((.025,s*.035,0)),Vector(ankle)+Vector((-.025,s*.02,.02)),.012)
            for t in [-1,0,1]:
                yy=ankle[1]+t*.045
                plate(leg,'Curved talon',[(ankle[0]-.015,.08),(ankle[0]+.06,.09),(ankle[0]+.13,.025),(ankle[0]+.14,.003),(ankle[0]+.055,.035)],yy,.024,'steel')
            cable(leg,'Hydraulic hose',[hip,(x-.08,s*.29,.37),knee],'rubber',.012)
            for frame,angle in [(1,0),(9,.12 if rear else -.12),(17,0),(25,-.12 if rear else .12),(33,0)]:
                leg.rotation_euler.y=angle*s; leg.keyframe_insert('rotation_euler',frame=frame)
            if leg.animation_data: leg.animation_data.action.name='Idle'
    return p

def build_turret():
    p=root('SENTRY_Turret'); base=root('AnchoredBase'); base.parent=p
    cyl(base,'Bolted footing',(0,0,.055),.49,.11,'dark')
    cyl(base,'Foundation armor',(0,0,.15),.405,.16,'ceramic')
    ring(base,'Foundation steel trim',(0,0,.10),.455,.018)
    bolts(base,(0,0,.116),.445,count=12)
    cyl(base,'Yaw bearing',(0,0,.275),.31,.09,'steel')
    ring(base,'Amber yaw ring',(0,0,.308),.288,.011,'orange')
    for i in range(8):
        a=i*math.pi/4
        box(base,'Foundation brace',(.39*math.cos(a),.39*math.sin(a),.16),(.12,.055,.15),'steel',rot=(0,0,a),bevel=.008)
    head=root('AimingHead'); head.parent=p
    box(head,'Gimbal neck',(0,0,.39),(.18,.27,.22),'dark')
    box(head,'Weapon receiver',(.0,0,.58),(.42,.43,.30),'dark',bevel=.04)
    for s in [-1,1]:
        plate(head,'Receiver side armor',[(-.23,.50),(-.22,.73),(.12,.75),(.23,.64),(.18,.50)],s*.23,.045)
        cyl(head,'Elevation gearbox',(-.06,s*.245,.45),.105,.045,'steel',(0,1,0))
        ring(head,'Elevation bearing',(-.06,s*.276,.45),.08,.012,'edge',(0,1,0))
        bolts(head,(-.06,s*.281,.45),.062,(0,1,0),6)
        box(head,'Ammunition cassette',(-.17,s*.345,.60),(.24,.16,.27),'dark')
        box(head,'Cassette face armor',(-.17,s*.435,.60),(.20,.025,.22),'ceramic')
        for j in range(5): cyl(head,'Exposed brass cell',(-.025,s*.347,.515+j*.038),.014,.11,'brass',(0,1,0),12)
        cable(head,'Flexible ammunition conduit',[(-.25,s*.32,.54),(-.30,s*.30,.38),(-.08,s*.20,.35)],r=.018)
        barrel(head,.66,s*.11,.58,.52,.06,'orange')
        box(head,'Muzzle shroud',(.51,s*.11,.58),(.20,.15,.14),'ceramic')
        box(head,'Shroud status slit',(.51,s*.19,.58),(.105,.012,.02),'orange',bevel=.003)
    cyl(head,'Target optic housing',(.20,0,.745),.067,.055,'dark',(1,0,0))
    ring(head,'Target optic bezel',(.231,0,.745),.056,.009,'edge',(1,0,0))
    cyl(head,'Amber sensor',(.236,0,.745),.044,.012,'orange',(1,0,0))
    return p

def build_gunship():
    p=root('HEAVY_Gunship')
    box(p,'Central avionics hull',(-.05,0,0),(1.10,.54,.40),'dark',bevel=.085)
    plate(p,'Angular nose armor',[(.1,.23),(.45,.20),(.72,-.02),(.58,-.18),(.22,-.16)],0,.42)
    box(p,'Dorsal ceramic plate',(-.23,0,.235),(.57,.37,.06),'ceramic',bevel=.035)
    for s in [-1,1]:
        y=s*.46
        box(p,'Engine armored nacelle',(-.25,y,.03),(.77,.34,.42),'dark',bevel=.055)
        box(p,'Engine ceramic cap',(-.29,y,.25),(.58,.29,.06),'ceramic',bevel=.025)
        cyl(p,'Rear thruster recess',(-.66,y,.04),.145,.10,'rubber',(1,0,0))
        ring(p,'Thruster machined rim',(-.72,y,.04),.146,.024,'steel',(1,0,0))
        ring(p,'Violet engine ring',(-.728,y,.04),.106,.014,'violet',(1,0,0))
        cyl(p,'Engine luminous core',(-.715,y,.04),.082,.008,'violet',(1,0,0))
        for i in range(8):
            a=i*math.pi/4
            box(p,'Thruster radial vane',(-.73,y+.12*math.cos(a),.04+.12*math.sin(a)),(.035,.015,.045),'steel',rot=(a,0,0),bevel=.003)
        # Swept polygon wings in the horizontal plane.
        outline=[(-.50,s*.52),(-.62,s*.97),(-.29,s*.90),(.12,s*.56)]
        verts=[(x,yy,z) for z in [.025,.065] for x,yy in outline]
        mesh=bpy.data.meshes.new('Swept wing'); mesh.from_pydata(verts,[],[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
        o=bpy.data.objects.new('Swept ceramic wing',mesh); bpy.context.collection.objects.link(o); finish(o,o.name,'ceramic',p,.014)
        plate(p,'Dorsal stabilizer',[(-.49,.22),(-.56,.46),(-.35,.42),(-.20,.22)],s*.32,.028,'steel')
        vent(p,-.18,-abs(y)-.18,.04,.34,.24,'violet',4) if s==-1 else None
        cyl(p,'Underslung gun gimbal',(.02,y,-.22),.085,.12,'steel',(0,1,0))
        barrel(p,.72,y,-.26,.66,.055,'violet')
        cable(p,'Gun power feed',[(-.3,y,-.16),(-.20,y,-.32),(.02,y,-.29)],r=.016)
        for j in range(4): box(p,'Hull service hatch',(-.40+j*.16,s*.281,-.045),(.11,.015,.11),'steel',bevel=.004)
    cyl(p,'Command sensor bezel',(.67,0,.05),.059,.045,'dark',(1,0,0))
    cyl(p,'Violet command eye',(.697,0,.05),.044,.015,'violet',(1,0,0))
    return p

def build_boss():
    p=root('APEX_Dreadnought')
    box(p,'Fortress central chassis',(-.15,0,0),(2.20,1.45,.83),'dark',bevel=.12)
    box(p,'Layered upper deck',(-.25,0,.47),(1.87,1.30,.12),'steel',bevel=.04)
    for s in [-1,1]:
        y=s*.87
        box(p,'Siege weapon sponson',(-.15,y,-.03),(1.75,.49,.62),'dark',bevel=.08)
        for j in range(3):
            x=-.80+j*.53
            plate(p,'Overlapping fortress armor',[(x-.25,.15),(x-.23,.42),(x+.13,.46),(x+.26,.29),(x+.20,.09)],y+s*.23,.065)
            vent(p,x,-abs(y)-.29,-.18,.36,.30,'red',5) if s==-1 else None
            for z in [.2,.34]: cyl(p,'Armor rivet',(x,y+s*.272,z),.018,.014,'steel',(0,1,0),6)
        barrel(p,1.68,y,-.14,1.53,.12,'red')
        box(p,'Siege barrel outer armor',(.98,y,-.02),(.91,.26,.12),'dark',bevel=.03)
        # Antigravity turbines under each armored section.
        for x in [-.83,-.16,.48]:
            cyl(p,'Antigravity turbine',(x,y,-.43),.22,.14,'steel')
            ring(p,'Antigravity red ring',(x,y,-.512),.17,.019,'red')
            cyl(p,'Antigravity core',(x,y,-.505),.115,.025,'red')
            for k in range(6):
                a=k*math.pi/3
                link(p,'Turbine hanging strut',(x+.15*math.cos(a),y+.15*math.sin(a),-.48),(x+.12*math.cos(a),y+.12*math.sin(a),-.65),.012,'dark')
        cable(p,'Siege power trunk',[(-.75,y,-.20),(-.1,y+s*.19,-.33),(.57,y,-.21)],'rubber',.035)
        cable(p,'Red high voltage conduit',[(-.65,y,.19),(-.13,y+s*.14,.21),(.52,y,.10)],'red',.012)
    # Side-facing reactor is readable from the gameplay camera.
    for s in [-1,1]:
        y=s*1.16
        cyl(p,'Reactor armored socket',(.18,y,.08),.34,.10,'dark',(0,1,0))
        for rr,th,mat in [(.32,.025,'steel'),(.265,.017,'red'),(.22,.021,'edge')]: ring(p,'Reactor containment ring',(.18,y+s*.065,.08),rr,th,mat,(0,1,0))
        cyl(p,'Exposed red reactor',(.18,y+s*.067,.08),.185,.06,'red',(0,1,0))
        bolts(p,(.18,y+s*.09,.08),.295,(0,1,0),12)
        for j in range(3):
            x=-.49+j*.43
            plate(p,'Gothic crown fin',[(x-.13,.48),(x-.08,.97+(j==1)*.17),(x+.035,1.08+(j==1)*.17),(x+.13,.50)],s*.40,.065)
            box(p,'Crown red channel',(x,s*.44,.64),(.018,.014,.25),'red',bevel=.003)
        plate(p,'Forward armored mandible',[(.54,.18),(.95,.08),(1.06,-.48),(.85,-.34),(.63,-.05)],s*.52,.13)
    box(p,'Front spread emitter',(.995,0,-.08),(.16,.56,.43),'dark',bevel=.035)
    for j in range(5): box(p,'Spread emitter aperture',(1.082,-.20+j*.1,-.08),(.015,.025,.26),'red',bevel=.004)
    for x in [-.9,-.5,0,.45]:
        for s in [-1,1]: box(p,'Deck ceramic panel',(x,s*.22,.56),(.30,.29,.045),'ceramic',bevel=.012)
    return p

BUILDERS={'crawler':build_crawler,'turret':build_turret,'gunship':build_gunship,'boss':build_boss}
ROOTS={}

def export_asset(kind):
    p=BUILDERS[kind](); ROOTS[kind]=p
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT'); p.select_set(True)
    for o in p.children_recursive: o.select_set(True)
    bpy.context.view_layer.objects.active=p
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='ACTIONS',export_yup=True)
    deps=bpy.context.evaluated_depsgraph_get(); tris=0
    for o in p.children_recursive:
        if o.type=='MESH':
            mesh=o.evaluated_get(deps).to_mesh(); mesh.calc_loop_triangles(); tris+=len(mesh.loop_triangles); o.evaluated_get(deps).to_mesh_clear()
    print('ASSET_EXPORTED',kind,'triangles',tris,'objects',len(p.children_recursive))
    return p

def render_asset(kind):
    p=ROOTS[kind]
    for o in bpy.data.objects:
        o.hide_render = o != p and o not in p.children_recursive
    # Isolated studio rig, excluded from asset exports.
    rigs=[]
    size={'crawler':1.7,'turret':1.45,'gunship':2.0,'boss':3.9}[kind]
    target=Vector((0,0,.35 if kind in ['crawler','turret'] else .08))
    bpy.ops.object.camera_add(location=target+Vector((size*1.3,-size*2.1,size*1.15)))
    cam=bpy.context.object; rigs.append(cam); cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=size*1.65
    bpy.context.scene.camera=cam
    for loc,power,color,scale in [((1,-3,4),280,(.86,.91,1),4),((-3,1,2),420,(.60,.72,1),3),((3,3,3),350,(1,.70,.45),2)]:
        bpy.ops.object.light_add(type='AREA',location=Vector(loc)*size*.6); l=bpy.context.object; rigs.append(l); l.data.energy=power*size; l.data.color=color; l.data.shape='DISK'; l.data.size=scale*size*.5; l.rotation_euler=(target-l.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.scene.render.film_transparent=True
    bpy.context.scene.render.filepath=str(PREVIEW/(kind+'.png')); bpy.ops.render.render(write_still=True)
    for o in rigs: bpy.data.objects.remove(o,do_unlink=True)
    print('PREVIEW_RENDERED',kind)

def save_workbench():
    for i,(kind,p) in enumerate(ROOTS.items()):
        p.location.y=i*3.7
        for o in [p]+list(p.children_recursive): o.hide_render=False
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL'
            area.spaces.active.region_3d.view_distance=13
            area.spaces.active.region_3d.view_location=(0,5,.2)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'reference_enemy_workbench.blend'))
    print('WORKBENCH_SAVED')

def stencil(p,text,loc,size=.055,rot=(math.pi/2,0,0)):
    bpy.ops.object.text_add(location=loc,rotation=rot)
    o=bpy.context.object; o.data.body=text; o.data.size=size; o.data.extrude=.0003
    o.data.align_x='CENTER'; o.parent=p; o.data.materials.append(M['dark']); o.name='Factory stencil '+text

def polish(kind):
    p=ROOTS[kind]
    if kind=='crawler':
        for s in [-1,1]:
            for x in [-.43,.17]:
                plate(p,'Layered shoulder carapace',[(x-.13,.52),(x-.14,.68),(x-.03,.73),(x+.10,.64),(x+.15,.50),(x+.02,.43)],s*.255,.058)
                plate(p,'Shoulder inlaid armor',[(x-.105,.59),(x-.06,.69),(x+.075,.61),(x+.12,.53)],s*.292,.014,'steel')
                for j in range(3):
                    xx=x-.085+j*.07
                    cyl(p,'Shoulder recessed screw',(xx,s*.303,.61),.009,.010,'dark',(0,1,0),6)
                cable(p,'Shoulder braided return',[(x-.15,s*.23,.50),(x-.20,s*.30,.38),(x-.1,s*.28,.31)],r=.008)
            for x in [-.35,-.12,.11]:
                box(p,'Segment side armor',(x,s*.21,.49),(.13,.025,.10),'steel',rot=(0,-.1,0),bevel=.01)
                for j in range(3): link(p,'Segment cooling pipe',(x-.04+j*.03,s*.23,.43),(x-.04+j*.03,s*.23,.54),.006,'brass')
            plate(p,'Swept skull cheek',[(.29,.57),(.50,.61),(.68,.52),(.52,.49),(.33,.50)],s*.166,.025)
            for j in range(3): box(p,'Skull cooling slit',(.38+j*.04,s*.183,.55),(.012,.012,.052),'rubber',rot=(0,.4,0),bevel=.002)
            # A hooked jaw tip is much clearer than a flat wedge in silhouette.
            plate(p,'Hooked predator fang',[(.66,.39),(.73,.34),(.73,.16),(.70,.21),(.67,.29)],s*.12,.024,'edge')
        stencil(p,'RIFT / 07',(-.27,-.29,.65),.036)
        # Move leg origins to their hip joints and keep their children in place.
        for leg in [o for o in p.children if o.type=='EMPTY']:
            hip=Vector((-.43 if 'Rear' in leg.name else .17,-.2 if 'near' in leg.name else .2,.51))
            leg.animation_data_clear()
            for o in leg.children: o.location-=hip
            leg.location=hip
    elif kind=='turret':
        base=next(o for o in p.children if o.name.startswith('AnchoredBase'))
        head=next(o for o in p.children if o.name.startswith('AimingHead'))
        for i in range(12):
            a=i*math.pi/6
            xx,yy=.42*math.cos(a),.42*math.sin(a)
            box(base,'Inset footing panel',(xx,yy,.17),(.067,.045,.088),'dark',rot=(0,0,a),bevel=.005)
            box(base,'Footing amber locator',(xx*1.025,yy*1.025,.235),(.054,.012,.014),'orange',rot=(0,0,a),bevel=.002)
        for s in [-1,1]:
            plate(head,'Receiver layered shell',[(-.21,.73),(-.12,.80),(.04,.80),(.16,.72),(.13,.66),(-.09,.69)],s*.26,.025)
            for j in range(4): box(head,'Receiver cooling inset',(-.16+j*.05,s*.278,.737),(.018,.012,.051),'rubber',bevel=.002)
            for j in range(4):
                box(head,'Ammo charge indicator',(-.22,s*.454,.53+j*.032),(.037,.009,.008),'orange',bevel=.002)
            box(head,'Ammo armored strap',(-.11,s*.455,.60),(.027,.015,.22),'steel',bevel=.003)
            for xx in [-.24,-.1,.10]: cyl(head,'Receiver torx screw',(xx,s*.27,.53),.012,.010,'dark',(0,1,0),6)
            link(head,'Elevation hydraulic ram',(-.13,s*.17,.34),(.14,s*.17,.55),.020,'steel')
        stencil(head,'SENTRY\n03',(-.08,-.28,.585),.043)
    elif kind=='gunship':
        for s in [-1,1]:
            y=s*.46
            # Large violet intake apertures, squared rims and dark recessed vanes.
            box(p,'Engine front dark intake',(.155,y,.04),(.022,.26,.29),'rubber',bevel=.032)
            for z in [-.12,.20]: box(p,'Intake horizontal armored rim',(.18,y,z),(.095,.33,.042),'steel',bevel=.014)
            for yy in [y-.155,y+.155]: box(p,'Intake vertical armored rim',(.18,yy,.04),(.095,.037,.30),'steel',bevel=.012)
            for j in range(4):
                zz=-.071+j*.07
                box(p,'Violet intake vanes',(.168,y,zz),(.016,.24,.019),'violet',bevel=.003)
                box(p,'Intake shadow separator',(.19,y,zz+.026),(.04,.24,.024),'dark',bevel=.003)
            plate(p,'Nacelle side layered armor',[(-.59,.12),(-.48,.22),(-.12,.24),(.06,.15),(-.05,.06),(-.49,.025)],y+s*.183,.03)
            for xx in [-.49,-.32,-.15]: cyl(p,'Nacelle flush fastener',(xx,y+s*.202,.12),.009,.01,'dark',(0,1,0),6)
            cable(p,'External engine plumbing',[(-.5,y+s*.16,-.12),(-.24,y+s*.20,-.16),(.04,y+s*.12,-.11)],r=.014)
            for j in range(5): box(p,'Dorsal engine exhaust slots',(-.46+j*.065,y,.283),(.018,.17,.009),'rubber',bevel=.002)
            for xx in [-.52,-.3]:
                cyl(p,'Wing pivot hardware',(xx,s*.62,.08),.027,.012,'steel')
            for j in range(3): link(p,'Underslung coolant pipes',(-.50,y-.045+j*.045,-.2),(-.17,y-.045+j*.045,-.2),.008,'steel')
        plate(p,'Split nose upper armor',[(.18,.255),(.40,.24),(.59,.10),(.34,.16)],0,.23)
        stencil(p,'HG-09',(-.25,0,.271),.065,rot=(0,0,-math.pi/2))
    elif kind=='boss':
        for s in [-1,1]:
            for j in range(3):
                x=-.78+j*.52
                plate(p,'Sponson secondary shield',[(x-.23,.13),(x-.19,.23),(x+.15,.17),(x+.22,-.08),(x+.12,-.13),(x-.15,-.05)],s*1.14,.044)
                for k in range(4): box(p,'Shield recessed radiator',(x-.12+k*.07,s*1.17,.07),(.016,.013,.085),'rubber',bevel=.002)
                for zz in [-.01,.16]: cyl(p,'Shield armor bolt',(x-.16,s*1.175,zz),.014,.012,'steel',(0,1,0),6)
                cable(p,'Armored conduit loop',[(x-.2,s*1.08,-.22),(x-.06,s*1.15,-.35),(x+.16,s*1.08,-.22)],r=.022)
            for j in range(6):
                xx=-.83+j*.31
                box(p,'Deck segmented armored rib',(xx,0,.50),(.04,1.40,.044),'dark',bevel=.006)
                for yy in [-.57,.57]: cyl(p,'Deck captive bolt',(xx,yy,.535),.016,.018,'edge',vertices=6)
            # Crown shaped reinforcement around the exposed reactor.
            for xx in [-.2,.56]:
                plate(p,'Reactor protective claw',[(xx-.1,.30),(xx+.035,.38),(xx+.16,.10),(xx+.08,-.19),(xx-.05,-.07)],s*1.235,.058)
            for j in range(4):
                xx=-.8+j*.35
                plate(p,'Upper deck interlocking armor',[(xx-.12,.56),(xx-.1,.66),(xx+.10,.63),(xx+.14,.55)],s*.66,.19)
            for xx in [-.94,-.44]:
                cyl(p,'Missile launch socket',(xx,s*.20,.62),.075,.045,'dark')
                ring(p,'Missile launch red status',(xx,s*.20,.652),.05,.008,'red')
                cyl(p,'Missile shutter',(xx,s*.20,.65),.035,.012,'rubber')
            for j in range(4):
                xx=.61+j*.23
                box(p,'Siege barrel armor sleeve',(xx,s*.87,-.10),(.16,.24,.18),'steel',bevel=.02)
                box(p,'Siege barrel red side channel',(xx,s*1.0,-.08),(.10,.012,.026),'red',bevel=.003)
            stencil(p,'APEX / 001',(-.7,-1.18,.30),.066)
        cyl(p,'Top reactor platform',(.18,0,.57),.34,.10,'dark')
        ring(p,'Top reactor containment',(.18,0,.63),.28,.024,'steel')
        ring(p,'Top reactor luminous rim',(.18,0,.64),.23,.013,'red')
        cyl(p,'Top reactor iris',(.18,0,.639),.19,.025,'red')
        bolts(p,(.18,0,.65),.30,count=12)
    print('POLISHED',kind)

def optimize_export(kind):
    p=ROOTS[kind]
    # Join geometry per movable parent and material. Retain the authored hierarchy.
    groups={}
    for o in list(p.children_recursive):
        if o.type not in ['MESH','CURVE','FONT']: continue
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
        bpy.ops.object.convert(target='MESH')
        for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        mat=o.data.materials[0].name if o.data.materials else 'none'
        groups.setdefault((o.parent,mat),[]).append(o)
    for (parent,mat),obs in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs: o.select_set(True)
        bpy.context.view_layer.objects.active=obs[0]
        if len(obs)>1: bpy.ops.object.join()
        o=obs[0]; o.name=(parent.name if parent else kind)+'_'+mat
        # Smooth cylinder sidewalls without softening broad armor panels.
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.ops.object.select_all(action='DESELECT'); p.select_set(True)
    for o in p.children_recursive: o.select_set(True)
    bpy.context.view_layer.objects.active=p
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_yup=True)
    print('FINAL_EXPORT',kind,'mesh batches',len(groups))

def final_lenses(kind):
    p=ROOTS[kind]
    if kind=='crawler':
        for s in [-1,1]:
            ring(p,'Optical focusing iris',(.58,s*.202,.48),.030,.006,'dark',(0,1,0))
            cyl(p,'Hot eye pupil',(.58,s*.21,.48),.012,.012,'orange',(0,1,0))
    elif kind=='turret':
        head=next(o for o in p.children if o.name.startswith('AimingHead'))
        ring(head,'Sensor inner iris',(.247,0,.745),.029,.005,'dark',(1,0,0))
        cyl(head,'Sensor hot pupil',(.251,0,.745),.017,.008,'orange',(1,0,0))
    elif kind=='boss':
        for s in [-1,1]:
            yy=s*1.26
            ring(p,'Reactor inner dark iris',(.18,yy,.08),.142,.017,'dark',(0,1,0))
            ring(p,'Reactor inner luminous iris',(.18,yy+s*.012,.08),.095,.012,'red',(0,1,0))
            cyl(p,'Reactor central dark hub',(.18,yy+s*.02,.08),.054,.023,'dark',(0,1,0))
            ring(p,'Reactor hub light',(.18,yy+s*.04,.08),.033,.007,'red',(0,1,0))
            for i in range(12):
                a=i*math.pi/6
                xx=.18+.171*math.cos(a); zz=.08+.171*math.sin(a)
                box(p,'Reactor segmented iris blade',(xx,yy,zz),(.042,.025,.012),'steel',rot=(0,-a+.5,0),bevel=.003)
    print('FINAL_OPTICS',kind)

def reexport_existing(kind):
    p=ROOTS[kind]; p.location=(0,0,0)
    bpy.ops.object.select_all(action='DESELECT'); p.select_set(True)
    for o in p.children_recursive: o.select_set(True)
    bpy.context.view_layer.objects.active=p
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_yup=True)
    print('REFRESHED',kind)

def create_asset_library():
    setup()
    for kind in BUILDERS:
        ROOTS[kind]=BUILDERS[kind]()
        polish(kind)
        final_lenses(kind)
        optimize_export(kind)
        render_asset(kind)
    save_workbench()
