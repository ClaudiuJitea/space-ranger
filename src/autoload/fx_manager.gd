extends Node

# FX Manager: Spawns particle bursts, camera shake, and visual shockwaves

signal camera_shake_requested(intensity: float, duration: float)

func shake(intensity: float = 0.3, duration: float = 0.25) -> void:
	emit_signal("camera_shake_requested", intensity, duration)

func spawn_hit_spark(pos: Vector3, color: Color = Color(0.2, 0.9, 1.0)) -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	
	var p := GPUParticles3D.new()
	p.position = pos
	p.emitting = true
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
	mat.color = color
	p.process_material = mat
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	var std_mat := StandardMaterial3D.new()
	std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	std_mat.albedo_color = color
	mesh.material = std_mat
	p.draw_pass_1 = mesh
	
	tree.current_scene.add_child(p)
	
	await tree.create_timer(0.4).timeout
	if is_instance_valid(p):
		p.queue_free()

func spawn_explosion(pos: Vector3, scale_mult: float = 1.0, color: Color = Color(1.0, 0.5, 0.1)) -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	
	shake(0.4 * scale_mult, 0.3)
	
	# Central flash light
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = 8.0 * scale_mult
	light.omni_range = 8.0 * scale_mult
	tree.current_scene.add_child(light)
	
	# Sparks burst
	var p := GPUParticles3D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.98
	p.lifetime = 0.55 * scale_mult
	p.amount = int(28 * scale_mult)
	
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0 * scale_mult
	mat.initial_velocity_max = 12.0 * scale_mult
	mat.gravity = Vector3(0, -12.0, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.25 * scale_mult
	mat.color = color
	p.process_material = mat
	
	var mesh := SphereMesh.new()
	mesh.radius = 0.1 * scale_mult
	mesh.height = 0.2 * scale_mult
	var std_mat := StandardMaterial3D.new()
	std_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	std_mat.albedo_color = color
	mesh.material = std_mat
	p.draw_pass_1 = mesh
	
	tree.current_scene.add_child(p)
	
	var tween := tree.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.4 * scale_mult)
	tween.tween_callback(light.queue_free)
	
	await tree.create_timer(0.7 * scale_mult).timeout
	if is_instance_valid(p):
		p.queue_free()
