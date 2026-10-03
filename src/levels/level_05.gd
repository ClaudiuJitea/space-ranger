extends "res://src/levels/campaign_level.gd"

func _ready() -> void:
	mission_index = 5
	# Eclipse sanctuary: orbital terraces lead to the final singularity chamber.
	_platform("Arrival", Vector3(-4, 0, 0))
	_route(0, 352, 4)
	for x in range(356, 401, 4):
		_platform("SovereignArena_%d" % x, Vector3(x, 0, 0))
	for x in [364, 392]:
		_platform("OrbitPerch_%d" % x, Vector3(x, 3.5, 0), false)
	populate_encounters(16, 344)
	setup_mission(5, 356, 400, [80.0, 192.0, 304.0])
