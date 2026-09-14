extends Area3D

@export var speed: float = 32.0
@export var damage: float = 25.0
@export var lifetime: float = 2.5
@export var is_enemy: bool = false
@export var penetrates: bool = false
@export var color: Color = Color(0.1, 0.9, 1.0)

var velocity: Vector3 = Vector3.ZERO
var _timer: float = 0.0

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("area_entered", _on_area_entered)

func init_projectile(dir: Vector3, p_speed: float, p_damage: float, p_color: Color, p_is_enemy: bool = false, p_penetrates: bool = false) -> void:
	velocity = dir.normalized() * p_speed
	damage = p_damage
	color = p_color
	is_enemy = p_is_enemy
	penetrates = p_penetrates
	look_at_target(global_position + velocity)

func look_at_target(target: Vector3) -> void:
	if global_position.distance_squared_to(target) > 0.001:
		look_at(target, Vector3.UP)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	global_position.z = 0.0 # Restrict strictly to 2.5D plane
	
	_timer += delta
	if _timer >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if is_enemy:
		if body.is_in_group("player"):
			GameManager.take_player_damage(damage)
			FXManager.spawn_hit_spark(global_position, color)
			queue_free()
		elif not body.is_in_group("enemies"):
			FXManager.spawn_hit_spark(global_position, color)
			queue_free()
	else:
		if body.is_in_group("enemies"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			FXManager.spawn_hit_spark(global_position, color)
			if not penetrates:
				queue_free()
		elif not body.is_in_group("player"):
			FXManager.spawn_hit_spark(global_position, color)
			if not penetrates:
				queue_free()

func _on_area_entered(area: Area3D) -> void:
	if is_enemy and area.is_in_group("player"):
		GameManager.take_player_damage(damage)
		FXManager.spawn_hit_spark(global_position, color)
		queue_free()
	elif not is_enemy and area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		elif area.get_parent() and area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)
		FXManager.spawn_hit_spark(global_position, color)
		if not penetrates:
			queue_free()
