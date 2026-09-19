"""HV-4 flight asset, authored through Blender MCP. Forward is Godot -Z.

Rebuild: blender --background --python tools/build_havoc_missile.py
The .blend retains editable parts; GLB exports one consolidated flight mesh.
"""
from pathlib import Path
import math
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1] if '__file__' in globals() else Path('/home/clau/Godot/games/space-ranger')
DEST = ROOT / 'assets/models/projectiles'
SCENE_NAME = 'HV4_Missile_Workbench'


def coords(p):
    return (p[0], -p[2], p[1])


def material(name, color, metallic, roughness):
    mat = bpy.data.materials.new('HV4_' + name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    return mat


def finish(obj, mat, bevel=0.0015):
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('Machined edge bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    obj.parent = bpy.data.objects['HV4_AssetRoot']
    return obj


def lathe(name, rings, mat, caps=True, segments=24):
    vertices = [coords((math.cos(i * math.tau / segments) * r,
                        math.sin(i * math.tau / segments) * r, z))
                for z, r in rings for i in range(segments)]
    faces = []
    for j in range(len(rings) - 1):
        for i in range(segments):
            a = j * segments + i
            b = j * segments + (i + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    if caps:
        faces.append(tuple(reversed(range(segments))))
        faces.append(tuple((len(rings) - 1) * segments + i for i in range(segments)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    finish(obj, mat)
    # Recalculate normals independently of profile direction (no negative scales).
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    return obj


def box(name, location, dimensions, mat, bevel=0.0015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=coords(location))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (dimensions[0], dimensions[2], dimensions[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(obj, mat, bevel)
    obj.select_set(False)
    return obj


def build_model():
    if bpy.data.scenes.get(SCENE_NAME):
        raise RuntimeError('Workbench already exists; use the existing model instead of overwriting it.')
    scene = bpy.data.scenes.new(SCENE_NAME)
    bpy.context.window.scene = scene
    root = bpy.data.objects.new('HV4_AssetRoot', None)
    scene.collection.objects.link(root)
    ceramic = material('Slate ceramic casing', (0.12, 0.19, 0.23), 0.45, 0.38)
    steel = material('Brushed titanium nose', (0.48, 0.58, 0.62), 0.75, 0.30)
    dark = material('Carbon stabilizers', (0.035, 0.055, 0.07), 0.3, 0.48)
    amber = material('Amber safety markings', (0.95, 0.48, 0.065), 0.32, 0.38)
    copper = material('Burnished exhaust lip', (0.38, 0.22, 0.11), 0.8, 0.40)
    black = material('Nozzle interior', (0.012, 0.018, 0.022), 0.25, 0.62)
    ink = material('Stencil ink', (0.014, 0.021, 0.027), 0.05, 0.65)
    lathe('Segmented pressure casing', [(-0.205, 0.086), (-0.18, 0.092),
          (0.10, 0.092), (0.13, 0.086), (0.21, 0.086)], ceramic)
    lathe('Ogive penetrator nose', [(-0.445, 0.004), (-0.415, 0.02),
          (-0.37, 0.044), (-0.30, 0.068), (-0.23, 0.082), (-0.205, 0.086)], steel)
    for z in [-0.20, 0.115, 0.205]:
        lathe('Titanium seam collar', [(z - 0.006, 0.094), (z + 0.006, 0.094)], steel)
    for z in [-0.165, 0.085]:
        lathe('Amber identification band', [(z - 0.012, 0.094), (z + 0.012, 0.094)], amber)
    # Hollow bell with a visible lip and recessed throat, rather than a glowing nose.
    lathe('Flared copper nozzle bell', [(0.215, 0.057), (0.25, 0.069),
          (0.31, 0.083), (0.325, 0.083), (0.325, 0.060), (0.25, 0.044),
          (0.22, 0.039)], copper, caps=False)
    lathe('Recessed nozzle throat', [(0.215, 0.04), (0.235, 0.04)], black)
    for i in range(4):
        angle = i * math.pi / 2 + math.pi / 4
        polygon = [(0.082, 0.025), (0.108, 0.075), (0.185, 0.235),
                   (0.175, 0.285), (0.082, 0.255)]
        verts = []
        for thickness in [-0.006, 0.006]:
            for radial, z in polygon:
                x = radial * math.cos(angle) - thickness * math.sin(angle)
                y = radial * math.sin(angle) + thickness * math.cos(angle)
                verts.append(coords((x, y, z)))
        n = len(polygon)
        faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
        faces += [(j, (j + 1) % n, (j + 1) % n + n, j + n) for j in range(n)]
        mesh = bpy.data.meshes.new('Swept stabilizer')
        mesh.from_pydata(verts, [], faces)
        obj = bpy.data.objects.new('Swept stabilizer %d' % i, mesh)
        scene.collection.objects.link(obj)
        finish(obj, dark, 0.002)
        # High contrast tips make the four swept fins readable at gameplay scale.
        stripe = box('Fin amber tip', (math.cos(angle) * 0.166, math.sin(angle) * 0.166, 0.235),
                     (0.026, 0.014, 0.036), amber, 0.001)
        stripe.rotation_euler.y = -angle
    for sign in [-1, 1]:
        box('Stamped identification plate', (sign * 0.093, 0, -0.03), (0.006, 0.043, 0.14), amber)
        text = bpy.data.curves.new('HV4 serial stencil', 'FONT')
        text.body = 'HV-4'
        text.size = 0.023
        text.extrude = 0.00015
        text.align_y = 'CENTER'
        obj = bpy.data.objects.new('HV4 serial stencil', text)
        scene.collection.objects.link(obj)
        obj.location = coords((sign * 0.097, 0, 0.027))
        basis = Matrix(((0, 0, sign), (sign, 0, 0), (0, 1, 0)))
        obj.rotation_euler = basis.to_euler()
        obj.data.materials.append(ink)
        obj.parent = root
    socket = bpy.data.objects.new('ExhaustSocket', None)
    socket.location = coords((0, 0, 0.326))
    socket.parent = root
    scene.collection.objects.link(socket)
    nose = bpy.data.objects.new('NoseSocket', None)
    nose.location = coords((0, 0, -0.445))
    nose.parent = root
    scene.collection.objects.link(nose)
    print('HV4 geometry authored:', len(root.children), 'editable components')


def export_asset():
    DEST.mkdir(parents=True, exist_ok=True)
    scene = bpy.data.scenes[SCENE_NAME]
    bpy.context.window.scene = scene
    root = bpy.data.objects['HV4_AssetRoot']
    bpy.ops.wm.save_as_mainfile(filepath=str(DEST / 'hv4_havoc_missile.blend'))
    # Consolidate evaluated parts into one runtime mesh with material groups.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    exports = []
    for obj in list(root.children):
        if obj.type not in {'MESH', 'FONT'}:
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = bpy.data.meshes.new_from_object(evaluated, depsgraph=depsgraph)
        duplicate = bpy.data.objects.new('Flight_' + obj.name, mesh)
        scene.collection.objects.link(duplicate)
        duplicate.matrix_world = obj.matrix_world.copy()
        exports.append(duplicate)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in exports:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = exports[0]
    bpy.ops.object.join()
    flight = bpy.context.object
    flight.name = 'HV4_Havoc_FlightMesh'
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    root.select_set(True)
    flight.parent = root
    for name in ['ExhaustSocket', 'NoseSocket']:
        bpy.data.objects[name].select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(DEST / 'hv4_havoc_missile.glb'),
        export_format='GLB', use_selection=True, use_active_scene=True, export_yup=True,
        export_cameras=False, export_lights=False, export_animations=False,
        export_materials='EXPORT')
    flight.data.calc_loop_triangles()
    print('HV4 exported:', len(flight.data.loop_triangles), 'triangles,',
          len(flight.data.materials), 'material slots; forward -Z, nozzle +Z 0.326m')
    bpy.data.objects.remove(flight, do_unlink=True)
    # Source .blend already saved before export-only consolidation.


if __name__ == '__main__':
    build_model()
    export_asset()
