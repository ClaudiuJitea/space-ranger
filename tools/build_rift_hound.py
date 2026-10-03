"""Reference-inspired biomechanical predator, authored/exported through Blender MCP.
X forward, Z up in Blender; named pivots preserve the existing Godot gait.
"""
import bpy, math
import numpy as np
from mathutils import Vector
from pathlib import Path
BASE=Path('/home/clau/dev/space-ranger')
scene=bpy.data.scenes.get('Rift Hound Atelier') or bpy.data.scenes.new('Rift Hound Atelier')
bpy.context.window.scene=scene
for o in list(scene.objects): bpy.data.objects.remove(o,do_unlink=True)
def mat(name,c,metal,rough,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emission:p.inputs['Emission Color'].default_value=(*c,1);p.inputs['Emission Strength'].default_value=emission
 return m
BONE=mat('Rift | worn ivory ceramic',(.44,.36,.24),.18,.68)
EDGE=mat('Rift | plate edges',(.32,.29,.23),.45,.44)
DARK=mat('Rift | tendon graphite',(.025,.033,.036),.65,.37)
STEEL=mat('Rift | exposed hydraulics',(.12,.15,.15),.68,.46)
RED=mat('Rift | crimson spine core',(.8,.012,.065),.25,.26,2.1)
CLAW=mat('Rift | sharpened talons',(.38,.41,.37),.8,.27)
# Baked ceramic mottling and fine abrasion survive glTF export.
y,x=np.mgrid[0:256,0:256];rng=np.random.default_rng(73)
wear=.72+.10*np.sin(x*.083+y*.045)+.07*np.sin(x*.17-y*.094)+rng.random((256,256))*.14
scratches=(np.sin(x*.51+y*.014)>.992)&(np.sin(y*.041)>0)
wear[scratches]*=.57
pixels=np.ones((256,256,4),dtype=np.float32)
pixels[:,:,:3]=wear[:,:,None]*np.array([.78,.74,.66])
image=bpy.data.images.new('Rift baked worn ceramic',width=256,height=256)
image.pixels.foreach_set(pixels.ravel());image.pack()
node=BONE.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
BONE.node_tree.links.new(node.outputs['Color'],BONE.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
def empty(name,pos=(0,0,0),parent=None):
 o=bpy.data.objects.new(name,None);scene.collection.objects.link(o);o.parent=parent;o.location=pos;return o
root=empty('Rift_Hound')
def mesh(name,verts,faces,material,parent=root):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
 o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.parent=parent;data.materials.append(material)
 for p in data.polygons:p.use_smooth=True
 return o
def orb(name,pos,size,material,parent=root):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,radius=1)
 o=bpy.context.object;o.name=name;o.parent=parent;o.location=pos;o.scale=size;o.data.materials.append(material)
 for p in o.data.polygons:p.use_smooth=True
 return o
def tube(name,points,radii,material,parent=root,sides=10):
 verts=[];faces=[];pts=[Vector(p) for p in points]
 for i,p in enumerate(pts):
  tangent=pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]
  rot=tangent.to_track_quat('Z','Y')
  for j in range(sides):
   a=j*math.tau/sides;verts.append(p+rot@Vector((math.cos(a)*radii[i],math.sin(a)*radii[i],0)))
 for i in range(len(pts)-1):
  for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
 faces+=[tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+j for j in range(sides))]
 return mesh(name,verts,faces,material,parent)
def plate(name,pos,size,parent=root,tilt=0,material=BONE):
 # Layered tapered shell, with a pointed fore edge and sculpted transverse crown.
 verts=[];faces=[];sections=[(-.5,.08),(-.36,.72),(-.12,1),(.22,.86),(.42,.48),(.52,.015)]
 for x,r in sections:
  for j in range(12):
   a=j*math.tau/12;verts.append((x*size[0],math.cos(a)*size[1]*r*.5,math.sin(a)*size[2]*r*.5))
 for i in range(5):
  for j in range(12):faces.append((i*12+j,i*12+(j+1)%12,(i+1)*12+(j+1)%12,(i+1)*12+j))
 faces += [tuple(reversed(range(12))),tuple(60+j for j in range(12))]
 o=mesh(name,verts,faces,material,parent)
 uv=o.data.uv_layers.new(name='Ceramic surface')
 for polygon in o.data.polygons:
  for loop_index in polygon.loop_indices:
   index=o.data.loops[loop_index].vertex_index
   uv.data[loop_index].uv=(index//12/5,(index%12)/11)
 o.location=pos;o.rotation_euler.y=tilt
 return o
# Broad forequarters slope into a narrow rear pelvis.
orb('Muscular mechanical torso',(-.10,0,.94),(.73,.31,.39),DARK)
orb('Shoulder tendon mass',(.30,0,1.10),(.43,.40,.42),DARK)
orb('Rear pelvis',(-.64,0,.77),(.32,.25,.26),DARK)
for side in [-1,1]:
 for i in range(4):
  x=-.60+i*.23
  plate('Overlapping rib carapace',(x,side*.27,.99+i*.045),(.39,.25,.39),tilt=-.26)
  tube('Exposed rib piston',[(x-.05,side*.32,.81),(x+.04,side*.34,.98)],[.026,.026],STEEL)
 plate('Shoulder blade crown',(.25,side*.30,1.31),(.64,.35,.43),tilt=-.27)
 tube('Scapula swept horn',[(.03,side*.30,1.40),(.10,side*.36,1.65),(.28,side*.36,1.78)],[.10,.065,.001],BONE)
 # Heavy forward limbs, with all armor attached to gait pivots.
 leg=empty('Front_near' if side<0 else 'Front_far',(.33,side*.34,1.10),root)
 orb('Shoulder ball',(0,0,0),(.19,.19,.20),STEEL,leg)
 tube('Front humerus',[(0,0,0),(.14,side*.06,-.22),(.10,side*.11,-.43)],[.12,.14,.10],DARK,leg)
 plate('Humerus shell',(.12,side*.05,-.20),(.43,.27,.30),leg,tilt=1.20)
 orb('Foreleg elbow',(.10,side*.11,-.43),(.13,.13,.13),STEEL,leg)
 tube('Long forearm tendon',[(.10,side*.11,-.43),(.22,side*.12,-.64),(.27,side*.12,-.91)],[.10,.12,.065],DARK,leg)
 plate('Razor forearm armor',(.20,side*.12,-.63),(.56,.31,.26),leg,tilt=1.18)
 for offset in [-.055,.055]:tube('Forearm hydraulic',[(.05,side*.12+offset,-.40),(.17,side*.12+offset,-.78)],[.021,.021],STEEL,leg)
 orb('Front knuckle',(.28,side*.12,-.94),(.13,.13,.08),DARK,leg)
 for digit in [-1,0,1]:
  y=side*.12+digit*.072
  tube('Long hooked foreclaw',[(.30,y,-.94),(.42,y,-.95),(.55,y,-1.015),(.57,y,-1.075)],[.043,.036,.018,.001],CLAW,leg)
 tube('Elbow spur',[(.03,side*.11,-.47),(-.16,side*.12,-.63),(-.26,side*.13,-.75)],[.072,.035,.001],BONE,leg)
 # Digitigrade hindquarters.
 leg=empty('Rear_near' if side<0 else 'Rear_far',(-.63,side*.25,.80),root)
 orb('Hind hip',(0,0,0),(.14,.14,.16),STEEL,leg)
 tube('Hind tendon',[(0,0,0),(.15,side*.03,-.28),(-.07,side*.06,-.49),(-.03,side*.06,-.72)],[.12,.095,.055,.046],DARK,leg)
 plate('Haunch plate',(.06,side*.03,-.12),(.44,.27,.29),leg,tilt=.80)
 orb('Reverse knee',(.15,side*.03,-.28),(.09,.09,.09),STEEL,leg)
 plate('Hock guard',(-.04,side*.05,-.47),(.32,.15,.19),leg,tilt=1.1)
 for digit in [-1,0,1]:
  y=side*.06+digit*.06
  tube('Hind talon',[(-.03,y,-.71),(.09,y,-.72),(.21,y,-.79)],[.043,.026,.001],CLAW,leg)
# Low reptilian head, recessed eyes, jaw gap and serrated teeth.
head=empty('HoundHead',(.62,0,1.08),root)
orb('Cranial tendon',(0,0,0),(.32,.23,.23),DARK,head)
plate('Skull crown',(.04,0,.15),(.59,.45,.27),head,tilt=.20)
plate('Tapered snout',(.29,0,-.04),(.43,.28,.20),head,tilt=.20)
plate('Lower jaw',(.26,0,-.20),(.46,.27,.085),head,tilt=-.10,material=EDGE)
orb('Nose sensor',(.48,0,-.075),(.052,.105,.045),DARK,head)
for side in [-1,1]:
 orb('Crimson recessed eye',(.13,side*.202,.043),(.092,.024,.034),RED,head)
 plate('Swept brow',(.09,side*.205,.095),(.34,.065,.13),head,tilt=.15)
 plate('Cheek armor',(-.015,side*.20,-.035),(.32,.115,.20),head,tilt=-.3)
 tube('Cranial horn',[(-.12,side*.17,.18),(-.22,side*.19,.39),(-.29,side*.20,.47)],[.075,.035,.001],BONE,head)
 for i in range(5):
  x=.10+i*.072
  tube('Upper fang',[(x,side*.115,-.105),(x+.025,side*.105,-.17)],[.023,.001],CLAW,head)
# Red dorsal reactor nodules enclosed by ivory vertebral shell segments.
for i in range(7):
 x=.24-i*.17;z=1.45-max(0,i-1)*.075
 orb('Spine reactor %02d'%i,(x,0,z),(.083,.11,.11),RED)
 for side in [-1,1]:
  plate('Vertebral core enclosure',(x,side*.115,z-.025),(.22,.10,.21),tilt=-.3)
  tube('Dorsal spine hook',[(x-.025,side*.065,z+.06),(x-.13,side*.075,z+.19),(x-.22,side*.08,z+.23)],[.055,.032,.001],BONE)
# Long articulated tail, repeating bone sleeves over a dark flexible cable.
points=[(-.84,0,.88),(-1.06,0,.75),(-1.31,0,.64),(-1.56,0,.65),(-1.80,0,.76),(-2.01,0,.91),(-2.17,0,1.02)]
tube('Flexible tail tendon',points,[.105,.093,.076,.059,.043,.029,.002],DARK)
for i in range(len(points)-1):
 a,b=Vector(points[i]),Vector(points[i+1]);d=b-a
 o=plate('Segmented tail armor',(a+b)*.5,(d.length*.95,.19-i*.024,.17-i*.021));o.rotation_euler.y=-math.atan2(d.z,d.x)
tube('Tail blade',points[-2:]+[(-2.33,0,1.12)],[.039,.022,.001],CLAW)
# Recessed shoulder rail organ follows the same gameplay aim pivot.
weapon=empty('WeaponMount',(.24,0,1.28),root)
for side in [-1,1]:
 tube('Shoulder rail barrel',[(0,side*.27,0),(.32,side*.27,0),(.49,side*.27,0)],[.065,.05,.046],DARK,weapon)
 plate('Rail organic shroud',(.13,side*.27,.04),(.50,.16,.16),weapon)
 tube('Rail charge vein',[(0,side*.30,.02),(.30,side*.30,.02)],[.013,.013],RED,weapon)
empty('Muzzle',(.53,0,0),weapon)
bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for o in scene.objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(BASE/'assets/models/arsenal_refit/hound.glb'),export_format='GLB',use_selection=True)
bpy.data.libraries.write(str(BASE/'assets/models/arsenal_refit/rift_hound_atelier.blend'),{scene},fake_user=True,compress=True)
print('RIFT HOUND EXPORTED',len(scene.objects),'objects')
