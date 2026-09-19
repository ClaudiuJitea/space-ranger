extends CharacterBody3D

@export var max_health: float = 50.0
@export var speed: float = 5.5
@export var attack_range: float = 14.0
@export var min_distance: float = 5.0
@export var fire_interval: float = 1.6
@export var score_value: int = 150

var health: float
var fire_timer: float = 0.0
var hover_timer: float = 0.0
var flight_side := 0.0
var facing_dir := 1.0
var player_ref: Node3D = null

var proj_scene: PackedScene = preload("res://src/projectiles/enemy_projectile.tscn")
var pickup_energy_scene: PackedScene = preload("res://src/entities/pickups/pickup.tscn")

@onready var visual: Node3D = $Visual
@onready var animator = $ModelAnimation
@onready var left_flame: Node3D = $Visual/LeftJetFlame
@onready var right_flame: Node3D = $Visual/RightJetFlame
@onready var jet_heat: OmniLight3D = $Visual/JetHeatLight

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	fire_timer = randf_range(0.5, fire_interval)
	hover_timer = randf() * TAU

func _physics_process(delta: float) -> void:
	hover_timer += delta * 3.0
	var previous_velocity := velocity

	if not player_ref:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	if player_ref and is_instance_valid(player_ref) and GameManager.health > 0:
		var diff := player_ref.global_position - global_position
		diff.z = 0.0
		var dist := diff.length()

		# Adapt flight side dynamically when player moves well past
		if flight_side == 0.0 or (absf(diff.x) > min_distance * 1.5 and signf(diff.x) == flight_side):
			flight_side = -signf(diff.x) if absf(diff.x) > 0.15 else -1.0
		elif dist < min_distance * 0.55 and absf(diff.x) > 0.4:
			flight_side = -signf(diff.x)

		# Multi-harmonic organic aerial orbit
		var hover_y := sin(hover_timer * 0.5) * 0.36 + sin(hover_timer * 1.15) * 0.12
		var hover_x := cos(hover_timer * 0.42) * 0.45
		var target_pos := player_ref.global_position + Vector3(flight_side * min_distance + hover_x, 2.1 + hover_y, 0.0)
		var to_target := target_pos - global_position
		to_target.z = 0.0

		var desired_velocity := to_target * 1.8
		if desired_velocity.length() > speed:
			desired_velocity = desired_velocity.normalized() * speed
		velocity = velocity.move_toward(desired_velocity, 8.5 * delta)

		# Hysteresis facing to prevent rapid flipping
		if absf(diff.x) > 0.75:
			var desired_facing := 1.0 if diff.x > 0.0 else -1.0
			if desired_facing != facing_dir:
				facing_dir = desired_facing
		visual.scale.x = 0.82

		if dist < attack_range:
			fire_timer -= delta
			if fire_timer <= 0.0:
				_fire_at_player(diff.normalized())
				fire_timer = fire_interval + randf_range(-0.2, 0.2)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, 5.0 * delta)

	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0

	var flight_accel := (velocity - previous_velocity) / maxf(delta, 0.001)

	# Natural body posture: organic hover bobbing + bank/pitch into thrust acceleration
	visual.position.y = sin(hover_timer * 0.6) * 0.035 + sin(hover_timer * 1.2) * 0.012
	var target_bank := clampf(-velocity.x * 0.030 - flight_accel.x * 0.010, -0.26, 0.26)
	var target_pitch := clampf(-velocity.y * 0.022 - flight_accel.y * 0.008, -0.14, 0.14)
	visual.rotation.z = lerpf(visual.rotation.z, target_bank, 5.5 * delta)
	visual.rotation.x = lerpf(visual.rotation.x, target_pitch, 4.8 * delta)
	visual.rotation.y = -PI * 0.5 * facing_dir + sin(hover_timer * 0.35) * 0.025

	# Jetpack exhaust flames and thrust light response
	var left_flicker := sin(hover_timer * 5.7) * 0.13 + sin(hover_timer * 11.2) * 0.045
	var right_flicker := sin(hover_timer * 5.7 + 1.4) * 0.13 + sin(hover_timer * 10.3) * 0.045
	var thrust_boost := clampf(flight_accel.length() * 0.022, 0.0, 0.45)
	var thrust_length := 0.96 + thrust_boost + clampf(absf(velocity.y) * 0.022, 0.0, 0.14)
	left_flame.scale = Vector3(1.0, thrust_length + left_flicker, 1.0)
	right_flame.scale = Vector3(1.0, thrust_length + right_flicker, 1.0)
	jet_heat.light_energy = 0.52 + thrust_boost * 0.5 + (left_flicker + right_flicker) * 0.22

	var aim := Vector3(facing_dir, 0.0, 0.0)
	if player_ref and is_instance_valid(player_ref):
		aim = player_ref.global_position + Vector3.UP * 1.1 - global_position - Vector3.UP * 1.2
		aim.z = 0.0

	# Pass full kinematics to the visual animator and the physical leg solver
	animator.update_visual(velocity.length(), aim, true, velocity, flight_accel, visual.rotation)

func _fire_at_player(dir: Vector3) -> void:
	if not proj_scene:
		return
	var spawn_pos: Vector3 = animator.get_muzzle_position()
	spawn_pos.z = 0.0
	var p = proj_scene.instantiate()
	get_parent().add_child(p)
	p.global_position = spawn_pos
	p.init_projectile(dir, 16.0, 15.0, Color(0.78, 0.84, 0.77), true, false)
	FXManager.spawn_muzzle_flash(spawn_pos, dir, Color(0.78, 0.84, 0.77))
	SoundManager.play("enemy_laser", 1.1, -3.0)

	# Firing recoil shove in zero-ground flight: torso kicks back, legs swing forward
	velocity -= dir * 0.75
	animator.kick_weapon()
	animator.apply_leg_impulse(-dir * 2.8)

func take_damage(amount: float) -> void:
	health -= amount
	SoundManager.play("hit", 1.2, 0.0)
	FXManager.spawn_hit_spark(global_position, Color(1.0, 0.8, 0.2))

	# Midair knockback reaction: hit impulse displaces body and kicks hanging legs
	var knockback_dir := Vector3.UP
	if player_ref and is_instance_valid(player_ref):
		knockback_dir = (global_position - player_ref.global_position).normalized()
	knockback_dir.z = 0.0
	velocity += knockback_dir * clampf(amount * 0.06, 0.8, 3.2)
	animator.apply_leg_impulse(knockback_dir * 4.2)

	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(visual.scale.x * 1.08, 0.9, 0.9), 0.06)
	tween.tween_property(visual, "scale", Vector3(visual.scale.x, 0.82, 0.82), 0.06)

	if health <= 0.0:
		_die()

func _die() -> void:
	GameManager.add_score(score_value)
	SoundManager.play("explosion", 1.2, 2.0)
	FXManager.spawn_explosion(global_position, 0.8, Color(1.0, 0.3, 0.1))

	if randf() < 0.45:
		var pickup = pickup_energy_scene.instantiate()
		# Parent is the level root (identity transform), so position == global.
		pickup.position = global_position
		get_parent().call_deferred("add_child", pickup)

	queue_free()
