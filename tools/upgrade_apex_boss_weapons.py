"""Upgrades the Apex Iron Vanguard model with special weapons:
- Twin Shoulder-Mounted Tactical Rocket Pods (Left & Right)
- Chest-Mounted High-Intensity Thermal Beam Aperture
Authored for Blender MCP.
"""
import bpy
import math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path('/home/clau/Godot/games/space-ranger')
OUT = ROOT / 'assets/models/campaign_bosses'
APEX_GLB = OUT / 'apex.glb'


def create_material(name, color, metal=0.8, rough=0.35, emission=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (*color, 1.0)
        bsdf.inputs['Metallic'].default_value = metal
        bsdf.inputs['Roughness'].default_value = rough
        if emission > 0:
            key = 'Emission Color' if 'Emission Color' in bsdf.inputs else 'Emission'
            bsdf.inputs[key].default_value = (*color, 1.0)
            if 'Emission Strength' in bsdf.inputs:
                bsdf.inputs['Emission Strength'].default_value = emission
    return mat


def box(parent, name, loc, size, mat, bevel=0.008):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.parent = parent
    o.data.materials.append(mat)
    if bevel > 0:
        mod = o.modifiers.new('Bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    return o


def cylinder(parent, name, loc, radius, depth, mat, axis='Y', bevel=0.004):
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=radius, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    if axis == 'Y':
        o.rotation_euler.x = math.pi / 2
    elif axis == 'X':
        o.rotation_euler.y = math.pi / 2
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.parent = parent
    o.data.materials.append(mat)
    for poly in o.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    if bevel > 0:
        mod = o.modifiers.new('Bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    return o


def ring(parent, name, loc, radius, thickness, mat, axis='Y'):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness, major_segments=24, minor_segments=8, location=loc)
    o = bpy.context.object
    o.name = name
    if axis == 'Y':
        o.rotation_euler.x = math.pi / 2
    elif axis == 'X':
        o.rotation_euler.y = math.pi / 2
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.parent = parent
    o.data.materials.append(mat)
    for poly in o.data.polygons:
        poly.use_smooth = True
    return o


def upgrade():
    # Clear Blender data
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

    # Import apex.glb
    print(f"Importing {APEX_GLB}...")
    bpy.ops.import_scene.gltf(filepath=str(APEX_GLB))

    # Materials
    m_dark = create_material('VANGUARD_weapon_dark', (0.02, 0.03, 0.04), metal=0.75, rough=0.38)
    m_ceramic = create_material('VANGUARD_weapon_ceramic', (0.16, 0.22, 0.25), metal=0.45, rough=0.42)
    m_steel = create_material('VANGUARD_weapon_steel', (0.35, 0.42, 0.45), metal=0.88, rough=0.28)
    m_rocket_glow = create_material('VANGUARD_rocket_glow', (1.0, 0.35, 0.05), metal=0.2, rough=0.25, emission=2.5)
    m_beam_core = create_material('VANGUARD_beam_core', (1.0, 0.12, 0.04), metal=0.1, rough=0.2, emission=3.5)

    # 1. BUILD SHOULDER ROCKET PODS (Left and Right)
    # Positions in Blender coordinates (Y is forward, Z is up)
    for side, sign in [('L', -1), ('R', 1)]:
        # Clean previous pod if exists
        old_pod = bpy.data.objects.get(f'ShoulderRocketPod_{side}')
        if old_pod:
            bpy.data.objects.remove(old_pod, do_unlink=True)

        pod_root = bpy.data.objects.new(f'ShoulderRocketPod_{side}', None)
        bpy.context.collection.objects.link(pod_root)
        px, py, pz = sign * 0.38, -0.06, 1.54
        pod_root.location = (px, py, pz)

        # Main armored pod casing
        box(pod_root, f'Pod_Casing_{side}', (0, 0, 0), (0.16, 0.28, 0.16), m_dark, bevel=0.010)
        # Sloped ceramic top strike plate
        box(pod_root, f'Pod_ArmorPlate_{side}', (0, 0.02, 0.088), (0.14, 0.24, 0.03), m_ceramic, bevel=0.006)
        # Structural mounting bracket to shoulder
        box(pod_root, f'Pod_Mount_{side}', (-sign * 0.075, -0.04, -0.05), (0.05, 0.14, 0.08), m_steel, bevel=0.004)

        # 4 Launch Tubes in a 2x2 grid (firing along +Y in Blender)
        tube_offsets = [(-0.04, 0.04), (0.04, 0.04), (-0.04, -0.04), (0.04, -0.04)]
        for idx, (tx, tz) in enumerate(tube_offsets):
            # Outer launch tube sleeve
            cylinder(pod_root, f'Tube_{side}_{idx}', (tx, 0.06, tz), 0.028, 0.15, m_steel, axis='Y', bevel=0.002)
            # Inner dark barrel bore
            cylinder(pod_root, f'Bore_{side}_{idx}', (tx, 0.07, tz), 0.022, 0.16, m_dark, axis='Y', bevel=0.0)
            # Glowing rocket warhead tip inside the tube
            cylinder(pod_root, f'Warhead_{side}_{idx}', (tx, 0.11, tz), 0.016, 0.03, m_rocket_glow, axis='Y', bevel=0.0)

        # Rear exhaust blast deflector louvers (at -Y)
        for j in range(3):
            box(pod_root, f'ExhaustLouver_{side}_{j}', (0, -0.145, -0.04 + j * 0.04), (0.13, 0.015, 0.025), m_steel, bevel=0.002)

        # Socket for projectile spawning (at front face +Y)
        socket = bpy.data.objects.new(f'RocketSocket_{side}', None)
        socket.parent = pod_root
        socket.location = (0, 0.18, 0)
        bpy.context.collection.objects.link(socket)

    # 2. BUILD CHEST THERMAL BEAM APERTURE
    old_beam = bpy.data.objects.get('ChestBeamAperture')
    if old_beam:
        bpy.data.objects.remove(old_beam, do_unlink=True)

    beam_root = bpy.data.objects.new('ChestBeamAperture', None)
    bpy.context.collection.objects.link(beam_root)
    beam_root.location = (0.0, 0.14, 1.34)

    # Outer heavy titanium retaining ring
    cylinder(beam_root, 'Beam_OuterCollar', (0, 0, 0), 0.12, 0.04, m_dark, axis='Y', bevel=0.006)
    ring(beam_root, 'Beam_TitaniumRim', (0, 0.02, 0), 0.115, 0.010, m_steel, axis='Y')
    # Stepped magnetic focusing coils
    ring(beam_root, 'Beam_InnerCoil', (0, 0.028, 0), 0.082, 0.008, m_dark, axis='Y')
    # High-intensity glowing plasma beam core lens
    cylinder(beam_root, 'Beam_CoreEmitter', (0, 0.025, 0), 0.065, 0.02, m_beam_core, axis='Y', bevel=0.002)

    # 4 titanium containment clamps around the emitter
    for i in range(4):
        a = i * math.pi / 2
        cx = 0.10 * math.cos(a)
        cz = 0.10 * math.sin(a)
        box(beam_root, f'Beam_Clamp_{i}', (cx, 0.02, cz), (0.025, 0.035, 0.025), m_steel, bevel=0.003)

    # Re-export apex.glb
    print(f"Exporting updated {APEX_GLB}...")
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=str(APEX_GLB),
        export_format='GLB',
        use_selection=True,
        export_apply=False,
        export_animations=True,
        export_animation_mode='NLA_TRACKS',
        export_yup=True
    )
    print("APEX BOSS SPECIAL WEAPONS MODEL UPGRADE COMPLETE!")


if __name__ == '__main__':
    upgrade()
