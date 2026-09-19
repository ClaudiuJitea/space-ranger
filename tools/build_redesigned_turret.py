"""Redesigned Flying Sentry / Combat Turret for Space Ranger.
Authored for Blender MCP. High-fidelity hard-surface model matching the game's PBR aesthetic.
Preserves the (AnchoredBase, AimingHead) hierarchy for runtime Godot articulation and tests.
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

BASE = Path('/home/clau/Godot/games/space-ranger')
if str(BASE / 'tools') not in sys.path:
    sys.path.append(str(BASE / 'tools'))

import build_concept_enemies_v2 as b2
h = b2.h
OUT = b2.OUT
PREVIEW = b2.PREVIEW


def build_redesigned_sentry():
    # Clear previous objects if present
    for o in list(bpy.data.objects):
        if 'RedesignedSentry' in o.name or 'SENTRY_Turret_V2' in o.name:
            bpy.data.objects.remove(o, do_unlink=True)

    p = h.root('SENTRY_Turret_V2')
    base = h.root('AnchoredBase')
    base.parent = p

    # =========================================================================
    # 1. ANCHORED BASE: Anti-Gravity Levitation Cowl & Heavy Fortified Chassis
    # Engineered with faceted stealth armor, outrigger thruster pods, swept wings,
    # and a multi-layered glowing anti-gravity reactor core.
    # No flat circular plate! Every millimeter is detailed with hard-surface aerospace forms.
    # =========================================================================

    # Core chassis ring (slender, chamfered rim)
    h.cyl(base, 'Central chassis ring', (0, 0, 0.08), 0.43, 0.07, 'armor', vertices=32)
    h.ring(base, 'Chassis lower rim bevel', (0, 0, 0.046), 0.428, 0.008, 'edge')

    # Sloped armored skirt / lower foundation
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.42, radius2=0.33, depth=0.18, location=(0, 0, 0.19))
    cone = bpy.context.object
    h.finish(cone, 'Armored skirt foundation', 'armor', base, 0.009)
    for f in cone.data.polygons:
        f.use_smooth = len(f.vertices) == 4

    # -------------------------------------------------------------------------
    # 8 RADIAL ARMOR CANOPY RIBS & RECESSED HEAT EXCHANGER VENTS
    # Breaks up the circular top face with 8 faceted composite armor wedges
    # -------------------------------------------------------------------------
    for i in range(8):
        a = i * math.pi / 4
        ca, sa = math.cos(a), math.sin(a)

        # Raised structural armor spine extending from inner core to outer rim
        b2.loft(base, f'Armor canopy rib_{i}', [
            (0.18 * ca, 0.18 * sa, -0.015, 0.035),
            (0.32 * ca, 0.32 * sa, 0.010, 0.060),
            (0.43 * ca, 0.43 * sa, 0.040, 0.085)
        ], mat='ceramic', corner=0.25)

        # Chamfered dark bracket on the outer knuckle
        h.box(base, f'Rib knuckle bracket_{i}', (0.43 * ca, 0.43 * sa, 0.065), (0.055, 0.085, 0.07), 'dark', rot=(0, 0.22, a), bevel=0.006)
        h.cyl(base, f'Rib hex bolt_{i}', (0.442 * ca, 0.442 * sa, 0.075), 0.010, 0.012, 'steel', (ca, sa, 0), 6)

        # Recessed heat exchanger vents between ribs (offset by 22.5 deg)
        va = a + math.pi / 8
        cva, sva = math.cos(va), math.sin(va)
        vx, vy = 0.30 * cva, 0.30 * sva

        # Dark recessed vent tray
        h.box(base, f'Heat vent tray_{i}', (vx, vy, 0.035), (0.16, 0.09, 0.025), 'dark', rot=(0, 0.18, va), bevel=0.004)
        # Glowing orange thermal grille louvers
        for j in range(3):
            lv_d = 0.24 + j * 0.05
            h.box(base, f'Vent louver_{i}_{j}', (lv_d * cva, lv_d * sva, 0.028 + j * 0.008), (0.014, 0.075, 0.014), 'orange', rot=(0, 0.22, va), bevel=0.002)

        # Lower perimeter reinforcing plate on the skirt
        h.box(base, f'Skirt armor pad_{i}', (0.385 * ca, 0.385 * sa, 0.19), (0.055, 0.11, 0.14), 'ceramic', rot=(0, 0.24, a), bevel=0.006)
        h.cyl(base, f'Skirt pad fastener_{i}', (0.435 * ca, 0.435 * sa, 0.105), 0.010, 0.012, 'steel', vertices=6)

    # -------------------------------------------------------------------------
    # CENTRAL ANTI-GRAVITY LEVITATION REACTOR CROWN (Z ≈ -0.04 to 0.02)
    # Raised, tiered multi-ring magnetic emitter housing with intense glowing core
    # -------------------------------------------------------------------------
    # Armored reactor crown base
    h.cyl(base, 'Reactor crown base', (0, 0, 0.010), 0.20, 0.045, 'dark', vertices=32)
    h.ring(base, 'Reactor titanium collar', (0, 0, -0.008), 0.195, 0.010, 'steel')

    # Concentric magnetic accelerator coils
    h.ring(base, 'Magnetic accelerator coil 1', (0, 0, -0.016), 0.165, 0.009, 'edge')
    h.ring(base, 'Magnetic accelerator coil 2', (0, 0, -0.022), 0.125, 0.008, 'steel')
    h.ring(base, 'Magnetic accelerator coil 3', (0, 0, -0.028), 0.085, 0.007, 'orange')

    # Stepped glowing plasma reactor core
    h.cyl(base, 'AntiGrav plasma emitter core', (0, 0, -0.022), 0.080, 0.028, 'orange', vertices=24)
    # Central focus emitter crystal / dark iris
    h.cyl(base, 'Emitter focal node', (0, 0, -0.034), 0.035, 0.018, 'dark', vertices=16)
    h.ring(base, 'Emitter focal lens ring', (0, 0, -0.041), 0.036, 0.004, 'orange')

    # 4 magnetic containment blades crossing over the core
    for i in range(4):
        a = i * math.pi / 2
        h.box(base, f'Magnetic blade_{i}', (0.10 * math.cos(a), 0.10 * math.sin(a), -0.020), (0.17, 0.022, 0.018), 'steel', rot=(0, 0, a), bevel=0.003)

    # -------------------------------------------------------------------------
    # 4 OUTRIGGER VECTORING ION THRUSTER NACELLES
    # Project outwards at 45°, 135°, 225°, 315° beyond the chassis rim
    # -------------------------------------------------------------------------
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        ca, sa = math.cos(a), math.sin(a)
        tx, ty = 0.46 * ca, 0.46 * sa
        tz = 0.09

        # Structural pylon extending from chassis to thruster pod
        h.box(base, f'Thruster pylon_{i}', (0.38 * ca, 0.38 * sa, tz), (0.14, 0.08, 0.06), 'steel', rot=(0, 0, a), bevel=0.008)

        # Armored thruster nacelle fairing
        h.box(base, f'Thruster nacelle_{i}', (tx, ty, tz), (0.16, 0.14, 0.18), 'dark', rot=(0, 0, a), bevel=0.012)
        # Angled ceramic heat deflector cowl
        h.box(base, f'Thruster deflector cowl_{i}', (tx + 0.02 * ca, ty + 0.02 * sa, tz - 0.06), (0.12, 0.12, 0.05), 'ceramic', rot=(0, 0, a), bevel=0.008)

        # Dual vectoring exhaust nozzles per nacelle (forward/aft or angled)
        h.cyl(base, f'Thruster nozzle bell_{i}', (tx, ty, tz - 0.075), 0.052, 0.065, 'steel', (0, 0, 1), 24)
        h.ring(base, f'Thruster nozzle lip_{i}', (tx, ty, tz - 0.105), 0.053, 0.007, 'edge')
        # Intense glowing plasma flame interior
        h.cyl(base, f'Thruster ion plasma_{i}', (tx, ty, tz - 0.095), 0.040, 0.035, 'orange', (0, 0, 1), 16)

        # Radiator cooling gills on nacelle outer flanks
        for s in [-1, 1]:
            fx = tx - 0.075 * sa * s
            fy = ty + 0.075 * ca * s
            h.box(base, f'Nacelle heatsink_{i}_{s}', (fx, fy, tz), (0.10, 0.012, 0.11), 'steel', rot=(0, 0, a), bevel=0.002)

        # Armored power conduit linking nacelle to central reactor
        h.cable(base, f'Thruster conduit_{i}', [
            (0.20 * ca, 0.20 * sa, 0.02),
            (0.32 * ca, 0.32 * sa, 0.05),
            (tx - 0.04 * ca, ty - 0.04 * sa, tz)
        ], r=0.012)

    # -------------------------------------------------------------------------
    # SWEPT STABILIZER WINGS & AERO SURFACES (Y = ±0.45 to ±0.68)
    # Gives the enemy an aggressive, predatory aerospace profile
    # -------------------------------------------------------------------------
    for s in [-1, 1]:
        wy = s * 0.44
        # Swept delta main wing panel
        b2.mesh(base, f'Aero wing panel_{s}', [
            (-0.18, wy, 0.11), (0.18, wy, 0.11),
            (0.08, wy + s * 0.24, 0.10), (-0.14, wy + s * 0.24, 0.10),
            (-0.18, wy, 0.06), (0.18, wy, 0.06),
            (0.08, wy + s * 0.24, 0.06), (-0.14, wy + s * 0.24, 0.06)
        ], [
            (0, 1, 2, 3), (7, 6, 5, 4),  # top and bottom
            (0, 4, 5, 1), (1, 5, 6, 2),  # inner and front
            (2, 6, 7, 3), (3, 7, 4, 0)   # outer and rear
        ], mat='armor', smooth=False, bevel=0.007)

        # Wing ceramic armor strike face
        h.box(base, f'Wing ceramic plate_{s}', (-0.01, wy + s * 0.11, 0.118), (0.24, 0.12, 0.022), 'ceramic', bevel=0.005)
        # Leading edge Mach slat
        h.box(base, f'Wing leading edge_{s}', (0.14, wy + s * 0.12, 0.095), (0.025, 0.18, 0.035), 'edge', rot=(0, 0, -s * 0.28), bevel=0.004)

        # Wingtip navigation beacon strobe (Red on port, Orange on starboard)
        beacon_color = 'red' if s < 0 else 'orange'
        h.cyl(base, f'Wingtip beacon_{s}', (-0.03, wy + s * 0.245, 0.085), 0.016, 0.032, beacon_color, (0, 1, 0), 12)
        h.ring(base, f'Wingtip beacon bezel_{s}', (-0.03, wy + s * 0.245, 0.085), 0.017, 0.004, 'dark', (0, 1, 0))

        # Forward telemetry / pitot antenna needle (+X)
        h.cyl(base, f'Pitot antenna_{s}', (0.25, wy + s * 0.08, 0.085), 0.006, 0.18, 'steel', (1, 0, 0), 12)

    # -------------------------------------------------------------------------
    # YAW TURNTABLE & GIMBAL BEARING (Facing the Turret Head at Z ≈ 0.32 to 0.40)
    # -------------------------------------------------------------------------
    h.cyl(base, 'Yaw turntable', (0, 0, 0.325), 0.335, 0.06, 'steel', vertices=64)
    h.ring(base, 'Yaw orange locator ring', (0, 0, 0.335), 0.325, 0.009, 'orange')
    h.cyl(base, 'Turntable inner collar', (0, 0, 0.355), 0.28, 0.035, 'dark', vertices=48)
    h.ring(base, 'Turntable bearing ring', (0, 0, 0.370), 0.285, 0.008, 'edge')

    # =========================================================================
    # 2. AIMING HEAD: Heavy Articulated Twin Autocannon Turret & Sensor Suite
    # Reparented to Godot's SwivelHead for runtime mouse / player tracking.
    # Barrels face +X, pivot center around Z ≈ 0.45.
    # =========================================================================
    head = h.root('AimingHead')
    head.parent = p

    # Gimbal articulation yoke & spherical neck bearing
    h.cyl(head, 'Gimbal spherical pivot', (0, 0, 0.41), 0.16, 0.10, 'dark', vertices=32)
    b2.loft(head, 'Gimbal support trunnion', [
        (-0.16, 0.14, 0.345, 0.46),
        (0.06, 0.15, 0.350, 0.50),
        (0.14, 0.11, 0.370, 0.48)
    ], 'steel', corner=0.18)

    # Hydraulic elevation dampeners flanking the gimbal
    for s in [-1, 1]:
        h.cyl(head, f'Elevation cylinder_{s}', (-0.12, s * 0.18, 0.41), 0.024, 0.11, 'dark', (0, 0, 1), 16)
        h.cyl(head, f'Elevation piston_{s}', (-0.12, s * 0.18, 0.46), 0.014, 0.09, 'steel', (0, 0, 1), 16)
        # Flexible corrugated conduit from base to turret breech
        h.cable(head, f'Base to head conduit_{s}', [
            (-0.18, s * 0.20, 0.35),
            (-0.25, s * 0.22, 0.42),
            (-0.16, s * 0.20, 0.52)
        ], r=0.014)

    # -------------------------------------------------------------------------
    # MAIN WEAPON RECEIVER CHASSIS
    # Sleek, multi-faceted stealth armored housing matching gunship & boss style
    # -------------------------------------------------------------------------
    # Core weapon housing chassis
    b2.loft(head, 'Compact chamfered weapon housing', [
        (-0.31, 0.21, 0.47, 0.69),
        (-0.25, 0.24, 0.44, 0.75),
        (0.12, 0.24, 0.45, 0.75),
        (0.23, 0.18, 0.47, 0.70)
    ], 'armor', corner=0.20)

    # Pale sloping upper ceramic armor hood
    b2.loft(head, 'Pale sloping upper housing', [
        (-0.29, 0.19, 0.68, 0.71),
        (-0.21, 0.22, 0.73, 0.77),
        (0.11, 0.22, 0.73, 0.77),
        (0.22, 0.17, 0.69, 0.72)
    ], 'ceramic', corner=0.22)

    # Lateral cheek armor plates & elevation joint hubs
    for s in [-1, 1]:
        b2.joint(head, (-0.04, s * 0.255, 0.46), 0.10, s)
        # Heavy ceramic cheek shield
        h.plate(head, f'Receiver side shield_{s}', [
            (-0.28, 0.50), (-0.29, 0.66), (-0.20, 0.74),
            (0.12, 0.72), (0.20, 0.63), (0.12, 0.51)
        ], s * 0.245, 0.030, 'ceramic')
        # Dark armor under-plate
        h.box(head, f'Receiver cheek underplate_{s}', (-0.04, s * 0.262, 0.61), (0.34, 0.018, 0.18), 'dark', bevel=0.010)

        # Recessed cooling intake vents
        for j in range(4):
            b2.slit(head, (-0.18 + j * 0.055, s * 0.272, 0.655), (0.018, 0.012, 0.055), 'rubber')
            # Glowing thermal slot inside vent
            h.cyl(head, f'Internal vent glow_{s}_{j}', (-0.18 + j * 0.055, s * 0.270, 0.655), 0.005, 0.010, 'orange', (0, 1, 0), 8)

        # High-pressure elevation motor cable
        h.cable(head, f'Elevation motor conduit_{s}', [
            (-0.23, s * 0.25, 0.54),
            (-0.27, s * 0.29, 0.40),
            (-0.09, s * 0.23, 0.365)
        ], r=0.013)

    # Rear heat dissipation radiator fins (aft of receiver)
    for k in range(5):
        rx = -0.28 - k * 0.035
        h.box(head, f'Radiator fin_{k}', (rx, 0.0, 0.58), (0.016, 0.28, 0.14), 'dark', bevel=0.003)
        h.box(head, f'Radiator core glow_{k}', (rx, 0.0, 0.58), (0.018, 0.18, 0.08), 'orange', bevel=0.002)

    # -------------------------------------------------------------------------
    # TWIN HEAVY AUTOCANNONS (Vertically stacked, pointing +X)
    # Positions match concept sheet and Godot muzzle markers: Z = 0.52 and Z = 0.625
    # -------------------------------------------------------------------------
    for z in [0.52, 0.625]:
        # Heavy barrel trunnion clamp
        h.box(head, f'Barrel trunnion clamp_{z}', (0.18, -0.055, z), (0.16, 0.12, 0.095), 'dark', bevel=0.010)
        # The main perforated autocannon with vented shroud and muzzle compensator
        b2.barrel(head, tip=0.68, y=-0.055, z=z, length=0.50, r=0.048, energy='orange', shroud=True)
        # Heavy multi-port muzzle brake at barrel tip
        h.cyl(head, f'Muzzle brake compensator_{z}', (0.665, -0.055, z), 0.054, 0.045, 'dark', (1, 0, 0), 24)
        for side in [-1, 1]:
            h.cyl(head, f'Compensator side port_{z}_{side}', (0.665, -0.055 + side * 0.045, z), 0.015, 0.03, 'rubber', (0, 1, 0), 12)
            h.cyl(head, f'Compensator port glow_{z}_{side}', (0.665, -0.055 + side * 0.038, z), 0.008, 0.01, 'orange', (0, 1, 0), 8)
        # Recoil hydraulic dampener cylinder above/beside barrel
        h.cyl(head, f'Barrel recoil damper_{z}', (0.34, 0.015, z), 0.018, 0.22, 'steel', (1, 0, 0), 16)

    # -------------------------------------------------------------------------
    # CYCLOPS TARGETING OPTICS SUITE
    # Primary ocular targeting eye + auxiliary rangefinder laser
    # -------------------------------------------------------------------------
    # Primary cyclops optic on forward brow
    b2.optic(head, (0.22, 0.12, 0.665), 0.055, 'orange', axis=(1, 0, 0))
    # Armored optic protective hood / brow cowl
    h.box(head, 'Optic protective hood', (0.20, 0.12, 0.725), (0.12, 0.14, 0.04), 'ceramic', rot=(0, -0.15, 0), bevel=0.008)
    # Secondary auxiliary tactical laser / rangefinder (violet optic)
    b2.optic(head, (0.235, 0.02, 0.685), 0.028, 'violet', axis=(1, 0, 0))

    # -------------------------------------------------------------------------
    # AMMUNITION POD & POWER SYSTEM (Starboard Side: Y ≈ +0.33)
    # -------------------------------------------------------------------------
    pod = h.box(head, 'Side ammunition pod', (-0.01, 0.33, 0.57), (0.32, 0.18, 0.21), 'dark', bevel=0.025)
    # Ceramic outer armor strike plate
    h.box(head, 'Pod protective outer plate', (-0.01, 0.432, 0.57), (0.26, 0.026, 0.18), 'ceramic', bevel=0.018)
    # Hexagonal service maintenance cap
    h.cyl(head, 'Pod service cap', (-0.01, 0.446, 0.57), 0.038, 0.015, 'steel', (0, 1, 0), 6)

    # 6 glowing ammo / charge status indicator cells
    for yy in [0.287, 0.365]:
        for zz in [0.515, 0.570, 0.625]:
            h.cyl(head, f'Pod status cell well_{yy}_{zz}', (0.150, yy, zz), 0.019, 0.016, 'dark', (1, 0, 0), 20)
            h.cyl(head, f'Pod status LED_{yy}_{zz}', (0.159, yy, zz), 0.010, 0.012, 'orange', (1, 0, 0), 20)

    # Heavy armored ammo feed chute / power conduit into gun breech
    h.cable(head, 'Ammunition feed conduit', [
        (0.12, 0.31, 0.54),
        (0.16, 0.22, 0.52),
        (0.10, 0.10, 0.52)
    ], r=0.022, mat='steel')

    # Quick release toggle latches
    for xx in [-0.11, 0.09]:
        h.cyl(head, f'Pod latch fastener_{xx}', (xx, 0.446, 0.635), 0.009, 0.010, 'steel', (0, 1, 0), 6)

    # -------------------------------------------------------------------------
    # AVIONICS & TELEMETRY POD (Port Side: Y ≈ -0.33)
    # Balances the silhouette with flight avionics, comms, and cooling
    # -------------------------------------------------------------------------
    h.box(head, 'Avionics module pod', (-0.02, -0.33, 0.57), (0.30, 0.16, 0.20), 'dark', bevel=0.022)
    h.box(head, 'Avionics outer plate', (-0.02, -0.422, 0.57), (0.24, 0.025, 0.16), 'ceramic', bevel=0.016)
    # Radiator cooling gills on avionics pod
    for j in range(4):
        h.box(head, f'Avionics cooling vane_{j}', (-0.10 + j * 0.055, -0.428, 0.57), (0.012, 0.018, 0.12), 'steel', bevel=0.003)
    # Telemetry sensor lens (orange status)
    b2.optic(head, (0.14, -0.33, 0.57), 0.035, 'orange', axis=(1, 0, 0))
    # Comms antenna probe extending upward
    h.cyl(head, 'Avionics antenna mast', (-0.12, -0.33, 0.72), 0.007, 0.16, 'steel', (0, 0, 1), 12)

    return p


def export_and_validate():
    b2.init()
    p = build_redesigned_sentry()
    b2.ROOTS['turret'] = p
    h.ROOTS['turret'] = p
    h.OUT = OUT
    h.PREVIEW = PREVIEW

    # Join and optimize export with clean PBR materials
    h.optimize_export('turret')
    print('REDESIGNED_TURRET_EXPORTED_OK')

    # Render sheet view (upright isometric)
    b2.render_sheet_view('turret')
    print('REDESIGNED_TURRET_RENDERED_OK')


if __name__ == '__main__':
    export_and_validate()
