extends "res://src/entities/enemies/crawler.gd"

## Cerberus K-9 combines the crawler's readable lunge with a charged rail shot.
const BOLT := preload("res://src/projectiles/enemy_projectile.tscn")
var rail_timer := 2.8
var rail_charge := 0.0
var gait := 0.0
var legs: Array[Node3D] = []
var weapon: Node3D
var muzzle: Node3D

func _ready() -> void:
	super._ready()
	for pattern in ["Front_near*", "Rear_far*", "Front_far*", "Rear_near*"]:
		var leg := $Visual/Model.find_child(pattern, true, false) as Node3D
		if leg: legs.append(leg)
	weapon = $Visual/Model.find_child("WeaponMount*", true, false)
	muzzle = $Visual/Model.find_child("Muzzle*", true, false)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	gait += delta * absf(velocity.x) * 3.2
	for i in legs.size():
		legs[i].rotation.z = sin(gait + (0 if i < 2 else PI)) * minf(absf(velocity.x) * 0.08, 0.38)
	if not is_instance_valid(player_ref) or GameManager.health <= 0:
		return
	var diff := player_ref.global_position + Vector3.UP - global_position - Vector3.UP * 1.2
	if weapon:
		weapon.rotation.z = clampf(atan2(diff.y, absf(diff.x)), -0.6, 0.6)
	if state == State.WINDUP or state == State.LUNGE:
		rail_charge = 0
		return
	rail_timer -= delta
	if rail_timer > 0 or absf(diff.x) < 3 or absf(diff.x) > 13:
		return
	# Charge light and sound give the player a dodge window.
	if rail_charge == 0:
		SoundManager.play("alarm", 1.6, -10)
	rail_charge += delta
	eye_light.light_energy = 2 + rail_charge * 5
	if rail_charge < 0.7:
		return
	var origin := muzzle.global_position if muzzle else global_position + Vector3.UP * 1.2
	origin.z = 0
	var direction := (player_ref.global_position + Vector3.UP - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, player_ref.global_position + Vector3.UP, 1)
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		var bolt := BOLT.instantiate()
		get_parent().add_child(bolt)
		bolt.global_position = origin
		bolt.init_projectile(direction, 19.0, 12.0, Color(1, 0.25, 0.08), true, false)
		FXManager.spawn_muzzle_flash(origin, direction, Color(1, 0.25, 0.08))
		SoundManager.play("hound_fire", 0.9, -5)
	rail_timer = 3.2
	rail_charge = 0
	eye_light.light_energy = 1.6
