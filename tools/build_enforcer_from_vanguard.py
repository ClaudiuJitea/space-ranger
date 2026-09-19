"""Run inside Blender MCP: derive the Nightguard suit from the player mesh.

The enemy deliberately shares the Vanguard character's anatomy, worn armor
texture and animation rig. It differs through cool, subdued suit markings.
"""

import bpy
from pathlib import Path

ROOT = Path('/home/clau/Godot/games/space-ranger/assets/models')

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'player.glb'))

character = next(o for o in bpy.context.selected_objects if o.type == 'ARMATURE')
character.name = 'Nightguard_Rig'
body = next(o for o in character.children if o.type == 'MESH' and 'visor' not in o.name.lower())
visor = next(o for o in character.children if o.type == 'MESH' and 'visor' in o.name.lower())
body.name = 'Nightguard_Suit'
visor.name = 'Nightguard_Visor'

source = bpy.data.images.load(str(ROOT / 'player_vanguard_vanguard_diffuse_tga.jpg'), check_existing=False)
target = source.copy()
target.name = 'Nightguard_Suit_Diffuse'
pixels = list(source.pixels[:])
for index in range(0, len(pixels), 4):
    red, green, blue = pixels[index:index + 3]
    # The player's red stripes become worn desaturated steel-blue markings.
    if red > green * 1.35 and red > blue * 1.35 and green < 0.42:
        luminance = max(0.16, min(0.42, (red + green + blue) / 3.0))
        pixels[index] = luminance * 0.68
        pixels[index + 1] = luminance * 0.86
        pixels[index + 2] = luminance
    # Tan ceramic armor and olive fabric are cooler/darker than the player.
    elif red > 0.35 and green > 0.24 and blue < green * 0.9:
        pixels[index] = red * 0.74
        pixels[index + 1] = green * 0.79
        pixels[index + 2] = min(1.0, blue * 0.9 + 0.035)
target.pixels[:] = pixels
target.filepath_raw = str(ROOT / 'enemy_enforcer_diffuse.png')
target.file_format = 'PNG'
target.save()

body_material = body.data.materials[0].copy()
body_material.name = 'Nightguard_WornSuit'
for node in body_material.node_tree.nodes:
    if node.type == 'TEX_IMAGE' and node.image and 'diffuse' in node.image.name.lower():
        node.image = target
    if node.type == 'BSDF_PRINCIPLED':
        node.inputs['Metallic'].default_value = 0.18
        node.inputs['Roughness'].default_value = 0.68
        node.inputs['Emission Strength'].default_value = 0.0
body.data.materials[0] = body_material

visor_material = visor.data.materials[0].copy()
visor_material.name = 'Nightguard_VisorGlass'
for node in visor_material.node_tree.nodes:
    if node.type == 'BSDF_PRINCIPLED':
        node.inputs['Base Color'].default_value = (0.22, 0.31, 0.35, 1.0)
        node.inputs['Metallic'].default_value = 0.15
        node.inputs['Roughness'].default_value = 0.36
        node.inputs['Emission Strength'].default_value = 0.0
visor.data.materials[0] = visor_material

bpy.ops.object.select_all(action='DESELECT')
character.select_set(True)
for child in character.children_recursive:
    child.select_set(True)
bpy.context.view_layer.objects.active = character
bpy.ops.export_scene.gltf(
    filepath=str(ROOT / 'enemy_enforcer.glb'),
    export_format='GLB',
    use_selection=True,
    export_animations=True,
    export_animation_mode='NLA_TRACKS',
    export_apply=True,
    export_lights=False,
    export_cameras=False,
)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'nightguard_vanguard_variant.blend'))
print('NIGHTGUARD_VANGUARD_VARIANT_OK', target.size[:], (ROOT / 'enemy_enforcer.glb').stat().st_size)
