extends CharacterBody3D

@export var max_health: float = 80.0
@export var attack_range: float = 16.0
@export var burst_count: int = 3
@export var burst_delay: float = 0.12
@export var cycle_delay: float = 1.8
@export var score_value: int = 200

var health: float
var cycle_timer: float = 0.0
var burst_left: int = 0
var burst_timer: float = 0.0
var player_ref: Node3D = null
var current_aim_dir: Vector3 = Vector3.RIGHT

var proj_scene: PackedScene = preload("res://src/projectiles/enemy_projectile.tscn")

@onready var swivel_head: Node3D = $SwivelHead
@onready var muzzle: Marker3D = $SwivelHead/Muzzle

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	cycle_timer = randf_range(0.5, cycle_delay)

func _physics_process(delta: float) -> void:
	if not player_ref:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	if player_ref and is_instance_valid(player_ref) and GameManager.health > 0:
		var diff := player_ref.global_position - global_position
		diff.z = 0.0
		var dist := diff.length()

		if dist < attack_range:
			current_aim_dir = diff.normalized()
			var target_angle := atan2(diff.y, diff.x)
			swivel_head.rotation.z = lerp_angle(swivel_head.rotation.z, target_angle, 8.0 * delta)

			if burst_left > 0:
				burst_timer -= delta
				if burst_timer <= 0.0:
					_fire_single_shot()
					burst_left -= 1
					burst_timer = burst_delay
			else:
				cycle_timer -= delta
				if cycle_timer <= 0.0:
					burst_left = burst_count
					burst_timer = 0.0
					cycle_timer = cycle_delay

func _fire_single_shot() -> void:
	if not proj_scene:
		return
	var spawn_pos := muzzle.global_position if muzzle else global_position
	spawn_pos.z = 0.0
	var p = proj_scene.instantiate()
	get_parent().add_child(p)
	p.global_position = spawn_pos
	p.init_projectile(current_aim_dir, 22.0, 12.0, Color(0.78, 0.84, 0.77), true, false)
	FXManager.spawn_muzzle_flash(spawn_pos, current_aim_dir, Color(0.78, 0.84, 0.77))
	SoundManager.play("enemy_laser", 1.3, -3.0)
	FXManager.shake(0.08, 0.06)

func take_damage(amount: float) -> void:
	health -= amount
	SoundManager.play("hit", 1.1, 0.0)
	FXManager.spawn_hit_spark(global_position, Color(1.0, 0.6, 0.1))

	var tween := create_tween()
	tween.tween_property(swivel_head, "scale", Vector3(1.15, 1.15, 1.15), 0.05)
	tween.tween_property(swivel_head, "scale", Vector3(1.0, 1.0, 1.0), 0.05)

	if health <= 0.0:
		_die()

func _die() -> void:
	GameManager.add_score(score_value)
	SoundManager.play("explosion", 1.1, 3.0)
	FXManager.spawn_explosion(global_position, 1.0, Color(1.0, 0.3, 0.1))
	queue_free()
