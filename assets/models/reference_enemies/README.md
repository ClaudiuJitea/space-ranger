# Reference enemy asset library

Four original mechanical enemy models authored in Blender through Blender MCP from the user's concept sheet and seven reference PNGs.

| Asset | Reference images | Visual identity |
|---|---|---|
| `crawler.glb` | 1.png, 6.png | Four articulated legs, hooked jaws, layered shoulder shields, red optics and dorsal blades |
| `turret.glb` | 2.png | Anchored circular footing, independent aiming receiver, brass ammo cells, orange targeting optic |
| `gunship.glb` | 3.png, 5.png | Swept wings, armored twin nacelles, recessed violet intakes, twin underslung cannons |
| `boss.glb` | 4.png, 7.png | Crown fins, exposed segmented reactor, siege cannons, armored sponsons and antigravity turbines |

All models face +X in Godot, with Y up. Scale is fitted to the current enemy scenes. The existing collision shapes and combat values are retained. Broad armor uses embedded 1024 px wear textures; machined steel, dark mechanisms, brass, hoses and colored emitters use glTF PBR materials. Geometry is combined by material within each movable group.

`reference_enemy_workbench.blend` is the editable source, with the four models spaced along Blender's Y axis for inspection. Each exported GLB is independently positioned at the origin; workbench staging offsets are not part of the game assets.

Runtime presentation lives in `src/entities/enemies/reference_enemy_visuals.gd`: crawler leg motion and windup compression, turret head articulation and recoil, gunship bank/recoil, and boss recoil. The turret model's `AimingHead` is reparented beneath the existing swivel node, keeping `AnchoredBase` stationary.

Authoring source: `tools/build_reference_enemies.py`. Import it in Blender via MCP and call `create_asset_library()` to regenerate a fresh library. Do not run twice in the same scene without removing the previous generated library, as Blender will suffix duplicate names.

Validation: `tools/verify_reference_enemy_assets.gd` checks imports, visual bindings, four crawler legs, lunge compression, anchored turret base, head parenting, cannon orientation, and both level resources. `tools/reference_enemy_gallery.tscn` captures three-quarter and side views in Godot. Rendered previews are in `tools/blender_previews/reference_enemies/`.

These are modeled interpretations of the references, with geometry and textures designed for real-time rendering; they are not image-to-3D reconstructions.
