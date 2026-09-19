extends CharacterBody3D

## NIGHTGUARD Enforcer — armored humanoid rifleman. Advances between cover,
## holds a readable firing distance and telegraphs controlled three-shot bursts.

@export var max_health := 95.0
@export var move_speed := 3.1
@export var attack_range := 15.0
@export var preferred_range := 7.0
@export var burst_delay := 0.14
@export var burst_cooldown := 1.65
@export var score_value := 300

var health := 95.0
var player_ref: Node3D
var facing := -1.0
var burst_left := 0
var fire_timer := 0.7
var last_velocity_x := 0.0
var idle_phase := 0.0
var hit_flash := 0.0
var projectile_scene := preload("res://src/projectiles/enemy_projectile.tscn")

@onready var visual: Node3D = $Visual
@onready var optic: OmniLight3D = $Visual/OpticLight
@onready var animator = $ModelAnimation

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	fire_timer = randf_range(0.45, burst_cooldown)

func _physics_process(delta: float) -> void:
	if global_position.y < -14.0:
		queue_free()
		return
	if not is_on_floor():
		velocity.y -= 30.0 * delta
	if not player_ref or not is_instance_valid(player_ref):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0]

	if player_ref and is_instance_valid(player_ref) and GameManager.health > 0.0:
		var offset := player_ref.global_position - global_position
		offset.z = 0.0
		var distance := offset.length()
		facing = signf(offset.x) if absf(offset.x) > 0.1 else facing
		var desired_speed := 0.0
		if distance < attack_range:
			if distance > preferred_range + 1.5 and not _edge_ahead(facing):
				desired_speed = facing * move_speed
			elif distance < preferred_range - 1.5 and not _edge_ahead(-facing):
				desired_speed = -facing * move_speed * 0.7
			_process_weapon(delta, offset.normalized())
		else:
			desired_speed = facing * move_speed * 0.55 if not _edge_ahead(facing) else 0.0
		velocity.x = move_toward(velocity.x, desired_speed, (7.0 if absf(desired_speed) > 0.01 else 10.0) * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)

	move_and_slide()
	global_position.z = 0.0
	_update_presentation(delta)

func _process_weapon(delta: float, aim_direction: Vector3) -> void:
	fire_timer -= delta
	if fire_timer > 0.0:
		return
	if burst_left <= 0:
		burst_left = 3
		fire_timer = 0.22
		optic.light_energy = 0.4
		SoundManager.play("alarm", 1.65, -12.0)
		return
	_fire(aim_direction)
	burst_left -= 1
	fire_timer = burst_delay if burst_left > 0 else burst_cooldown + randf_range(-0.15, 0.2)

func _fire(direction: Vector3) -> void:
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	var shot_origin: Vector3 = animator.get_muzzle_position()
	projectile.global_position = shot_origin
	projectile.global_position.z = 0.0
	projectile.init_projectile(direction, 20.0, 14.0, Color(0.78, 0.83, 0.76), true, false)
	FXManager.spawn_muzzle_flash(shot_origin, direction, Color(0.78, 0.83, 0.76))
	SoundManager.play("enemy_laser", randf_range(0.86, 0.96), -5.0)
	if animator:
		animator.play_clip("attack")

func _edge_ahead(direction: float) -> bool:
	if not is_on_floor():
		return false
	var from := global_position + Vector3(direction * 0.55, 0.15, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.75, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _update_presentation(delta: float) -> void:
	visual.scale.x = 1.0
	visual.rotation.y = -PI * 0.5 * facing
	idle_phase += delta * 1.8
	var acceleration := (velocity.x - last_velocity_x) / maxf(delta, 0.001)
	last_velocity_x = velocity.x
	# The authored walk/run clips carry the footfalls; keep the root settled.
	var idle_weight := 1.0 - clampf(absf(velocity.x) / 0.9, 0.0, 1.0)
	var breathing := sin(idle_phase) * 0.009 * idle_weight
	visual.position.y = lerpf(visual.position.y, breathing, 8.0 * delta)
	var body_lean := clampf(-velocity.x * 0.014 - acceleration * 0.004, -0.085, 0.085)
	body_lean += sin(idle_phase * 0.55) * 0.012 * idle_weight
	visual.rotation.z = lerpf(visual.rotation.z, body_lean, 6.0 * delta)
	var aim := Vector3(facing, 0.0, 0.0)
	if player_ref and is_instance_valid(player_ref):
		aim = player_ref.global_position + Vector3.UP * 1.1 - global_position - Vector3.UP * 1.35
		aim.z = 0.0
	animator.update_visual(absf(velocity.x), aim, not is_on_floor())
	optic.light_energy = lerpf(optic.light_energy, 0.05, 5.5 * delta)
	if hit_flash > 0.0:
		hit_flash -= delta

func take_damage(amount: float) -> void:
	health -= amount
	hit_flash = 0.1
	SoundManager.play("hit", 1.0, 0.0)
	FXManager.spawn_hit_spark(global_position + Vector3(0, 1.25, 0), Color(0.8, 0.85, 0.78))
	FXManager.spawn_enemy_hitmarker(global_position + Vector3(0, 1.25, 0))
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.06, 1.06, 1.06), 0.045)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.07)
	if health <= 0.0:
		_die()

func _die() -> void:
	GameManager.add_score(score_value)
	SoundManager.play("explosion", 0.88, 1.0)
	FXManager.spawn_explosion(global_position + Vector3(0, 1.0, 0), 0.85, Color(0.72, 0.78, 0.73))
	queue_free()
