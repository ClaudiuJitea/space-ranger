extends CharacterBody3D

@export var move_speed: float = 11.0
@export var acceleration: float = 65.0
@export var friction: float = 55.0
@export var jump_velocity: float = 13.5
@export var double_jump_velocity: float = 11.5
@export var gravity: float = 30.0

@export var dash_speed: float = 26.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.65

# Shooting cooldowns
var fire_cooldowns: Array[float] = [0.15, 0.32, 0.75]
var fire_timer: float = 0.0

var can_double_jump: bool = false
var is_dashing: bool = false
var dash_time_left: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0

var invulnerable_timer: float = 0.0
var aim_direction: Vector3 = Vector3.RIGHT

# Preloaded projectile scenes
var proj_pulse: PackedScene = preload("res://src/projectiles/projectile.tscn")
var proj_spread: PackedScene = preload("res://src/projectiles/spread_projectile.tscn")
var proj_beam: PackedScene = preload("res://src/projectiles/beam_projectile.tscn")

@onready var visual_root: Node3D = $VisualRoot
@onready var muzzle: Marker3D = $VisualRoot/Muzzle
@onready var thruster_particles = get_node_or_null("VisualRoot/ThrusterParticles")

func _ready() -> void:
	add_to_group("player")
	GameManager.connect("player_died", _on_player_died)

func _physics_process(delta: float) -> void:
	if GameManager.health <= 0:
		return

	# Handle cooldowns
	if fire_timer > 0.0:
		fire_timer -= delta
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		visual_root.visible = fmod(invulnerable_timer, 0.1) > 0.05
	else:
		visual_root.visible = true

	# Calculate Aiming from Mouse Cursor onto Z=0 plane
	_update_aim()

	# Gravity & Grounding
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		can_double_jump = true

	# Jump & Double Jump
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			SoundManager.play("thruster", 1.2, -2.0)
		elif can_double_jump:
			velocity.y = double_jump_velocity
			can_double_jump = false
			SoundManager.play("thruster", 1.6, -1.0)
			FXManager.spawn_hit_spark(global_position + Vector3(0, -0.2, 0), Color(0.2, 0.8, 1.0))
			if thruster_particles and thruster_particles.has_method("restart"):
				thruster_particles.restart()

	# Dash mechanic
	var input_x := Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		is_dashing = true
		dash_time_left = dash_duration
		dash_cooldown_timer = dash_cooldown
		dash_direction = input_x if input_x != 0.0 else (1.0 if visual_root.scale.x > 0 else -1.0)
		SoundManager.play("dash", 1.1, 0.0)
		FXManager.shake(0.2, 0.15)
		FXManager.spawn_hit_spark(global_position, Color(0.3, 0.9, 1.0))

	if is_dashing:
		dash_time_left -= delta
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0
		if dash_time_left <= 0.0:
			is_dashing = false
	else:
		if input_x != 0.0:
			velocity.x = move_toward(velocity.x, input_x * move_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0

	# Weapon Selection Keys
	if Input.is_action_just_pressed("weapon_1"):
		GameManager.select_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"):
		GameManager.select_weapon(1)
	elif Input.is_action_just_pressed("weapon_3"):
		GameManager.select_weapon(2)

	# Firing
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0 and not is_dashing:
		_shoot()

	_update_visuals(delta, input_x)

func _update_aim() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	
	if abs(ray_dir.z) > 0.0001:
		var t := -ray_origin.z / ray_dir.z
		var world_pos := ray_origin + ray_dir * t
		var dir := (world_pos - global_position)
		dir.z = 0.0
		if dir.length_squared() > 0.1:
			aim_direction = dir.normalized()

func _update_visuals(delta: float, _input_x: float) -> void:
	var target_facing := 1.0 if aim_direction.x >= 0.0 else -1.0
	visual_root.scale.x = target_facing
	
	var target_tilt := -velocity.x * 0.02
	visual_root.rotation.z = lerpf(visual_root.rotation.z, target_tilt, 15.0 * delta)
	
	if muzzle:
		muzzle.look_at(muzzle.global_position + aim_direction, Vector3.UP)

func _shoot() -> void:
	var current_w := GameManager.current_weapon
	fire_timer = fire_cooldowns[current_w]
	var spawn_pos := muzzle.global_position if muzzle else global_position + aim_direction * 0.8
	spawn_pos.z = 0.0

	match current_w:
		0:
			var p = proj_pulse.instantiate()
			get_parent().add_child(p)
			p.global_position = spawn_pos
			p.init_projectile(aim_direction, 34.0, 25.0, Color(0.1, 0.9, 1.0), false, false)
			SoundManager.play("laser_pulse", 1.0 + randf_range(-0.05, 0.05), -2.0)
			FXManager.shake(0.1, 0.08)

		1:
			var angles := [-0.22, -0.11, 0.0, 0.11, 0.22]
			for angle in angles:
				var p = proj_spread.instantiate()
				get_parent().add_child(p)
				p.global_position = spawn_pos
				var spread_dir := aim_direction.rotated(Vector3(0, 0, 1), angle)
				p.init_projectile(spread_dir, 28.0, 16.0, Color(1.0, 0.5, 0.05), false, false)
			SoundManager.play("laser_spread", 1.0, 0.0)
			FXManager.shake(0.2, 0.12)

		2:
			var p = proj_beam.instantiate()
			get_parent().add_child(p)
			p.global_position = spawn_pos
			p.init_projectile(aim_direction, 52.0, 80.0, Color(0.3, 1.0, 0.9), false, true)
			SoundManager.play("laser_beam", 0.95, 2.0)
			FXManager.shake(0.45, 0.22)

func _on_player_died() -> void:
	FXManager.spawn_explosion(global_position, 1.8, Color(0.2, 0.8, 1.0))
	visible = false
