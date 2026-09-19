HV-4 Havoc flight model

Authored through Blender MCP; editable source: hv4_havoc_missile.blend.
Runtime export: hv4_havoc_missile.glb (one mesh, seven material groups, 4,496 triangles).

Godot coordinates: metres, forward -Z; nose socket Z=-0.445,
exhaust socket Z=+0.326. Godot attaches its animated exhaust to ExhaustSocket.
Collision, flight, damage and blast radius stay in rocket_projectile.tscn/gd.

Rebuild in a fresh Blender session:
  blender --background --python tools/build_havoc_missile.py

Preview and validate the model, nozzle alignment and live firing:
  /home/clau/Godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/havoc_missile_preview.tscn

Screenshots: /tmp/havoc-missile-detail.png and /tmp/havoc-missile-ingame.png.
