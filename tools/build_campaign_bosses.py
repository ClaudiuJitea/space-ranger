"""Three original campaign bosses, built through Blender MCP in separate scenes.
Godot metres, Y up, Z=0 combat plane; presentation faces camera +Z.
Standalone rebuild: blender --background --python tools/build_campaign_bosses.py
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/campaign_bosses'


def p(v): return (v[0], -v[2], v[1])


def material(name, color, metal=0.6, rough=0.38, emission=0):
    m=bpy.data.materials.new(name); m.use_nodes=True; m.diffuse_color=(*color,1)
    shader=m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Metallic'].default_value=metal
    shader.inputs['Roughness'].default_value=rough
    if emission:
        shader.inputs['Emission Color'].default_value=(*color,1)
        shader.inputs['Emission Strength'].default_value=emission
    return m


def begin(kind):
    name='CampaignBoss_'+kind
    if bpy.data.scenes.get(name): raise RuntimeError('Scene already exists: '+name)
    scene=bpy.data.scenes.new(name); bpy.context.window.scene=scene
    root=bpy.data.objects.new(kind+'_Root',None); scene.collection.objects.link(root)
    themes={'apex':((0.14,0.21,0.25),(1,0.37,0.06)),
            'warden':((0.10,0.07,0.18),(0.63,0.17,1)),
            'seraph':((0.07,0.09,0.12),(1,0.16,0.035))}
    armor,color=themes[kind]
    mats={'armor':material(kind+'_ceramic',armor,.45,.43),
          'steel':material(kind+'_titanium',(.47,.56,.60),.82,.30),
          'dark':material(kind+'_carbon',(.018,.027,.035),.25,.56),
          'bone':material(kind+'_ivory',(.66,.67,.58),.45,.42),
          'trim':material(kind+'_copper',(.47,.28,.13),.75,.38),
          'energy':material(kind+'_reactor',color,.1,.28,3),
          'mark':material(kind+'_markings',color,.3,.45)}
    return root,mats


def finish(obj,root,mat,edge=.035):
    obj.parent=root; obj.data.materials.append(mat)
    if edge:
        b=obj.modifiers.new('Machined bevels','BEVEL'); b.width=edge; b.segments=2
        obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    obj.select_set(False)
    return obj


def box(root,name,pos,dims,mat,edge=.035,rot=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p(pos)); o=bpy.context.object; o.name=name
    o.dimensions=(dims[0],dims[2],dims[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.rotation_euler.y=-rot
    return finish(o,root,mat,edge)


def sphere(root,name,pos,size,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=p(pos))
    o=bpy.context.object; o.name=name; o.scale=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for face in o.data.polygons: face.use_smooth=True
    return finish(o,root,mat,0)


def cylinder(root,name,pos,radius,depth,mat,axis='Z',top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=radius,radius2=radius if top is None else top,depth=depth,location=p(pos))
    o=bpy.context.object; o.name=name
    # Cone's local Z is Godot Y by default; aim along Godot Z or X as needed.
    if axis=='Z': o.rotation_euler.x=math.pi/2
    elif axis=='X': o.rotation_euler.y=math.pi/2
    return finish(o,root,mat,.015)


def torus(root,name,pos,radius,thickness,mat,tilt=0):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,major_radius=radius,minor_radius=thickness,location=p(pos))
    o=bpy.context.object; o.name=name; o.rotation_euler.x=math.pi/2+tilt
    return finish(o,root,mat,0)


def plate(root,name,outline,z,thickness,mat):
    # Extruded polygon, sculpted silhouette rather than stacked unshaped boxes.
    n=len(outline)
    vertices=[p((x,y,depth)) for depth in [z-thickness/2,z+thickness/2] for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.scene.collection.objects.link(o)
    finish(o,root,mat,.035)
    # Recompute outward normals for mirrored outlines as well.
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT'); o.select_set(False)
    return o


def socket(root,name,pos):
    o=bpy.data.objects.new(name,None); o.parent=root; o.location=p(pos); bpy.context.scene.collection.objects.link(o)
    return o


def build_apex():
    r,m=begin('apex')
    plate(r,'Angular siege breastplate',[(-1.1,-.65),(-1.25,.7),(-.75,1.25),(.75,1.25),(1.25,.7),(1.1,-.65),(.55,-1),(-.55,-1)],.15,1.2,m['armor'])
    cylinder(r,'Armored core socket',(0,.2,.85),.64,.16,m['dark'])
    torus(r,'Reactor containment',(0,.2,.96),.58,.08,m['steel'])
    sphere(r,'Exposed amber reactor',(0,.2,.94),(.43,.43,.18),m['energy'])
    plate(r,'Crowned command helmet',[(-.63,1.35),(-.76,1.8),(-.35,2.3),(.35,2.3),(.76,1.8),(.63,1.35)],.05,.9,m['steel'])
    box(r,'Command visor',(0,1.68,.53),(1.0,.10,.055),m['energy'],.012)
    for side in [-1,1]:
        plate(r,'Layered shoulder',[(side*1.03,.55),(side*1.15,1.45),(side*1.95,1.25),(side*2.35,.60),(side*2.17,.1),(side*1.5,.18)],.03,1.35,m['bone'])
        sphere(r,'Shoulder gimbal',(side*1.5,.36,0),(.34,.34,.43),m['dark'])
        box(r,'Hydraulic forearm',(side*1.9,-.5,.12),(.74,1.15,1.0),m['armor'],.09)
        cylinder(r,'Rotary siege housing',(side*1.9,-.55,.25),.39,.95,m['steel'],axis='X')
        # Three barrels point toward the approaching player on the left.
        for angle in [0,math.tau/3,math.tau*2/3]:
            y=-.55+math.cos(angle)*.18; z=.25+math.sin(angle)*.18
            cylinder(r,'Rotary barrel',(side*1.9-.65,y,z),.09,1.1,m['dark'],axis='X')
            cylinder(r,'Hot bore lip',(side*1.9-1.21,y,z),.10,.05,m['trim'],axis='X')
        socket(r,'MuzzleLeft' if side<0 else 'MuzzleRight',(side*1.9-1.23,-.55,.25))
        box(r,'Upper leg',(side*.65,-1.37,-.05),(.63,.72,.68),m['dark'],.05)
        plate(r,'Shin armor',[(side*.32,-1.6),(side*.95,-1.55),(side*1.06,-2.27),(side*.37,-2.37)],.18,.75,m['steel'])
        box(r,'Magnetic siege foot',(side*.69,-2.46,.25),(.9,.25,1.15),m['armor'],.06)
        for y in [.75,.95,1.15]:
            box(r,'Shoulder vent',(side*1.62,y,.75),(.43,.075,.045),m['dark'],.008)
        cylinder(r,'Back turbine',(side*.66,-.1,-.9),.28,.7,m['dark'])
        torus(r,'Back turbine lip',(side*.66,-.1,-1.25),.22,.04,m['trim'])
    for x in [-.75,.75]: box(r,'Reactor armor seam',(x,.23,.80),(.06,.72,.06),m['mark'],.01)
    socket(r,'CoreSocket',(0,.2,1.05))
    return r


def build_warden():
    r,m=begin('warden')
    sphere(r,'Suspended reactor heart',(0,0,.05),(.80,.80,.63),m['dark'])
    sphere(r,'Violet singularity lens',(0,0,.66),(.52,.52,.19),m['energy'])
    torus(r,'Inner iris',(0,0,.75),.67,.07,m['steel'])
    rotor=socket(r,'ReactorRotor',(0,0,0))
    torus(rotor,'Orbital containment crown',(0,0,0),1.45,.11,m['bone'])
    torus(rotor,'Outer violet circuit',(0,0,.10),1.60,.035,m['energy'])
    torus(r,'Tilted containment orbit',(0,0,-.12),1.20,.08,m['trim'],.65)
    for i in range(6):
        a=i*math.tau/6
        x=math.cos(a)*1.68; y=math.sin(a)*1.68
        box(rotor,'Orbit armor segment',(x,y,0),(.68,.36,.55),m['armor'],.06,rot=a)
        box(rotor,'Orbit luminous node',(x,y,.32),(.22,.08,.04),m['energy'],.015,rot=a)
    for side in [-1,1]:
        plate(r,'Guardian crescent',[(side*1.55,-1.42),(side*2.28,-1.02),(side*2.62,.45),(side*2.1,1.8),(side*1.48,2.12),(side*1.83,.68),(side*1.8,-.65)],-.10,.6,m['steel'])
        sphere(r,'Beam pod gimbal',(side*2.05,-.82,.35),(.42,.42,.40),m['dark'])
        cylinder(r,'Prismatic beam pod',(side*2.05,-.82,.35),.24,.95,m['armor'],axis='X')
        torus(r,'Beam pod iris',(side*2.05,-.82,.65),.18,.035,m['energy'])
        socket(r,'MuzzleLeft' if side<0 else 'MuzzleRight',(side*2.05-.50,-.82,.35))
        for y in [-.25,.15,.55]:
            box(r,'Crescent etching',(side*2.23,y,.24),(.08,.25,.04),m['energy'],.008)
    plate(r,'Obsidian crown',[(-.52,1.5),(-.26,2.65),(0,2.35),(.26,2.65),(.52,1.5)],-.14,.45,m['armor'])
    plate(r,'Suspended keel',[(-.5,-1.55),(-.20,-2.50),(0,-2.18),(.20,-2.50),(.5,-1.55)],-.1,.35,m['bone'])
    socket(r,'CoreSocket',(0,0,.85))
    return r


def build_seraph():
    r,m=begin('seraph')
    plate(r,'Seraph armored spine',[(-.65,-1.22),(-1.02,.12),(-.47,1.30),(0,1.76),(.47,1.30),(1.02,.12),(.65,-1.22),(0,-1.72)],0,1.0,m['armor'])
    plate(r,'Ivory death mask',[(-.5,.35),(-.57,.87),(-.25,1.23),(.25,1.23),(.57,.87),(.5,.35),(0,.12)],.67,.26,m['bone'])
    for side in [-1,1]:
        box(r,'Seraph eye',(side*.26,.7,.84),(.31,.07,.055),m['energy'],.01,rot=side*.2)
        # Sculpted double wings, with layered ivory feather armor and hot channels.
        upper=[(side*.82,.58),(side*1.35,1.55),(side*3.85,2.25),(side*3.42,.85),(side*2.2,.20)]
        lower=[(side*1.0,.0),(side*2.05,.17),(side*3.25,-.30),(side*2.73,-1.6),(side*1.52,-.76)]
        plate(r,'Swept upper wing',upper,-.12,.34,m['steel'])
        plate(r,'Obsidian lower wing',lower,-.08,.30,m['armor'])
        for j in range(3):
            start=1.2+j*.68
            feather=[(side*start,.95+j*.22),(side*(start+.58),1.27+j*.22),(side*(start+.72),.78+j*.22),(side*(start+.12),.5+j*.15)]
            plate(r,'Ivory wing feather',feather,.11,.15,m['bone'])
            box(r,'Wing plasma channel',(side*(start+.24),.88+j*.20,.23),(.45,.055,.05),m['energy'],.008,rot=side*.28)
        sphere(r,'Inferno turbine',(side*1.72,-.65,.12),(.43,.43,.38),m['dark'])
        torus(r,'Inferno turbine ring',(side*1.72,-.65,.51),.36,.055,m['trim'])
        cylinder(r,'Inferno furnace',(side*1.72,-.65,.54),.25,.05,m['energy'])
        plate(r,'Bladed talon',[(side*.38,-1.0),(side*.94,-1.28),(side*.93,-2.0),(side*.5,-1.7)],.15,.3,m['steel'])
        socket(r,'MuzzleLeft' if side<0 else 'MuzzleRight',(side*1.72,-.65,.58))
    torus(r,'Heart containment',(0,-.35,.65),.48,.09,m['steel'])
    sphere(r,'Emberfall heart',(0,-.35,.70),(.35,.35,.16),m['energy'])
    for i in range(5):
        x=(i-2)*.22
        box(r,'Spine heat vent',(x,-.95,.56),(.10,.24,.05),m['trim'],.01)
    socket(r,'CoreSocket',(0,-.35,.86))
    return r


def export(kind):
    OUT.mkdir(parents=True,exist_ok=True)
    scene=bpy.data.scenes['CampaignBoss_'+kind]; bpy.context.window.scene=scene
    root=bpy.data.objects[kind+'_Root']
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for obj in root.children_recursive: obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',
       use_selection=True,use_active_scene=True,export_apply=True,export_animations=False,
       export_yup=True,export_lights=False,export_cameras=False)
    deps=bpy.context.evaluated_depsgraph_get()
    triangles=0
    for obj in root.children_recursive:
        if obj.type=='MESH':
            mesh=obj.evaluated_get(deps).to_mesh(); mesh.calc_loop_triangles(); triangles+=len(mesh.loop_triangles); obj.evaluated_get(deps).to_mesh_clear()
    print('CAMPAIGN BOSS EXPORTED',kind,'components',len(root.children_recursive),'triangles',triangles)


def save_source():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'campaign_boss_workbench.blend'))


if __name__=='__main__':
    seraph_path=ROOT/'tools/build_seraph_boss.py'
    seraph_builder={'__name__':'seraph_builder','__file__':str(seraph_path)}
    exec(compile(seraph_path.read_text(),str(seraph_path),'exec'),seraph_builder)
    root_obj = seraph_builder['build_seraph']()
    seraph_builder['optimize_and_export'](root_obj)
    vanguard_path=ROOT/'tools/build_apex_vanguard.py'
    replacement={'__name__':'vanguard_builder','__file__':str(vanguard_path)}
    exec(compile(vanguard_path.read_text(),str(vanguard_path),'exec'),replacement)
    replacement['build'](); replacement['export']()
    rig_path=ROOT/'tools/rebuild_rigged_vanguard.py'
    rig={'__name__':'rigged_vanguard','__file__':str(rig_path)}
    exec(compile(rig_path.read_text(),str(rig_path),'exec'),rig)
    rig['build']()

    colossus_path=ROOT/'tools/build_nightglass_colossus.py'
    colossus={'__name__':'colossus_builder','__file__':str(colossus_path)}
    exec(compile(colossus_path.read_text(),str(colossus_path),'exec'),colossus)
    colossus['build']()
    beast_path=ROOT/'tools/pose_colossus_as_beast.py'
    beast={'__name__':'beast_builder','__file__':str(beast_path)}
    exec(compile(beast_path.read_text(),str(beast_path),'exec'),beast)
    beast['pose']()
    matriarch_path=ROOT/'tools/sculpt_rift_matriarch.py'
    matriarch={'__name__':'matriarch_builder','__file__':str(matriarch_path)}
    exec(compile(matriarch_path.read_text(),str(matriarch_path),'exec'),matriarch)
    matriarch['build']()
