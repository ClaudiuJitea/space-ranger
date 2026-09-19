"""Executed inside Blender through Blender MCP. Builds and exports enemy GLBs."""

import bpy
import math
from pathlib import Path
from mathutils import Vector

OUT = Path("/home/clau/Godot/games/space-ranger/assets/models")


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.actions):
        pass


def material(name, color, metallic=0.75, roughness=0.32, emission=None, strength=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        key = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
        bsdf.inputs[key].default_value = (*emission, 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = strength
    return mat


MATS = {}


def init_materials():
    MATS.update({
        "black": material("SR_BlackTitanium", (0.012, 0.02, 0.03), 0.92, 0.2),
        "metal": material("SR_Gunmetal", (0.055, 0.085, 0.12), 0.86, 0.28),
        "armor": material("SR_ArmorCeramic", (0.2, 0.27, 0.34), 0.62, 0.3),
        "white": material("SR_WhiteArmor", (0.48, 0.58, 0.66), 0.5, 0.26),
        "cyan": material("SR_CyanEmission", (0.12, 0.26, 0.28), 0.25, 0.42, (0.16, 0.42, 0.45), 0.9),
        "red": material("SR_RedEmission", (0.28, 0.31, 0.27), 0.25, 0.45, (0.4, 0.43, 0.38), 0.55),
        "orange": material("SR_OrangeEmission", (0.3, 0.27, 0.2), 0.2, 0.42, (0.5, 0.42, 0.26), 0.75),
        "violet": material("SR_VioletEmission", (0.26, 0.26, 0.31), 0.2, 0.48, (0.34, 0.33, 0.38), 0.55),
        "olive": material("SR_EnforcerOlive", (0.12, 0.15, 0.13), 0.52, 0.48),
        "cloth": material("SR_EnforcerCloth", (0.035, 0.045, 0.05), 0.08, 0.76),
        "bone": material("SR_EnforcerBoneArmor", (0.34, 0.35, 0.31), 0.42, 0.4),
        "amber": material("SR_EnforcerAmberOptic", (0.22, 0.27, 0.28), 0.15, 0.4, (0.4, 0.5, 0.5), 0.4),
    })


def finish(obj, name, mat, bevel=0.035):
    obj.name = name
    if mat:
        obj.data.materials.append(MATS[mat] if isinstance(mat, str) else mat)
    if bevel > 0:
        mod = obj.modifiers.new("Weighted bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return obj


def box(root, name, loc, scale, mat="metal", rot=(0, 0, 0), bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.object
    obj.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.parent = root
    return finish(obj, name, mat, bevel)


def sphere(root, name, loc, scale, mat="metal", segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.parent = root
    return finish(obj, name, mat, 0)


def cylinder(root, name, loc, radius, depth, mat="metal", rot=(0, 0, 0), vertices=12, bevel=0.025):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.parent = root
    return finish(obj, name, mat, bevel)


def cone(root, name, loc, r1, r2, depth, mat="metal", rot=(0, 0, 0), vertices=8):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.parent = root
    return finish(obj, name, mat, 0.02)


def torus(root, name, loc, major, minor, mat="cyan", rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=16, minor_segments=6, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.parent = root
    return finish(obj, name, mat, 0)


def root(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type = "CUBE"
    obj.empty_display_size = 0.25
    return obj


def key_action(obj, name, keyframes):
    action = bpy.data.actions.new(name)
    obj.animation_data_create()
    obj.animation_data.action = action
    for frame, location, rotation, scale in keyframes:
        obj.location = location
        obj.rotation_euler = rotation
        obj.scale = scale
        obj.keyframe_insert("location", frame=frame)
        obj.keyframe_insert("rotation_euler", frame=frame)
        obj.keyframe_insert("scale", frame=frame)
    track = obj.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(keyframes[0][0]), action)
    obj.animation_data.action = None


def animate(root_obj, amplitude=0.04):
    key_action(root_obj, "Idle", [
        (1, (0, 0, 0), (0, 0, -0.025), (1, 1, 1)),
        (20, (0, 0, amplitude), (0, 0, 0.025), (1, 1, 1)),
        (40, (0, 0, 0), (0, 0, -0.025), (1, 1, 1)),
    ])
    key_action(root_obj, "Attack", [
        (1, (0, 0, 0), (0, 0, 0), (1, 1, 1)),
        (7, (0, 0.08, 0), (0.06, 0, 0), (0.96, 1.08, 0.97)),
        (18, (0, 0, 0), (0, 0, 0), (1, 1, 1)),
    ])
    key_action(root_obj, "Death", [
        (1, (0, 0, 0), (0, 0, 0), (1, 1, 1)),
        (18, (0, 0, 0.1), (0.4, 0.2, 1.25), (1.08, 1.08, 1.08)),
        (35, (0, 0, -0.25), (1.0, 0.7, 2.5), (0.01, 0.01, 0.01)),
    ])


def build_drone():
    r = root("ReconDrone_Root")
    sphere(r, "DroneCore", (0, 0, 0), (0.46, 0.42, 0.32), "black")
    sphere(r, "ArmoredCowl", (0, -0.03, 0.12), (0.38, 0.34, 0.25), "white", 12, 6)
    sphere(r, "Optic", (0, 0.34, -0.01), (0.14, 0.07, 0.14), "cyan", 12, 6)
    torus(r, "OpticGuard", (0, 0.37, -0.01), 0.17, 0.025, "metal", (math.pi/2, 0, 0))
    for side in (-1, 1):
        box(r, f"Wing_{side}", (side*0.48, -0.02, 0.02), (0.5, 0.34, 0.08), "armor", (0, side*0.18, side*0.08))
        cone(r, f"Thruster_{side}", (side*0.58, -0.22, -0.02), 0.11, 0.06, 0.28, "cyan", (math.pi/2, 0, 0))
        box(r, f"Antenna_{side}", (side*0.27, -0.08, 0.35), (0.035, 0.035, 0.28), "cyan", (0, side*0.2, 0))
    animate(r, 0.06)
    return r


def build_gunship():
    r = root("HeavyGunship_Root")
    box(r, "Fuselage", (0, 0, 0), (1.05, 1.35, 0.55), "black", bevel=0.1)
    box(r, "TopArmor", (0, -0.02, 0.34), (0.8, 0.95, 0.2), "armor", (0.08, 0, 0), 0.06)
    box(r, "NoseWedge", (0, 0.72, -0.02), (0.72, 0.38, 0.36), "white", (0.16, 0, 0), 0.05)
    sphere(r, "CommandEye", (0, 0.83, 0.13), (0.18, 0.06, 0.09), "violet", 12, 6)
    for side in (-1, 1):
        box(r, f"WingBlade_{side}", (side*0.78, -0.06, 0.02), (0.72, 0.9, 0.12), "armor", (0, side*0.12, side*0.09), 0.035)
        cylinder(r, f"Engine_{side}", (side*0.72, -0.46, -0.02), 0.18, 0.5, "black", (math.pi/2, 0, 0), 12)
        cylinder(r, f"EngineGlow_{side}", (side*0.72, -0.73, -0.02), 0.11, 0.035, "violet", (math.pi/2, 0, 0), 12, 0)
        cylinder(r, f"Cannon_{side}", (side*0.46, 0.66, -0.2), 0.07, 0.58, "metal", (math.pi/2, 0, 0), 10)
        cylinder(r, f"MuzzleGlow_{side}", (side*0.46, 0.96, -0.2), 0.075, 0.035, "orange", (math.pi/2, 0, 0), 10, 0)
    animate(r, 0.04)
    return r


def build_turret():
    r = root("SentryTurret_Root")
    cylinder(r, "AnchoredBase", (0, 0, 0.12), 0.52, 0.24, "black", vertices=12, bevel=0.04)
    cylinder(r, "RotationRing", (0, 0, 0.3), 0.43, 0.13, "cyan", vertices=16, bevel=0.015)
    sphere(r, "GimbalHousing", (0, 0.03, 0.58), (0.42, 0.38, 0.34), "armor", 12, 6)
    box(r, "FacePlate", (0, 0.34, 0.6), (0.55, 0.13, 0.28), "white", (0.05, 0, 0), 0.035)
    sphere(r, "TargetLens", (0, 0.42, 0.69), (0.1, 0.055, 0.1), "orange", 12, 6)
    for side in (-1, 1):
        cylinder(r, f"BurstCannon_{side}", (side*0.24, 0.61, 0.52), 0.06, 0.6, "metal", (math.pi/2, 0, 0), 10)
        box(r, f"AmmoPod_{side}", (side*0.43, 0.02, 0.52), (0.18, 0.45, 0.36), "black", bevel=0.04)
        box(r, f"HeatStripe_{side}", (side*0.43, 0.25, 0.52), (0.19, 0.03, 0.06), "orange", bevel=0.005)
    animate(r, 0.02)
    return r


def build_crawler():
    r = root("RiftCrawler_Root")
    box(r, "CrawlerBody", (0, 0, 0.46), (0.9, 0.58, 0.42), "black", (0, 0.08, 0), 0.08)
    box(r, "SpineArmor", (-0.08, 0, 0.72), (0.64, 0.48, 0.16), "armor", (0, -0.1, 0), 0.04)
    cone(r, "HeadBlade", (0.52, 0, 0.48), 0.27, 0.1, 0.54, "white", (0, math.pi/2, 0), 6)
    sphere(r, "PredatorEye", (0.75, 0, 0.57), (0.055, 0.17, 0.085), "red", 10, 5)
    for side in (-1, 1):
        for idx, x in enumerate((-0.3, 0.2)):
            box(r, f"LegUpper_{side}_{idx}", (x, side*0.4, 0.33), (0.14, 0.48, 0.12), "armor", (side*0.28, 0, side*0.12), 0.025)
            box(r, f"LegLower_{side}_{idx}", (x+0.08, side*0.62, 0.14), (0.12, 0.34, 0.12), "black", (side*0.42, 0, -side*0.1), 0.02)
        cone(r, f"Claw_{side}", (0.58, side*0.4, 0.22), 0.09, 0.0, 0.42, "red", (0, math.pi/2, 0), 5)
    for x in (-0.28, 0.0, 0.28):
        box(r, f"SpineGlow_{x}", (x, 0, 0.82), (0.08, 0.28, 0.035), "red", bevel=0.008)
    animate(r, 0.025)
    return r


def build_enforcer():
    """Armored human-scale boarding trooper with restrained practical lights."""
    r = root("NightguardEnforcer_Root")
    # Boots and articulated legs establish a readable human silhouette.
    for side in (-1, 1):
        x = side * 0.19
        box(r, f"Boot_{side}", (x + 0.04, -0.02, 0.11), (0.24, 0.46, 0.18), "black", (0, 0, side * 0.015), 0.045)
        cylinder(r, f"Shin_{side}", (x, 0, 0.46), 0.105, 0.56, "cloth", vertices=10, bevel=0.025)
        box(r, f"KneePlate_{side}", (x, -0.095, 0.68), (0.23, 0.12, 0.22), "bone", (0.08, 0, 0), 0.04)
        cylinder(r, f"Thigh_{side}", (x, 0, 0.88), 0.13, 0.48, "olive", vertices=10, bevel=0.035)

    box(r, "PelvisRig", (0, 0, 1.08), (0.52, 0.34, 0.3), "black", bevel=0.07)
    box(r, "TorsoUnderSuit", (0, 0, 1.45), (0.68, 0.38, 0.7), "cloth", bevel=0.12)
    box(r, "ChestPlate", (0, -0.12, 1.53), (0.72, 0.13, 0.55), "bone", (0.05, 0, 0), 0.07)
    box(r, "AbdominalArmor", (0, -0.115, 1.22), (0.48, 0.11, 0.18), "olive", bevel=0.035)
    box(r, "Backpack", (0, 0.23, 1.5), (0.5, 0.22, 0.62), "black", bevel=0.065)
    # Helmet reads as military hardware rather than a glowing robot head.
    sphere(r, "HelmetShell", (0, 0, 1.97), (0.31, 0.28, 0.32), "olive", 16, 8)
    box(r, "HelmetBrow", (0, -0.245, 2.02), (0.55, 0.09, 0.17), "bone", (0.08, 0, 0), 0.045)
    box(r, "DarkVisor", (0, -0.295, 1.94), (0.43, 0.035, 0.12), "black", bevel=0.025)
    box(r, "VisorSlit", (0.08, -0.318, 1.95), (0.18, 0.018, 0.025), "amber", bevel=0.006)
    cylinder(r, "Breather", (0, -0.29, 1.82), 0.105, 0.12, "black", (math.pi/2, 0, 0), 10)

    for side in (-1, 1):
        x = side * 0.47
        sphere(r, f"ShoulderJoint_{side}", (x, 0, 1.64), (0.2, 0.22, 0.2), "cloth", 12, 6)
        box(r, f"ShoulderPad_{side}", (side * 0.53, 0, 1.68), (0.27, 0.4, 0.24), "bone", (0, side * 0.08, side * 0.08), 0.06)
        cylinder(r, f"UpperArm_{side}", (side * 0.53, -0.04, 1.39), 0.105, 0.42, "olive", (0, side * 0.13, 0), 10)
        cylinder(r, f"Forearm_{side}", (side * 0.43, -0.14, 1.18), 0.095, 0.42, "black", (0.12, side * 0.24, 0), 10)

    # Compact rifle carried across the chest, with a single low-output status lamp.
    box(r, "RifleReceiver", (0.32, -0.36, 1.38), (0.86, 0.16, 0.2), "black", (0, 0, -0.06), 0.035)
    box(r, "RifleStock", (-0.2, -0.34, 1.43), (0.42, 0.14, 0.19), "olive", (0, 0, -0.06), 0.04)
    cylinder(r, "RifleBarrel", (0.88, -0.36, 1.34), 0.055, 0.6, "metal", (0, math.pi/2, 0), 10)
    cylinder(r, "RifleMuzzle", (1.19, -0.36, 1.34), 0.068, 0.08, "amber", (0, math.pi/2, 0), 10, 0)
    box(r, "Magazine", (0.25, -0.34, 1.18), (0.18, 0.14, 0.34), "metal", (0, 0, 0.1), 0.025)
    animate(r, 0.018)
    return r


def build_boss():
    r = root("ApexDreadnought_Root")
    box(r, "CoreChassis", (0, 0, 0), (1.55, 2.75, 1.25), "black", bevel=0.16)
    sphere(r, "ReactorCore", (0, 1.42, 0), (0.48, 0.14, 0.48), "red", 16, 8)
    torus(r, "ReactorContainment", (0, 1.46, 0), 0.58, 0.065, "metal", (math.pi/2, 0, 0))
    for side in (-1, 1):
        box(r, f"ShoulderArmor_{side}", (side*1.12, 0.05, 0.2), (0.9, 2.1, 0.78), "armor", (0, side*0.08, side*0.08), 0.1)
        box(r, f"CrownBlade_{side}", (side*0.72, -0.55, 0.95), (0.22, 1.2, 0.55), "white", (side*0.18, 0, side*0.16), 0.04)
        cylinder(r, f"SiegeCannon_{side}", (side*1.14, 1.05, -0.18), 0.16, 1.5, "metal", (math.pi/2, 0, 0), 12)
        cylinder(r, f"SiegeMuzzle_{side}", (side*1.14, 1.82, -0.18), 0.18, 0.06, "orange", (math.pi/2, 0, 0), 12, 0)
        box(r, f"EnergyRail_{side}", (side*0.76, 0.0, -0.56), (0.12, 1.8, 0.05), "cyan", bevel=0.01)
        cone(r, f"Mandible_{side}", (side*0.65, 1.15, 0.35), 0.2, 0.04, 0.9, "white", (math.pi/2, 0, side*0.2), 6)
    for z in (-0.62, 0.66):
        box(r, f"CoreVent_{z}", (0, -0.85, z), (0.7, 0.42, 0.1), "red", bevel=0.02)
    animate(r, 0.07)
    return r


def export_root(r, filename):
    bpy.ops.object.select_all(action="DESELECT")
    r.select_set(True)
    for obj in r.children_recursive:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = r
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / filename),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_apply=True,
        export_lights=False,
        export_cameras=False,
    )


reset_scene()
init_materials()
assets = [
    (build_drone(), "drone.glb"),
    (build_gunship(), "gunship.glb"),
    (build_turret(), "turret.glb"),
    (build_crawler(), "enemy_crawler.glb"),
    (build_boss(), "boss.glb"),
]
for asset_root, filename in assets:
    export_root(asset_root, filename)

# Preserve a clean Blender-authored source workbench and arrange a comparison lineup.
positions = (-5.2, -2.7, -0.4, 2.0, 5.0)
for (asset_root, _), x in zip(assets, positions):
    asset_root.location.x = x
    asset_root.location.z = 0.1

bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 40
bpy.context.scene.render.engine = "BLENDER_EEVEE"
bpy.context.scene.render.resolution_x = 1400
bpy.context.scene.render.resolution_y = 720
bpy.context.scene.render.resolution_percentage = 100
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "enemies_aaa_workbench.blend"))
print("ENEMY_ASSET_EXPORT_OK", [(name, (OUT / name).stat().st_size) for _, name in assets])
