extends CharacterBody3D

@export var max_health: float = 140.0
@export var speed: float = 3.5
@export var attack_range: float = 18.0
@export var score_value: int = 350

var health: float
var fire_timer: float = 0.0
var patrol_center: Vector3
var patrol_dir: float = 1.0
var patrol_dist: float = 6.0
var player_ref: Node3D = null
var current_barrel: int = 0

var proj_scene: PackedScene = preload("res://src/projectiles/enemy_projectile.tscn")
var pickup_scene: PackedScene = preload("res://src/entities/pickups/pickup.tscn")

@onready var visual: Node3D = $Visual
@onready var muzzle_left: Marker3D = $Visual/MuzzleLeft
@onready var muzzle_right: Marker3D = $Visual/MuzzleRight

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	patrol_center = global_position
	fire_timer = 1.2

func _physics_process(delta: float) -> void:
	if not player_ref:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	var dist_to_player := 999.0
	if player_ref and is_instance_valid(player_ref) and GameManager.health > 0:
		var diff := player_ref.global_position - global_position
		diff.z = 0.0
		dist_to_player = diff.length()
		
		if dist_to_player < attack_range:
			visual.scale.x = 1.0 if diff.x >= 0.0 else -1.0

			fire_timer -= delta
			if fire_timer <= 0.0:
				_fire_cannon(diff.normalized())
				fire_timer = 0.45

	velocity.x = patrol_dir * speed
	if abs(global_position.x - patrol_center.x) > patrol_dist:
		patrol_dir = -sign(global_position.x - patrol_center.x)
	
	velocity.y = sin(Time.get_ticks_msec() * 0.002) * 0.5
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0

func _fire_cannon(dir: Vector3) -> void:
	if not proj_scene:
		return
	var m: Marker3D = muzzle_right if current_barrel == 0 else muzzle_left
	current_barrel = 1 - current_barrel
	var spawn_pos := m.global_position if m else global_position
	spawn_pos.z = 0.0
	
	var p = proj_scene.instantiate()
	get_parent().add_child(p)
	p.global_position = spawn_pos
	p.init_projectile(dir, 20.0, 20.0, Color(0.78, 0.84, 0.77), true, false)
	FXManager.spawn_muzzle_flash(spawn_pos, dir, Color(0.78, 0.84, 0.77))
	SoundManager.play("enemy_laser", 0.9, -1.0)
	FXManager.shake(0.12, 0.1)

func take_damage(amount: float) -> void:
	health -= amount
	SoundManager.play("hit", 1.0, 1.0)
	FXManager.spawn_hit_spark(global_position, Color(1.0, 0.7, 0.1))
	
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(visual.scale.x * 1.1, 1.1, 1.1), 0.05)
	tween.tween_property(visual, "scale", Vector3(visual.scale.x, 1.0, 1.0), 0.05)

	if health <= 0.0:
		_die()

func _die() -> void:
	GameManager.add_score(score_value)
	SoundManager.play("explosion", 0.9, 4.0)
	FXManager.spawn_explosion(global_position, 1.4, Color(1.0, 0.45, 0.1))

	var pickup = pickup_scene.instantiate()
	# Parent is the level root (identity transform), so position == global.
	pickup.position = global_position
	pickup.pickup_type = 1
	get_parent().call_deferred("add_child", pickup)

	queue_free()
