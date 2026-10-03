extends "res://src/levels/campaign_level.gd"

func _ready() -> void:
	if not GameManager.retry_pending:
		GameManager.reset_game()
	# Keep the original docking encounters; move their arena to the new finale.
	for group_name in ["Platforms", "Props", "Hazards", "Pickups", "Enemies", "BackgroundDecor"]:
		for child in get_node(group_name).get_children():
			if child is Node3D and child.position.x >= 96:
				child.position.x += 160
	_route(96, 252, 0)
	_platform("FinalDeck250", Vector3(282, 0, 0))
	_platform("FinalDeck254", Vector3(286, 0, 0))
	populate_encounters(104, 248)
	
	# Pre-boss supply staging area & in-arena pickups
	_spawn(preload("res://src/environment/prop_terminal.tscn"), props, Vector3(252, 0, 0))
	_spawn(preload("res://src/environment/prop_crate.tscn"), props, Vector3(254, 0, 0))
	_spawn(PICKUP, pickups, Vector3(253, 1.2, 0), {"pickup_type": 2, "weapon_to_unlock": 3})
	_spawn(PICKUP, pickups, Vector3(264, 1.2, 0), {"pickup_type": 0}) # Health Core in arena
	_spawn(PICKUP, pickups, Vector3(278, 1.2, 0), {"pickup_type": 1}) # Shield Core in arena
	_spawn(preload("res://src/environment/prop_crate.tscn"), props, Vector3(270, 0, 0)) # Mid-arena crate

	setup_mission(1, 256, 288, [76.0, 164.0, 232.0])
