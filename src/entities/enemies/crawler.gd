extends CharacterBody3D

## RIFT Crawler — ground melee pressure unit. Patrols its platform, chases the
## player, telegraphs a lunge, then dashes in for contact damage. Refuses to
## walk off ledges and always leaves a recovery window after lunging.

@export var max_health: float = 70.0
@export var patrol_speed: float = 2.2
@export var chase_speed: float = 4.6
@export var lunge_speed: float = 11.0
@export var aggro_range: float = 11.0
@export var deaggro_range: float = 16.0
@export var lunge_trigger_range: float = 2.4
@export var contact_damage: float = 14.0
@export var score_value: int = 250

enum State { PATROL, CHASE, WINDUP, LUNGE, RECOVER }

var health: float
var state: int = State.PATROL
var state_timer: float = 0.0
var patrol_dir: float = 1.0
var facing: float = 1.0
var lunge_dir: float = 1.0
var hit_cooldown: float = 0.0
var player_ref: Node3D = null

var pickup_energy_scene: PackedScene = preload("res://src/entities/pickups/pickup.tscn")

@onready var visual: Node3D = $Visual
@onready var eye_light: OmniLight3D = $Visual/EyeLight

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	patrol_dir = 1.0 if randf() < 0.5 else -1.0
	facing = patrol_dir
	state_timer = randf_range(0.4, 1.6)

func _physics_process(delta: float) -> void:
	# Safety net: a crawler that somehow leaves the world despawns quietly.
	if global_position.y < -14.0:
		queue_free()
		return
	if hit_cooldown > 0.0:
		hit_cooldown -= delta
	if not is_on_floor():
		velocity.y -= 28.0 * delta

	if not player_ref or not is_instance_valid(player_ref):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	var dx := 999.0
	if player_ref and is_instance_valid(player_ref) and GameManager.health > 0:
		dx = player_ref.global_position.x - global_position.x

	state_timer -= delta
	match state:
		State.PATROL:
			_move_ground(patrol_dir * patrol_speed)
			if _edge_ahead() or is_on_wall():
				patrol_dir = -patrol_dir
			if absf(dx) < aggro_range:
				_enter(State.CHASE, 0.0)
		State.CHASE:
			var dir := signf(dx)
			if _edge_ahead() and absf(dx) > lunge_trigger_range:
				velocity.x = 0.0 # hold at the ledge instead of falling in
			else:
				_move_ground(dir * chase_speed)
			_face(dir)
			if absf(dx) > deaggro_range:
				_enter(State.PATROL, 0.0)
				patrol_dir = dir
			elif absf(dx) < lunge_trigger_range and is_on_floor():
				_start_windup(dir)
		State.WINDUP:
			velocity.x = 0.0
			# Telegraph: flare the eye and rear back.
			eye_light.light_energy = 2.0 + 6.0 * (1.0 - state_timer / 0.45)
			if state_timer <= 0.0:
				_enter(State.LUNGE, 0.32)
				lunge_dir = facing
				velocity.x = lunge_dir * lunge_speed
				velocity.y = 2.5
				SoundManager.play("lunge", randf_range(0.95, 1.1), 0.0)
		State.LUNGE:
			velocity.x = lunge_dir * lunge_speed * maxf(state_timer / 0.32, 0.35)
			if state_timer <= 0.0:
				_enter(State.RECOVER, 0.7)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			eye_light.light_energy = lerpf(eye_light.light_energy, 1.6, 6.0 * delta)
			if state_timer <= 0.0:
				_enter(State.CHASE, 0.0)

	# Contact damage with a short per-crawler cooldown so it can't machine-gun.
	if hit_cooldown <= 0.0 and absf(dx) < 1.05 and absf(global_position.y - _player_y()) < 1.3:
		GameManager.take_player_damage(contact_damage)
		FXManager.spawn_hit_spark(global_position + Vector3(0, 0.4, 0), Color(1.0, 0.2, 0.1))
		FXManager.shake(0.2, 0.12)
		hit_cooldown = 0.9

	move_and_slide()
	global_position.z = 0.0
	_update_motion_feedback(delta)

func _player_y() -> float:
	if player_ref and is_instance_valid(player_ref):
		return player_ref.global_position.y
	return global_position.y

func _move_ground(target_vx: float) -> void:
	velocity.x = move_toward(velocity.x, target_vx, 24.0 * get_physics_process_delta_time())
	if absf(velocity.x) > 0.1:
		_face(signf(velocity.x))

## Lunge telegraph entry: face the target, then rear back while the eye flares.
func _start_windup(dir: float) -> void:
	_face(dir)
	_enter(State.WINDUP, 0.45)
	SoundManager.play("alarm", 1.8, -8.0)

func _face(dir: float) -> void:
	if dir != 0.0:
		facing = dir

func _edge_ahead() -> bool:
	if not is_on_floor():
		return false
	# Direct space query instead of a RayCast3D node: the Visual node runs a
	# negative scale for facing, which corrupts raycasts parented under it.
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(facing * 0.75, 0.15, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -0.7, 0), 1)
	return space.intersect_ray(query).is_empty()

func _enter(next: int, timer: float) -> void:
	state = next
	state_timer = timer

func _update_motion_feedback(_delta: float) -> void:
	visual.scale.x = facing

func take_damage(amount: float) -> void:
	health -= amount
	SoundManager.play("hit", 1.3, 0.0)
	FXManager.spawn_hit_spark(global_position + Vector3(0, 0.4, 0), Color(1.0, 0.8, 0.2))
	FXManager.spawn_enemy_hitmarker(global_position + Vector3(0, 0.4, 0))

	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(visual.scale.x * 1.15, 1.15, 1.15), 0.05)
	tween.tween_property(visual, "scale", Vector3(visual.scale.x, 1.0, 1.0), 0.05)

	# Getting shot out of a lunge staggers it back into recovery.
	if state == State.LUNGE and randf() < 0.4:
		_enter(State.RECOVER, 0.5)

	if health <= 0.0:
		_die()

func _die() -> void:
	GameManager.add_score(score_value)
	SoundManager.play("explosion", 1.3, 2.0)
	FXManager.spawn_explosion(global_position + Vector3(0, 0.3, 0), 1.0, Color(1.0, 0.25, 0.1))

	if randf() < 0.45:
		var pickup = pickup_energy_scene.instantiate()
		pickup.position = global_position + Vector3(0, 0.6, 0)
		get_parent().call_deferred("add_child", pickup)

	queue_free()
