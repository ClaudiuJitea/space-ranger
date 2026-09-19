extends Area3D

## HV-4 Havoc rocket: flies flat with a slight gravity arc, spawns a smoke
## trail, and detonates on contact or at end of life with an area explosion.
## Enemies take blast damage; the player only gets a knockback impulse
## (rocket-jump friendly, never self-damage).

@export var speed: float = 28.0
@export var damage: float = 85.0
@export var blast_damage: float = 140.0
@export var blast_radius: float = 5.2
@export var lifetime: float = 3.5
@export var gravity_scale: float = 0.12
@export var homing_strength: float = 10.0
@export var terminal_speed: float = 38.0

var velocity: Vector3 = Vector3.ZERO
var _timer: float = 0.0
var _exploded: bool = false
var _visual: Node3D
var _launch_depth := 0.0
var _target_node: Node3D = null
var _guidance_trail: GPUParticles3D
var _guidance_process: ParticleProcessMaterial

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("area_entered", _on_area_entered)
	$ExhaustLight.light_energy = 0.9
	_visual = Node3D.new()
	_visual.set_script(preload("res://src/projectiles/rocket_visual.gd"))
	add_child(_visual)
	_build_guidance_trail()

func _build_guidance_trail() -> void:
	_guidance_trail = GPUParticles3D.new()
	_guidance_trail.name = "GuidanceTrail"
	_guidance_trail.amount = 42
	_guidance_trail.lifetime = 0.55
	_guidance_trail.local_coords = false
	_guidance_trail.visibility_aabb = AABB(Vector3(-40, -20, -2), Vector3(80, 40, 4))
	_guidance_process = ParticleProcessMaterial.new()
	_guidance_process.direction = Vector3.LEFT
	_guidance_process.spread = 7.0
	_guidance_process.initial_velocity_min = 1.2
	_guidance_process.initial_velocity_max = 2.8
	_guidance_process.gravity = Vector3.ZERO
	_guidance_process.scale_min = 0.45
	_guidance_process.scale_max = 1.25
	_guidance_process.color = Color(0.12, 0.82, 1.0, 0.8)
	_guidance_trail.process_material = _guidance_process
	var spark := QuadMesh.new()
	spark.size = Vector2(0.075, 0.022)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.albedo_color = Color(0.35, 0.92, 1.0, 0.9)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(0.1, 0.72, 1.0)
	spark_mat.emission_energy_multiplier = 2.2
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark.material = spark_mat
	_guidance_trail.draw_pass_1 = spark
	add_child(_guidance_trail)

func set_target(target: Node3D) -> void:
	if is_instance_valid(target):
		_target_node = target

func _target_point(target: Node3D) -> Vector3:
	var point := target.global_position
	if target is CharacterBody3D:
		point.y += 0.85
	point.z = 0.0
	return point

func init_projectile(dir: Vector3, p_speed: float, p_damage: float, _p_color: Color, _p_is_enemy: bool = false, _p_penetrates: bool = false) -> void:
	_launch_depth = global_position.z
	global_position.z = 0
	velocity = dir.normalized() * p_speed
	damage = p_damage
	if global_position.distance_to(global_position + velocity) > 0.001:
		look_at(global_position + velocity, Vector3.FORWARD if absf(velocity.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)

	_visual.position = global_basis.inverse() * Vector3(0, 0, _launch_depth)

func _get_homing_target() -> Node3D:
	if is_instance_valid(_target_node) and not _target_node.is_queued_for_deletion():
		return _target_node
	var best_node: Node3D = null
	var best_dist := 60.0
	var cur_dir := velocity.normalized()

	# Prioritize bosses
	for boss in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(boss) and not boss.is_queued_for_deletion() and not boss.get("is_dead"):
			var to_boss: Vector3 = _target_point(boss) - global_position
			to_boss.z = 0.0
			var dist := to_boss.length()
			if dist < 60.0 and cur_dir.dot(to_boss.normalized()) > 0.05:
				_target_node = boss
				return _target_node

	# Otherwise seek nearest enemy
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var to_enemy: Vector3 = _target_point(enemy) - global_position
		to_enemy.z = 0.0
		var dist := to_enemy.length()
		if dist < best_dist and cur_dir.dot(to_enemy.normalized()) > 0.05:
			best_dist = dist
			best_node = enemy
	_target_node = best_node
	return _target_node

func _physics_process(delta: float) -> void:
	var target := _get_homing_target()
	if target and is_instance_valid(target):
		var to_target: Vector3 = _target_point(target) - global_position
		to_target.z = 0.0
		if to_target.length_squared() > 0.05:
			var target_dir := to_target.normalized()
			var current_dir := velocity.normalized()
			var current_spd := move_toward(velocity.length(), terminal_speed, 18.0 * delta)
			var new_dir := current_dir.slerp(target_dir, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
			velocity = new_dir * current_spd
	else:
		velocity.y -= 9.8 * gravity_scale * delta

	global_position += velocity * delta
	global_position.z = 0.0

	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.FORWARD if absf(velocity.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
		if _guidance_process:
			_guidance_process.direction = -velocity.normalized()
	$ExhaustLight.light_color = Color(0.15, 0.72, 1.0).lerp(Color(1.0, 0.42, 0.08), 0.5 + sin(_timer * 28.0) * 0.5)
	$ExhaustLight.light_energy = 1.6 + sin(_timer * 34.0) * 0.35
	_visual.position = global_basis.inverse() * Vector3(0, 0, _launch_depth * maxf(0, 1 - _timer / 0.09))
	_timer += delta
	if _timer >= lifetime:
		_detonate()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return # never detonate on the shooter
	# Deferred: detonation queries the physics space, which stays locked
	# until the body_entered flush has finished.
	call_deferred("_detonate")

func _on_area_entered(area: Area3D) -> void:
	# Ignore pickups / hazard volumes; only hostile hitboxes set rockets off.
	if area.is_in_group("enemies"):
		call_deferred("_detonate")

func _detonate() -> void:
	if _exploded:
		return
	_exploded = true

	SoundManager.play("rocket_explode", 1.0 + randf_range(-0.08, 0.08), 0.0)
	FXManager.spawn_explosion(global_position, 1.6, Color(1.0, 0.5, 0.12))
	FXManager.spawn_shockwave(global_position, Color(1.0, 0.55, 0.15), blast_radius * 0.9)
	FXManager.hit_stop(0.065, 0.05)
	FXManager.add_trauma(0.55)

	# Area damage to enemies + knockback to everything (player included)
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var results := space.intersect_shape(query, 24)
	for hit in results:
		var collider: Object = hit.get("collider")
		if collider == null:
			continue
		if collider is Node and ((collider as Node).is_in_group("enemies") or (collider as Node).is_in_group("damageable_props")):
			if collider.has_method("take_damage"):
				collider.take_damage(blast_damage)
		elif collider is RigidBody3D:
			collider.apply_central_impulse((collider.global_position - global_position).normalized() * 8.0)

	# Rocket-jump: shove the player away from the blast without damage
	var players := get_tree().get_nodes_in_group("player")
	for pl in players:
		if pl is Node3D and is_instance_valid(pl):
			var away: Vector3 = pl.global_position - global_position
			away.z = 0.0
			if away.length() < blast_radius and away.length_squared() > 0.01:
				var push: Vector3 = away.normalized() * 16.0
				push.y = maxf(push.y, 6.0)
				if "velocity" in pl:
					pl.velocity += push

	queue_free()
