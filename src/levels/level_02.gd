extends "res://src/levels/campaign_level.gd"

func _ready() -> void:
	mission_index = 2
	# Original reactor ascent, followed by a new cooling tower and crown approach.
	var route := [Vector3(-2, 0, 0), Vector3(2, 0, 0), Vector3(6, 0, 0), Vector3(10, 0, 0),
		Vector3(16, 2.5, 0), Vector3(22, 5, 0), Vector3(28, 2, 0), Vector3(34, -0.5, 0),
		Vector3(38, -0.5, 0), Vector3(44, 3, 0), Vector3(50, 6, 0), Vector3(56, 8.5, 0),
		Vector3(62, 5, 0), Vector3(68, 1.5, 0), Vector3(72, 1.5, 0), Vector3(78, 4.5, 0),
		Vector3(84, 7.5, 0), Vector3(90, 4, 0), Vector3(96, 0, 0), Vector3(100, 0, 0),
		Vector3(106, 3, 0), Vector3(112, 3, 0)]
	for i in route.size():
		_platform("ReactorAscent_%02d" % i, route[i])
	_route(116, 256, 1)
	for x in range(264, 289, 4):
		_platform("WardenArena_%d" % x, Vector3(x, 0, 0))
	_platform("WardenPerchL", Vector3(264, 3.5, 0))
	_platform("WardenPerchR", Vector3(288, 3.5, 0))
	populate_encounters(12, 252)
	_spawn(PICKUP, pickups, Vector3(22, 6.2, 0), {"pickup_type": 2, "weapon_to_unlock": 2})
	_spawn(PICKUP, pickups, Vector3(148, _floor_at(148) + 1.2, 0), {"pickup_type": 2, "weapon_to_unlock": 3})
	setup_mission(2, 260, 288, [78.0, 196.0])
