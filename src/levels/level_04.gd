extends "res://src/levels/campaign_level.gd"

func _ready() -> void:
	mission_index = 4
	# Frostworks: undulating coolant decks, optional elevator rewards, manta arena.
	_platform("Arrival", Vector3(-4, 0, 0))
	_route(0, 320, 3)
	for x in range(324, 369, 4):
		_platform("LeviathanArena_%d" % x, Vector3(x, 0, 0))
	for x in [332, 360]:
		_platform("SiegeCover_%d" % x, Vector3(x, 3, 0), false)
	populate_encounters(16, 312)
	_spawn(PICKUP, pickups, Vector3(24, _floor_at(24) + 1.3, 0), {"pickup_type": 2, "weapon_to_unlock": 3})
	setup_mission(4, 324, 368, [72.0, 184.0, 280.0])
