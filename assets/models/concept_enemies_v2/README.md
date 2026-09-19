# Concept sheet rebuild, version 2

This library replaces the first reference-inspired pass in the four active enemy scenes. It was rebuilt directly in Blender through MCP, using the supplied four-panel concept sheet as the primary design reference.

## Shape corrections

- **Crawler:** compound curved carapace shells with inset red seams; scalloped shoulder cowls; smoothly swept upper-leg shields, tapered shins, articulated bearings, curved claws and mandibular blades; sloping skull with inset optics.
- **Turret:** sloped circular bolted foundation; compact chamfered receiver; elevation bearing and hoses; vertically stacked cannons with Boolean-cut shroud perforations; recessed cooling ports; side pod with six orange indicators.
- **Gunship:** tapered fuselage and pale layered nose, recessed forward viewport, raised violet command visor, short swept wings, shaped nacelle caps, rear turbine bells and underslung cannons.
- **Boss:** broad chamfered chassis with stepped overlapping armor; central top reactor with concentric containment; rear crown; layered side shields; twin stacked cannon pairs, forward armor mandibles, heat exchangers and underside hover drives.

Each GLB faces +X in Godot and uses its own origin. The editable `concept_enemy_workbench_v2.blend` spaces the four models along Blender Y for review. Workbench offsets are not included in the exported models.

PBR materials include restrained 1024px albedo wear and tangent-space micro-normal textures, machined metal, pale armor, dark mechanisms, and red/orange/violet emitters. Static geometry is consolidated per material within movable groups; four crawler legs and the turret head remain separate. There are no baked presentation animations in these exports: the existing visual controller reads the live combat state to drive articulation and recoil.

The existing enemy collision shapes, movement scripts, attack timing and damage values are retained. Muzzle and light markers were repositioned to the new geometry. The upper boss cannon pair supplies the existing two projectile origins; the model retains the concept's additional lower barrels.

Authoring source: `tools/build_concept_enemies_v2.py`. In Blender MCP, import the module, call `init()`, then `build(kind)` and `render_sheet_view(kind)` for crawler, turret, gunship and boss; finish with `save()`. Start in a fresh scene or remove the previous generated V2 objects before regenerating to avoid suffixed articulation names.

Validation: `tools/verify_reference_enemy_assets.gd`; renderer QA: `tools/reference_enemy_gallery.tscn`. Actual renders and the reference/model comparison are saved under `tools/blender_previews/concept_enemies_v2/`.
