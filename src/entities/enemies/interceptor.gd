extends CharacterBody3D

## Wasp machine drone: strafes above the ranger, warns, then fires a two-shot burst.
const BOLT := preload("res://src/projectiles/enemy_projectile.tscn")
@export var max_health := 65.0
var health := 65.0
var is_dead := false
var timer := 1.6
var charge := 0.0
var age := 0.0
var player_ref: Node3D
var rotors: Array[Node3D] = []
@onready var visual: Node3D = $Visual
@onready var light: OmniLight3D = $Visual/EyeLight

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	for side in [-1, 1]:
		var rotor := $Visual/Model.find_child("Rotor%s*" % side, true, false) as Node3D
		if rotor: rotors.append(rotor)

func _physics_process(delta: float) -> void:
	age += delta
	for rotor in rotors: rotor.rotation.y += delta * 24
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player_ref) or GameManager.health <= 0:
		return
	var target := player_ref.global_position + Vector3(cos(age * 0.7) * 6, 3.5 + sin(age) * 0.5, 0)
	velocity = velocity.move_toward((target - global_position).limit_length(4.5), delta * 6)
	move_and_slide()
	global_position.z = 0
	visual.rotation.z = lerpf(visual.rotation.z, -velocity.x * 0.04, delta * 4)
	visual.scale.x = 1 if player_ref.global_position.x > global_position.x else -1
	if global_position.distance_to(player_ref.global_position) > 17:
		return
	timer -= delta
	if timer > 0: return
	if charge == 0: SoundManager.play("alarm", 1.8, -12)
	charge += delta
	light.light_energy = 1 + charge * 4
	if charge < 0.6: return
	var socket := $Visual/Model.find_child("Muzzle*", true, false) as Node3D
	var origin := socket.global_position if socket else global_position
	origin.z = 0
	var heading := (player_ref.global_position + Vector3.UP - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, player_ref.global_position + Vector3.UP, 1)
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		for angle in [-0.08, 0.08]:
			var bolt := BOLT.instantiate()
			get_parent().add_child(bolt)
			bolt.global_position = origin
			bolt.init_projectile(heading.rotated(Vector3.BACK, angle), 13.0, 9.0, Color(0.08, 0.75, 1), true, false)
		FXManager.spawn_muzzle_flash(origin, heading, Color(0.08, 0.75, 1))
		SoundManager.play("wasp_fire", 1.4, -6)
	timer = 2.2
	charge = 0
	light.light_energy = 0.6

func take_damage(amount: float) -> void:
	if is_dead: return
	health -= amount
	FXManager.spawn_hit_spark(global_position, Color(1, 0.7, 0.2))
	FXManager.spawn_enemy_hitmarker(global_position)
	if health <= 0:
		is_dead = true
		GameManager.add_score(250)
		FXManager.spawn_explosion(global_position, 0.85, Color(0.1, 0.8, 1))
		SoundManager.play("explosion", 1.3, -3)
		queue_free()
