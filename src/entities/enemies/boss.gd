extends CharacterBody3D

@export var max_health: float = 1000.0
var health: float = 1000.0
var player_ref: Node3D = null

var state_timer: float = 0.0
var attack_state: int = 0
var phase_2: bool = false
var is_dead: bool = false

var home_position: Vector3
var target_hover_pos: Vector3

var proj_scene: PackedScene = preload("res://src/projectiles/enemy_projectile.tscn")
var drone_scene: PackedScene = preload("res://src/entities/enemies/drone.tscn")

@onready var visual: Node3D = $Visual
@onready var core_light: OmniLight3D = $Visual/CoreLight
@onready var cannon_left: Marker3D = $Visual/CannonLeft
@onready var cannon_right: Marker3D = $Visual/CannonRight

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	home_position = global_position
	target_hover_pos = home_position
	GameManager.update_boss_health(health, max_health)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not player_ref:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	var t := Time.get_ticks_msec() * 0.0015
	target_hover_pos.y = home_position.y + sin(t) * 1.5
	target_hover_pos.x = home_position.x + cos(t * 0.7) * 2.5
	global_position = global_position.lerp(target_hover_pos, 2.0 * delta)
	global_position.z = 0.0

	if player_ref and is_instance_valid(player_ref):
		var dx: float = player_ref.global_position.x - global_position.x
		visual.scale.x = 1.0 if dx >= 0.0 else -1.0

	state_timer -= delta
	if state_timer <= 0.0:
		_execute_next_attack()

func _execute_next_attack() -> void:
	if not player_ref or not is_instance_valid(player_ref) or GameManager.health <= 0:
		state_timer = 2.0
		return

	var diff := (player_ref.global_position - global_position).normalized()
	diff.z = 0.0

	attack_state = (attack_state + 1) % (4 if phase_2 else 3)
	
	match attack_state:
		0:
			_fire_twin_cannon(diff)
			state_timer = 1.2 if not phase_2 else 0.8
		1:
			_fire_missile_fan(diff)
			state_timer = 1.8 if not phase_2 else 1.2
		2:
			_fire_staggered_volley(diff)
			state_timer = 2.0 if not phase_2 else 1.4
		3:
			_spawn_support_drone()
			state_timer = 3.5

func _fire_twin_cannon(dir: Vector3) -> void:
	for m: Marker3D in [cannon_left, cannon_right]:
		if m and proj_scene:
			var spawn_pos: Vector3 = m.global_position
			spawn_pos.z = 0.0
			var p = proj_scene.instantiate()
			get_parent().add_child(p)
			p.global_position = spawn_pos
			p.init_projectile(dir, 24.0, 24.0, Color(1.0, 0.2, 0.0), true, false)
	SoundManager.play("enemy_laser", 0.8, 2.0)
	FXManager.shake(0.3, 0.2)

func _fire_missile_fan(center_dir: Vector3) -> void:
	var count := 7 if phase_2 else 5
	var spread := 0.6
	var step := spread / float(count - 1)
	var start_angle := -spread * 0.5
	
	for i in range(count):
		var angle := start_angle + step * float(i)
		var fire_dir := center_dir.rotated(Vector3(0, 0, 1), angle)
		var p = proj_scene.instantiate()
		get_parent().add_child(p)
		p.global_position = global_position
		p.init_projectile(fire_dir, 18.0, 18.0, Color(1.0, 0.1, 0.1), true, false)

	SoundManager.play("laser_spread", 0.7, 3.0)
	FXManager.shake(0.35, 0.25)

func _fire_staggered_volley(dir: Vector3) -> void:
	for i in range(3):
		await get_tree().create_timer(0.12).timeout
		if is_dead:
			return
		_fire_twin_cannon(dir)

func _spawn_support_drone() -> void:
	var d = drone_scene.instantiate()
	get_parent().add_child(d)
	d.global_position = global_position + Vector3(randf_range(-3.0, 3.0), 2.0, 0.0)
	SoundManager.play("alarm", 1.2, 0.0)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	GameManager.update_boss_health(health, max_health)
	SoundManager.play("hit", 0.8, 2.0)
	FXManager.spawn_hit_spark(global_position + Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), 0), Color(1.0, 0.3, 0.0))

	if not phase_2 and health <= max_health * 0.5:
		phase_2 = true
		SoundManager.play("alarm", 0.9, 4.0)
		FXManager.shake(0.6, 0.5)
		if core_light:
			core_light.light_color = Color(1.0, 0.0, 0.1)
			core_light.light_energy = 8.0

	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(visual.scale.x * 1.05, 1.05, 1.05), 0.04)
	tween.tween_property(visual, "scale", Vector3(visual.scale.x, 1.0, 1.0), 0.04)

	if health <= 0.0:
		_start_death_sequence()

func _start_death_sequence() -> void:
	is_dead = true
	GameManager.add_score(5000)
	SoundManager.play("boss_explosion", 0.9, 6.0)
	
	for i in range(8):
		var offset := Vector3(randf_range(-2.0, 2.0), randf_range(-1.5, 1.5), 0)
		FXManager.spawn_explosion(global_position + offset, 1.5, Color(1.0, 0.4, 0.1))
		SoundManager.play("explosion", randf_range(0.7, 1.3), 3.0)
		await get_tree().create_timer(0.25).timeout

	FXManager.spawn_explosion(global_position, 3.5, Color(1.0, 0.6, 0.2))
	FXManager.shake(1.0, 0.8)
	SoundManager.play("boss_explosion", 0.7, 8.0)
	
	visible = false
	await get_tree().create_timer(1.2).timeout
	GameManager.emit_signal("level_completed")
	queue_free()
