"""Fitted enemy and weapon refit, authored via Blender MCP, one asset per call.
Set REFIT_ASSET before executing; original GLBs and all gameplay sockets remain.
"""
import bpy, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix
BASE=Path('/home/clau/dev/space-ranger')
OUT=BASE/'assets/models/arsenal_refit';OUT.mkdir(parents=True,exist_ok=True)
# name: source, armor, accent, category
ASSETS={
 'enforcer':('enemy_enforcer',(.18,.26,.34),(1,.18,.06),'humanoid'),
 'scout':('enemy_enforcer',(.24,.36,.43),(.08,.7,1),'humanoid'),
 'scout_jetpack':('enemy_scout_jetpack',(.15,.24,.31),(.08,.7,1),'attachment'),
 'scout_flame':('enemy_scout_jet_flame',(.15,.24,.31),(.08,.7,1),'flame'),
 'crawler':('concept_enemies_v2/crawler',(.24,.3,.35),(1,.13,.05),'mech'),
 'turret':('concept_enemies_v2/turret',(.28,.32,.34),(1,.52,.06),'mech'),
 'gunship':('concept_enemies_v2/gunship',(.17,.24,.33),(.68,.18,1),'mech'),
 'hound':('eclipse_expansion/hound',(.23,.31,.37),(1,.2,.04),'mech'),
 'wasp':('eclipse_expansion/wasp',(.22,.34,.4),(.05,.75,1),'mech'),
 'apex':('eclipse_expansion/apex',(.2,.27,.34),(1,.44,.04),'boss'),
 'warden':('eclipse_expansion/warden',(.31,.25,.42),(.75,.12,1),'boss'),
 'seraph':('eclipse_expansion/seraph',(.3,.22,.18),(1,.37,.04),'boss'),
 'leviathan':('eclipse_expansion/leviathan',(.42,.64,.63),(.05,1,.63),'boss'),
 'sovereign':('eclipse_expansion/sovereign',(.23,.16,.34),(.7,.12,1),'boss'),
 'blaster':('weapon_blaster',(.64,.74,.78),(.035,.75,1),'weapon'),
 'scattergun':('weapon_scattergun',(.32,.38,.42),(1,.46,.05),'weapon'),
 'railgun':('weapon_railgun',(.28,.42,.43),(.05,1,.67),'weapon'),
 'launcher':('weapon_launcher',(.28,.31,.36),(1,.17,.045),'weapon'),
 'enemy_rifle':('nightguard_detail/nightguard_rifle',(.19,.28,.35),(1,.28,.065),'weapon'),
}
name=globals().get('REFIT_ASSET','enforcer'); source,armor,accent,category=ASSETS[name]
scene=bpy.context.scene if bpy.context.window is None else (bpy.data.scenes.get('Arsenal Refit Atelier') or bpy.data.scenes.new('Arsenal Refit Atelier'))
if bpy.context.window: bpy.context.window.scene=scene
scene.name='Arsenal Refit Atelier'
# Each asset lives in its own generated collection; rebuilding never erases other work.
collection_name='REFIT '+name
old=bpy.data.collections.get(collection_name)
if old:
 for o in list(old.objects):bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.collections.remove(old)
collection=bpy.data.collections.new(collection_name);scene.collection.children.link(collection)
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(BASE/'assets/models'/(source+'.glb')))
objects=set(bpy.data.objects)-before
bpy.context.view_layer.update()
# glTF imports create custom-bone display meshes in a helper collection.
# These are editor-only geometry, never part of the game asset.
helpers={o for o in objects if any(c.name.startswith('glTF_not_exported') for c in o.users_collection)}
objects={o for o in objects if o.name in bpy.context.view_layer.objects and o not in helpers}
for o in helpers: bpy.data.objects.remove(o,do_unlink=True)
for o in objects:
 for c in list(o.users_collection):c.objects.unlink(o)
 collection.objects.link(o)
roots=[o for o in objects if o.parent is None]
# Imported assets are authored at origin; previous gallery placements are excluded.
for o in roots:o.location.x=0 if abs(o.location.x)>4 else o.location.x
rig=next((o for o in objects if o.type=='ARMATURE'),None)
if rig:rig.data.pose_position='REST';bpy.context.view_layer.update()

def material(label,color,metal=.7,rough=.36,glow=0):
 m=bpy.data.materials.new('REFIT '+name+' '+label);m.use_nodes=True;m.diffuse_color=(*color,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
 p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if glow:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=glow
 return m
CARBON=material('carbon',(.016,.025,.038),.5,.5)
METAL=material('titanium',(.43,.53,.61),.86,.28)
PLATE=material('fitted ceramic',armor,.58,.38)
ACCENT=material('anodized markings',accent,.6,.36)
LIGHT=material('recessed optics',accent,.2,.24,1.7)
BLACK=material('vent cavity',(.007,.012,.02),.3,.55)

def regrade(original):
 low=original.name.lower()
 p=original.node_tree.nodes.get('Principled BSDF') if original.use_nodes else None
 luminous=p and p.inputs['Emission Strength'].default_value>.1 and sum(p.inputs['Emission Color'].default_value[:3])>.02
 if category=='flame' or luminous or any(w in low for w in ['glow','plasma','optics','reactor','ruby','conduit','optic','targeting','indicator','diode']):return LIGHT
 if any(w in low for w in ['rubber','polymer','carbon','undersuit','seals','joint','tendon','dark','cavit']):return CARBON
 if any(w in low for w in ['accent','trim','copper','gold','marking']):return ACCENT
 target=(.43,.53,.61) if any(w in low for w in ['steel','titanium','edge','cutting']) else armor
 if not p:return PLATE
 m=original.copy();m.name='REFIT '+name+' '+original.name
 shader=m.node_tree.nodes.get('Principled BSDF');shader.inputs['Metallic'].default_value=.82 if target==(.43,.53,.61) else .55
 shader.inputs['Roughness'].default_value=.32 if target==(.43,.53,.61) else .43
 # Bake the color into the existing albedo so glTF and Godot show the same finish.
 images=[n for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and not any(w in n.image.name.lower() for w in ['normal','rough','metal'])]
 if images:
  node=images[0];img=node.image.copy();w,h=img.size
  pixels=np.empty(w*h*4,dtype=np.float32);img.pixels.foreach_get(pixels);pixels=pixels.reshape(-1,4)
  luma=pixels[:,:3]@np.array([.2126,.7152,.0722],dtype=np.float32)
  pixels[:,:3]=np.clip(pixels[:,:3]*.28+luma[:,None]*(np.array(target)/.5)*.72,0,1)
  img.pixels.foreach_set(pixels.ravel());img.name='REFIT_'+name+'_'+str(len(bpy.data.images));img.pack();node.image=img
 else:shader.inputs['Base Color'].default_value=(*target,1)
 return m
mats={m for o in objects if o.type=='MESH' for m in o.data.materials if m}
remap={m:regrade(m) for m in mats}
for o in objects:
 if o.type=='MESH':
  for i,m in enumerate(o.data.materials):
   if m in remap:o.data.materials[i]=remap[m]

def find(prefix):return next((o for o in objects if o.name.startswith(prefix)),None)
def parent_world(obj,parent):
 if parent:obj.parent=parent;obj.matrix_parent_inverse=parent.matrix_world.inverted()
def shape(obj,label,pos,size,mat,parent=None,bone=None,bevel=.006):
 obj.name='REFIT '+name+' '+label;obj.location=pos;obj.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 obj.data.materials.append(mat)
 if bevel:
  b=obj.modifiers.new('Machined fillets','BEVEL');b.width=bevel;b.segments=3
  bpy.ops.object.modifier_apply(modifier=b.name)
  n=obj.modifiers.new('Weighted edge normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=n.name)
 for poly in obj.data.polygons:poly.use_smooth=True
 for c in list(obj.users_collection):c.objects.unlink(obj)
 collection.objects.link(obj)
 if bone and rig:
  obj.data.transform(rig.matrix_world.inverted()@obj.matrix_world)
  obj.parent=rig;obj.matrix_parent_inverse=Matrix.Identity(4);obj.matrix_basis=Matrix.Identity(4)
  group=obj.vertex_groups.new(name=bone);group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
  mod=obj.modifiers.new('Original armor skeleton','ARMATURE');mod.object=rig
 else:parent_world(obj,parent)
 objects.add(obj);return obj

def box(label,pos,size,mat,parent=None,bone=None,rot=None):
 bpy.ops.mesh.primitive_cube_add(size=1)
 obj=shape(bpy.context.object,label,pos,size,mat,parent,bone)
 if rot:obj.rotation_euler=rot
 return obj

def rod(label,a,b,radius,mat,parent=None):
 a,b=Vector(a),Vector(b);d=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=radius,depth=d.length)
 obj=bpy.context.object;obj.rotation_euler=d.to_track_quat('Z','Y').to_euler()
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
 return shape(obj,label,(a+b)/2,(1,1,1),mat,parent,bevel=.002)

def gbox(label,pos,size,mat,parent=None):
 # Game models use Y-up. Blender authoring uses Z-up.
 return box(label,(pos[0],-pos[2],pos[1]),(size[0],size[2],size[1]),mat,parent)
root=roots[0] if len(roots)==1 else None
if category=='humanoid':
 # Small, skin-weighted insignia follow the original cuirass; no bulky shell overlays.
 chest=rig.matrix_world@rig.data.bones['mixamorig:Spine2'].head_local
 for side in [-1,1]:
  for i in range(3):
   box('chest service stripe',chest+Vector((side*.095,.13,-.03+i*.032)),(.042,.008,.012),ACCENT,bone='mixamorig:Spine2')
 head=rig.matrix_world@rig.data.bones['mixamorig:Head'].head_local
 box('helmet sensor slit',head+Vector((0,.105,.01)),(.09,.009,.016),LIGHT,bone='mixamorig:Head')
 # Recessed backpack beacon remains attached to the torso through locomotion and IK.
 box('rear signal beacon',chest+Vector((0,-.115,.07)),(.045,.012,.08),LIGHT,bone='mixamorig:Spine2')
elif name=='crawler':
 for side in [-1,1]:
  gbox('flank armor inset',(-.18,.57,side*.255),(.48,.055,.025),PLATE,root)
  for i in range(4):gbox('flank cooling rib',(-.34+i*.105,.58,side*.273),(.034,.085,.015),METAL,root)
 for i in range(3):gbox('dorsal warning stripe',(-.32+i*.18,.705,0),(.09,.012,.17),ACCENT,root)
elif name=='turret':
 head=find('AimingHead')
 for side in [-1,1]:
  gbox('head cheek armor',(.02,.74,side*.25),(.46,.14,.025),PLATE,head)
  for i in range(4):gbox('head heat fin',(-.2+i*.06,.8,side*.27),(.025,.12,.035),METAL,head)
  gbox('rangefinder bracket',(.18,.84,side*.16),(.08,.12,.05),CARBON,head)
  gbox('optic rangefinder',(.18,.91,side*.16),(.10,.036,.05),LIGHT,head)
 base=find('AnchoredBase')
 for side in [-1,1]:gbox('base hazard band',(-.15,.16,side*.41),(.4,.026,.015),ACCENT,base)
elif name=='gunship':
 for side in [-1,1]:
  gbox('engine ceramic shield',(-.3,.23,side*.47),(.72,.035,.17),PLATE,root)
  for i in range(5):gbox('engine heat vane',(-.58+i*.12,.28,side*.46),(.036,.13,.17),METAL,root)
  gbox('targeting lens bed',(.56,.085,side*.32),(.20,.065,.04),CARBON,root)
  gbox('forward targeting strip',(.56,.12,side*.32),(.18,.035,.025),LIGHT,root)
 gbox('command telemetry',(-.4,.33,0),(.2,.018,.09),ACCENT,root)
elif name=='hound':
 for side in [-1,1]:
  for i in range(5):gbox('cerberus back vent',(-.43+i*.17,1.16,side*.13),(.035,.024,.15),METAL,root)
  gbox('rail receiver insignia',(-.1,1.23,side*.158),(.31,.025,.01),ACCENT,find('WeaponMount'))
  gbox('flank recessed panel',(-.22,.86,side*.29),(.47,.17,.018),PLATE,root)
 gbox('tracking crest',(.73,1.08,0),(.3,.018,.09),CARBON,find('HoundHead'))
elif name=='wasp':
 for side in [-1,1]:
  gbox('pylon marking',(-.08,.07,side*.45),(.25,.013,.045),ACCENT,root)
  for i in range(4):gbox('top thermal vent',(-.32+i*.115,.245,side*.11),(.03,.012,.15),METAL,root)
  gbox('weapon safety strip',(.22,-.1,side*.25),(.28,.018,.022),PLATE,root)
elif category=='weapon':
 if name=='blaster':
  for side in [-1,1]:
   for i in range(3):gbox('receiver serial dash',(side*.052,-.12-i*.023,-.11),(.009,.012,.023),ACCENT,root)
   gbox('power module frame',(side*.055,-.23,-.096),(.012,.11,.052),METAL,root)
 elif name=='scattergun':
  for side in [-1,1]:
   gbox('titan ceramic receiver',(side*.079,-.2,-.115),(.017,.25,.06),PLATE,root)
   for i in range(5):gbox('barrel cooling gill',(side*.069,-.47-i*.055,-.126),(.016,.024,.062),METAL,root)
   gbox('titan amber charge rail',(side*.085,-.30,-.101),(.012,.18,.012),LIGHT,root)
  gbox('pump shroud',(0,-.43,-.035),(.105,.19,.025),CARBON,root)
 elif name=='railgun':
  for side in [-1,1]:
   for i in range(5):
    gbox('accelerator saddle',(side*.061,-.30-i*.085,-.115),(.017,.024,.06),METAL,root)
    gbox('rail energy indicator',(side*.073,-.30-i*.085,-.115),(.008,.01,.035),LIGHT,root)
   gbox('capacitor side panel',(side*.065,-.12,-.104),(.02,.15,.07),PLATE,root)
  gbox('precision sight pedestal',(0,-.28,-.16),(.047,.07,.038),METAL,root)
  gbox('precision sight hood',(0,-.28,-.195),(.071,.13,.036),CARBON,root)
  gbox('precision optic',(0,-.35,-.195),(.045,.008,.018),LIGHT,root)
 elif name=='launcher':
  for side in [-1,1]:
   gbox('havoc tube side armor',(side*.113,-.40,-.115),(.025,.35,.10),PLATE,root)
   for i in range(5):gbox('tube exhaust gill',(side*.13,-.27-i*.048,-.115),(.012,.022,.063),METAL,root)
   gbox('warhead status strip',(side*.132,-.43,-.088),(.008,.12,.011),LIGHT,root)
  gbox('rangefinder bridge',(0,-.22,-.2),(.043,.068,.065),METAL,root)
  gbox('rangefinder housing',(0,-.22,-.235),(.078,.13,.052),CARBON,root)
  gbox('rangefinder optic',(0,-.286,-.235),(.048,.009,.025),LIGHT,root)
 elif name=='enemy_rifle':
  for side in [-1,1]:
   for i in range(4):gbox('rifle heat vane',(side*.04,-.27-i*.045,-.081),(.012,.019,.04),METAL,root)
   gbox('threat telemetry',(side*.046,-.17,-.076),(.009,.074,.012),LIGHT,root)
# Bosses already have articulated high-detail shells; preserve geometry and
# individually regrade every shell, weapon, optic and exposed mechanism.
if rig:rig.data.pose_position='POSE'
bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS')
# Gallery placement happens only AFTER export, preserving all gameplay origins.
for o in roots:o.location.x+=list(ASSETS).index(name)*8
manifest={k:{'source':('res://assets/models/arsenal_refit/rift_hound_atelier.blend' if k=='hound' else 'res://assets/models/'+v[0]+'.glb'),'model':'res://assets/models/arsenal_refit/'+k+'.glb','category':v[3]} for k,v in ASSETS.items()}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('ARSENAL REFIT EXPORTED',name,len(objects),'objects')
