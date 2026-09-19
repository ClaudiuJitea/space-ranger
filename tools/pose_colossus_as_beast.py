"""Transforms the authored Colossus into a stalking quadruped, retaining editable limbs."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
ns={'__name__':'colossus_builder','__file__':str(ROOT/'tools/build_nightglass_colossus.py')}
exec(compile(Path(ns['__file__']).read_text(),ns['__file__'],'exec'),ns)
p, sphere, shard, rod, tube, socket = [ns[k] for k in ['p','sphere','shard','rod','tube','socket']]

def pose():
    scene=bpy.data.scenes['CampaignBoss_nightglass_colossus'];bpy.context.window.scene=scene
    root=bpy.data.objects['Nightglass_Colossus_Root']
    if root.get('animal_pose'):raise RuntimeError('Animal pose already applied')
    root['animal_pose']=True
    torso=bpy.data.objects['ColossusTorso'];torso.location=p((0,-.5,0))
    for side,suffix in [(-1,'L'),(1,'R')]:
        bpy.data.objects['ColossusArm_'+suffix].location=p((side*1.04,.10,.65))
        bpy.data.objects['ColossusLeg_'+suffix].location=p((side*.67,-.62,-1.35))
    # Extend the spine into muscular haunches instead of an upright human pelvis.
    dark=bpy.data.materials.get('COLOSSUS obsidian pressure suit')
    bone=bpy.data.materials.get('COLOSSUS fractured pale carapace')
    steel=bpy.data.materials.get('COLOSSUS blackened steel actuators')
    lava=bpy.data.materials.get('COLOSSUS furnace red')
    # Existing pelvis becomes the lower rib basket; the hindquarters sit behind it.
    sphere(root,'Beast elongated abdominal mantle',(0,-.58,-.73),(.82,.61,1.10),dark)
    sphere(root,'Beast muscular haunches',(0,-.59,-1.30),(.80,.66,.58),dark)
    for side in [-1,1]:
        for j in range(4):
            z=-.35-j*.34
            shard(root,'Beast flank rib shell',[(side*.48,.13-j*.055),(side*.81,.07-j*.06),(side*.92,-.55),(side*.66,-.93),(side*.43,-.60)],z,.23,bone)
        tube(root,'Beast flank molten fissure',[(side*.75,-.22,-.18),(side*.81,-.36,-.52),(side*.76,-.35,-.88),(side*.68,-.42,-1.26)],.027,lava)
        rod(root,'Beast load-bearing rear tendon',(side*.45,-.51,-.67),(side*.63,-.78,-1.4),.09,steel)
    for side in [-1,1]:
        for j in range(3):
            outline=[(-.37,-.40),(-.43,.06),(-.22,.62),(.14,.72),(.37,.30),(.32,-.31),(.03,-.50)]
            obj=shard(root,'Beast overlapping flank armor',outline,0,.22,bone)
            obj.location=p((side*(1.26-j*.08),.42-j*.15,-.05-j*.42))
            obj.rotation_euler.z=side*math.pi/2
    tail=socket(root,'ColossusTail',(0,-.58,-1.65))
    tube(tail,'Beast flexible armored tail',[(0,0,0),(0,.05,-.44),(0,.22,-.86),(0,.33,-1.24)],.13,dark)
    for j in range(4):
        sphere(tail,'Tail overlapping vertebra',(0,.07+j*.065,-.18-j*.28),(.19-j*.025,.15-j*.02,.20),steel)
    # The beast's muzzle now faces -X along the gameplay plane.
    root.rotation_euler.z=-math.pi/2
    print('Quadruped stance and long body created')
    ns['export']()

if __name__=='__main__':pose()
