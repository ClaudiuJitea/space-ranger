extends CharacterBody3D

@export var max_health: float = 20.0
@export var explosion_damage: float = 90.0
@export var explosion_radius: float = 4.5

var health: float
var exploded: bool = false

@onready var visual: Node3D = $Visual

func _ready() -> void:
	add_to_group("enemies") # allows projectiles to hit it
	health = max_health

func take_damage(amount: float) -> void:
	if exploded:
		return
	health -= amount
	SoundManager.play("hit", 0.8, 2.0)
	FXManager.spawn_hit_spark(global_position, Color(1.0, 0.4, 0.1))

	if health <= 0.0:
		explode()

func explode() -> void:
	if exploded:
		return
	exploded = true
	
	SoundManager.play("boss_explosion", 1.2, 4.0)
	FXManager.spawn_explosion(global_position, 2.2, Color(1.0, 0.4, 0.05))
	FXManager.shake(0.6, 0.4)

	# Damage entities in radius
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = global_transform

	var results := space.intersect_shape(query, 32)
	for hit in results:
		var collider: Object = hit.get("collider")
		if collider and collider != self:
			if collider.has_method("take_damage"):
				collider.take_damage(explosion_damage)
			elif collider.is_in_group("player"):
				GameManager.take_player_damage(35.0)

	queue_free()
