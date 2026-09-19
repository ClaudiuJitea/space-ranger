extends "res://src/levels/campaign_level.gd"

func _ready() -> void:
	mission_index = 3
	# Broken outer ramparts, suspended bridges and the Emberfall throne arena.
	_route(0, 288, 2)
	_platform("DockingPad", Vector3(-4, 0, 0))
	for x in range(296, 329, 4):
		_platform("SeraphArena_%d" % x, Vector3(x, 0, 0))
	_platform("SeraphPerchL", Vector3(298, 3, 0), false)
	_platform("SeraphPerchR", Vector3(326, 3, 0), false)
	# Horizontal ferry routes are optional shortcuts above the broken deck.
	for x in [64, 136, 220]:
		var ferry := AnimatableBody3D.new()
		ferry.set_script(preload("res://src/environment/moving_platform.gd"))
		ferry.position = Vector3(x, _floor_at(x) + 3.8, 0)
		ferry.set("travel", Vector3(8, 0, 0))
		ferry.set("period", 6.5)
		platforms.add_child(ferry)
	populate_encounters(16, 280)
	
	# Pre-boss supply staging area
	_spawn(preload("res://src/environment/prop_terminal.tscn"), props, Vector3(287, 0, 0))
	_spawn(preload("res://src/environment/prop_crate.tscn"), props, Vector3(289, 0, 0))
	_spawn(PICKUP, pickups, Vector3(288, 1.2, 0), {"pickup_type": 2, "weapon_to_unlock": 3})

	# Tactical aerial arena support on perches
	_spawn(PICKUP, pickups, Vector3(298, 4.2, 0), {"pickup_type": 0}) # Health on Left Perch
	_spawn(PICKUP, pickups, Vector3(326, 4.2, 0), {"pickup_type": 1}) # Shield on Right Perch
	_spawn(preload("res://src/environment/prop_crate.tscn"), props, Vector3(312, 0, 0)) # Mid-arena supply crate

	setup_mission(3, 292, 328, [88.0, 176.0, 260.0])
