extends StaticBody3D

@export var max_health := 30.0
@export_enum("Hull:0", "Shield:1") var supply_type := 0
var health := 30.0
var _broken := false

func _ready() -> void:
	health = max_health
	add_to_group("damageable_props")

func take_damage(amount: float) -> void:
	if _broken:
		return
	health -= amount
	FXManager.spawn_hit_spark(global_position + Vector3.UP * 0.45, Color(1, 0.65, 0.2))
	SoundManager.play("hit", 0.85, -4)
	if health <= 0:
		_broken = true
		_break_open.call_deferred()

func _break_open() -> void:
	FXManager.spawn_explosion(global_position + Vector3.UP * 0.45, 0.55, Color(1, 0.65, 0.2))
	var pickup := preload("res://src/entities/pickups/pickup.tscn").instantiate()
	pickup.pickup_type = supply_type
	get_parent().add_child(pickup)
	pickup.global_position = global_position + Vector3.UP * 0.8
	GameManager.notify("SUPPLY CACHE OPEN // COLLECT SUPPLIES", Color(1, 0.7, 0.2))
	queue_free()
