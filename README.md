# Space Ranger: Eclipse Protocol

A fast-paced, modern 2.5D side-scrolling space shooter platformer built in **Godot 4.7 Forward+** with 3D assets crafted and exported directly using **Blender MCP**.

---

## 🚀 Features

- **Sleek Cyber-Sci-Fi Aesthetic**:
  - High-contrast Forward+ rendering with ACES tone mapping, real-time Bloom & Glow, and dynamic PBR lighting.
  - Deep parallax starfield with celestial nebulas and tumbling 3D asteroids.
  - Dark carbon hulls, brushed titanium accents, and glowing cyan/amber/crimson emissive conduits.

- **Fast, Punchy 2.5D Platformer Shooter Combat**:
  - **Full 360° Mouse Aiming**: Aim and shoot smoothly in any direction while jumping or running.
  - **Double Jump / Thruster Boost**: High-tech jetpack thruster bursts for vertical traversal.
  - **Evasive Dash**: High-speed thruster slide with invulnerability window to dodge enemy bullet hell patterns.
  - **Shield & Hull Regeneration**: Dynamic energy shield absorbs damage first, regenerating after a cooldown.

- **Modular Weapon Arsenal**:
  - **1. Pulse Blaster**: Rapid-fire sleek cyan plasma bolts with crisp recoil.
  - **2. Plasma Scatter**: 5-way wide fan spread for close-to-mid-range swarm clearing.
  - **3. Photon Railgun**: Heavy hyper-velocity beam that pierces through lines of enemies with camera shake.

- **Challenging Enemy Roster & Boss Encounter**:
  - **Recon Drone (Stalker)**: Agile aerial drones that hover with sine wave oscillation and track the player with red optic sensors.
  - **Heavy Sentinel Gunship**: Armored flying patrol gunship with alternating twin plasma cannons.
  - **Automated Swivel Turret**: Wall/ceiling/floor mounted robotic turrets with 2.5D tracking and rapid 3-round bursts.
  - **Hazard Laser Pylons**: Pulsing vertical laser barriers blocking corridors.
  - **Apex Dreadnought Core (Boss Encounter)**: Giant mechanized boss with multi-phase attacks:
    - Phase 1: Heavy twin cannons & radial missile fans.
    - Phase 2 (Enraged < 50% HP): Overclocked fire rate, staggered barrages, and drone reinforcements.
    - Cinematic multi-explosion death sequence.

- **Procedural Audio Synthesizer**:
  - Built-in GDScript `SoundManager` utilizing `AudioStreamWAV` buffers.
  - Generates authentic 16-bit retro-futuristic sound effects (lasers, beams, explosions, shield pings, thrusters, pickups) with 0 external dependencies!

- **Sleek Modern Glassmorphic HUD**:
  - Real-time animated health & shield gauges.
  - Dynamic score counter with combo multiplier badges (`x2`, `x3`, etc.).
  - Weapon selector interface with active weapon highlight.
  - Boss health bar with flashing warning states.
  - Tactical Pause Menu and Game Over / Victory redeployment screens.

---

## 🎮 Controls

| Action | Primary Key / Input | Secondary Key |
|---|---|---|
| **Move Left / Right** | `A` / `D` | `←` / `→` |
| **Jump / Thruster Double Jump** | `Space` | `W` / `↑` |
| **Evasive Dash** | `Shift` | Right Mouse Button |
| **Aim** | Mouse Cursor | 360° Cursor Tracking |
| **Fire Blaster** | Left Mouse Button | `J` |
| **Weapon 1 (Pulse Blaster)** | `1` | |
| **Weapon 2 (Plasma Scatter)** | `2` | |
| **Weapon 3 (Photon Railgun)** | `3` | |
| **Pause / Tactical Standby** | `Esc` | `P` |

---

## 🎨 3D Assets Created via Blender MCP

All 3D assets were created procedurally and exported to `.glb` format using the connected **Blender 5.2.1 LTS** via the Blender MCP server:

1. **`player.glb`**: Armored space ranger cyber-suit featuring curved aerodynamic cyan visor, chest reactor, shoulder pauldrons, jetpack thrusters, and integrated plasma rifle.
2. **`drone.glb`**: Triangular aerodynamic chassis with swept wings, glowing crimson optic eye, and underslung laser cannon.
3. **`gunship.glb`**: Heavy armored gunship fuselage with dual rotary plasma pods and twin glowing engine exhausts.
4. **`turret.glb`**: Beveled base plate with rotating swivel hemisphere and dual over-and-under laser barrels.
5. **`boss.glb`**: Apex Dreadnought Core featuring octagonal armored hull, glowing core reactor, upper missile pods, dual heavy cannons, and quad thrusters.
6. **`platform_straight.glb`**: Catwalk platform deck with anti-slip carbon grating, brushed steel brackets, and glowing neon cyan hazard trim.
7. **`platform_pillar.glb`**: Structural background space station support column with vertical glowing energy conduit.
8. **`hazard_pylon.glb`**: Industrial emitter base and post with dual prongs and glowing laser focus sphere.
9. **`pickup_energy.glb`**: Gold diamond crystal with orbiting glowing cyan ring.
10. **`pickup_shield.glb`**: Blue glowing cylindrical energy cell with containment rings.
11. **`pickup_weapon.glb`**: High-tech ordnance module with glowing orange crosshair glyph.
12. **`prop_crate.glb`**: Armored sci-fi container with reinforced corner brackets and indicator light.
13. **`prop_terminal.glb`**: Interactive sleek computer terminal with angled glowing holographic console.

---

## 🛠️ Project Structure

```
space-ranger/
├── assets/
│   └── models/               # 3D GLB assets generated via Blender MCP
│       ├── player.glb
│       ├── drone.glb
│       ├── gunship.glb
│       ├── turret.glb
│       ├── boss.glb
│       ├── platform_straight.glb
│       ├── platform_pillar.glb
│       ├── hazard_pylon.glb
│       ├── pickup_energy.glb
│       ├── pickup_shield.glb
│       ├── pickup_weapon.glb
│       ├── prop_crate.glb
│       └── prop_terminal.glb
├── src/
│   ├── autoload/             # Global managers
│   │   ├── game_manager.gd   # Health, shields, score, weapons, boss states
│   │   ├── sound_manager.gd  # Procedural sound effect synthesizer
│   │   └── fx_manager.gd     # Screen shake, particle bursts, hit sparks
│   ├── entities/
│   │   ├── player/           # Space Ranger CharacterBody3D
│   │   ├── enemies/          # Drones, Gunships, Turrets, Boss
│   │   └── pickups/          # Energy, Shield, Weapon upgrades
│   ├── environment/          # Modular platforms, hazard lasers, 3D backdrop
│   ├── projectiles/          # Pulse, Scatter, Railgun beam, Enemy lasers
│   ├── ui/                   # Modern glassmorphic HUD & Pause Menu
│   └── levels/               # Level 01: Orbital Dreadnought Astra-09
└── project.godot
```

---

## 🏃 Running the Game

To launch the game directly from terminal:
```bash
/home/clau/Godot/Godot_v4.7.2-stable_linux.x86_64 res://src/levels/level_01.tscn
```
Or open the project folder in the Godot Editor and press **F5** (Play Project).
