"""Blender MCP build: grounded, non-neon twin-thruster scout backpack."""

import bpy
from pathlib import Path

ROOT = Path('/home/clau/Godot/games/space-ranger/assets/models')

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metallic=0.0, roughness=0.7, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        bsdf.inputs['Emission Color'].default_value = (*color, 1.0)
        bsdf.inputs['Emission Strength'].default_value = emission
    return mat

shell = material('Nightguard_Scout_Ceramic', (0.24, 0.30, 0.32), 0.35, 0.65)
steel = material('Nightguard_Scout_Gunmetal', (0.11, 0.15, 0.16), 0.55, 0.54)
trim = material('Nightguard_Scout_SatinTrim', (0.43, 0.46, 0.42), 0.42, 0.62)
heat = material('Nightguard_Scout_ExhaustHeat', (0.64, 0.65, 0.55), 0.15, 0.42, 0.18)
dark = material('Nightguard_Scout_NozzleInterior', (0.035, 0.045, 0.046), 0.35, 0.88)

def bevel(obj, amount=0.012):
    modifier = obj.modifiers.new('Worn machined edges', 'BEVEL')
    modifier.width = amount
    modifier.segments = 2
    obj.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')

def box(name, pos, size, mat, edge=0.012):
    # Author locations in Godot coordinates, then convert to Blender's Z-up.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(pos[0], -pos[2], pos[1]))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if edge:
        bevel(obj, edge)
    return obj

def cylinder(name, pos, radius, depth, mat, vertices=16):
    # Cylinder's Blender Z axis becomes downward/upward Godot Y.
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(pos[0], -pos[2], pos[1]))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel(obj, 0.007)
    return obj

# Origin is at the middle of the wearer’s upper back; +Z faces the camera.
box('Backplate', (0, 0, -0.045), (0.43, 0.49, 0.07), steel)
box('Ceramic Power Module', (0, 0.055, 0.025), (0.34, 0.38, 0.13), shell, 0.025)
box('Service Panel', (0, 0.07, 0.105), (0.23, 0.22, 0.015), trim, 0.005)
for side in (-1, 1):
    x = side * 0.26
    box('Armored Shoulder Rail', (x, 0.12, -0.015), (0.08, 0.36, 0.11), shell)
    cylinder('Fuel Cell', (x, -0.015, 0.075), 0.095, 0.42, steel)
    for y in (0.13, -0.12):
        cylinder('Cell Collar', (x, y, 0.075), 0.106, 0.025, trim)
    cylinder('Downward Thruster Housing', (x, -0.27, 0.075), 0.115, 0.125, shell)
    cylinder('Dark Exhaust Throat', (x, -0.343, 0.075), 0.083, 0.012, dark)
    cylinder('Satin Heat Core', (x, -0.351, 0.075), 0.038, 0.014, heat)
    box('Clamp and Harness', (side * 0.155, 0.185, -0.07), (0.045, 0.18, 0.09), trim)

box('Upper Release Handle', (0, 0.245, 0.018), (0.16, 0.034, 0.075), trim)
for x in (-0.075, 0, 0.075):
    box('Cooling Vent', (x, -0.118, 0.107), (0.038, 0.13, 0.013), steel, 0.003)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=str(ROOT / 'enemy_scout_jetpack.glb'),
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_animations=False,
    export_lights=False,
    export_cameras=False,
)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'enemy_scout_jetpack.blend'))
print('SCOUT_JETPACK_OK', (ROOT / 'enemy_scout_jetpack.glb').stat().st_size)
