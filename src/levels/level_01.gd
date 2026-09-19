extends "res://src/levels/campaign_level.gd"

func _ready() -> void:
	if not GameManager.retry_pending:
		GameManager.reset_game()
	# Keep the original docking encounters; move their arena to the new finale.
	for group_name in ["Platforms", "Props", "Hazards", "Pickups", "Enemies", "BackgroundDecor"]:
		for child in get_node(group_name).get_children():
			if child is Node3D and child.position.x >= 96:
				child.position.x += 128
	_route(96, 220, 0)
	_platform("FinalDeck250", Vector3(250, 0, 0))
	_platform("FinalDeck254", Vector3(254, 0, 0))
	populate_encounters(104, 216)
	
	# --- Secret Cache: High-ground reward on the uniform upper supply deck (reached via lift) ---
	var cache_scene: PackedScene = preload("res://src/environment/secret_cache.tscn")
	_spawn(cache_scene, props, Vector3(125.5, 6.3, 0))

	# Pre-boss supply staging area & in-arena pickups
	_spawn(preload("res://src/environment/prop_terminal.tscn"), props, Vector3(220, 0, 0))
	_spawn(preload("res://src/environment/prop_crate.tscn"), props, Vector3(222, 0, 0))
	_spawn(PICKUP, pickups, Vector3(221, 1.2, 0), {"pickup_type": 2, "weapon_to_unlock": 3})
	_spawn(PICKUP, pickups, Vector3(232, 1.2, 0), {"pickup_type": 0}) # Health Core in arena
	_spawn(PICKUP, pickups, Vector3(246, 1.2, 0), {"pickup_type": 1}) # Shield Core in arena
	_spawn(preload("res://src/environment/prop_crate.tscn"), props, Vector3(238, 0, 0)) # Mid-arena crate

	setup_mission(1, 224, 256, [76.0, 164.0])
