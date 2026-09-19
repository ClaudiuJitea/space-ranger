extends Node

## FX Manager: pooled particle bursts, camera shake, muzzle flashes and
## shockwaves. Emitters are pre-created and recycled with restart(), so combat
## never allocates new nodes or materials at runtime.

signal camera_shake_requested(intensity: float, duration: float)
signal trauma_requested(amount: float)
signal enemy_hitmarked(world_pos: Vector3)

const SPARK_POOL_SIZE := 24
const EXPLOSION_POOL_SIZE := 10

## Global multiplier for camera shake (0 disables, 1 default) — driven by the
## settings screen so players can tune motion to taste.
var shake_scale: float = 1.0

var _spark_pool: Array[GPUParticles3D] = []
var _spark_mats: Array[ParticleProcessMaterial] = []
var _spark_mesh_mats: Array[StandardMaterial3D] = []
var _explosion_pool: Array[GPUParticles3D] = []
var _explosion_mats: Array[ParticleProcessMaterial] = []
var _explosion_mesh_mats: Array[StandardMaterial3D] = []
var _root: Node3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_build_pools")

func _build_pools() -> void:
	if _root != null and is_instance_valid(_root):
		return
	# Pool lives under the autoload itself so it survives scene reloads;
	# parenting it to current_scene left freed-node references after restart.
	_root = Node3D.new()
	_root.name = "FXPool"
	_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_root)

	for i in range(SPARK_POOL_SIZE):
		var p := GPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.lifetime = 0.35
		p.amount = 14

		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 4.0
		mat.initial_velocity_max = 8.0
		mat.gravity = Vector3(0, -9.8, 0)
		mat.scale_min = 0.05
		mat.scale_max = 0.12
		p.process_material = mat

		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.08, 0.08)
		var std_mat := StandardMaterial3D.new()
		std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std_mat.albedo_color = Color.WHITE
		mesh.material = std_mat
		p.draw_pass_1 = mesh

		_root.add_child(p)
		_spark_pool.append(p)
		_spark_mats.append(mat)
		_spark_mesh_mats.append(std_mat)

	for i in range(EXPLOSION_POOL_SIZE):
		var p := GPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.98
		p.lifetime = 0.55
		p.amount = 28

		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 5.0
		mat.initial_velocity_max = 12.0
		mat.gravity = Vector3(0, -12.0, 0)
		mat.scale_min = 0.1
		mat.scale_max = 0.25
		p.process_material = mat

		var mesh := SphereMesh.new()
		mesh.radius = 0.1
		mesh.height = 0.2
		var std_mat := StandardMaterial3D.new()
		std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		std_mat.albedo_color = Color.WHITE
		mesh.material = std_mat
		p.draw_pass_1 = mesh

		_root.add_child(p)
		_explosion_pool.append(p)
		_explosion_mats.append(mat)
		_explosion_mesh_mats.append(std_mat)

func shake(intensity: float = 0.3, duration: float = 0.25) -> void:
	if shake_scale <= 0.0:
		return
	emit_signal("camera_shake_requested", intensity * shake_scale, duration)

var _hit_stop_active := false

func hit_stop(duration_sec: float = 0.05, time_scale: float = 0.05) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = time_scale
	var timer := get_tree().create_timer(duration_sec, true, false, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
		_hit_stop_active = false
	)

func add_trauma(amount: float) -> void:
	if shake_scale <= 0.0:
		return
	emit_signal("trauma_requested", amount * shake_scale)
	shake(amount * 0.45, 0.25)

func _next_free(pool: Array[GPUParticles3D]) -> int:
	for i in range(pool.size()):
		if is_instance_valid(pool[i]) and not pool[i].emitting:
			return i
	return -1

func spawn_hit_spark(pos: Vector3, color: Color = Color(0.2, 0.9, 1.0)) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	var idx := _next_free(_spark_pool)
	if idx < 0:
		return
	var p := _spark_pool[idx]
	p.position = pos
	_spark_mesh_mats[idx].albedo_color = color
	p.restart()

func spawn_armor_impact(pos: Vector3, projectile_color: Color = Color(1.0, 0.45, 0.12)) -> void:
	# Hot metal fragments retain a hint of the weapon energy at their core.
	spawn_hit_spark(pos, Color(1.0, 0.38, 0.08).lerp(projectile_color, 0.22))

func spawn_shield_impact(pos: Vector3) -> void:
	spawn_hit_spark(pos, Color(0.15, 0.9, 1.0))
	spawn_shockwave(pos, Color(0.12, 0.82, 1.0, 0.72), 1.15)

func spawn_enemy_hitmarker(pos: Vector3) -> void:
	emit_signal("enemy_hitmarked", pos)

func spawn_explosion(pos: Vector3, scale_mult: float = 1.0, color: Color = Color(1.0, 0.5, 0.1)) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	shake(0.4 * scale_mult, 0.3)

	# Central flash light (pooled via short-lived tween on a recycled light)
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = 8.0 * scale_mult
	light.omni_range = 8.0 * scale_mult
	light.shadow_enabled = false
	_root.add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.4 * scale_mult)
	tween.tween_callback(light.queue_free)

	var idx := _next_free(_explosion_pool)
	if idx < 0:
		return
	var p := _explosion_pool[idx]
	p.position = pos
	p.lifetime = 0.55 * clampf(scale_mult, 0.7, 2.0)
	p.scale = Vector3.ONE * clampf(scale_mult, 0.7, 2.2)
	_explosion_mats[idx].color = color
	_explosion_mesh_mats[idx].albedo_color = color
	p.restart()

func spawn_muzzle_flash(pos: Vector3, dir: Vector3, color: Color, profile := "pulse", attachment: Node3D = null) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	var burst := Node3D.new()
	burst.set_script(preload("res://src/projectiles/muzzle_burst.gd"))
	if attachment and is_instance_valid(attachment):
		attachment.add_child(burst)
	else:
		_root.add_child(burst)
	burst.global_position = pos
	burst.look_at(pos + dir, Vector3.FORWARD if absf(dir.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
	burst.configure(profile, color)

func spawn_emp_burst(pos: Vector3, scale_mult: float = 2.4) -> void:
	spawn_shockwave(pos, Color(0.1, 0.75, 1.0, 0.8), scale_mult)
	spawn_shockwave(pos, Color(0.45, 0.95, 1.0, 0.55), scale_mult * 0.68)
	for i in range(3):
		spawn_hit_spark(pos + Vector3(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25), 0), Color(0.35, 0.9, 1.0))

## Expanding ring shockwave used for rockets / boss deaths.
func spawn_shockwave(pos: Vector3, color: Color = Color(1.0, 0.5, 0.2), max_scale: float = 4.0) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.44
	torus.outer_radius = 0.56
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position = pos
	ring.rotation = Vector3(PI * 0.5, 0, 0) # lie flat in the XY play plane
	_root.add_child(ring)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * max_scale, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)
