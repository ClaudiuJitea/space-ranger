"""Reference-guided Nightguard refinement; execute individual stages through Blender MCP."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path('/home/clau/Godot/games/space-ranger')
OUT=ROOT/'assets/models/nightguard_detail'
PRE=ROOT/'tools/blender_previews/nightguard_detail'
parts=[]
rig=None

def material(name,color,metal=.65,rough=.42,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 if emit: p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emit
 return m

def palette():
 global armor,steel,edge,rubber,glass,optic,blue
 armor=material('NG worn slate ceramic',(.27,.32,.34),.58,.47)
 steel=material('NG machined gunmetal',(.07,.095,.11),.8,.35)
 edge=material('NG exposed steel edges',(.43,.49,.51),.82,.3)
 rubber=material('NG flexible joint seals',(.018,.025,.029),.05,.8)
 glass=material('NG smoked visor',(.018,.038,.052),.68,.17)
 optic=material('NG amber targeting lens',(1,.29,.035),.2,.25,3)
 blue=material('NG ion core',(.035,.46,1),.2,.28,5)
 wear_material(armor,(.27,.32,.34),.47)
 wear_material(steel,(.07,.095,.11),.35)
 wear_material(edge,(.43,.49,.51),.3)

def finish(o,name,mat,bone=None,bevel=.008):
 o.name=name; o.data.materials.append(mat)
 if bevel:
  m=o.modifiers.new('Rounded machined edges','BEVEL'); m.width=bevel; m.segments=3; m.harden_normals=True
  bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=m.name)
 for p in o.data.polygons:p.use_smooth=True
 if bevel:
  n=o.modifiers.new('Stable plate normals','WEIGHTED_NORMAL');n.keep_sharp=True;n.weight=50
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=n.name)
 if bone:
  # Bake the world-space authoring geometry into the original rig's centimetre frame.
  transform=rig.matrix_world.inverted()@o.matrix_world
  o.data.transform(transform); o.matrix_world=rig.matrix_world.copy(); o.parent=rig; o.matrix_parent_inverse=Matrix.Identity(4); o.matrix_basis=Matrix.Identity(4)
  group=o.vertex_groups.new(name='mixamorig:'+bone); group.add(list(range(len(o.data.vertices))),1,'REPLACE')
  m=o.modifiers.new('Original Nightguard rig','ARMATURE'); m.object=rig
 parts.append(o); return o

def box(name,pos,size,mat,bone=None,bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.view_layer.objects.active; o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,mat,bone,bevel)

def ell(name,pos,size,mat,bone=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=pos);o=bpy.context.view_layer.objects.active;o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,mat,bone,0)

def cyl(name,pos,radius,depth,mat,bone=None,axis='Z'):
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=depth,location=pos);o=bpy.context.view_layer.objects.active
 if axis=='X':o.rotation_euler.y=math.pi/2
 if axis=='Y':o.rotation_euler.x=math.pi/2
 return finish(o,name,mat,bone,.003)

def hose(name,points,radius,mat,bone=None):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=radius;c.bevel_resolution=3
 s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
 for p,co in zip(s.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True)
 bpy.ops.object.convert(target='MESH');return finish(bpy.context.view_layer.objects.active,name,mat,bone,0)

def init_character():
 global rig,parts
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/models/nightguard_vanguard_variant.blend'))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST';parts=[];palette()
 for o in list(bpy.data.objects):
  if o!=rig and o not in rig.children_recursive:bpy.data.objects.remove(o,do_unlink=True)

def character():
 # Neutral steel albedo preserves the source wear and fabric variation.
 import numpy as np
 body=bpy.data.objects['Nightguard_Suit']; mat=body.data.materials[0]
 node=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'Diffuse' in n.image.name)
 image=node.image.copy(); pixels=np.array(image.pixels[:],dtype=np.float32).reshape(-1,4)
 luma=pixels[:,:3]@np.array([.299,.587,.114]); pixels[:,:3]=luma[:,None]*np.array([.72,.83,.91])
 image.pixels[:]=pixels.ravel();image.name='Nightguard_Steel_Wear'; image.filepath_raw=str(OUT/'steel_wear.png');image.file_format='PNG';image.save();image.pack();node.image=image
 bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Metallic'].default_value=.52;bsdf.inputs['Roughness'].default_value=.56
 # Lower the source's tall shoulder collar fins beneath the new shoulder shells.
 for v in body.data.vertices:
  co=body.matrix_world@v.co
  if .17<abs(co.x)<.35 and co.z>1.57:
   co.z=1.57+(co.z-1.57)*.15;v.co=body.matrix_world.inverted()@co
 # Front is Blender +Y. Existing anatomy and worn texture remain visible between plates.
 ell('Helmet crown',(0,-.025,1.738),(.112,.108,.117),armor,'Head')
 box('Dark panoramic visor',(0,.091,1.735),(.164,.028,.055),glass,'Head',.018)
 box('Visor brow',(0,.104,1.771),(.177,.034,.022),edge,'Head',.009)
 box('Armored jaw',(0,.085,1.671),(.126,.064,.067),steel,'Head',.018)
 for s in [-1,1]:
  cyl('Helmet comms receiver',(s*.106,-.016,1.72),.034,.022,steel,'Head','X')
  cyl('Comms inset',(s*.119,-.016,1.72),.023,.007,edge,'Head','X')
  box('Cheek guard',(s*.072,.061,1.687),(.028,.045,.054),armor,'Head')
  box('Chest overlapping ceramic',(s*.091,.151,1.421),(.165,.045,.155),armor,'Spine2',.023)
  box('Chest inset panel',(s*.092,.179,1.432),(.113,.012,.081),steel,'Spine2',.009)
  for z in [1.412,1.432,1.452]:box('Chest machined ribs',(s*.092,.189,z),(.083,.007,.005),edge,'Spine2',.002)
  # Shoulder shells use upper-arm skin weights so all IK and locomotion still work.
  bone=('Right' if s>0 else 'Left')+'Arm'
  ell('Layered shoulder shell',(s*.233,-.045,1.494),(.10,.115,.074),armor,bone)
  box('Shoulder upper lip',(s*.245,.039,1.5),(.11,.014,.045),edge,bone,.006)
  for x in [s*.195,s*.26]:cyl('Shoulder fastener',(x,.065,1.494),.007,.005,steel,bone,'Y')
  bone=('Right' if s>0 else 'Left')+'ForeArm'
  box('Forearm armor',(s*.545,-.004,1.48),(.15,.089,.108),armor,bone,.022)
  box('Forearm service strip',(s*.545,.047,1.48),(.095,.01,.042),steel,bone)
  for x in [s*.51,s*.56,s*.59]:box('Forearm cooling slot',(x,.054,1.48),(.012,.006,.027),rubber,bone,.002)
  leg=('Right' if s>0 else 'Left')
  box('Thigh front shell',(s*.112,.114,.81),(.143,.072,.23),armor,leg+'UpLeg',.024)
  box('Thigh inset',(s*.112,.158,.828),(.09,.016,.12),steel,leg+'UpLeg',.009)
  box('Thigh unit stripe',(s*.112,.17,.856),(.064,.006,.018),edge,leg+'UpLeg',.002)
  ell('Knee articulated shell',(s*.099,.067,.572),(.078,.071,.075),armor,leg+'Leg')
  box('Shin tapered main plate',(s*.099,.065,.362),(.126,.062,.235),armor,leg+'Leg',.023)
  box('Shin central reinforcing rib',(s*.099,.104,.362),(.035,.012,.186),edge,leg+'Leg',.005)
  for z in [.3,.38,.44]:cyl('Shin recessed bolt',(s*.142,.098,z),.006,.006,steel,leg+'Leg','Y')
  box('Boot toe cap',(s*.098,.116,.093),(.144,.17,.085),steel,leg+'Foot',.018)
  for z in [1.19,1.23,1.27]:box('Abdominal segmented plate',(s*.059,.098,z),(.107,.035,.027),steel,'Spine',.007)
  box('Belt utility pouch',(s*.169,.085,1.055),(.075,.079,.091),steel,'Hips',.012)
  hose('Chest communication cable',[(s*.15,.088,1.49),(s*.18,.13,1.38),(s*.13,.13,1.33)],.008,rubber,'Spine2')
 box('Belt buckle',(0,.127,1.073),(.082,.035,.046),edge,'Hips')
 cyl('Amber optic',( .067,.127,1.749),.012,.012,optic,'Head','Y')
 # Small deterministic surface chips, weighted exactly like their armor plate.
 random.seed(17)
 for side in [-1,1]:
  for i in range(15):
   x=side*.091+random.uniform(-.069,.069);z=random.uniform(1.354,1.482)
   box('Chest edge abrasion',(x,.178,z),(random.uniform(.003,.012),.002,.002),edge,'Spine2',0)
 # Join additions by material to keep the skinned draw count modest.
 for mat in [armor,steel,edge,rubber,glass,optic]:
  obs=[o for o in rig.children if o.type=='MESH' and o.data.materials[0]==mat]
  if not obs:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in obs:o.select_set(True)
  bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();obs[0].name=mat.name
 rig.data.pose_position='POSE'
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
 for o in rig.children_recursive:o.select_set(True)
 bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/enemy_enforcer.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_apply=False,export_lights=False,export_cameras=False)
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'nightguard_armored.blend'))
 print('CHARACTER_DETAIL_OK')

def render_character(path='enforcer.png'):
 scene=bpy.context.scene
 for t in rig.animation_data.nla_tracks:t.mute=t.name!='Idle'
 scene.frame_set(12)
 render_setup((2.6,4.3,2.25),(0,0,.95),2.3)
 scene.render.filepath=str(PRE/path);bpy.ops.render.render(write_still=True)
 print('RENDER',scene.render.filepath)

def render_setup(camera,target,scale):
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
 scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
 scene.world.color=(.16,.16,.16)
 bpy.ops.object.camera_add(location=camera);cam=bpy.context.view_layer.objects.active;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale;scene.camera=cam
 for pos,power,size in [((2,3,4),500,3),((-3,1,2),350,3),((0,-3,3),600,2)]:
  bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.view_layer.objects.active;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
 scene.view_settings.view_transform='AgX'

def clear():
 global parts,rig
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);parts=[];rig=None;palette()

def save_static(filename,blendname):
 for mat in [armor,steel,edge,rubber,blue,optic,glass]:
  obs=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat]
  if len(obs)<2:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in obs:o.select_set(True)
  bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join()
 bpy.ops.object.select_all(action='DESELECT')
 for o in bpy.data.objects:
  if o.type in ['MESH','EMPTY']:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(filename),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_lights=False,export_cameras=False)
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/blendname))

def jetpack():
 clear()
 # Same attachment origin and exhaust centres as the existing runtime scene.
 box('Structural backplate',(0,.045,0),(.44,.07,.50),steel)
 box('Reactor ceramic cover',(0,-.025,.035),(.32,.15,.37),armor,bevel=.024)
 box('Recessed service panel',(0,-.108,.04),(.23,.018,.23),steel)
 box('Service panel inset',(0,-.12,.075),(.175,.012,.12),armor)
 for x in [-.08,.08]:
  for z in [-.025,.16]:cyl('Panel captive bolt',(x,-.13,z),.009,.008,edge,axis='Y')
 for i in range(7):box('Reactor cooling louver',(0,-.133,-.075+i*.014),(.17,.012,.005),edge,bevel=.001)
 for s in [-1,1]:
  x=s*.26
  cyl('Fuel cylinder',(x,-.075,-.015),.096,.43,steel)
  ell('Armored tank dome',(x,-.075,.209),(.098,.098,.077),armor)
  for z in [.15,-.12]:
   cyl('Split retaining collar',(x,-.075,z),.109,.029,edge)
   box('Collar locking latch',(x,-.179,z),(.051,.023,.04),steel)
   cyl('Latch screw',(x,-.196,z),.009,.007,edge,axis='Y')
  for dx in [-.049,.049]:box('Tank longitudinal reinforcement',(x+dx,-.156,0),(.018,.024,.29),armor)
  cyl('Thruster combustion casing',(x,-.075,-.25),.114,.17,armor)
  for z in [-.19,-.22,-.25,-.28]:cyl('Heat exchanger ring',(x,-.075,z),.119,.014,steel)
  # Open annular nozzle, rather than a solid capped cylinder.
  bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=(x,-.075,-.333),major_radius=.084,minor_radius=.023)
  finish(bpy.context.view_layer.objects.active,'Open nozzle bell lip',edge)
  cyl('Recessed nozzle cavity',(x,-.075,-.306),.079,.008,rubber)
  cyl('Ion injector',(x,-.075,-.315),.040,.007,blue)
  for i in range(8):
   a=i*math.tau/8;cyl('Nozzle circumferential fastener',(x+math.cos(a)*.099,-.075+math.sin(a)*.099,-.345),.005,.008,steel)
  hose('Braided propellant line',[(s*.12,-.10,.11),(s*.17,-.17,.16),(x,-.16,.11)],.013,rubber)
  hose('Secondary coolant line',[(s*.10,-.10,-.08),(s*.16,-.17,-.12),(x,-.16,-.16)],.007,edge)
  box('Shoulder harness mount',(s*.17,.066,.185),(.055,.08,.13),steel)
  cyl('Harness pivot',(s*.17,.111,.185),.019,.012,edge,axis='Y')
 box('Carry handle upper',(0,-.04,.28),(.18,.045,.032),edge)
 for s in [-1,1]:box('Carry handle upright',(s*.09,-.04,.249),(.024,.045,.065),steel)
 save_static(ROOT/'assets/models/enemy_scout_jetpack.glb','scout_jetpack.blend')
 render_setup((1.2,-2,1.0),(0,-.02,-.035),.95);bpy.context.scene.render.filepath=str(PRE/'jetpack.png');bpy.ops.render.render(write_still=True)
 print('JETPACK_DETAIL_OK')

def rifle():
 clear()
 # Work in weapon-local Godot coordinates. Convert to Blender Z-up on completion.
 box('Chamfered upper receiver',(0,-.13,-.065),(.092,.36,.09),steel,bevel=.012)
 box('Layered receiver side plates',(0,-.13,-.067),(.104,.245,.068),armor)
 box('Rear stock spine',(0,.17,-.066),(.065,.22,.066),steel)
 box('Shoulder stock',(0,.279,-.031),(.098,.033,.143),rubber)
 box('Adjustable cheek rest',(0,.17,-.11),(.078,.17,.026),armor)
 box('Pistol grip',(0,.05,.024),(.058,.075,.127),rubber)
 for z in [.015,.034,.053,.072]:box('Grip molded ridges',(0,.088,z),(.063,.01,.008),steel,bevel=.002)
 box('Power magazine',(0,-.055,.045),(.069,.082,.13),steel)
 box('Magazine baseplate',(0,-.055,.109),(.078,.09,.018),edge)
 for x in [-.041,.041]:
  box('Magazine viewing slot',(x,-.055,.045),(.008,.052,.071),rubber)
  for z in [.025,.044,.063]:box('Energy charge indicator',(x*1.12,-.055,z),(.005,.035,.009),optic,bevel=.001)
 cyl('Heavy barrel',(0,-.37,-.064),.031,.29,steel,axis='Y')
 for y in [-.27,-.31,-.35,-.39]:cyl('Barrel cooling ring',(0,y,-.064),.041,.017,edge,axis='Y')
 box('Foregrip shroud',(0,-.318,-.039),(.098,.17,.09),armor)
 for x in [-.053,.053]:
  for y in [-.27,-.30,-.33,-.36]:box('Shroud recessed vent',(x,y,-.06),(.008,.016,.034),rubber,bevel=.003)
 cyl('Muzzle flash suppressor',(0,-.515,-.064),.040,.064,steel,axis='Y')
 cyl('Recessed bore',(0,-.55,-.064),.024,.004,rubber,axis='Y')
 cyl('Pulse emitter',(0,-.553,-.064),.012,.004,optic,axis='Y')
 box('Top accessory rail',(0,-.13,-.123),(.041,.31,.024),steel)
 for y in [-.25+i*.025 for i in range(12)]:box('Picatinny rail tooth',(0,y,-.137),(.053,.013,.009),edge,bevel=.001)
 box('Low profile optic housing',(0,-.079,-.166),(.057,.088,.051),steel)
 cyl('Sight front glass',(0,-.125,-.166),.015,.003,glass,axis='Y')
 for x in [-.057,.057]:
  for y in [-.20,-.10,-.02]:cyl('Receiver captive fastener',(x,y,-.067),.006,.007,edge,axis='X')
 box('Bolt access inset',(.058,-.08,-.084),(.007,.085,.022),rubber)
 box('Bolt handle',(.07,-.048,-.081),(.022,.023,.016),edge)
 # Blender -> glTF maps (x,y,z) to (x,z,-y).
 conv=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
 for o in parts:o.matrix_world=conv@o.matrix_world
 bpy.ops.object.empty_add(type='PLAIN_AXES',location=(0,.064,-.565));bpy.context.view_layer.objects.active.name='Muzzle'
 save_static(OUT/'nightguard_rifle.glb','nightguard_rifle.blend')
 render_setup((1.1,-1.8,1.1),(0,0,-.15),.95);bpy.context.scene.render.filepath=str(PRE/'rifle.png');bpy.ops.render.render(write_still=True)
 print('RIFLE_DETAIL_OK')


def wear_material(mat,color,rough):
 import numpy as np
 rng=np.random.default_rng(81);n=512
 coarse=np.repeat(np.repeat(rng.random((32,32)),16,axis=0),16,axis=1)
 for _ in range(12):coarse=(coarse+np.roll(coarse,1,0)+np.roll(coarse,-1,0)+np.roll(coarse,1,1)+np.roll(coarse,-1,1))/5
 fine=rng.random((n,n));variation=.91+.14*coarse+.035*fine
 rgb=variation[:,:,None]*np.array(color)[None,None,:]
 # Restrained hairline scratches and paint chips at a texture scale visible in close-ups.
 for _ in range(220):
  x,y=rng.integers(0,n,2);length=int(rng.integers(2,16));rgb[y,x:min(n,x+length),:]=np.array(color)*1.45
 def image(name,rgba):
  im=bpy.data.images.new(name,width=n,height=n);im.pixels[:]=rgba.astype(np.float32).ravel();im.filepath_raw=str(OUT/(__import__('re').sub(r'\.\d{3}(?=_)','',name)+'.png'));im.file_format='PNG';im.save();im.pack();return im
 rgba=np.ones((n,n,4));rgba[:,:,:3]=rgb
 im=image(mat.name.replace(' ','_')+'_wear',rgba)
 nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF');t=nodes.new('ShaderNodeTexImage');t.image=im;links.new(t.outputs['Color'],p.inputs['Base Color'])
 rgba[:,:,:3]=np.clip(rough+.14*(coarse[:,:,None]-.5)+.045*(fine[:,:,None]-.5),0,1)
 im=image(mat.name.replace(' ','_')+'_rough',rgba);im.colorspace_settings.name='Non-Color';t=nodes.new('ShaderNodeTexImage');t.image=im;links.new(t.outputs['Color'],p.inputs['Roughness'])

def flames():
 source=(ROOT/'tools/build_scout_flames.py').read_text()
 source=source.replace("(0.98, 0.43, 0.11), 1.15, 0.88", "(0.025, 0.30, 1.0), 3.5, 0.48")
 source=source.replace("(1.0, 0.91, 0.65), 1.8, 1.0", "(0.46, 0.86, 1.0), 6.0, 1.0")
 source=source.replace('sides=10', 'sides=24').replace('(-0.20, 0.080)', '(-0.20, 0.053)').replace('(-0.29, 0.055)', '(-0.29, 0.044)').replace('(-0.49, 0.003)', '(-0.59, 0.001)').replace('(-0.19, 0.050)', '(-0.19, 0.034)').replace('(-0.34, 0.003)', '(-0.45, 0.001)')
 source=source.replace('Amber','Blue').replace('Ivory','WhiteBlue').replace('Outer Amber','Outer Blue')
 source=source.replace("ROOT / 'enemy_scout_jet_flame.blend'", "ROOT / 'nightguard_detail/scout_ion_flame.blend'")
 exec(compile(source,'scout_ion_flame','exec'),{})
 print('BLUE_FLAME_OK')
