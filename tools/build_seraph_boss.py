"""True AAA Re-design for Emberfall Seraph (Campaign Boss 3).
Constructs an apex aerodynamic angelic war dreadnought with articulated quad-wings,
dual heavy inferno turbines, crowned war visage, sculpted layered slate ceramic armor,
machined titanium spars, copper heat radiator arrays, and a pulsating solar singularity core.
Godot coordinates: X horizontal, Y vertical, Z depth (combat at Z=0).
Exported via Blender MCP to assets/models/campaign_bosses/seraph.glb.
"""
import bpy
import math
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/campaign_bosses'
OUT.mkdir(parents=True, exist_ok=True)

def p(v):
    """Map Godot (x, y, z) to Blender (x, -z, y)."""
    return (v[0], -v[2], v[1])

def make_texture_images():
    """Generate high-resolution PBR wear, albedo, and micro-normal maps."""
    n = 1024
    rng = np.random.default_rng(912)
    
    # 1. Slate Ceramic Armor Albedo & Wear map
    yy, xx = np.mgrid[:n, :n]
    mottled = 0.88 + 0.08 * np.sin(xx * 0.018) * np.cos(yy * 0.015) + (rng.random((n, n)) - 0.5) * 0.08
    armor_rgb = np.ones((n, n, 4), dtype=np.float32)
    base_col = np.array([0.13, 0.16, 0.20], dtype=np.float32)
    armor_rgb[:, :, :3] = np.clip(mottled[:, :, None] * base_col, 0, 1)
    
    # Edge scratches and panel highlight wear
    for _ in range(450):
        x, y = rng.integers(10, n - 10, 2)
        length = int(rng.integers(8, 50))
        angle = rng.uniform(0, math.tau)
        dx, dy = math.cos(angle), math.sin(angle)
        for k in range(length):
            px = int(x + k * dx)
            py = int(y + k * dy)
            if 0 <= px < n and 0 <= py < n:
                armor_rgb[py, px, :3] = np.clip(armor_rgb[py, px, :3] * 1.9 + 0.15, 0, 1)
    
    img_armor = bpy.data.images.get('seraph_armor_albedo') or bpy.data.images.new('seraph_armor_albedo', width=n, height=n)
    img_armor.pixels.foreach_set(armor_rgb.ravel())
    img_armor.pack()
    
    # 2. Brushed Machined Titanium Albedo & Wear map
    brushed = 0.85 + 0.15 * np.sin(xx * 0.08) + (rng.random((n, n)) - 0.5) * 0.10
    titanium_rgb = np.ones((n, n, 4), dtype=np.float32)
    steel_col = np.array([0.44, 0.48, 0.52], dtype=np.float32)
    titanium_rgb[:, :, :3] = np.clip(brushed[:, :, None] * steel_col, 0, 1)
    for _ in range(500):
        x, y = rng.integers(5, n - 5, 2)
        length = int(rng.integers(12, 70))
        titanium_rgb[y:y+1, x:min(n, x + length), :3] = np.clip(titanium_rgb[y:y+1, x:min(n, x + length), :3] * 1.6 + 0.18, 0, 1)
    
    img_titanium = bpy.data.images.get('seraph_titanium_albedo') or bpy.data.images.new('seraph_titanium_albedo', width=n, height=n)
    img_titanium.pixels.foreach_set(titanium_rgb.ravel())
    img_titanium.pack()

    # 3. Fine Tangent Micro-Normal map
    normal = np.ones((n, n, 4), dtype=np.float32)
    normal[:, :, 0] = 0.5 + (rng.random((n, n)) - 0.5) * 0.08 + 0.04 * np.sin(xx * 0.12)
    normal[:, :, 1] = 0.5 + (rng.random((n, n)) - 0.5) * 0.08
    normal[:, :, 2] = 1.0
    img_normal = bpy.data.images.get('seraph_micro_normal') or bpy.data.images.new('seraph_micro_normal', width=n, height=n)
    img_normal.pixels.foreach_set(normal.ravel())
    img_normal.pack()
    img_normal.colorspace_settings.name = 'Non-Color'

    return img_armor, img_titanium, img_normal

def create_materials():
    img_armor, img_titanium, img_normal = make_texture_images()
    
    def mat(name, color, metal=0.6, rough=0.38, emit=0, emit_col=None, tex_img=None, is_norm=False):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        tree = m.node_tree
        tree.nodes.clear()
        out_node = tree.nodes.new('ShaderNodeOutputMaterial')
        bsdf = tree.nodes.new('ShaderNodeBsdfPrincipled')
        tree.links.new(bsdf.outputs['BSDF'], out_node.inputs['Surface'])
        
        bsdf.inputs['Base Color'].default_value = (*color, 1.0)
        bsdf.inputs['Metallic'].default_value = metal
        bsdf.inputs['Roughness'].default_value = rough
        if emit > 0:
            ec = emit_col if emit_col else color
            bsdf.inputs['Emission Color'].default_value = (*ec, 1.0)
            bsdf.inputs['Emission Strength'].default_value = emit
            
        if tex_img:
            tex_node = tree.nodes.new('ShaderNodeTexImage')
            tex_node.image = tex_img
            tree.links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
            
        if is_norm and img_normal:
            n_tex = tree.nodes.new('ShaderNodeTexImage')
            n_tex.image = img_normal
            norm_map = tree.nodes.new('ShaderNodeNormalMap')
            norm_map.inputs['Strength'].default_value = 0.35
            tree.links.new(n_tex.outputs['Color'], norm_map.inputs['Color'])
            tree.links.new(norm_map.outputs['Normal'], bsdf.inputs['Normal'])
            
        return m

    mats = {
        'armor': mat('SERAPH_Slate_Armor', (0.13, 0.16, 0.20), 0.52, 0.38, tex_img=img_armor, is_norm=True),
        'titanium': mat('SERAPH_Machined_Titanium', (0.44, 0.48, 0.52), 0.88, 0.26, tex_img=img_titanium, is_norm=True),
        'dark': mat('SERAPH_Carbon_Undersuit', (0.02, 0.028, 0.038), 0.15, 0.70),
        'copper': mat('SERAPH_Radiator_Copper', (0.75, 0.38, 0.15), 0.90, 0.32),
        'gold': mat('SERAPH_Solar_Trim', (0.88, 0.62, 0.20), 0.85, 0.26),
        'core_energy': mat('SERAPH_Singularity_Core', (1.0, 0.42, 0.08), 0.05, 0.20, emit=10.0, emit_col=(1.0, 0.40, 0.06)),
        'optic_sensor': mat('SERAPH_Sensor_Optic', (1.0, 0.08, 0.02), 0.10, 0.20, emit=6.5, emit_col=(1.0, 0.08, 0.02)),
        'plasma_conduit': mat('SERAPH_Wing_Conduit', (1.0, 0.50, 0.10), 0.10, 0.25, emit=5.0, emit_col=(1.0, 0.48, 0.08)),
        'exhaust_glow': mat('SERAPH_Exhaust_Inferno', (1.0, 0.32, 0.04), 0.05, 0.20, emit=11.0, emit_col=(1.0, 0.28, 0.03)),
    }
    return mats

def finish(obj, root, mat, bevel=0.018):
    obj.parent = root
    obj.data.materials.append(mat)
    for f in obj.data.polygons:
        f.use_smooth = True
    if bevel > 0:
        b = obj.modifiers.new('Machined_Bevel', 'BEVEL')
        b.width = bevel
        b.segments = 2
        b.harden_normals = True
        wn = obj.modifiers.new('Weighted_Normals', 'WEIGHTED_NORMAL')
        wn.keep_sharp = True
    obj.select_set(False)
    return obj

def box(root, name, pos, dims, mat, bevel=0.015, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p(pos))
    o = bpy.context.object
    o.name = name
    o.dimensions = (dims[0], dims[2], dims[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = (rot[0], -rot[2], rot[1])
    return finish(o, root, mat, bevel)

def sphere(root, name, pos, size, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=16, location=p(pos))
    o = bpy.context.object
    o.name = name
    o.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, root, mat, 0)

def cylinder(root, name, pos, radius, depth, mat, axis='Z', top=None, bevel=0.012):
    r2 = radius if top is None else top
    bpy.ops.mesh.primitive_cone_add(vertices=28, radius1=radius, radius2=r2, depth=depth, location=p(pos))
    o = bpy.context.object
    o.name = name
    if axis == 'Z':
        o.rotation_euler.x = math.pi / 2
    elif axis == 'X':
        o.rotation_euler.y = math.pi / 2
    return finish(o, root, mat, bevel)

def torus(root, name, pos, radius, thickness, mat, tilt=0):
    bpy.ops.mesh.primitive_torus_add(major_segments=36, minor_segments=12, major_radius=radius, minor_radius=thickness, location=p(pos))
    o = bpy.context.object
    o.name = name
    o.rotation_euler.x = math.pi / 2 + tilt
    return finish(o, root, mat, 0)

def socket(root, name, pos):
    scene = bpy.context.scene
    o = bpy.data.objects.new(name, None)
    if root:
        o.parent = root
    o.location = p(pos)
    scene.collection.objects.link(o)
    return o

def loft(root, name, sections, mat, bevel=0.016):
    """Loft smooth cross sections with sculpted contours.
    Each section is (center_x, y, center_z, radius_x, radius_z).
    """
    scene = bpy.context.scene
    contour = [(-0.70, 1.0), (0.70, 1.0), (1.0, 0.65), (0.95, -0.60), (0.65, -1.0), (-0.65, -1.0), (-0.95, -0.60), (-1.0, 0.65)]
    verts = []
    for cx, y, cz, rx, rz in sections:
        verts.extend([p((cx + x * rx, y, cz + z * rz)) for x, z in contour])
    n = len(contour)
    faces = [tuple(reversed(range(n)))]
    for ring in range(len(sections) - 1):
        for i in range(n):
            faces.append((ring * n + i, ring * n + (i + 1) % n, (ring + 1) * n + (i + 1) % n, (ring + 1) * n + i))
    faces.append(tuple(range((len(sections) - 1) * n, len(sections) * n)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(o)
    finish(o, root, mat, bevel)
    scene.view_layers[0].objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    o.select_set(False)
    return o

def plate(root, name, outline, z, thickness, mat, bevel=0.016):
    """Extruded 3D polygon plate with chamfered bevels and weighted normals."""
    scene = bpy.context.scene
    n = len(outline)
    verts = [p((x, y, z - thickness / 2)) for x, y in outline] + [p((x, y, z + thickness / 2)) for x, y in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(o)
    finish(o, root, mat, bevel)
    scene.view_layers[0].objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    o.select_set(False)
    return o

def build_seraph():
    scene_name = 'CampaignBoss_seraph'
    scene = bpy.data.scenes.get(scene_name)
    if not scene:
        scene = bpy.data.scenes.new(scene_name)
    bpy.context.window.scene = scene
    bpy.context.window.view_layer = scene.view_layers[0]
    for o in list(scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
        
    m = create_materials()
    root = socket(None, 'Seraph_Root', (0, 0, 0))
    
    # -------------------------------------------------------------
    # 1. TORSO & CHASSIS
    # -------------------------------------------------------------
    torso = socket(root, 'SeraphTorso', (0, 0, 0))
    
    # Recessed aerodynamic main fuselage (pushed slightly back so core dominates front)
    chassis_sections = [
        (0, -1.30, -0.05, 0.42, 0.40),
        (0, -0.70, -0.02, 0.65, 0.50),
        (0,  0.05,  0.00, 0.85, 0.58),
        (0,  0.80, -0.02, 0.72, 0.52),
        (0,  1.30, -0.05, 0.45, 0.40)
    ]
    loft(torso, 'Chassis_Fuselage', chassis_sections, m['armor'], 0.024)
    
    # Internal carbon structural spine
    box(torso, 'Chassis_Internal_Frame', (0, 0.0, -0.08), (0.75, 2.3, 0.65), m['dark'], 0.02)
    
    # Armored collar rim around neck
    torus(torso, 'Neck_Collar_Armor', (0, 1.18, 0.12), 0.38, 0.05, m['titanium'], tilt=0.15)

    # Lateral pectoral carapaces framing the central core aperture
    for side in [-1, 1]:
        # Pectoral carapace leaves a circular open cradle in the center
        pectoral = [
            (side * 0.55, 0.82), (side * 1.15, 0.68), (side * 1.25, 0.20),
            (side * 1.05, -0.32), (side * 0.55, -0.28), (side * 0.42, 0.05),
            (side * 0.44, 0.45)
        ]
        plate(torso, f'Pectoral_Carapace_{"L" if side<0 else "R"}', pectoral, 0.24, 0.16, m['armor'], 0.016)
        
        # Upper shoulder deflector pauldron
        pauldron = [
            (side * 0.65, 0.75), (side * 1.25, 0.95), (side * 1.45, 0.55), (side * 0.95, 0.42)
        ]
        plate(torso, f'Shoulder_Deflector_{"L" if side<0 else "R"}', pauldron, 0.30, 0.12, m['titanium'], 0.014)

        # Thermal dissipation louvers on lower ribs
        for j in range(4):
            y_pos = -0.38 - j * 0.16
            box(torso, f'Rib_Vent_{j}_{"L" if side<0 else "R"}', (side * 0.68, y_pos, 0.12), (0.35, 0.06, 0.08), m['copper'], 0.008, rot=(0, 0, side * 0.18))
            box(torso, f'Vent_Armor_Slat_{j}_{"L" if side<0 else "R"}', (side * 0.72, y_pos + 0.03, 0.16), (0.40, 0.04, 0.06), m['titanium'], 0.006)

    # Lower ventral keel apron plate (below the core)
    keel = [(-0.35, -0.45), (0.35, -0.45), (0.22, -1.25), (0.0, -1.55), (-0.22, -1.25)]
    plate(torso, 'Central_Keel_Armor', keel, 0.26, 0.14, m['titanium'], 0.018)
    # Keel heat conduit
    box(torso, 'Keel_Thermal_Strip', (0, -0.95, 0.34), (0.08, 0.85, 0.04), m['plasma_conduit'], 0.004)
    
    # Dorsal spinal cooling vertebrae
    for k in range(7):
        z_fin = -0.42 - k * 0.03
        y_fin = 1.05 - k * 0.34
        spine_fin = [(-0.06, y_fin), (0.06, y_fin), (0.03, y_fin - 0.24), (-0.03, y_fin - 0.24)]
        plate(torso, f'Dorsal_Spine_{k}', spine_fin, z_fin, 0.05, m['titanium'], 0.01)
        box(torso, f'Spine_Heat_Element_{k}', (0, y_fin - 0.12, z_fin - 0.08), (0.04, 0.16, 0.08), m['copper'], 0.005)

    # -------------------------------------------------------------
    # 2. THE EMBERFALL SINGULARITY (SOLAR CORE) - PROUD & PROMINENT
    # -------------------------------------------------------------
    # Sits prominently at z = 0.30 - 0.55, unshielded by any overlapping keel!
    socket(torso, 'CoreSocket', (0, 0.18, 0.58))
    
    # Sunken reactor containment housing
    cylinder(torso, 'Core_Cavity_Wall', (0, 0.18, 0.18), 0.62, 0.28, m['dark'], axis='Z')
    # Outer machined titanium containment collar
    torus(torso, 'Core_Outer_Containment_Ring', (0, 0.18, 0.32), 0.58, 0.065, m['titanium'])
    # 8 radiating copper electromagnetic stator poles
    for i in range(8):
        ang = i * (math.pi / 4)
        px = math.cos(ang) * 0.62
        py = 0.18 + math.sin(ang) * 0.62
        box(torso, f'Core_Stator_Pole_{i}', (px, py, 0.30), (0.12, 0.06, 0.10), m['copper'], 0.006, rot=(0, 0, ang))
        box(torso, f'Core_Radiator_Node_{i}', (px * 1.15, py * 1.15, 0.28), (0.07, 0.07, 0.06), m['gold'], 0.004)
        
    # Concentric copper induction coils
    torus(torso, 'Core_Copper_Induction_Coil', (0, 0.18, 0.36), 0.48, 0.045, m['copper'])
    torus(torso, 'Core_Inner_Gold_Lip', (0, 0.18, 0.40), 0.39, 0.038, m['gold'])
    
    # Pulsing spherical singularity core (intensely emissive!)
    sphere(torso, 'Singularity_Solar_Sphere', (0, 0.18, 0.32), (0.36, 0.36, 0.28), m['core_energy'])
    
    # 4 Articulated interlocking iris aperture shutters
    for i in range(4):
        ang = i * (math.pi / 2) + 0.38
        bx = math.cos(ang) * 0.36
        by = 0.18 + math.sin(ang) * 0.36
        box(torso, f'Core_Iris_Shutter_{i}', (bx, by, 0.42), (0.18, 0.14, 0.035), m['titanium'], 0.008, rot=(0, 0, ang))

    # -------------------------------------------------------------
    # 3. WAR VISAGE / HEAD (CROWN OF THE SERAPH)
    # -------------------------------------------------------------
    head = socket(torso, 'SeraphHead', (0, 1.25, 0.26))
    
    # Aerodynamic crested helmet shell
    helmet_sections = [
        (0, -0.22, -0.08, 0.26, 0.24),
        (0,  0.05, -0.04, 0.32, 0.26),
        (0,  0.38, -0.02, 0.30, 0.24),
        (0,  0.65, -0.06, 0.16, 0.16)
    ]
    loft(head, 'Helmet_Crown_Shell', helmet_sections, m['armor'], 0.016)
    
    # Angled knightly brow crest
    brow = [(-0.30, 0.20), (0.30, 0.20), (0.22, 0.48), (0.0, 0.68), (-0.22, 0.48)]
    plate(head, 'Helmet_Brow_Plate', brow, 0.32, 0.10, m['titanium'], 0.014)
    
    # Prominent glowing ruby/solar visor strip
    box(head, 'Main_Optic_Sensor_Visor', (0, 0.16, 0.36), (0.42, 0.08, 0.06), m['optic_sensor'], 0.006)
    
    for side in [-1, 1]:
        # Angled cheek targeting sensor lenses
        box(head, f'Cheek_Sensor_{"L" if side<0 else "R"}', (side * 0.22, 0.04, 0.32), (0.10, 0.04, 0.03), m['core_energy'], 0.004, rot=(0, 0, side * 0.32))
        # Swept antennae / sensor horns
        vane = [(side * 0.24, 0.30), (side * 0.44, 0.82), (side * 0.34, 0.92), (side * 0.20, 0.48)]
        plate(head, f'Antenna_Vane_{"L" if side<0 else "R"}', vane, 0.06, 0.045, m['titanium'], 0.008)
        # Cheek deflectors
        cheek = [(side * 0.14, -0.20), (side * 0.30, -0.06), (side * 0.28, 0.16), (side * 0.16, 0.10)]
        plate(head, f'Cheek_Deflector_{"L" if side<0 else "R"}', cheek, 0.28, 0.08, m['armor'], 0.01)

    # Chin respirator grille
    for r in range(4):
        box(head, f'Chin_Respirator_{r}', (0, -0.08 - r * 0.04, 0.30), (0.18 - r * 0.035, 0.025, 0.035), m['copper'], 0.004)

    # -------------------------------------------------------------
    # 4. PRIMARY RAZOR WINGS (UPPER WINGS: L & R)
    # -------------------------------------------------------------
    for side, suffix in [(-1, 'L'), (1, 'R')]:
        wing_upper = socket(torso, f'WingUpper_{suffix}', (side * 0.95, 0.65, 0.02))
        
        # Heavy shoulder gimbal housing
        sphere(wing_upper, f'Wing_Shoulder_Gimbal_{suffix}', (0, 0, 0), (0.34, 0.34, 0.34), m['dark'])
        torus(wing_upper, f'Wing_Gimbal_Ring_{suffix}', (0, 0, 0), 0.36, 0.045, m['titanium'])
        
        # Swept titanium wing spar with upward arch
        spar_pts = [
            (0, 0.05, 0.06),
            (side * 0.70, 0.38, 0.05),
            (side * 1.75, 0.85, 0.03),
            (side * 2.80, 1.35, 0.01),
            (side * 3.40, 1.65, 0.00)
        ]
        for idx in range(len(spar_pts) - 1):
            p1, p2 = spar_pts[idx], spar_pts[idx + 1]
            mid = ((p1[0] + p2[0]) * 0.5, (p1[1] + p2[1]) * 0.5, (p1[2] + p2[2]) * 0.5)
            dx, dy = p2[0] - p1[0], p2[1] - p1[1]
            length = math.hypot(dx, dy)
            rot_ang = math.atan2(dy, dx)
            box(wing_upper, f'Spar_Segment_{idx}_{suffix}', mid, (length, 0.22 - idx * 0.035, 0.16 - idx * 0.025), m['titanium'], 0.015, rot=(0, 0, rot_ang))

        # 6 Layered Razor Blade Feathers fanning gracefully downward & outward
        # Creates a majestic tiered angel-of-war wing silhouette!
        feather_configs = [
            # (start_x, start_y, length, sweep_angle, width, thickness)
            (0.50, 0.15, 1.25, -0.45, 0.36, 0.07),
            (0.95, 0.35, 1.65, -0.32, 0.34, 0.065),
            (1.50, 0.65, 2.05, -0.18, 0.32, 0.06),
            (2.10, 0.95, 2.35, -0.05, 0.28, 0.055),
            (2.70, 1.25, 2.30,  0.08, 0.25, 0.05),
            (3.20, 1.50, 1.95,  0.22, 0.20, 0.045)
        ]
        for f_idx, (fx, fy, flen, frot, fwidth, fthick) in enumerate(feather_configs):
            tip_x = fx + math.cos(frot) * flen
            tip_y = fy + math.sin(frot) * flen
            perp_x = -math.sin(frot) * fwidth * 0.5
            perp_y =  math.cos(frot) * fwidth * 0.5
            
            blade_poly = [
                (side * (fx - perp_x * 0.7), fy - perp_y * 0.7),
                (side * (fx + perp_x * 0.9), fy + perp_y * 0.9),
                (side * (tip_x + perp_x * 0.3), tip_y + perp_y * 0.3),
                (side * (tip_x + math.cos(frot) * 0.30), tip_y + math.sin(frot) * 0.30),
                (side * (tip_x - perp_x * 0.5), tip_y - perp_y * 0.5)
            ]
            plate(wing_upper, f'Razor_Feather_{f_idx}_{suffix}', blade_poly, 0.02 + f_idx * 0.012, fthick, m['armor'], 0.012)
            
            # Radiant Solar Plasma Lightguide Channel along each feather
            conduit_poly = [
                (side * (fx), fy),
                (side * (fx + perp_x * 0.25), fy + perp_y * 0.25),
                (side * (tip_x * 0.88 + perp_x * 0.1), tip_y * 0.88 + perp_y * 0.1),
                (side * (tip_x * 0.88 - perp_x * 0.15), tip_y * 0.88 - perp_y * 0.15)
            ]
            plate(wing_upper, f'Solar_Conduit_{f_idx}_{suffix}', conduit_poly, 0.035 + f_idx * 0.012, fthick * 0.5, m['plasma_conduit'], 0.005)
            
            # Gold edge trim on outer blade tips
            if f_idx >= 3:
                edge_poly = [
                    (side * (tip_x * 0.85), tip_y * 0.85),
                    (side * (tip_x + math.cos(frot) * 0.28), tip_y + math.sin(frot) * 0.28),
                    (side * (tip_x - perp_x * 0.4), tip_y - perp_y * 0.4)
                ]
                plate(wing_upper, f'Gold_Tip_{f_idx}_{suffix}', edge_poly, 0.03 + f_idx * 0.012, fthick * 0.6, m['gold'], 0.004)

        # Underslung Heavy Siege Cannon Battery
        cannon_mount = socket(wing_upper, f'Cannon_Mount_{suffix}', (side * 2.05, 0.10, -0.02))
        box(cannon_mount, f'Cannon_Receiver_{suffix}', (0, 0, 0), (0.75, 0.32, 0.30), m['armor'], 0.018)
        cylinder(cannon_mount, f'Cannon_Shroud_{suffix}', (0, -0.45, 0), 0.15, 0.65, m['titanium'], axis='Y', bevel=0.01)
        cylinder(cannon_mount, f'Cannon_Barrel_{suffix}', (0, -0.95, 0), 0.09, 0.55, m['dark'], axis='Y')
        cylinder(cannon_mount, f'Cannon_Muzzle_Brake_{suffix}', (0, -1.25, 0), 0.13, 0.18, m['copper'], axis='Y')
        cylinder(cannon_mount, f'Cannon_Bore_{suffix}', (0, -1.35, 0), 0.075, 0.06, m['core_energy'], axis='Y')
        
        # Sockets for Godot projectiles & muzzle flashes
        socket(wing_upper, 'MuzzleLeft' if side < 0 else 'MuzzleRight', (side * 2.05, -1.30, -0.02))

    # -------------------------------------------------------------
    # 5. SECONDARY STABILIZER WINGS (LOWER WINGS: L & R)
    # -------------------------------------------------------------
    for side, suffix in [(-1, 'L'), (1, 'R')]:
        wing_lower = socket(torso, f'WingLower_{suffix}', (side * 0.75, -0.25, -0.06))
        
        # Lower hinge servo
        cylinder(wing_lower, f'Lower_Wing_Servo_{suffix}', (0, 0, 0), 0.22, 0.18, m['titanium'], axis='Z')
        
        # Swept downward stabilizer fin
        lower_fin = [
            (0, 0.05), (side * 0.85, 0.10), (side * 2.05, -0.55),
            (side * 2.35, -1.05), (side * 1.75, -1.25), (side * 0.45, -0.65)
        ]
        plate(wing_lower, f'Lower_Stabilizer_Fin_{suffix}', lower_fin, 0.0, 0.08, m['armor'], 0.014)
        
        # Titanium maneuvering flap
        flap = [
            (side * 0.55, -0.62), (side * 1.65, -1.15),
            (side * 1.55, -1.35), (side * 0.48, -0.78)
        ]
        plate(wing_lower, f'Maneuvering_Flap_{suffix}', flap, 0.03, 0.05, m['titanium'], 0.008)
        
        # Vernier RCS Thruster at tip
        box(wing_lower, f'RCS_Block_{suffix}', (side * 1.95, -0.80, 0.04), (0.20, 0.12, 0.10), m['copper'], 0.006)
        cylinder(wing_lower, f'RCS_Nozzle_{suffix}', (side * 2.05, -0.80, 0.04), 0.045, 0.07, m['plasma_conduit'], axis='X')

    # -------------------------------------------------------------
    # 6. DUAL HEAVY INFERNO TURBINES (JET DRIVES: L & R)
    # -------------------------------------------------------------
    for side, suffix in [(-1, 'L'), (1, 'R')]:
        thruster = socket(torso, f'Thruster_{suffix}', (side * 1.50, -0.40, -0.15))
        
        # Heavy structural pylon connecting engine to chassis
        box(thruster, f'Turbine_Pylon_{suffix}', (-side * 0.38, 0.22, 0.12), (0.75, 0.22, 0.18), m['titanium'], 0.015, rot=(0, 0, side * 0.28))
        
        # Main Engine Nacelle Cowling (facing slightly outward/downward)
        cylinder(thruster, f'Turbine_Outer_Cowl_{suffix}', (0, 0.12, 0), 0.48, 0.95, m['armor'], axis='Y', bevel=0.018)
        torus(thruster, f'Turbine_Intake_Lip_{suffix}', (0, 0.62, 0), 0.48, 0.065, m['titanium'], tilt=0)
        
        # Internal compressor hub and 12-blade spinner
        cylinder(thruster, f'Compressor_Spinner_{suffix}', (0, 0.48, 0), 0.20, 0.28, m['titanium'], axis='Y', top=0.02)
        for b_idx in range(12):
            b_ang = b_idx * (math.pi / 6)
            bx = math.cos(b_ang) * 0.32
            bz = math.sin(b_ang) * 0.32
            box(thruster, f'Turbine_Blade_{b_idx}_{suffix}', (bx, 0.42, bz), (0.15, 0.03, 0.11), m['titanium'], 0.004, rot=(0, b_ang, 0.45))
            
        # Glowing combustion chamber liner
        cylinder(thruster, f'Combustion_Chamber_Glow_{suffix}', (0, -0.18, 0), 0.38, 0.45, m['exhaust_glow'], axis='Y')
        
        # Converging-Diverging Vectoring Nozzle
        cylinder(thruster, f'Vectoring_Nozzle_Petals_{suffix}', (0, -0.52, 0), 0.44, 0.34, m['titanium'], axis='Y', top=0.38, bevel=0.01)
        torus(thruster, f'Afterburner_Flame_Ring_{suffix}', (0, -0.70, 0), 0.34, 0.05, m['exhaust_glow'], tilt=0)
        
        # Sockets for Godot particle flares & lighting
        socket(thruster, f'ThrusterSocket_{suffix}', (0, -0.78, 0))

    # -------------------------------------------------------------
    # 7. RAPTOR TALONS / LANDING CHASSIS (L & R)
    # -------------------------------------------------------------
    for side, suffix in [(-1, 'L'), (1, 'R')]:
        talon_root = socket(torso, f'Talon_{suffix}', (side * 0.52, -1.15, 0.05))
        
        # Hip knuckle servo
        sphere(talon_root, f'Talon_Hip_Knuckle_{suffix}', (0, 0, 0), (0.18, 0.18, 0.18), m['dark'])
        # Upper digitigrade thigh strut
        box(talon_root, f'Talon_Thigh_Strut_{suffix}', (side * 0.08, -0.26, -0.06), (0.16, 0.50, 0.18), m['titanium'], 0.012, rot=(0.2, 0, side * 0.1))
        # Hydraulic knee actuator piston
        cylinder(talon_root, f'Talon_Hydraulic_Piston_{suffix}', (side * 0.08, -0.30, 0.08), 0.04, 0.38, m['copper'], axis='Y')
        
        # Lower tarsus & claws
        tarsus_y = -0.55
        box(talon_root, f'Talon_Tarsus_{suffix}', (side * 0.12, tarsus_y, 0.02), (0.22, 0.22, 0.22), m['armor'], 0.015)
        
        # 3 Curved razor talons
        for c_idx, claw_ang in enumerate([-0.25, 0.0, 0.25]):
            claw_poly = [
                (side * (0.04 + c_idx * 0.06), tarsus_y),
                (side * (0.08 + c_idx * 0.06), tarsus_y - 0.26),
                (side * (0.16 + c_idx * 0.08), tarsus_y - 0.52),
                (side * (0.12 + c_idx * 0.07), tarsus_y - 0.48),
                (side * (0.02 + c_idx * 0.05), tarsus_y - 0.22)
            ]
            plate(talon_root, f'Razor_Claw_{c_idx}_{suffix}', claw_poly, 0.08 + claw_ang * 0.15, 0.05, m['titanium'], 0.008)

    print('AAA EMBERFALL SERAPH BUILT IN SCENE:', scene_name)
    return root

def optimize_and_export(root):
    scene = bpy.data.scenes['CampaignBoss_seraph']
    bpy.context.window.scene = scene
    bpy.context.window.view_layer = scene.view_layers[0]
    
    # 1. Convert curves to meshes
    for o in list(scene.objects):
        if o.type == 'CURVE':
            bpy.ops.object.select_all(action='DESELECT')
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.convert(target='MESH')
            
    # 2. Apply modifiers and generate UVs
    for o in list(scene.objects):
        if o.type != 'MESH':
            continue
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            try:
                bpy.ops.object.modifier_apply(modifier=mod.name)
            except Exception:
                pass
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.uv.smart_project(island_margin=0.012)
        bpy.ops.object.mode_set(mode='OBJECT')

    # 3. Batch meshes by (parent, material) to minimize draw calls while keeping articulated hierarchy!
    groups = {}
    for o in list(scene.objects):
        if o.type != 'MESH' or not o.parent:
            continue
        mat_name = o.data.materials[0].name if o.data.materials else 'default'
        parent_name = o.parent.name
        groups.setdefault((parent_name, mat_name), []).append(o)
        
    for (p_name, m_name), objs in groups.items():
        if len(objs) > 1:
            bpy.ops.object.select_all(action='DESELECT')
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.object.join()
            objs[0].name = f'{p_name}_{m_name}_Combined'
            
    # 4. Select all objects under Seraph_Root
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for o in root.children_recursive:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root

    # 5. Export to GLB
    glb_path = OUT / 'seraph.glb'
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format='GLB',
        use_selection=True,
        use_active_scene=True,
        export_apply=True,
        export_animations=False,
        export_yup=True,
        export_lights=False,
        export_cameras=False
    )
    
    # Calculate triangle count
    deps = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    for o in root.children_recursive:
        if o.type == 'MESH':
            mesh = o.evaluated_get(deps).to_mesh()
            mesh.calc_loop_triangles()
            triangles += len(mesh.loop_triangles)
            o.evaluated_get(deps).to_mesh_clear()
            
    # Save workbench blend
    blend_path = OUT / 'campaign_boss_workbench.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    
    print('========================================')
    print('AAA EMBERFALL SERAPH EXPORTED SUCCESSFULLY!')
    print('GLB Path:', glb_path)
    print('Components:', len(root.children_recursive))
    print('Total Triangles:', triangles)
    print('========================================')

if __name__ == '__main__':
    root_obj = build_seraph()
    optimize_and_export(root_obj)
