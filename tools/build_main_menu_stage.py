"""Rebuild the SPACE RANGER cinematic title dock inside Menu_Title_Scene.

Keeps the existing Mixamo ranger, then replaces the command deck with a
dark-metal platform, cyan neon channels, holographic consoles, a data cube,
and distant starship silhouettes. Exports assets/models/menu_title_dock.glb.
"""

from __future__ import annotations

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Vector

ROOT = Path("/home/clau/Godot/games/space-ranger")
GLB_PATH = ROOT / "assets/models/menu_title_dock.glb"
BLEND_PATH = ROOT / "assets/models/menu_title_dock.blend"

CYAN = (0.18, 0.85, 1.0, 1.0)
CYAN_SOFT = (0.22, 0.72, 0.95, 1.0)
METAL = (0.035, 0.042, 0.052, 1.0)
METAL_MID = (0.07, 0.085, 0.10, 1.0)
PANEL = (0.018, 0.024, 0.032, 1.0)


def _ensure_scene() -> bpy.types.Scene:
    scene = bpy.data.scenes.get("Menu_Title_Scene")
    if scene is None:
        raise RuntimeError("Menu_Title_Scene is missing")
    bpy.context.window.scene = scene
    return scene


def _mat(name: str, color, metallic=0.0, roughness=0.5, emission=None, emission_strength=0.0, alpha=1.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.45
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = "BLEND"
        if hasattr(mat, "shadow_method"):
            mat.shadow_method = "NONE"
        if hasattr(mat, "show_transparent_back"):
            mat.show_transparent_back = False
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def _link(obj, parent, loc=(0, 0, 0), rot=(0, 0, 0), scale=None):
    obj.parent = parent
    obj.location = loc
    obj.rotation_euler = Euler(rot)
    if scale is not None:
        obj.scale = scale
    return obj


def _mesh(name, mesh, parent, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, scale=None):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    _link(obj, parent, loc, rot, scale)
    if mat is not None:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    return obj


def _box(name, size, parent, loc=(0, 0, 0), rot=(0, 0, 0), mat=None):
    mesh = bpy.data.meshes.new(name + "Mesh")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    bm.to_mesh(mesh)
    bm.free()
    return _mesh(name, mesh, parent, loc, rot, mat)


def _cyl(name, radius, depth, parent, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, segs=48):
    mesh = bpy.data.meshes.new(name + "Mesh")
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=radius, radius2=radius, depth=depth)
    bm.to_mesh(mesh)
    bm.free()
    return _mesh(name, mesh, parent, loc, rot, mat)


def _ico(name, radius, parent, loc=(0, 0, 0), mat=None, subdiv=2):
    mesh = bpy.data.meshes.new(name + "Mesh")
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    bm.to_mesh(mesh)
    bm.free()
    return _mesh(name, mesh, parent, loc, mat=mat)


def _bevel_object(obj, width=0.04, segments=2):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    return obj


def _clear_old_deck(root):
    doomed = [c for c in root.children if c.name != "Character"]
    # Keep Character; remove previous deck parts hanging off Menu_Title_Environment
    keep = {"Character", "Rig_Key_Light", "Rig_Rim_Light", "Rig_Accent_Point"}
    doomed = [c for c in list(root.children) if c.name not in keep]
    for obj in doomed:
        _delete_hierarchy(obj)


def _delete_hierarchy(obj):
    children = list(obj.children)
    for child in children:
        _delete_hierarchy(child)
    bpy.data.objects.remove(obj, do_unlink=True)


def _build_platform(env, mats):
    root = bpy.data.objects.new("Command_Deck_Root", None)
    bpy.context.scene.collection.objects.link(root)
    root.parent = env
    root.empty_display_size = 0.4

    # Main angular slab facing the camera (-Y). Large enough to fill the lower frame.
    slab = _box("Command_Deck_Slab", (9.6, 7.4, 0.42), root, loc=(0.15, -0.35, -0.21), mat=mats["metal"])
    _bevel_object(slab, 0.08, 3)

    under = _box("Deck_Undercarriage", (8.4, 6.2, 1.15), root, loc=(0.15, -0.15, -0.92), mat=mats["panel"])
    _bevel_object(under, 0.06, 2)

    keel = _box("Deck_Keel", (4.8, 3.6, 1.4), root, loc=(0.2, 0.15, -1.85), mat=mats["metal_mid"])
    _bevel_object(keel, 0.05, 2)

    # Side cheeks give the silhouette the stepped, machined look from the reference.
    for i, x in enumerate((-3.55, 3.85)):
        cheek = _box(f"Deck_Cheek_{i}", (1.7, 5.4, 0.55), root, loc=(x, -0.4, -0.48), mat=mats["metal"])
        _bevel_object(cheek, 0.04, 2)

    nose = _box("Deck_Nose", (5.2, 1.6, 0.28), root, loc=(0.1, -3.55, -0.08), mat=mats["metal_mid"])
    _bevel_object(nose, 0.03, 2)

    # Extra mass under the nose so the silhouette reads as a command deck, not a table.
    for i, (sx, loc) in enumerate((
        ((7.2, 1.15, 0.55), (0.15, -3.05, -0.55)),
        ((6.1, 0.85, 0.75), (0.18, -2.35, -0.95)),
        ((3.4, 2.2, 0.7), (0.2, 1.55, -0.72)),
    )):
        step = _box(f"Deck_Step_{i}", sx, root, loc=loc, mat=mats["metal" if i != 1 else "panel"])
        _bevel_object(step, 0.04, 2)

    # Inset panel on the left of the slab (holo projector area).
    inset = _box("Deck_Inset_Well", (2.4, 1.8, 0.08), root, loc=(-1.55, -1.55, 0.04), mat=mats["panel"])

    # Cyan neon channels along the top surface.
    strip_specs = [
        ("Neon_Center_X", (7.6, 0.06, 0.03), (0.2, -0.35, 0.03)),
        ("Neon_Forward_X", (4.8, 0.05, 0.03), (0.1, -3.35, 0.08)),
        ("Neon_Rear_X", (6.4, 0.05, 0.03), (0.15, 2.55, 0.03)),
        ("Neon_Left_Y", (0.055, 5.8, 0.03), (-4.55, -0.4, 0.03)),
        ("Neon_Right_Y", (0.055, 5.8, 0.03), (4.85, -0.4, 0.03)),
        ("Neon_Inner_L", (0.04, 3.4, 0.03), (-2.35, -0.55, 0.03)),
        ("Neon_Inner_R", (0.04, 3.4, 0.03), (2.65, -0.55, 0.03)),
        ("Neon_Nose_L", (1.8, 0.045, 0.03), (-1.6, -3.55, 0.08)),
        ("Neon_Nose_R", (1.8, 0.045, 0.03), (1.8, -3.55, 0.08)),
        ("Neon_Under_L", (0.04, 4.6, 0.035), (-3.95, -0.35, -0.55)),
        ("Neon_Under_R", (0.04, 4.6, 0.035), (4.25, -0.35, -0.55)),
        ("Neon_Front_Face", (6.8, 0.04, 0.05), (0.15, -3.95, -0.18)),
    ]
    for name, size, loc in strip_specs:
        _box(name, size, root, loc=loc, mat=mats["neon"])

    # Corner ticks.
    for i, (x, y) in enumerate(((-4.4, -3.2), (4.7, -3.2), (-4.4, 2.4), (4.7, 2.4))):
        _box(f"Neon_Tick_{i}", (0.28, 0.045, 0.03), root, loc=(x, y, 0.04), mat=mats["neon"])
        _box(f"Neon_TickV_{i}", (0.045, 0.28, 0.03), root, loc=(x, y, 0.04), mat=mats["neon"])

    # Hero dais: circular pad with emissive ring, slightly back-right of center.
    dais_x, dais_y = 0.55, 0.35
    _cyl("Hero_Dais_Base", 0.82, 0.10, root, loc=(dais_x, dais_y, 0.06), mat=mats["metal_mid"], segs=64)
    ring_mesh = bpy.data.meshes.new("Hero_Dais_RingMesh")
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=False, segments=72, radius=0.84)
    for v in list(bm.verts):
        v.co.z = 0.0
    geom = bmesh.ops.extrude_edge_only(bm, edges=bm.edges)["geom"]
    verts = [e for e in geom if isinstance(e, bmesh.types.BMVert)]
    for v in verts:
        v.co.z = 0.025
        radial = Vector((v.co.x, v.co.y, 0.0)).normalized()
        v.co.x = radial.x * 0.78
        v.co.y = radial.y * 0.78
    bm.to_mesh(ring_mesh)
    bm.free()
    ring = _mesh("Hero_Dais_Ring", ring_mesh, root, loc=(dais_x, dais_y, 0.12), mat=mats["neon"])

    inner = _cyl("Hero_Dais_Inner", 0.62, 0.02, root, loc=(dais_x, dais_y, 0.115), mat=mats["panel"], segs=48)
    _cyl("Hero_Dais_Core", 0.18, 0.04, root, loc=(dais_x, dais_y, 0.13), mat=mats["neon_soft"], segs=24)

    # Support column under the dais.
    _cyl("Support_Column", 0.55, 2.4, root, loc=(dais_x, dais_y, -1.35), mat=mats["metal"], segs=24)

    return root, (dais_x, dais_y)


def _build_holograms(root, mats):
    # Glowing data-cube projector on the left well — a cyan cylinder like the reference.
    _cyl("Holo_Console_Pedestal", 0.38, 0.14, root, loc=(-1.45, -1.55, 0.12), mat=mats["metal_mid"], segs=32)
    _cyl("Holo_Pedestal_Ring", 0.40, 0.03, root, loc=(-1.45, -1.55, 0.20), mat=mats["neon"], segs=32)
    _cyl("Holo_Energy_Core", 0.13, 0.38, root, loc=(-1.45, -1.55, 0.42), mat=mats["holo_solid"], segs=24)
    _cyl("Holo_Core_Column", 0.09, 0.22, root, loc=(-1.45, -1.55, 0.44), mat=mats["holo_glow"], segs=16)
    cube = _box("Holo_Data_Cube", (0.16, 0.16, 0.16), root, loc=(-1.45, -1.55, 0.68), mat=mats["holo_solid"])
    cube.rotation_euler = Euler((0.4, 0.55, 0.3))

    # Floating translucent consoles.
    left = _box("Holo_Console_Left", (1.15, 0.02, 0.62), root, loc=(-1.85, -1.05, 0.55), rot=(0.35, 0.05, 0.35), mat=mats["holo_panel"])
    right = _box("Holo_Console_Right", (0.85, 0.02, 0.42), root, loc=(1.85, -0.55, 0.72), rot=(0.4, -0.08, -0.25), mat=mats["holo_panel"])
    mid = _box("Holo_Console_Mid", (0.55, 0.016, 0.32), root, loc=(-0.55, -1.15, 0.48), rot=(0.5, 0.0, 0.1), mat=mats["holo_panel"])

    # Tiny telemetry bricks around the projector.
    for i, loc in enumerate(((-1.05, -1.7, 0.28), (-1.85, -1.75, 0.26), (-1.15, -1.15, 0.26))):
        _box(f"Holo_Brick_{i}", (0.22, 0.04, 0.14), root, loc=loc, rot=(0.2, 0.0, 0.15 * i), mat=mats["holo_panel"])

    # Circular HUD ring around the ranger.
    hud = bpy.data.meshes.new("Holo_HUD_RingMesh")
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=False, segments=96, radius=1.55)
    geom = bmesh.ops.extrude_edge_only(bm, edges=bm.edges)["geom"]
    verts = [e for e in geom if isinstance(e, bmesh.types.BMVert)]
    for v in verts:
        radial = Vector((v.co.x, v.co.y, 0.0)).normalized()
        v.co.x = radial.x * 1.48
        v.co.y = radial.y * 1.48
        v.co.z = 0.01
    bm.to_mesh(hud)
    bm.free()
    _mesh("Holo_HUD_Ring", hud, root, loc=(0.55, 0.35, 1.05), rot=(0.12, 0.0, 0.0), mat=mats["holo_line"])

    hud2 = bpy.data.meshes.new("Holo_HUD_ArcMesh")
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=False, segments=80, radius=1.95)
    geom = bmesh.ops.extrude_edge_only(bm, edges=bm.edges)["geom"]
    verts = [e for e in geom if isinstance(e, bmesh.types.BMVert)]
    for v in verts:
        radial = Vector((v.co.x, v.co.y, 0.0)).normalized()
        v.co.x = radial.x * 1.90
        v.co.y = radial.y * 1.90
        v.co.z = 0.008
    bm.to_mesh(hud2)
    bm.free()
    _mesh("Holo_HUD_Arc", hud2, root, loc=(0.55, 0.35, 1.15), rot=(0.18, 0.05, 0.0), mat=mats["holo_line"])

    return left, right, mid


def _clear_backdrop():
    existing = bpy.data.objects.get("MenuCinematicBackdrop")
    if existing:
        _delete_hierarchy(existing)
    leftovers = [o.name for o in bpy.data.objects if o.name.startswith(("MenuGasGiant", "MenuPlanetRing_", "MenuStar_", "MenuNebula_", "Starship_"))]
    for name in leftovers:
        obj = bpy.data.objects.get(name)
        if obj:
            bpy.data.objects.remove(obj, do_unlink=True)


def _gas_giant_texture():
    w, h = 1024, 512
    img = bpy.data.images.get("MenuGasGiantAlbedo") or bpy.data.images.new("MenuGasGiantAlbedo", width=w, height=h)
    pixels = [0.0] * (w * h * 4)
    for y in range(h):
        v = y / (h - 1)
        b1 = 0.5 + 0.5 * math.sin(v * math.pi * 16.0)
        b2 = 0.5 + 0.5 * math.sin(v * math.pi * 37.0 + 1.4)
        b3 = 0.5 + 0.5 * math.sin(v * math.pi * 7.0 + 0.6)
        mix = 0.48 * b1 + 0.32 * b2 + 0.20 * b3
        cream = (0.93, 0.86, 0.70)
        tan = (0.78, 0.66, 0.48)
        dusk = (0.42, 0.33, 0.26)
        if mix > 0.55:
            t = (mix - 0.55) / 0.45
            col = [cream[i] * t + tan[i] * (1.0 - t) for i in range(3)]
        else:
            t = mix / 0.55
            col = [tan[i] * t + dusk[i] * (1.0 - t) for i in range(3)]
        for x in range(w):
            swirl = 0.045 * math.sin((x / w) * math.pi * 8.0 + v * 12.0)
            idx = (y * w + x) * 4
            pixels[idx] = max(0.0, min(1.0, col[0] + swirl))
            pixels[idx + 1] = max(0.0, min(1.0, col[1] + swirl * 0.7))
            pixels[idx + 2] = max(0.0, min(1.0, col[2] + swirl * 0.4))
            pixels[idx + 3] = 1.0
    img.pixels.foreach_set(pixels)
    img.pack()
    return img


def _assign_image(mat, image):
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def _build_cinematic_backdrop(mats):
    bg = bpy.data.objects.new("MenuCinematicBackdrop", None)
    bpy.context.scene.collection.objects.link(bg)
    bg.empty_display_size = 2.0

    img = _gas_giant_texture()
    _assign_image(mats["planet"], img)

    planet = _ico("MenuGasGiant", 16.0, bg, loc=(-18.5, 22.0, 7.5), mat=mats["planet"], subdiv=4)
    planet.rotation_euler = Euler((0.35, 0.4, 1.1))
    _ico("MenuGasGiantAtmo", 16.7, bg, loc=(-18.5, 22.0, 7.5), mat=mats["atmo"], subdiv=3)

    ring_rot = (math.radians(72.0), math.radians(12.0), math.radians(-18.0))
    for i, (major, minor) in enumerate(((22.5, 0.18), (25.8, 0.55), (29.4, 0.22), (32.8, 0.12))):
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=96, minor_segments=12, location=(-18.5, 22.0, 7.5))
        ring = bpy.context.active_object
        ring.name = f"MenuPlanetRing_{i}"
        ring.rotation_euler = Euler(ring_rot)
        ring.parent = bg
        ring.data.materials.append(mats["ring"])

    # Distant starships near the rings.
    def ship(name, loc, scale, yaw, roll=0.0):
        root = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(root)
        _link(root, bg, loc, (roll, 0.15, yaw), (scale, scale, scale))
        _box(name + "_Hull", (3.4, 0.85, 0.42), root, mat=mats["ship"])
        _box(name + "_Spine", (4.4, 0.22, 0.16), root, loc=(0.15, 0.0, 0.06), mat=mats["ship"])
        _box(name + "_WingL", (1.0, 2.1, 0.08), root, loc=(-0.15, 1.1, 0.0), mat=mats["ship"])
        _box(name + "_WingR", (1.0, 2.1, 0.08), root, loc=(-0.15, -1.1, 0.0), mat=mats["ship"])
        _box(name + "_Engine", (0.4, 0.32, 0.32), root, loc=(-1.9, 0.0, 0.0), mat=mats["neon_soft"])
        _box(name + "_Window", (0.7, 0.2, 0.08), root, loc=(1.3, 0.0, 0.16), mat=mats["holo_solid"])
        return root

    ship("Starship_A", loc=(-8.5, 6.5, 5.8), scale=0.85, yaw=0.7)
    ship("Starship_B", loc=(-12.2, 10.5, 3.4), scale=0.45, yaw=0.35, roll=0.1)
    ship("Starship_C", loc=(9.8, 8.5, 7.4), scale=1.15, yaw=-0.55)
    ship("Starship_D", loc=(13.5, 14.0, 6.2), scale=0.7, yaw=-0.85)
    ship("Starship_E", loc=(6.2, 16.5, 9.5), scale=0.4, yaw=-0.2)

    # Sparse star sprinkles for the viewport preview.
    import random
    rng = random.Random(42)
    for i in range(90):
        loc = (
            rng.uniform(-40.0, 30.0),
            rng.uniform(8.0, 50.0),
            rng.uniform(-8.0, 28.0),
        )
        s = rng.uniform(0.04, 0.14)
        star = _ico(f"MenuStar_{i}", s, bg, loc=loc, mat=mats["star"], subdiv=1)
        star.hide_render = False

    # Soft nebula cards.
    for i, (loc, size, col) in enumerate((
        ((-6.0, 30.0, 10.0), 42.0, (0.18, 0.12, 0.38, 1.0)),
        ((12.0, 28.0, 4.0), 36.0, (0.28, 0.08, 0.22, 1.0)),
        ((-20.0, 18.0, 2.0), 28.0, (0.08, 0.16, 0.32, 1.0)),
    )):
        mesh = bpy.data.meshes.new(f"Nebula{i}Mesh")
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size * 0.5)
        bm.to_mesh(mesh)
        bm.free()
        nmat = _mat(f"MenuNebula{i}", col, metallic=0.0, roughness=1.0, emission=col, emission_strength=0.45, alpha=0.18)
        card = _mesh(f"MenuNebula_{i}", mesh, bg, loc=loc, rot=(math.radians(78), 0.0, 0.2 * i), mat=nmat)
        card.display_type = "TEXTURED"
    return bg


def _tune_character(env, dais):
    character = bpy.data.objects.get("Character")
    if character is None:
        return
    character.parent = env
    character.location = (dais[0], dais[1], 0.12)
    # Face the camera (Blender -Y) with a slight three-quarter turn.
    character.rotation_euler = Euler((-math.pi * 0.5, 0.0, math.pi + 0.22))
    character.scale = (0.019, 0.019, 0.019)


def _tune_lights(env):
    key = bpy.data.objects.get("Rig_Key_Light")
    rim = bpy.data.objects.get("Rig_Rim_Light")
    accent = bpy.data.objects.get("Rig_Accent_Point")
    if key:
        key.parent = env
        key.location = (-4.8, -6.2, 5.4)
        key.data.type = "SUN"
        key.data.color = (0.78, 0.86, 1.0)
        key.data.energy = 4.2
        key.rotation_euler = Euler((math.radians(52), math.radians(-18), math.radians(22)))
    if rim:
        rim.parent = env
        rim.location = (5.5, 4.2, 4.8)
        rim.data.type = "AREA"
        rim.data.color = (0.35, 0.75, 1.0)
        rim.data.energy = 180.0
        if hasattr(rim.data, "size"):
            rim.data.size = 4.0
    if accent:
        accent.parent = env
        accent.location = (-1.45, -1.45, 0.7)
        accent.data.type = "POINT"
        accent.data.color = (0.25, 0.9, 1.0)
        accent.data.energy = 40.0

    fill = bpy.data.objects.get("Rig_Fill_Light") or bpy.data.objects.new("Rig_Fill_Light", bpy.data.lights.new("Rig_Fill_LightData", "AREA"))
    if fill.name not in bpy.context.scene.objects:
        bpy.context.scene.collection.objects.link(fill)
    fill.parent = env
    fill.location = (0.2, -7.5, 3.8)
    fill.data.color = (0.55, 0.7, 0.95)
    fill.data.energy = 90.0
    if hasattr(fill.data, "size"):
        fill.data.size = 6.0

    planet_sun = bpy.data.objects.get("Rig_Planet_Light") or bpy.data.objects.new("Rig_Planet_Light", bpy.data.lights.new("Rig_Planet_LightData", "SUN"))
    if planet_sun.name not in bpy.context.scene.objects:
        bpy.context.scene.collection.objects.link(planet_sun)
    planet_sun.parent = env
    planet_sun.location = (-8.0, -12.0, 6.0)
    planet_sun.data.color = (1.0, 0.92, 0.78)
    planet_sun.data.energy = 2.8
    planet_sun.rotation_euler = Euler((math.radians(48), math.radians(-35), 0.0))


def _setup_world(scene):
    world = bpy.data.worlds.get("MenuTitleWorld") or bpy.data.worlds.new("MenuTitleWorld")
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Color"].default_value = (0.012, 0.018, 0.045, 1.0)
    bg.inputs["Strength"].default_value = 0.35
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    scene.world = world
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    if hasattr(scene.eevee, "use_bloom"):
        scene.eevee.use_bloom = True
        scene.eevee.bloom_intensity = 0.12
        scene.eevee.bloom_threshold = 0.8
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080


def _frame_camera():
    cam = bpy.data.objects.get("TitleCamera")
    if cam is None:
        cam_data = bpy.data.cameras.new("TitleCamera")
        cam = bpy.data.objects.new("TitleCamera", cam_data)
        bpy.context.scene.collection.objects.link(cam)
    cam.location = (2.35, -7.8, 2.55)
    direction = Vector((0.35, 0.15, 0.85)) - Vector(cam.location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 32.0
    cam.data.clip_end = 400.0
    bpy.context.scene.camera = cam
    for area in bpy.context.screen.areas:
        if area.type != "VIEW_3D":
            continue
        space = area.spaces.active
        space.shading.type = "MATERIAL"
        space.shading.use_scene_lights = True
        space.shading.use_scene_world = True
        space.overlay.show_floor = False
        space.overlay.show_axis_x = False
        space.overlay.show_axis_y = False
        space.overlay.show_axis_z = False
        space.overlay.show_cursor = False
        space.overlay.show_extras = False
        space.region_3d.view_perspective = "CAMERA"
    return cam


def _export_glb(env):
    bpy.ops.object.select_all(action="DESELECT")
    env.select_set(True)
    for obj in bpy.context.scene.objects:
        walk = obj
        while walk is not None:
            if walk == env:
                obj.select_set(True)
                break
            walk = walk.parent
    bpy.context.view_layer.objects.active = env
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        use_active_scene=True,
        export_apply=True,
        export_animations=True,
        export_yup=True,
        export_lights=True,
        export_cameras=False,
        export_extras=False,
    )
    print(f"EXPORTED {GLB_PATH}")


def build():
    scene = _ensure_scene()
    env = bpy.data.objects.get("Menu_Title_Environment")
    if env is None:
        env = bpy.data.objects.new("Menu_Title_Environment", None)
        scene.collection.objects.link(env)

    mats = {
        "metal": _mat("MenuMetal", METAL, metallic=0.92, roughness=0.28),
        "metal_mid": _mat("MenuMetalMid", METAL_MID, metallic=0.78, roughness=0.38),
        "panel": _mat("MenuPanel", PANEL, metallic=0.55, roughness=0.48),
        "neon": _mat("MenuNeon", (0.04, 0.12, 0.16, 1.0), metallic=0.15, roughness=0.22, emission=(0.18, 0.48, 0.58, 1.0), emission_strength=0.85),
        "neon_soft": _mat("MenuNeonSoft", (0.04, 0.11, 0.15, 1.0), metallic=0.2, roughness=0.28, emission=(0.16, 0.42, 0.52, 1.0), emission_strength=0.45),
        "holo_panel": _mat("MenuHoloPanel", (0.03, 0.10, 0.14, 1.0), metallic=0.08, roughness=0.22, emission=(0.16, 0.48, 0.58, 1.0), emission_strength=0.28, alpha=0.22),
        "holo_solid": _mat("MenuHoloSolid", (0.05, 0.16, 0.20, 1.0), metallic=0.1, roughness=0.24, emission=(0.18, 0.52, 0.62, 1.0), emission_strength=0.55, alpha=0.42),
        "holo_glow": _mat("MenuHoloGlow", (0.05, 0.16, 0.20, 1.0), metallic=0.08, roughness=0.26, emission=(0.18, 0.50, 0.60, 1.0), emission_strength=0.4, alpha=0.35),
        "holo_line": _mat("MenuHoloLine", (0.12, 0.42, 0.55, 1.0), metallic=0.0, roughness=0.18, emission=(0.20, 0.58, 0.70, 1.0), emission_strength=0.35, alpha=0.28),
        "planet": _mat("MenuPlanet", (0.82, 0.72, 0.55, 1.0), metallic=0.02, roughness=0.72),
        "atmo": _mat("MenuAtmo", (0.55, 0.62, 0.75, 1.0), metallic=0.0, roughness=1.0, emission=(0.35, 0.5, 0.75, 1.0), emission_strength=0.35, alpha=0.08),
        "ring": _mat("MenuRing", (0.72, 0.68, 0.58, 1.0), metallic=0.15, roughness=0.55, emission=(0.45, 0.42, 0.35, 1.0), emission_strength=0.25, alpha=0.55),
        "star": _mat("MenuStar", (0.9, 0.95, 1.0, 1.0), metallic=0.0, roughness=1.0, emission=(0.9, 0.95, 1.0, 1.0), emission_strength=4.0),
        "ship": _mat("MenuShip", (0.04, 0.05, 0.07, 1.0), metallic=0.88, roughness=0.32),
    }

    _clear_old_deck(env)
    _clear_backdrop()
    root, dais = _build_platform(env, mats)
    _build_holograms(root, mats)
    _tune_character(env, dais)
    _tune_lights(env)
    _build_cinematic_backdrop(mats)
    _setup_world(scene)
    _frame_camera()
    bpy.context.view_layer.update()
    _export_glb(env)
    print("MENU_STAGE_READY")


build()
