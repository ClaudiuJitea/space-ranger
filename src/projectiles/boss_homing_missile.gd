extends Area3D

## Boss Homing Micro-Missile
## Launches from boss shoulder pods, arcs into the air, then homes toward the player.
## Can be shot down by the player or dodged with a dash.

@export var speed: float = 16.0
@export var damage: float = 16.0
@export var turn_speed: float = 3.5
@export var lifetime: float = 5.0
@export var health: float = 1.0

var velocity: Vector3 = Vector3.ZERO
var player_ref: Node3D = null
var _timer: float = 0.0
var _arming_delay: float = 0.25
var _exploded: bool = false
var _visual: Node3D

func _ready() -> void:
	add_to_group("enemies") # allows player projectiles to hit and destroy the missile
	connect("body_entered", _on_body_entered)
	connect("area_entered", _on_area_entered)
	_visual = Node3D.new()
	_visual.set_script(preload("res://src/projectiles/rocket_visual.gd"))
	add_child(_visual)

func init_missile(launch_dir: Vector3, launch_speed: float, p_damage: float, p_speed: float) -> void:
	damage = p_damage
	speed = p_speed
	velocity = launch_dir.normalized() * launch_speed
	global_position.z = 0.0
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP)
	player_ref = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		_detonate()
		return

	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node3D

	if _timer > _arming_delay and is_instance_valid(player_ref):
		var target := player_ref.global_position + Vector3(0, 0.8, 0)
		var desired_dir := (target - global_position).normalized()
		desired_dir.z = 0.0
		var current_dir := velocity.normalized()
		var new_dir := current_dir.lerp(desired_dir, turn_speed * delta).normalized()
		velocity = new_dir * speed
	else:
		# Initial launch arc (slight gravity drop during arming)
		velocity.y -= 12.0 * delta

	global_position += velocity * delta
	global_position.z = 0.0

	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP)

func _on_body_entered(body: Node) -> void:
	if _exploded:
		return
	if body.is_in_group("player"):
		GameManager.take_player_damage(int(damage))
		_detonate()
	elif not body.is_in_group("bosses") and not body.is_in_group("boss_sidekicks"):
		_detonate()

func _on_area_entered(area: Area3D) -> void:
	if _exploded:
		return
	# Player projectiles hitting the missile destroy it
	if not area.is_in_group("enemies") and area.has_method("get") and not area.get("is_enemy"):
		take_damage(10.0)

func take_damage(_amount: float) -> void:
	if _exploded:
		return
	health -= _amount
	if health <= 0.0:
		_detonate(true)

func _detonate(shot_down: bool = false) -> void:
	if _exploded:
		return
	_exploded = true

	SoundManager.play("rocket_explode", 1.2 if shot_down else 1.0, -2.0)
	FXManager.spawn_explosion(global_position, 1.2 if shot_down else 1.5, Color(1.0, 0.45, 0.1))
	FXManager.spawn_shockwave(global_position, Color(1.0, 0.5, 0.15), 2.5)
	if not shot_down and is_instance_valid(player_ref):
		var dist := global_position.distance_to(player_ref.global_position)
		if dist < 2.5:
			GameManager.take_player_damage(int(damage * (1.0 - dist / 2.5)))

	queue_free()
