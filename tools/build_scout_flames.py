"""Blender MCP build: restrained but unmistakable jet flames for flying scouts."""

import bpy
from math import cos, pi, sin
from pathlib import Path

ROOT = Path('/home/clau/Godot/games/space-ranger/assets/models')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def flame_material(name, color, emission, alpha):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, alpha)
    bsdf.inputs['Roughness'].default_value = 0.92
    bsdf.inputs['Alpha'].default_value = alpha
    bsdf.inputs['Emission Color'].default_value = (*color, 1.0)
    bsdf.inputs['Emission Strength'].default_value = emission
    if alpha < 1.0 and hasattr(mat, 'surface_render_method'):
        mat.surface_render_method = 'BLENDED'
    return mat

outer = flame_material('Scout_Jet_Amber_Heat', (0.98, 0.43, 0.11), 1.15, 0.88)
inner = flame_material('Scout_Jet_Ivory_Core', (1.0, 0.91, 0.65), 1.8, 1.0)

def tapered_flame(name, rings, material, sides=10, phase=0.0):
    verts = []
    faces = []
    for ring_index, (height, radius) in enumerate(rings):
        for side in range(sides):
            angle = 2.0 * pi * side / sides + phase
            # Author in Godot's Y-up frame; Blender's Z is vertical.
            sway = 0.016 * sin(ring_index * 1.3 + phase)
            godot_x = radius * cos(angle) + sway
            godot_z = radius * sin(angle)
            verts.append((godot_x, -godot_z, height))
    for ring_index in range(len(rings) - 1):
        for side in range(sides):
            a = ring_index * sides + side
            b = ring_index * sides + (side + 1) % sides
            c = (ring_index + 1) * sides + (side + 1) % sides
            d = (ring_index + 1) * sides + side
            faces.append((a, b, c, d))
    faces.append(tuple(reversed(range(sides))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(material)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj

tapered_flame('Outer Amber Flame', [
    (0.02, 0.040), (-0.055, 0.068), (-0.12, 0.058),
    (-0.20, 0.080), (-0.29, 0.055), (-0.39, 0.031),
    (-0.49, 0.003),
], outer)
tapered_flame('Inner Pale Flame', [
    (0.01, 0.026), (-0.055, 0.047), (-0.12, 0.036),
    (-0.19, 0.050), (-0.27, 0.031), (-0.34, 0.003),
], inner, phase=0.15)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=str(ROOT / 'enemy_scout_jet_flame.glb'),
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_animations=False,
    export_lights=False,
    export_cameras=False,
)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'enemy_scout_jet_flame.blend'))
print('SCOUT_JET_FLAME_OK', (ROOT / 'enemy_scout_jet_flame.glb').stat().st_size)
