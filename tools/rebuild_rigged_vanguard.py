"""Blender authoring: articulated Iron Vanguard, preserves campaign workbench scenes."""
import bpy, math
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/campaign_bosses'
def build():
    scene=bpy.data.scenes.get('Vanguard_Rigged_Rebuild')
    if scene is None:
        scene=bpy.data.scenes.new('Vanguard_Rigged_Rebuild');bpy.context.window.scene=scene
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/enemy_enforcer.glb'))
    bpy.context.window.scene=scene
    if scene.get('vanguard_complete'):
        bpy.ops.export_scene.gltf(filepath=str(OUT/'apex.glb'),export_format='GLB',use_active_scene=True,export_animations=True,export_animation_mode='NLA_TRACKS')
        return
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    for o in list(scene.objects):
        if o.name.startswith('Icosphere'):bpy.data.objects.remove(o,do_unlink=True)
    ns={'__file__':str(ROOT/'tools/build_apex_vanguard.py'),'__name__':'helpers'}
    exec(compile(Path(ns['__file__']).read_text(),ns['__file__'],'exec'),ns)
    if 'CampaignBoss_apex_vanguard' not in bpy.data.scenes:ns['build']();bpy.context.window.scene=scene
    source=bpy.data.scenes['CampaignBoss_apex_vanguard']
    def copy_group(prefix,name,scale,position,rotation=None):
        src=next(o for o in source.objects if o.name.startswith(prefix))
        root=bpy.data.objects.new(name,None);scene.collection.objects.link(root)
        root.location=ns['p'](position)
        for old in [src]+list(src.children_recursive):
            if old==src:continue
            o=old.copy()
            if old.data:o.data=old.data.copy()
            scene.collection.objects.link(o);o.parent=root
            o.matrix_parent_inverse=Matrix.Identity(4)
            o.matrix_basis=Matrix.Diagonal((scale,scale,scale,1))@src.matrix_world.inverted()@old.matrix_world
        return root
    gun=copy_group('VanguardGun','VanguardGun',.40,(0,0,0))
    # Original -X barrel becomes glTF -Y barrel and -Z sights, matching the arm IK solver.
    fix=Matrix.Rotation(-math.pi/2,4,'Z')@Matrix.Rotation(math.pi/2,4,'Y')
    # Work directly in Blender: desired glTF (x,y,z)=(oldZ,oldX,-oldY).
    fix=Matrix(((0,1,0,0),(0,0,1,0),(1,0,0,0),(0,0,0,1)))
    for o in gun.children:o.matrix_basis=fix@o.matrix_basis
    for side in ['L','R']:
        copy_group('VanguardThruster_'+side,'VanguardThruster_'+side,.40,(-.31 if side=='L' else .31,1.47,.23))
    helmet=copy_group('VanguardHead','VanguardHelmet',.36,(0,1.57,-.035))
    helmet.rotation_euler.z=math.pi
    # Replace the inherited head rather than layering two helmets and visors.
    import bmesh
    for o in list(scene.objects):
        if o.type != 'MESH' or not o.name.startswith(('Nightguard', 'NG ')): continue
        group=o.vertex_groups.get('mixamorig:Head')
        if not group: continue
        bm=bmesh.new();bm.from_mesh(o.data)
        weights=bm.verts.layers.deform.active
        if weights:
            remove=[v for v in bm.verts if v[weights].get(group.index,0)>.25 and (o.matrix_world@v.co).z>1.53]
            bmesh.ops.delete(bm,geom=remove,context='VERTS')
        bm.to_mesh(o.data);bm.free();o.data.update()
        if not len(o.data.polygons): bpy.data.objects.remove(o,do_unlink=True)
    helmet_path=ROOT/'tools/refit_vanguard_helmet.py'
    helmet_builder={'__name__':'helmet_builder','__file__':str(helmet_path)}
    exec(compile(helmet_path.read_text(),str(helmet_path),'exec'),helmet_builder)
    helmet_builder['refit']()
    # Existing sculpted, weighted armour retains anatomical silhouette and authored UV detail.
    for o in scene.objects:
        if o.type=='MESH' and o.name.startswith('NG amber'):
            for mat in o.data.materials:
                bs=mat.node_tree.nodes.get('Principled BSDF')
                if bs:
                    bs.inputs['Base Color'].default_value=(.65,.008,.008,1)
                    bs.inputs['Emission Color'].default_value=(1,.005,.008,1);bs.inputs['Emission Strength'].default_value=2
    # Preserve UV detail while matching the reference's cool graphite finish.
    suit=next(o for o in scene.objects if o.name.startswith('Nightguard_Suit'))
    for mat in suit.data.materials:
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image and 'diffuse' in node.image.name.lower():
                import numpy as np
                im=node.image.copy();im.name='Iron Vanguard graphite suit'
                a=np.array(im.pixels[:],dtype=np.float32).reshape(-1,4)
                lum=a[:,:3]@np.array([.2126,.7152,.0722]);a[:,:3]=lum[:,None]*np.array([.73,.84,.88])
                im.pixels.foreach_set(a.ravel());im.pack();node.image=im
    armor=ns['material']('Vanguard sculpted titanium',(.10,.15,.17),.55,.68)
    # Rounded shoulder caps, no box primitives: upper ellipsoidal shells with layered edge bevels.
    for side in [-1,1]:
        verts=[];faces=[]
        for j in range(9):
            theta=.12+j/8*1.70
            for i in range(24):
                a=i/24*math.tau
                verts.append((side*.245+.19*math.sin(theta)*math.cos(a),-.015+.19*math.sin(theta)*math.sin(a),1.48+.17*math.cos(theta)))
        for j in range(8):
            for i in range(24):faces.append((j*24+i,j*24+(i+1)%24,(j+1)*24+(i+1)%24,(j+1)*24+i))
        mesh=bpy.data.meshes.new('Contoured shoulder shell');mesh.from_pydata(verts,[],faces);mesh.update()
        o=bpy.data.objects.new('Vanguard curved pauldron',mesh);scene.collection.objects.link(o);mesh.materials.append(armor)
        solid=o.modifiers.new('Forged thickness','SOLIDIFY');solid.thickness=.016
        bevel=o.modifiers.new('Machined lip','BEVEL');bevel.width=.007;bevel.segments=3
        for poly in mesh.polygons:poly.use_smooth=True
        # Vertices stored in rig space, rigid skin weights follow the animated upper arm.
        mesh.transform(rig.matrix_world.inverted());o.matrix_world=rig.matrix_world
        group=o.vertex_groups.new(name='mixamorig:LeftShoulder' if side<0 else 'mixamorig:RightShoulder');group.add(list(range(len(mesh.vertices))),1,'REPLACE')
        mod=o.modifiers.new('Skeleton skin','ARMATURE');mod.object=rig;o.parent=rig;o.matrix_world=rig.matrix_world
    bpy.ops.object.select_all(action='DESELECT')
    for o in scene.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'apex.glb'),export_format='GLB',use_active_scene=True,use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_apply=False)
    scene['vanguard_complete']=True
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'campaign_boss_workbench.blend'))
if __name__=='__main__':build()
