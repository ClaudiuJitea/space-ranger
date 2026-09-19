extends Area3D

@export var speed: float = 32.0
@export var damage: float = 25.0
@export var lifetime: float = 2.5
@export var is_enemy: bool = false
@export var penetrates: bool = false
@export var color: Color = Color(0.1, 0.9, 1.0)

var velocity: Vector3 = Vector3.ZERO
var _timer: float = 0.0
@export_enum("pulse", "scatter", "rail", "enemy", "emp") var fx_profile := "pulse"
var _visual: Node3D
var _launch_depth := 0.0
var _hit_targets: Dictionary = {}
var _spent := false

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("area_entered", _on_area_entered)
	_visual = Node3D.new()
	_visual.set_script(preload("res://src/projectiles/shot_visual.gd"))
	add_child(_visual)

func init_projectile(dir: Vector3, p_speed: float, p_damage: float, p_color: Color, p_is_enemy: bool = false, p_penetrates: bool = false) -> void:
	velocity = dir.normalized() * p_speed
	damage = p_damage
	color = p_color
	is_enemy = p_is_enemy
	penetrates = p_penetrates
	_launch_depth = global_position.z
	global_position.z = 0
	look_at_target(global_position + velocity)
	# Local Z points along the shot, so launch depth must be expressed in local space.
	_visual.configure("enemy" if is_enemy else fx_profile, color, velocity, _launch_depth)

func set_fx_profile(profile: String) -> void:
	fx_profile = profile
	if _visual:
		_visual.configure(profile, color, velocity, 0.0)

func look_at_target(target: Vector3) -> void:
	if global_position.distance_squared_to(target) > 0.001:
		look_at(target, Vector3.FORWARD if absf((target - global_position).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)

func _physics_process(delta: float) -> void:
	if _spent:
		return
	var previous := global_position
	var destination := previous + velocity * delta
	# Sweep between physics ticks: thin beams and fast bolts cannot tunnel through props.
	var query := PhysicsRayQueryParameters3D.create(previous, destination, collision_mask)
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	for player in get_tree().get_nodes_in_group("player"):
		if not is_enemy and player is CollisionObject3D:
			query.exclude = query.exclude + [player.get_rid()]
	for target in _hit_targets.values():
		if is_instance_valid(target) and target is CollisionObject3D:
			query.exclude = query.exclude + [target.get_rid()]
	for attempt in range(12):
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		global_position = hit.position
		if hit.collider is Area3D:
			_on_area_entered(hit.collider)
		else:
			_on_body_entered(hit.collider)
		if _spent:
			return
		query.exclude = query.exclude + [hit.collider.get_rid()]
	global_position = destination
	global_position.z = 0.0 # Restrict strictly to 2.5D plane

	_visual.advance(delta)
	_timer += delta
	if _timer >= lifetime:
		_retire()

func _on_body_entered(body: Node) -> void:
	if _spent or _hit_targets.has(body.get_instance_id()):
		return
	if not is_enemy and body.is_in_group("player"):
		return
	_hit_targets[body.get_instance_id()] = body
	if is_enemy:
		if body.is_in_group("player"):
			var hit_shield := GameManager.shield > 0.0
			GameManager.take_player_damage(damage)
			if hit_shield:
				FXManager.spawn_shield_impact(global_position)
			else:
				FXManager.spawn_armor_impact(global_position)
			_spent = true
			_retire()
		elif not body.is_in_group("enemies"):
			FXManager.spawn_hit_spark(global_position, color)
			_spent = true
			_retire()
	else:
		if body.is_in_group("enemies") or body.is_in_group("damageable_props"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			FXManager.spawn_armor_impact(global_position, color)
			if fx_profile == "emp": FXManager.spawn_emp_burst(global_position, 1.5)
			FXManager.spawn_enemy_hitmarker(global_position)
			SoundManager.play("hitmarker", 1.0 + randf_range(-0.1, 0.1), -8.0)
			if fx_profile == "scatter":
				FXManager.hit_stop(0.025, 0.15)
				FXManager.add_trauma(0.12)
			elif fx_profile == "rail":
				FXManager.hit_stop(0.055, 0.05)
				FXManager.add_trauma(0.32)
			elif fx_profile == "emp":
				FXManager.hit_stop(0.04, 0.1)
				FXManager.add_trauma(0.2)
			else:
				FXManager.add_trauma(0.035)
			if not penetrates:
				_spent = true
				_retire()
		elif not body.is_in_group("player"):
			FXManager.spawn_hit_spark(global_position, color)
			_spent = true
			_retire()

func _on_area_entered(area: Area3D) -> void:
	var target: Node = area
	if not area.has_method("take_damage") and area.get_parent() and area.get_parent().has_method("take_damage"):
		target = area.get_parent()
	if _spent or _hit_targets.has(target.get_instance_id()):
		return
	_hit_targets[target.get_instance_id()] = target
	if is_enemy and area.is_in_group("player"):
		var hit_shield := GameManager.shield > 0.0
		GameManager.take_player_damage(damage)
		if hit_shield:
			FXManager.spawn_shield_impact(global_position)
		else:
			FXManager.spawn_armor_impact(global_position)
		_spent = true
		_retire()
	elif not is_enemy and area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		elif area.get_parent() and area.get_parent().has_method("take_damage"):
			area.get_parent().take_damage(damage)
		FXManager.spawn_armor_impact(global_position, color)
		if fx_profile == "emp": FXManager.spawn_emp_burst(global_position, 1.5)
		FXManager.spawn_enemy_hitmarker(global_position)
		SoundManager.play("hitmarker", 1.0 + randf_range(-0.1, 0.1), -8.0)
		if fx_profile == "scatter":
			FXManager.hit_stop(0.025, 0.15)
			FXManager.add_trauma(0.12)
		elif fx_profile == "rail":
			FXManager.hit_stop(0.055, 0.05)
			FXManager.add_trauma(0.32)
		elif fx_profile == "emp":
			FXManager.hit_stop(0.04, 0.1)
			FXManager.add_trauma(0.2)
		else:
			FXManager.add_trauma(0.035)
		if not penetrates:
			_spent = true
			_retire()

func _retire() -> void:
	_spent = true
	if _visual:
		_visual.release_trail()
	queue_free()
