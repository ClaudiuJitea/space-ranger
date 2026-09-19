"""
Build script for AAA PX-9 Pulse Blaster (Slot 01) in weapons.blend.
Generates high-fidelity geometry, high-resolution procedural PBR textures,
and exports assets/models/weapon_blaster.glb with exact Godot mounting alignment.
"""

import bpy
import bmesh
import math
import numpy as np
from pathlib import Path

try:
    ROOT = Path(__file__).resolve().parent.parent
except NameError:
    ROOT = Path("/home/clau/Godot/games/space-ranger")
BLEND_PATH = ROOT / "assets/models/weapons.blend"
GLB_PATH = ROOT / "assets/models/weapon_blaster.glb"

def p(pos):
    """Utility to ensure tuple."""
    return tuple(pos)

def create_textures():
    """Create high-res procedural PBR textures packed into Blender."""
    rng = np.random.default_rng(101)
    n = 1024
    yy, xx = np.mgrid[:n, :n]

    # 1. White / Pearl Ceramic Armor Albedo (1024x1024)
    # Matches Vanguard operative armor - crisp high-contrast sci-fi look
    mottled_w = 0.96 + 0.04 * np.sin(xx * 0.03) * np.cos(yy * 0.03) + (rng.random((n, n)) - 0.5) * 0.04
    white_rgb = np.ones((n, n, 4), dtype=np.float32)
    base_white = np.array([0.88, 0.91, 0.95], dtype=np.float32)
    white_rgb[:, :, :3] = np.clip(mottled_w[:, :, None] * base_white, 0.0, 1.0)
    # Edge scratches and weathering
    for _ in range(250):
        x, y = rng.integers(10, n - 10, 2)
        length = int(rng.integers(4, 30))
        angle = rng.uniform(0, math.tau)
        dx, dy = math.cos(angle), math.sin(angle)
        for k in range(length):
            px, py = int(x + k * dx), int(y + k * dy)
            if 0 <= px < n and 0 <= py < n:
                white_rgb[py, px, :3] = np.clip(white_rgb[py, px, :3] * 0.75 - 0.05, 0.0, 1.0)

    img_white = bpy.data.images.get('px9_white_armor_albedo') or bpy.data.images.new('px9_white_armor_albedo', width=n, height=n)
    img_white.pixels.foreach_set(white_rgb.ravel())
    img_white.pack()

    # 2. Gunmetal / Carbon Receiver Albedo (1024x1024)
    mottled_gm = 0.92 + 0.08 * np.sin(xx * 0.025) * np.cos(yy * 0.025) + (rng.random((n, n)) - 0.5) * 0.06
    gunmetal_rgb = np.ones((n, n, 4), dtype=np.float32)
    base_gm = np.array([0.075, 0.082, 0.095], dtype=np.float32)
    gunmetal_rgb[:, :, :3] = np.clip(mottled_gm[:, :, None] * base_gm, 0.0, 1.0)
    for _ in range(350):
        x, y = rng.integers(10, n - 10, 2)
        length = int(rng.integers(6, 40))
        angle = rng.uniform(0, math.tau)
        dx, dy = math.cos(angle), math.sin(angle)
        for k in range(length):
            px, py = int(x + k * dx), int(y + k * dy)
            if 0 <= px < n and 0 <= py < n:
                gunmetal_rgb[py, px, :3] = np.clip(gunmetal_rgb[py, px, :3] * 1.8 + 0.12, 0.0, 1.0)

    img_gm = bpy.data.images.get('px9_gunmetal_albedo') or bpy.data.images.new('px9_gunmetal_albedo', width=n, height=n)
    img_gm.pixels.foreach_set(gunmetal_rgb.ravel())
    img_gm.pack()

    # 3. Brushed Titanium / Tungsten Steel Albedo (1024x1024)
    brushed = 0.88 + 0.12 * np.sin(xx * 0.09) + (rng.random((n, n)) - 0.5) * 0.08
    titanium_rgb = np.ones((n, n, 4), dtype=np.float32)
    base_ti = np.array([0.52, 0.56, 0.60], dtype=np.float32)
    titanium_rgb[:, :, :3] = np.clip(brushed[:, :, None] * base_ti, 0.0, 1.0)
    for _ in range(400):
        x, y = rng.integers(5, n - 5, 2)
        length = int(rng.integers(10, 60))
        titanium_rgb[y:y+1, x:min(n, x + length), :3] = np.clip(titanium_rgb[y:y+1, x:min(n, x + length), :3] * 1.4 + 0.15, 0.0, 1.0)

    img_ti = bpy.data.images.get('px9_titanium_albedo') or bpy.data.images.new('px9_titanium_albedo', width=n, height=n)
    img_ti.pixels.foreach_set(titanium_rgb.ravel())
    img_ti.pack()

    # 4. Tactical Polymer Albedo (1024x1024)
    poly_rgb = np.ones((n, n, 4), dtype=np.float32)
    stipple = 0.94 + (rng.random((n, n)) - 0.5) * 0.12
    base_poly = np.array([0.024, 0.026, 0.030], dtype=np.float32)
    poly_rgb[:, :, :3] = np.clip(stipple[:, :, None] * base_poly, 0.0, 1.0)

    img_poly = bpy.data.images.get('px9_polymer_albedo') or bpy.data.images.new('px9_polymer_albedo', width=n, height=n)
    img_poly.pixels.foreach_set(poly_rgb.ravel())
    img_poly.pack()

    # 5. Tangent-space Micro-Normal Map (1024x1024)
    norm = np.ones((n, n, 4), dtype=np.float32)
    norm[:, :, 0] = 0.5 + (rng.random((n, n)) - 0.5) * 0.08 + 0.03 * np.sin(xx * 0.14)
    norm[:, :, 1] = 0.5 + (rng.random((n, n)) - 0.5) * 0.08
    norm[:, :, 2] = 1.0

    img_norm = bpy.data.images.get('px9_micro_normal') or bpy.data.images.new('px9_micro_normal', width=n, height=n)
    img_norm.pixels.foreach_set(norm.ravel())
    img_norm.pack()
    img_norm.colorspace_settings.name = 'Non-Color'

    return img_white, img_gm, img_ti, img_poly, img_norm

def create_materials(img_white, img_gm, img_ti, img_poly, img_norm):
    """Create rich PBR shaders."""
    def make_pbr(name, base_col, metal=0.8, rough=0.35, emit=0.0, emit_col=None, tex_img=None, is_norm=False, alpha=1.0):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        tree = m.node_tree
        tree.nodes.clear()

        out_node = tree.nodes.new('ShaderNodeOutputMaterial')
        bsdf = tree.nodes.new('ShaderNodeBsdfPrincipled')
        tree.links.new(bsdf.outputs['BSDF'], out_node.inputs['Surface'])

        bsdf.inputs['Base Color'].default_value = (*base_col, 1.0)
        bsdf.inputs['Metallic'].default_value = metal
        bsdf.inputs['Roughness'].default_value = rough
        if 'Alpha' in bsdf.inputs and alpha < 1.0:
            bsdf.inputs['Alpha'].default_value = alpha

        if emit > 0.0:
            ec = emit_col if emit_col else base_col
            bsdf.inputs['Emission Color'].default_value = (*ec, 1.0)
            bsdf.inputs['Emission Strength'].default_value = emit

        if tex_img:
            tex_node = tree.nodes.new('ShaderNodeTexImage')
            tex_node.image = tex_img
            tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])

        if is_norm and img_norm:
            n_tex = tree.nodes.new('ShaderNodeTexImage')
            n_tex.image = img_norm
            norm_map = tree.nodes.new('ShaderNodeNormalMap')
            norm_map.inputs['Strength'].default_value = 0.40
            tree.links.new(n_tex.outputs['Color'], norm_map.inputs['Color'])
            tree.links.new(norm_map.outputs['Normal'], bsdf.inputs['Normal'])

        return m

    mats = {
        'white_armor': make_pbr('PX9_White_Armor', (0.88, 0.91, 0.95), metal=0.45, rough=0.28, tex_img=img_white, is_norm=True),
        'gunmetal': make_pbr('PX9_Gunmetal', (0.08, 0.09, 0.10), metal=0.78, rough=0.34, tex_img=img_gm, is_norm=True),
        'titanium': make_pbr('PX9_Titanium', (0.52, 0.56, 0.60), metal=0.96, rough=0.25, tex_img=img_ti, is_norm=True),
        'copper': make_pbr('PX9_Copper_Wrap', (0.85, 0.48, 0.22), metal=0.92, rough=0.30),
        'polymer': make_pbr('PX9_Polymer', (0.024, 0.026, 0.030), metal=0.06, rough=0.72, tex_img=img_poly, is_norm=True),
        'anodized': make_pbr('PX9_Anodized_Cyan', (0.04, 0.75, 0.96), metal=0.92, rough=0.25),
        'plasma': make_pbr('PX9_Plasma', (0.0, 0.95, 1.0), metal=0.0, rough=0.10, emit=15.0, emit_col=(0.0, 0.94, 1.0)),
        'plasma_dim': make_pbr('PX9_Plasma_Dim', (0.0, 0.70, 0.88), metal=0.0, rough=0.20, emit=5.0, emit_col=(0.0, 0.70, 0.88)),
        'amber_diode': make_pbr('PX9_Amber_Diode', (1.0, 0.55, 0.05), metal=0.1, rough=0.2, emit=9.0, emit_col=(1.0, 0.55, 0.05)),
        'glass': make_pbr('PX9_Optic_Glass', (0.05, 0.30, 0.35), metal=0.15, rough=0.06, alpha=0.50),
    }
    return mats

def finish(obj, root, mat, bevel=0.003):
    """Parent object to root, assign material, set smooth shading and modifiers."""
    obj.parent = root
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for f in obj.data.polygons:
        f.use_smooth = True
    if bevel > 0:
        b = obj.modifiers.new('Bevel', 'BEVEL')
        b.width = bevel
        b.segments = 2
        b.limit_method = 'ANGLE'
        b.angle_limit = math.radians(35)
        b.harden_normals = True
        wn = obj.modifiers.new('WeightedNormal', 'WEIGHTED_NORMAL')
        wn.keep_sharp = True
    obj.select_set(False)
    return obj

def box(root, name, pos, dims, mat, bevel=0.003, rot=(0, 0, 0)):
    """Create a box with center pos and dimensions (X, Y, Z)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=p(pos))
    o = bpy.context.object
    o.name = name
    o.dimensions = tuple(dims)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = tuple(rot)
    return finish(o, root, mat, bevel)

def cylinder(root, name, pos, radius, depth, mat, axis='Z', bevel=0.003, rot=(0, 0, 0), vertices=24):
    """Create a cylinder along the given axis."""
    r = list(rot)
    if axis == 'Z':
        pass
    elif axis == 'Y':
        r[0] += math.pi * 0.5
    elif axis == 'X':
        r[1] += math.pi * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=p(pos), rotation=tuple(r))
    o = bpy.context.object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, root, mat, bevel)

def torus_ring(root, name, pos, major_rad, minor_rad, mat, axis='Z', major_seg=28, minor_seg=14):
    """Create a torus ring for acceleration coils."""
    rot = (0, 0, 0)
    if axis == 'Z':
        pass
    elif axis == 'Y':
        rot = (math.pi * 0.5, 0, 0)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_rad, minor_radius=minor_rad,
        major_segments=major_seg, minor_segments=minor_seg,
        location=p(pos), rotation=rot
    )
    o = bpy.context.object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, root, mat, bevel=0.0)

def tube(root, name, pos, outer_r, inner_r, depth, mat, axis='Z', vertices=24):
    """Create a hollow tube along Z axis."""
    r_rot = (0, 0, 0)
    if axis == 'Y':
        r_rot = (math.pi * 0.5, 0, 0)
    
    mesh = bpy.data.meshes.new(name + "_mesh")
    bm = bmesh.new()
    
    half_d = depth * 0.5
    verts_out_top, verts_out_bot = [], []
    verts_in_top, verts_in_bot = [], []
    
    for i in range(vertices):
        theta = 2.0 * math.pi * i / vertices
        c, s = math.cos(theta), math.sin(theta)
        verts_out_top.append(bm.verts.new((c * outer_r, s * outer_r, half_d)))
        verts_out_bot.append(bm.verts.new((c * outer_r, s * outer_r, -half_d)))
        verts_in_top.append(bm.verts.new((c * inner_r, s * inner_r, half_d)))
        verts_in_bot.append(bm.verts.new((c * inner_r, s * inner_r, -half_d)))
        
    bm.verts.ensure_lookup_table()
    for i in range(vertices):
        next_i = (i + 1) % vertices
        bm.faces.new([verts_out_top[i], verts_out_top[next_i], verts_out_bot[next_i], verts_out_bot[i]])
        bm.faces.new([verts_in_top[next_i], verts_in_top[i], verts_in_bot[i], verts_in_bot[next_i]])
        bm.faces.new([verts_out_top[next_i], verts_out_top[i], verts_in_top[i], verts_in_top[next_i]])
        bm.faces.new([verts_out_bot[i], verts_out_bot[next_i], verts_in_bot[next_i], verts_in_bot[i]])
        
    bm.to_mesh(mesh)
    bm.free()
    
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.location = p(pos)
    o.rotation_euler = r_rot
    return finish(o, root, mat, bevel=0.002)

def build_blaster():
    """Construct the full AAA PX-9 Pulse Blaster model with high contrast and open magnetic coils."""
    print("=== STARTING AAA PX-9 PULSE BLASTER REBUILD ===")
    
    # 1. Prepare textures & materials
    img_white, img_gm, img_ti, img_poly, img_norm = create_textures()
    mats = create_materials(img_white, img_gm, img_ti, img_poly, img_norm)
    
    # 2. Get or create W_Blaster collection
    col = bpy.data.collections.get("W_Blaster")
    if not col:
        col = bpy.data.collections.new("W_Blaster")
        bpy.context.scene.collection.children.link(col)
        
    bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection.children.get("W_Blaster", bpy.context.view_layer.layer_collection)
    
    # Remove existing objects in W_Blaster
    old_objs = list(col.objects)
    for o in old_objs:
        bpy.data.objects.remove(o, do_unlink=True)
    print(f"Cleared {len(old_objs)} old objects from W_Blaster.")
    
    # 3. Create BlasterRoot Empty at (0, 0, 0)
    root = bpy.data.objects.new("BlasterRoot", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.1
    root.location = (0, 0, 0)
    col.objects.link(root)
    bpy.context.view_layer.objects.active = root

    # =========================================================================
    # COORDINATE ORIENTATION REFERENCE
    # =========================================================================
    # In Blender:
    # +X = Camera-facing side! (Godot +Z)
    # -X = Background-facing side (Godot -Z)
    # +Y = Up towards optic & sights (Godot -Z)
    # -Y = Down towards grip base & mag (Godot +Z)
    # -Z = Forward along barrel towards target (Godot -Y)
    # +Z = Rearward towards stock & shoulder (Godot +Y)
    # Barrel bore centerline: X = 0.0, Y = 0.100m
    # =========================================================================
    
    # --- A. RECEIVER & CHASSIS ---
    # Central receiver body (Z: +0.03 to -0.18, length 0.21, height 0.080, width 0.054)
    box(root, "Receiver_Core_Chassis", (0.0, 0.092, -0.075), (0.054, 0.078, 0.210), mats['gunmetal'], bevel=0.004)
    
    # Vanguard-matching White Ceramic Composite Armor Cheek Plates (HIGH CONTRAST!)
    # Top angled armor cowl:
    box(root, "Receiver_Armor_TopCowl", (0.0, 0.134, -0.075), (0.048, 0.020, 0.190), mats['white_armor'], bevel=0.003)
    # Left flank white armor plate:
    box(root, "Receiver_Armor_Plate_L", (-0.028, 0.106, -0.075), (0.005, 0.044, 0.180), mats['white_armor'], bevel=0.003)
    # Right flank white armor plate (CAMERA-FACING!):
    box(root, "Receiver_Armor_Plate_R", (0.028, 0.106, -0.075), (0.005, 0.044, 0.180), mats['white_armor'], bevel=0.003)
    
    # Recessed Glowing Cyan Power Conduit Strip running along both flanks (POPS ON CAMERA!)
    box(root, "PowerConduit_Glow_R", (0.031, 0.106, -0.075), (0.002, 0.012, 0.170), mats['plasma'], bevel=0.0)
    box(root, "PowerConduit_Glow_L", (-0.031, 0.106, -0.075), (0.002, 0.012, 0.170), mats['plasma'], bevel=0.0)
    
    # Camera-Facing (+X) High-Tech AMOLED Ammo / Energy Telemetry Display
    # Angled 45 deg frame and glowing digital readout
    box(root, "Telemetry_Display_Bezel", (0.030, 0.076, -0.045), (0.006, 0.024, 0.055), mats['anodized'], bevel=0.001)
    box(root, "Telemetry_Display_Screen", (0.033, 0.076, -0.045), (0.002, 0.018, 0.048), mats['plasma'], bevel=0.0)
    # Digital ammo segments inside screen
    box(root, "Telemetry_Display_Bar", (0.034, 0.071, -0.045), (0.001, 0.004, 0.040), mats['plasma_dim'], bevel=0.0)
    
    # Heat sink exhaust louvers (top rear)
    box(root, "Receiver_HeatExhaust_Cutout", (0.0, 0.144, 0.005), (0.034, 0.008, 0.035), mats['titanium'], bevel=0.001)
    for i in range(3):
        ez = -0.005 + i * 0.010
        box(root, f"Receiver_HeatExhaust_Fin_{i}", (0.0, 0.146, ez), (0.032, 0.006, 0.003), mats['plasma_dim'], bevel=0.0)

    # Tactical hardware / pivot pins
    cylinder(root, "Chassis_Pin_Front", (0.0, 0.054, -0.150), radius=0.006, depth=0.060, mat=mats['titanium'], axis='X', bevel=0.001)
    cylinder(root, "Chassis_Pin_Rear", (0.0, 0.058, 0.015), radius=0.006, depth=0.060, mat=mats['titanium'], axis='X', bevel=0.001)
    # Fire selector switch on camera flank (+X)
    cylinder(root, "Selector_Switch_R", (0.030, 0.062, -0.010), radius=0.008, depth=0.006, mat=mats['anodized'], axis='X', bevel=0.001)
    box(root, "Selector_Lever_R", (0.033, 0.068, -0.008), (0.003, 0.014, 0.005), mats['anodized'], bevel=0.001, rot=(-0.3, 0, 0))

    # --- B. ELEVATED TOP PICATINNY / NATO OPTIC RISER RAIL ---
    # Runs along receiver and extends forward over shroud (Z: +0.05 to -0.22, height Y = 0.148)
    box(root, "Top_Rail_Base", (0.0, 0.146, -0.085), (0.030, 0.012, 0.280), mats['titanium'], bevel=0.002)
    box(root, "Top_Rail_Spine", (0.0, 0.152, -0.085), (0.024, 0.005, 0.280), mats['titanium'], bevel=0.001)
    # 13 Milled transverse rail slots
    for i in range(13):
        rz = 0.045 - i * 0.021
        box(root, f"Top_Rail_Lug_{i}", (0.0, 0.154, rz), (0.027, 0.003, 0.010), mats['gunmetal'], bevel=0.001)

    # --- C. HOLOGRAPHIC REFLEX OPTIC (SIGHT) ---
    # Elevated hooded reflex optic mounted at Z = -0.015, Y = 0.158 to 0.205
    # Mounting clamp base with dual cross-bolts
    box(root, "Optic_Mount_Clamp", (0.0, 0.158, -0.015), (0.038, 0.010, 0.066), mats['titanium'], bevel=0.002)
    cylinder(root, "Optic_Mount_Bolt_1", (0.020, 0.158, -0.032), radius=0.004, depth=0.008, mat=mats['anodized'], axis='X')
    cylinder(root, "Optic_Mount_Bolt_2", (0.020, 0.158, 0.002), radius=0.004, depth=0.008, mat=mats['anodized'], axis='X')
    
    # Angular sunshade optic hood
    box(root, "Optic_Hood_Lower", (0.0, 0.170, -0.015), (0.040, 0.016, 0.072), mats['gunmetal'], bevel=0.002)
    box(root, "Optic_Hood_Wall_L", (-0.018, 0.190, -0.015), (0.005, 0.026, 0.068), mats['white_armor'], bevel=0.002)
    box(root, "Optic_Hood_Wall_R", (0.018, 0.190, -0.015), (0.005, 0.026, 0.068), mats['white_armor'], bevel=0.002)
    box(root, "Optic_Hood_Roof", (0.0, 0.203, -0.015), (0.040, 0.005, 0.068), mats['white_armor'], bevel=0.002)
    
    # Coated reflex optic glass lens
    box(root, "Optic_Glass_Lens", (0.0, 0.190, -0.015), (0.030, 0.022, 0.004), mats['glass'], bevel=0.0)
    # Bright cyan holographic reticle element (crosshair ring + bright central dot)
    box(root, "Optic_Reticle_OuterRing", (0.0, 0.190, -0.014), (0.015, 0.015, 0.001), mats['plasma'], bevel=0.0)
    cylinder(root, "Optic_Reticle_Pip", (0.0, 0.190, -0.0135), radius=0.0025, depth=0.001, mat=mats['plasma'], axis='Z')
    
    # Tactical elevation & windage adjustment dials
    cylinder(root, "Optic_Turret_Elevation", (0.0, 0.206, -0.015), radius=0.007, depth=0.006, mat=mats['anodized'], axis='Z', bevel=0.001)
    cylinder(root, "Optic_Turret_Windage", (0.021, 0.190, -0.015), radius=0.007, depth=0.006, mat=mats['anodized'], axis='X', bevel=0.001)

    # --- D. OPEN-CHASSIS MAGNETIC ACCELERATOR ASSEMBLY ---
    # Bore axis: X=0.0, Y=0.100m. Extends forward from Z = -0.180 to -0.460.
    
    # 1. Heavy Central Tungsten Plasma Bore Tube
    cylinder(root, "Barrel_Central_Bore", (0.0, 0.100, -0.320), radius=0.024, depth=0.280, mat=mats['titanium'], axis='Z', bevel=0.002, vertices=28)
    # Internal glowing plasma column inside the bore
    cylinder(root, "Barrel_Internal_Plasma", (0.0, 0.100, -0.320), radius=0.014, depth=0.282, mat=mats['plasma_dim'], axis='Z', bevel=0.0, vertices=16)

    # 2. Structural Open-Frame Rail Spines (top & bottom)
    # Top Spine:
    box(root, "Shroud_Top_Spine", (0.0, 0.144, -0.320), (0.038, 0.014, 0.280), mats['white_armor'], bevel=0.003)
    box(root, "Shroud_Top_RailCore", (0.0, 0.150, -0.320), (0.024, 0.006, 0.280), mats['titanium'], bevel=0.001)
    # Bottom Spine (AFG mounting rail):
    box(root, "Shroud_Bottom_Spine", (0.0, 0.056, -0.320), (0.038, 0.014, 0.280), mats['white_armor'], bevel=0.003)
    box(root, "Shroud_Bottom_RailCore", (0.0, 0.050, -0.320), (0.024, 0.006, 0.280), mats['titanium'], bevel=0.001)
    
    # Longitudinal glowing plasma supply tubes along the top spine
    cylinder(root, "Plasma_FeedLine_Top", (0.0, 0.134, -0.320), radius=0.005, depth=0.280, mat=mats['plasma'], axis='Z')

    # 3. Four Massive Quad Magnetic Accelerator Coils (FULLY EXPOSED AND GLOWING!)
    # Spaced at Z = -0.215, -0.275, -0.335, -0.395
    coils_z = [-0.215, -0.275, -0.335, -0.395]
    for i, cz in enumerate(coils_z):
        # A. Massive Toroidal Glowing Cyan Plasma Core Ring (POPS WITH VIBRANT LIGHT!)
        torus_ring(root, f"Coil_Plasma_Core_{i}", (0.0, 0.100, cz), major_rad=0.033, minor_rad=0.0075, mat=mats['plasma'], axis='Z', major_seg=32, minor_seg=16)
        
        # B. Copper Electromagnetic Windings inside the ring collar
        tube(root, f"Coil_Copper_Windings_{i}", (0.0, 0.100, cz), outer_r=0.037, inner_r=0.033, depth=0.012, mat=mats['copper'], vertices=24)
        
        # C. Machined Outer Containment Ring Collar with Anodized Cyan finish
        tube(root, f"Coil_Outer_Collar_{i}", (0.0, 0.100, cz), outer_r=0.041, inner_r=0.037, depth=0.016, mat=mats['anodized'], vertices=24)
        
        # D. Magnetic Flux Booster Fins extending outward on left and right (VISIBLE FROM CAMERA!)
        box(root, f"Coil_FluxFin_R_{i}", (0.041, 0.100, cz), (0.010, 0.030, 0.016), mats['titanium'], bevel=0.001)
        box(root, f"Coil_FluxGlow_R_{i}", (0.046, 0.100, cz), (0.002, 0.024, 0.012), mats['plasma'], bevel=0.0)
        box(root, f"Coil_FluxFin_L_{i}", (-0.041, 0.100, cz), (0.010, 0.030, 0.016), mats['titanium'], bevel=0.001)
        box(root, f"Coil_FluxGlow_L_{i}", (-0.046, 0.100, cz), (0.002, 0.024, 0.012), mats['plasma'], bevel=0.0)
        
        # E. Vertical Structural Struts connecting coil collar to top & bottom spines
        box(root, f"Coil_TopStrut_{i}", (0.0, 0.136, cz), (0.020, 0.008, 0.018), mats['gunmetal'], bevel=0.001)
        box(root, f"Coil_BotStrut_{i}", (0.0, 0.064, cz), (0.020, 0.008, 0.018), mats['gunmetal'], bevel=0.001)

    # Front Shroud Endcap Collar (transitions into compensator)
    cylinder(root, "Shroud_Front_Collar", (0.0, 0.100, -0.455), radius=0.035, depth=0.018, mat=mats['titanium'], axis='Z', bevel=0.002, vertices=24)
    tube(root, "Shroud_Front_GlowRing", (0.0, 0.100, -0.455), outer_r=0.037, inner_r=0.035, depth=0.008, mat=mats['plasma'], vertices=24)

    # --- E. HEAVY LINEAR COMPENSATOR / MUZZLE BRAKE ---
    # From Z: -0.455 to -0.520 (length 0.065)
    # Heavy octagonal compensator body
    cylinder(root, "Muzzle_Compensator_Body", (0.0, 0.100, -0.485), radius=0.032, depth=0.060, mat=mats['titanium'], axis='Z', bevel=0.003, vertices=8)
    # Internal heavy tungsten bore
    tube(root, "Muzzle_Tungsten_Bore", (0.0, 0.100, -0.485), outer_r=0.025, inner_r=0.016, depth=0.062, mat=mats['gunmetal'], vertices=20)
    
    # 4 Flared exhaust gas baffles (side vents)
    box(root, "Muzzle_Vent_Right", (0.028, 0.100, -0.485), (0.012, 0.018, 0.028), mats['gunmetal'], bevel=0.001)
    box(root, "Muzzle_Vent_Left", (-0.028, 0.100, -0.485), (0.012, 0.018, 0.028), mats['gunmetal'], bevel=0.001)
    box(root, "Muzzle_Vent_Top", (0.0, 0.128, -0.485), (0.018, 0.012, 0.028), mats['gunmetal'], bevel=0.001)
    box(root, "Muzzle_Vent_Bottom", (0.0, 0.072, -0.485), (0.018, 0.012, 0.028), mats['gunmetal'], bevel=0.001)
    
    # Front crown with recessed glowing plasma bore rim
    tube(root, "Muzzle_Crown_Bevel", (0.0, 0.100, -0.518), outer_r=0.030, inner_r=0.017, depth=0.006, mat=mats['anodized'], vertices=20)
    cylinder(root, "Muzzle_Plasma_Aperture", (0.0, 0.100, -0.519), radius=0.016, depth=0.004, mat=mats['plasma'], axis='Z', bevel=0.0)

    # --- F. MUZZLE MARKER SOCKETS ---
    # Barrel tip is at Z = -0.520, Y = 0.100, X = 0.0
    muzzle_empty = bpy.data.objects.new("Muzzle", None)
    muzzle_empty.empty_display_type = 'SINGLE_ARROW'
    muzzle_empty.empty_display_size = 0.08
    muzzle_empty.location = (0.0, 0.100, -0.520)
    muzzle_empty.parent = root
    col.objects.link(muzzle_empty)

    muzzle_alias = bpy.data.objects.new("Muzzle_W_Blaster", None)
    muzzle_alias.empty_display_type = 'PLAIN_AXES'
    muzzle_alias.empty_display_size = 0.05
    muzzle_alias.location = (0.0, 0.100, -0.520)
    muzzle_alias.parent = root
    col.objects.link(muzzle_alias)

    # --- G. ERGONOMIC PISTOL GRIP & TRIGGER GROUP ---
    # Grip center at (0, 0.045, 0.030) with 14 deg backward tilt
    grip_rot = (-math.radians(14), 0, 0)
    # Tactical ergonomic grip core
    box(root, "Pistol_Grip_Core", (0.0, 0.036, 0.032), (0.032, 0.072, 0.046), mats['polymer'], bevel=0.006, rot=grip_rot)
    
    # 3 Anatomical finger grooves on front strap
    for i in range(3):
        gy = 0.055 - i * 0.020
        gz = 0.010 + i * 0.005
        box(root, f"Grip_FingerGroove_{i}", (0.0, gy, gz), (0.034, 0.012, 0.009), mats['polymer'], bevel=0.003, rot=grip_rot)
        
    # Rubberized palm-swell plate on back strap
    box(root, "Grip_Backstrap_Plate", (0.0, 0.032, 0.056), (0.028, 0.068, 0.008), mats['gunmetal'], bevel=0.003, rot=grip_rot)
    
    # Flared grip baseplate with QD sling socket
    box(root, "Grip_BasePlate", (0.0, -0.004, 0.044), (0.038, 0.012, 0.054), mats['titanium'], bevel=0.003, rot=grip_rot)
    cylinder(root, "Grip_Sling_Socket", (0.0, -0.008, 0.056), radius=0.006, depth=0.010, mat=mats['anodized'], axis='Y')

    # Tactical Trigger Guard
    box(root, "Trigger_Guard_Bottom", (0.0, 0.052, -0.024), (0.016, 0.005, 0.048), mats['titanium'], bevel=0.002)
    box(root, "Trigger_Guard_Front", (0.0, 0.063, -0.048), (0.016, 0.024, 0.005), mats['titanium'], bevel=0.002, rot=(math.radians(22), 0, 0))
    box(root, "Trigger_Guard_Rear", (0.0, 0.060, 0.000), (0.016, 0.020, 0.005), mats['titanium'], bevel=0.002)

    # Skeletonized match trigger
    box(root, "Trigger_Blade", (0.0, 0.066, -0.022), (0.008, 0.018, 0.006), mats['anodized'], bevel=0.001, rot=(math.radians(16), 0, 0))
    cylinder(root, "Trigger_PivotPin", (0.0, 0.074, -0.018), radius=0.003, depth=0.020, mat=mats['titanium'], axis='X')

    # --- H. TACTICAL ANGLED FOREGRIP (AFG) ---
    # Mounted on bottom rail under the coils at Z = -0.290, Y = 0.040
    box(root, "Foregrip_BaseRailClamp", (0.0, 0.044, -0.290), (0.030, 0.008, 0.096), mats['titanium'], bevel=0.002)
    box(root, "Foregrip_AngledBody", (0.0, 0.022, -0.290), (0.028, 0.036, 0.082), mats['polymer'], bevel=0.005, rot=(math.radians(24), 0, 0))
    box(root, "Foregrip_FrontStop", (0.0, 0.008, -0.332), (0.030, 0.026, 0.014), mats['polymer'], bevel=0.003)
    # Tactical grip ribbing
    for i in range(4):
        fz = -0.258 - i * 0.018
        box(root, f"Foregrip_Rib_{i}", (0.0, 0.012, fz), (0.030, 0.004, 0.008), mats['gunmetal'], bevel=0.001, rot=(math.radians(24), 0, 0))

    # --- I. HIGH-CAPACITY PLASMA BATTERY CELL (MAGAZINE) ---
    # Slanted forward 12 degrees in front of trigger guard: Z = -0.115, Y = 0.020 to -0.080
    mag_rot = (math.radians(12), 0, 0)
    # Flared magwell collar (White ceramic armor finish!)
    box(root, "Magwell_ArmorCollar", (0.0, 0.040, -0.110), (0.052, 0.020, 0.068), mats['white_armor'], bevel=0.003, rot=mag_rot)
    
    # Main plasma cell body
    box(root, "PlasmaCell_Body", (0.0, -0.012, -0.120), (0.044, 0.086, 0.056), mats['gunmetal'], bevel=0.004, rot=mag_rot)
    # White ceramic side armor plates on magazine
    box(root, "PlasmaCell_Armor_R", (0.023, -0.012, -0.120), (0.003, 0.076, 0.048), mats['white_armor'], bevel=0.002, rot=mag_rot)
    box(root, "PlasmaCell_Armor_L", (-0.023, -0.012, -0.120), (0.003, 0.076, 0.048), mats['white_armor'], bevel=0.002, rot=mag_rot)
    
    # Heavy rubberized bumper base pad
    box(root, "PlasmaCell_BumperBase", (0.0, -0.058, -0.130), (0.048, 0.016, 0.062), mats['polymer'], bevel=0.003, rot=mag_rot)
    
    # Segmented Cyan LED Battery Charge Level Gauge (ON CAMERA-FACING FLANK +X!)
    # 5 glowing battery bars indicating full military pulse charge!
    for i in range(5):
        by = 0.020 - i * 0.015
        bz = -0.113 - i * 0.003
        # Right side indicator bar (CAMERA-FACING!)
        box(root, f"Cell_ChargeLED_R_{i}", (0.025, by, bz), (0.002, 0.008, 0.030), mats['plasma'], bevel=0.0, rot=mag_rot)
        # Left side indicator bar
        box(root, f"Cell_ChargeLED_L_{i}", (-0.025, by, bz), (0.002, 0.008, 0.030), mats['plasma'], bevel=0.0, rot=mag_rot)

    # --- J. TACTICAL SKELETONIZED STOCK ---
    # Extends rearward: Z = +0.030 to +0.165, Y = 0.075 to 0.130
    # Upper titanium buffer tube cylinder
    cylinder(root, "Stock_BufferTube", (0.0, 0.100, 0.095), radius=0.018, depth=0.140, mat=mats['titanium'], axis='Z', bevel=0.002, vertices=24)
    # Glowing cyan buffer energy ring
    tube(root, "Stock_BufferEnergyRing", (0.0, 0.100, 0.155), outer_r=0.021, inner_r=0.018, depth=0.010, mat=mats['plasma'], vertices=24)
    
    # Lower diagonal reinforcement strut
    box(root, "Stock_LowerStrut", (0.0, 0.066, 0.095), (0.018, 0.016, 0.130), mats['gunmetal'], bevel=0.002, rot=(-math.radians(14), 0, 0))
    
    # White ceramic cheek rest plate (MATCHES VANGUARD SUIT!)
    box(root, "Stock_CheekRiser", (0.0, 0.122, 0.080), (0.040, 0.016, 0.095), mats['white_armor'], bevel=0.003)
    
    # Ergonomic rubberized recoil buttpad
    box(root, "Stock_ButtPad_Base", (0.0, 0.076, 0.165), (0.034, 0.090, 0.020), mats['polymer'], bevel=0.004)
    for i in range(5):
        ry = 0.110 - i * 0.017
        box(root, f"Stock_TractionRib_{i}", (0.0, ry, 0.176), (0.030, 0.006, 0.004), mats['polymer'], bevel=0.001)

    # --- K. TACTICAL PEQ MODULE (CAMERA-FACING SIDE RAIL +X) ---
    # Mounted at +X = 0.035, Y = 0.125, Z = -0.260
    box(root, "PEQ_Module_Body", (0.035, 0.125, -0.260), (0.020, 0.028, 0.060), mats['gunmetal'], bevel=0.002)
    # White top accent plate
    box(root, "PEQ_Top_Plate", (0.035, 0.140, -0.260), (0.018, 0.003, 0.056), mats['white_armor'], bevel=0.001)
    # Dual front optical emitter lenses
    cylinder(root, "PEQ_Lens_AimLaser", (0.035, 0.132, -0.291), radius=0.005, depth=0.004, mat=mats['amber_diode'], axis='Z')
    cylinder(root, "PEQ_Lens_IRIllum", (0.035, 0.118, -0.291), radius=0.004, depth=0.004, mat=mats['plasma'], axis='Z')
    cylinder(root, "PEQ_ActivationButton", (0.035, 0.142, -0.250), radius=0.005, depth=0.003, mat=mats['anodized'], axis='Y')

    total_objs = len(col.objects)
    total_polys = sum(len(o.data.polygons) for o in col.objects if o.type == 'MESH')
    print(f"=== AAA PX-9 PULSE BLASTER MODEL COMPLETE ===")
    print(f"Total Objects in W_Blaster: {total_objs}")
    print(f"Total Polygons: {total_polys}")

def export_blaster():
    """Export W_Blaster collection to assets/models/weapon_blaster.glb."""
    col = bpy.data.collections.get("W_Blaster")
    if not col:
        raise RuntimeError("W_Blaster collection not found!")

    bpy.ops.object.select_all(action='DESELECT')
    for o in col.objects:
        o.select_set(True)

    print(f"Exporting {len(col.objects)} objects to {GLB_PATH}...")
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_yup=True,
        export_image_format='AUTO',
        export_materials='EXPORT',
        export_lights=False,
        export_cameras=False
    )
    print("GLB export complete.")

    try:
        bpy.ops.wm.save_mainfile(filepath=str(BLEND_PATH))
        print("Weapons.blend saved successfully.")
    except Exception as e:
        print("Save notice:", e)

if __name__ == "__main__":
    build_blaster()
    export_blaster()
