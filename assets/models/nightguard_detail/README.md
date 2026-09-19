# Nightguard detail pass

Reference: `/home/clau/Downloads/game2.jpeg` (Nightguard unit technical sheet).

Built and exported through the connected Blender MCP session. This is a reference-guided refinement of the existing animated character, rather than an exact reconstruction of the illustrated character.

- Shared Enforcer/Scout body: neutral worn steel albedo, layered chest and shoulder armor, forearm service covers, thigh and shin plates, articulated knee covers, toe caps, utility pouches, helmet comms receivers, dark visor, and amber targeting optic.
- Enemy-only pulse rifle: layered receiver, adjustable stock, molded grip, power magazine with charge indicators, cooling rings, vented shroud, accessory rail, optic, recessed muzzle, and fasteners. Includes a `Muzzle` marker and uses the original weapon mounting axes and grip origin.
- Scout backpack: twin armored fuel cells, retaining clamps, braided feed lines, coolant tubing, service panel, cooling louvers, harness pivots, heat exchanger rings, and open nozzle lips. Existing attachment and exhaust origins are retained.
- Exhaust: blue outer ion plume and bright blue-white inner core; the runtime thrust light matches the reference.

The original skeleton and Idle/Walk/Run clips are retained. Added armor is rigidly weighted to the matching original bones and combined by material. Enemy visual yaw follows travel/firing facing. The enemy rifle pose adds support-hand IK and a closed-finger grip; the player's default aiming settings are unchanged. Health, movement values, attack timing, damage, score, collisions, and pickup chance retain their values from the working baseline.

Editable sources: `nightguard_armored.blend`, `nightguard_rifle.blend`, `scout_jetpack.blend`, `scout_ion_flame.blend`. All authoring textures are packed. The `source/` folder holds pre-pass GLB backups and is excluded from Godot import.

Rebuild through Blender MCP by importing `tools/build_nightguard_detail.py`. Call `init_character()` and `character()` in separate MCP calls (opening a blend resets Blender's UI context). Then call `jetpack()`, `rifle()`, and `flames()` as individual stages. `render_character()` captures a Blender close-up immediately after `character()`.

Godot gallery: `res://tools/nightguard_detail_gallery.tscn`. Checks animation and aim bindings, aiming left, right, diagonally, straight up, and straight down during movement, muzzle transforms, and level resources. Captures front, side, and back views of both units under `tools/blender_previews/nightguard_detail/`. Compatibility rendering is used for the gallery on this machine; the project's Forward+ setting is retained.

Geometry: character 30,060 triangles / 8 skinned meshes; backpack 29,064 triangles / 5 meshes; rifle 14,160 triangles / 6 meshes. Surface detail is separated across ceramic, gunmetal, exposed steel, flexible seals, smoked glass, and emissive optics. Added metal surfaces use 512px albedo and roughness maps; the source character's wear detail remains in its original UV layout.

Validation: Godot import succeeded and the combat QA harness reported `QA DRIVE OK`. Gallery hand-reach checks allow at most 5cm of error in the specified aiming poses, preventing stretched limbs. Existing quit-time ObjectDB and Compatibility renderer texture warnings can still appear.
