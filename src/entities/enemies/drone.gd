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
var player_ref: Node3D = null

var proj_scene: PackedScene = preload("res://src/projectiles/enemy_projectile.tscn")
var pickup_energy_scene: PackedScene = preload("res://src/entities/pickups/pickup.tscn")

@onready var visual: Node3D = $Visual
@onready var muzzle: Marker3D = $Visual/Muzzle

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	fire_timer = randf_range(0.5, fire_interval)
	hover_timer = randf() * TAU

func _physics_process(delta: float) -> void:
	hover_timer += delta * 3.0
	var hover_offset := sin(hover_timer) * 0.015

	if not player_ref:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	if player_ref and is_instance_valid(player_ref) and GameManager.health > 0:
		var diff := player_ref.global_position - global_position
		diff.z = 0.0
		var dist := diff.length()

		if dist < attack_range:
			var target_pos := player_ref.global_position + Vector3(-sign(diff.x) * min_distance, 1.8, 0)
			var move_dir := (target_pos - global_position).normalized()
			velocity = velocity.lerp(move_dir * speed, 5.0 * delta)

			visual.scale.x = 1.0 if diff.x >= 0.0 else -1.0

			fire_timer -= delta
			if fire_timer <= 0.0 and dist < attack_range:
				_fire_at_player(diff.normalized())
				fire_timer = fire_interval + randf_range(-0.2, 0.2)
		else:
			velocity = velocity.lerp(Vector3.ZERO, 3.0 * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, 3.0 * delta)

	velocity.y += hover_offset
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0

func _fire_at_player(dir: Vector3) -> void:
	if not proj_scene:
		return
	var spawn_pos := muzzle.global_position if muzzle else global_position
	spawn_pos.z = 0.0
	var p = proj_scene.instantiate()
	get_parent().add_child(p)
	p.global_position = spawn_pos
	p.init_projectile(dir, 16.0, 15.0, Color(1.0, 0.15, 0.15), true, false)
	SoundManager.play("enemy_laser", 1.1, -3.0)

func take_damage(amount: float) -> void:
	health -= amount
	SoundManager.play("hit", 1.2, 0.0)
	FXManager.spawn_hit_spark(global_position, Color(1.0, 0.8, 0.2))
	
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(visual.scale.x * 1.15, 1.15, 1.15), 0.06)
	tween.tween_property(visual, "scale", Vector3(visual.scale.x, 1.0, 1.0), 0.06)

	if health <= 0.0:
		_die()

func _die() -> void:
	GameManager.add_score(score_value)
	SoundManager.play("explosion", 1.2, 2.0)
	FXManager.spawn_explosion(global_position, 0.8, Color(1.0, 0.3, 0.1))

	if randf() < 0.45:
		var pickup = pickup_energy_scene.instantiate()
		get_parent().call_deferred("add_child", pickup)
		pickup.global_position = global_position

	queue_free()
