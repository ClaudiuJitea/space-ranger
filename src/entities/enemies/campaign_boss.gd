extends CharacterBody3D

## Three Blender-authored bosses with distinct, telegraphed three-phase encounters.
const MODELS := [preload("res://assets/models/campaign_bosses/apex.glb"), preload("res://assets/models/campaign_bosses/warden.glb"), preload("res://assets/models/campaign_bosses/seraph.glb")]
const TITLES := ["APEX IRON VANGUARD", "RIFT ALPHA MATRIARCH", "EMBERFALL SERAPH"]
const TINTS := [Color(1, 0.42, 0.08), Color(1, 0.08, 0.025), Color(1, 0.2, 0.08)]
const PROJECTILE := preload("res://src/projectiles/enemy_projectile.tscn")
const DRONE := preload("res://src/entities/enemies/drone.tscn")
const TURRET := preload("res://src/entities/enemies/turret.tscn")
const CRAWLER := preload("res://src/entities/enemies/crawler.tscn")
const ENFORCER := preload("res://src/entities/enemies/enforcer.tscn")
const HOMING_MISSILE := preload("res://src/projectiles/boss_homing_missile.tscn")
@export_range(0, 2) var boss_profile := 0
@export var max_health := 3500.0
var health := 3500.0
var phase := 1
var phase_2 := false
var is_dead := false
var active := false
var attack_state := -1
var state_timer := 1.8
var home_position := Vector3.ZERO
var player_ref: Node3D
var _charging := false
var _age := 0.0
var _exposed := 0.0
var _targets: Array[float] = []
var _markers: Array[Node3D] = []
var _muzzles: Array[Node3D] = []
var _rotor: Node3D
var _colossus: Node3D
var _charge_time := 0.0
var _charge_direction := -1.0
var _leap_pending := false
var _vanguard: Node3D
var _seraph: Node3D
var _impact_push := 0.0
var _facing_x := 1.0
var _stomp_pending := false
var _shield_active := false
var _shield_timer := 0.0
var _shield_mesh: MeshInstance3D
var _warning: Label3D
@onready var visual: Node3D = $Visual
@onready var core_light: OmniLight3D = $Visual/CoreLight

func _ready() -> void:
	add_to_group("bosses")
	health = max_health
	var old := visual.get_node_or_null("Model")
	if old:
		visual.remove_child(old)
		old.queue_free()
	var model: Node3D = MODELS[boss_profile].instantiate()
	model.name = "Model"
	visual.add_child(model)
	for name_text in ["MuzzleLeft", "MuzzleRight"]:
		var muzzle := model.find_child(name_text + "*", true, false) as Node3D
		if muzzle:
			_muzzles.append(muzzle)
	var core := model.find_child("CoreSocket*", true, false) as Node3D
	if core:
		core_light.global_position = core.global_position
	_rotor = model.find_child("ReactorRotor", true, false) as Node3D
	var shape := BoxShape3D.new()
	shape.size = [Vector3(4.3, 4.8, 1.6), Vector3(4.8, 4.2, 1.4), Vector3(5.8, 3.3, 1.3)][boss_profile]
	if boss_profile == 0:
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.72
		capsule.height = 4.9
		$CollisionShape3D.shape = capsule
		$CollisionShape3D.position.y = -0.15
		_vanguard = Node3D.new()
		_vanguard.set_script(preload("res://src/entities/enemies/vanguard_boss_visual.gd"))
		visual.add_child(_vanguard)
		_vanguard.bind(self, model)
		var armor_fill := OmniLight3D.new()
		armor_fill.position = Vector3(-1.0, 1.0, 2.8)
		armor_fill.light_color = Color(0.6, 0.75, 0.9)
		armor_fill.light_energy = 0.9
		armor_fill.omni_range = 5
		visual.add_child(armor_fill)
	elif boss_profile == 1:
		var beast_shape := BoxShape3D.new()
		beast_shape.size = Vector3(4.6, 3.4, 1.8)
		$CollisionShape3D.shape = beast_shape
		$CollisionShape3D.position = Vector3(0, -0.9, 0)
		_colossus = Node3D.new()
		_colossus.set_script(preload("res://src/entities/enemies/colossus_boss_visual.gd"))
		visual.add_child(_colossus)
		_colossus.bind(self, model)
	elif boss_profile == 2:
		var seraph_shape := BoxShape3D.new()
		seraph_shape.size = Vector3(6.6, 3.6, 1.6)
		$CollisionShape3D.shape = seraph_shape
		_seraph = Node3D.new()
		_seraph.set_script(preload("res://src/entities/enemies/seraph_boss_visual.gd"))
		visual.add_child(_seraph)
		_seraph.bind(self, model)
	else:
		$CollisionShape3D.shape = shape
	$CollisionShape3D.set_deferred("disabled", true)
	core_light.light_color = TINTS[boss_profile]
	_warning = Label3D.new()
	_warning.position.y = 3.15
	_warning.font = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
	_warning.font_size = 28
	_warning.pixel_size = 0.009
	_warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_warning.no_depth_test = true
	_warning.modulate = TINTS[boss_profile]
	visual.add_child(_warning)
	visible = false
	set_physics_process(false)

func activate_boss() -> void:
	if active or is_dead:
		return
	active = true
	visible = true
	home_position = global_position
	add_to_group("enemies")
	$CollisionShape3D.set_deferred("disabled", false)
	state_timer = 2.0
	_warning.text = "%s // PHASE 01" % TITLES[boss_profile]
	set_physics_process(true)
	GameManager.update_boss_health(health, max_health)
	SoundManager.set_music_mood("boss")
	if boss_profile == 0:
		_spawn_initial_squad()

func _physics_process(delta: float) -> void:
	if is_dead or not active:
		return
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node3D
	_age += delta
	_exposed = maxf(0, _exposed - delta)

	if _shield_active:
		_shield_timer -= delta
		if _shield_mesh and is_instance_valid(_shield_mesh):
			var pulse := 1.0 + sin(_age * 14.0) * 0.06
			_shield_mesh.scale = Vector3(pulse, pulse, pulse)
		if _shield_timer <= 0.0:
			_shield_active = false
			if _shield_mesh and is_instance_valid(_shield_mesh):
				_shield_mesh.visible = false
			_warning.text = "BARRIER COLLAPSED // ENGAGE"
			SoundManager.play("notify", 1.2, 0.0)

	if boss_profile == 0:
		_step_vanguard(delta)
	elif boss_profile == 1:
		_step_colossus(delta)
	else:
		var sway: float = [1.4, 2.7, 3.8][boss_profile]
		var altitude: float = [0.2, 0.65, 0.40][boss_profile]
		var target := home_position + Vector3(sin(_age * 0.65) * sway, sin(_age * 1.1) * altitude, 0)
		global_position = global_position.lerp(target, minf(1, delta * 2))
		global_position.z = 0
	if _rotor:
		_rotor.rotation.z += delta * (0.4 + phase * 0.2)

	if _exposed > 0.0:
		core_light.light_energy = 3.2 + sin(_age * 18.0) * 0.9
		core_light.light_color = Color(1.0, 0.7, 0.15)
	else:
		core_light.light_energy = 1.4 + sin(_age * 5.0) * 0.15
		core_light.light_color = TINTS[boss_profile]

	state_timer -= delta
	if state_timer <= 0 and GameManager.health > 0 and is_instance_valid(player_ref):
		if _charging:
			_charging = false
			_execute_attack()
			_clear_markers()
			if _exposed > 0:
				_warning.text = "CORE OVERHEAT // CRITICAL EXPOSURE" if _exposed >= 1.8 else "CORE EXPOSED // BONUS DAMAGE"
			state_timer = maxf(1.4, 2.8 - phase * 0.35)
		else:
			_telegraph()

func _step_vanguard(delta: float) -> void:
	var was_grounded := is_on_floor()
	var desired_x := home_position.x + sin(_age * 0.48) * 2.3
	var drive := clampf((desired_x - position.x) * 1.5, -1.1 - phase * 0.2, 1.1 + phase * 0.2)
	if is_instance_valid(player_ref):
		var separation := player_ref.position.x - position.x
		if absf(separation) > 7: drive = signf(separation) * (1.8 + phase * 0.2)
		elif absf(separation) < 3.5: drive = -signf(separation) * 1.2
		var target_facing := -1.0 if player_ref.position.x < position.x else 1.0
		_facing_x = move_toward(_facing_x, target_facing, delta * 3.0)
	if position.x < home_position.x - 8: drive = maxf(0, drive)
	elif position.x > home_position.x + 8: drive = minf(0, drive)
	velocity.x = move_toward(velocity.x, drive + _impact_push, delta * 6)
	_impact_push = move_toward(_impact_push, 0, delta * 2.2)
	velocity.y -= 24 * delta
	velocity.z = 0
	move_and_slide()
	if position.x < home_position.x - 8:
		velocity.x = maxf(0, velocity.x)
	elif position.x > home_position.x + 8:
		velocity.x = minf(0, velocity.x)
	if _stomp_pending and not was_grounded and is_on_floor():
		_stomp_pending = false
		_ground_shock()
	if is_instance_valid(player_ref) and absf(player_ref.position.x - position.x) < 1.1 and player_ref.position.y < position.y + 0.4 and player_ref.position.y > position.y - 2.8:
		GameManager.take_player_damage(18)
		if player_ref is CharacterBody3D:
			player_ref.velocity.x = -9 if player_ref.position.x < position.x else 9
			player_ref.velocity.y = maxf(5, player_ref.velocity.y)

func _step_colossus(delta: float) -> void:
	var was_grounded := is_on_floor()
	_charge_time = maxf(0, _charge_time - delta)
	var drive := 0.0
	if is_instance_valid(player_ref):
		var separation := player_ref.position.x - position.x
		if absf(separation) > 2.8:
			drive = signf(separation) * (3.0 + phase * 0.4)
	# Crouch during the warning, then hunt again during recovery.
	if _charging:
		drive = 0
	if _charge_time > 0:
		drive = _charge_direction * (4.5 if _leap_pending else 7 + phase * 0.7)
	if position.x < home_position.x - 8.5:
		drive = maxf(1.5, drive)
		_charge_time = 0
	elif position.x > home_position.x + 8.5:
		drive = minf(-1.5, drive)
		_charge_time = 0
	velocity.x = move_toward(velocity.x, drive + _impact_push, delta * 25)
	_impact_push = move_toward(_impact_push, 0, delta * 2.2)
	velocity.y -= 28 * delta
	velocity.z = 0
	move_and_slide()
	if _leap_pending and not was_grounded and is_on_floor():
		_leap_pending = false
		_colossus_slam()
	if is_instance_valid(player_ref) and absf(player_ref.position.x - position.x) < 1.5 and player_ref.position.y > position.y - 2.8 and player_ref.position.y < position.y + 1:
		GameManager.take_player_damage(22)
		if player_ref is CharacterBody3D:
			player_ref.velocity.x = -12 if player_ref.position.x < position.x else 12
			player_ref.velocity.y = maxf(5, player_ref.velocity.y)

func _colossus_attack() -> void:
	match attack_state:
		0:
			_charge_direction = -1 if player_ref.position.x < position.x else 1
			_charge_time = 0.85
		1:
			if is_on_floor(): _colossus_slam()
		2:
			if is_on_floor():
				velocity.y = 12.5
				_leap_pending = true
				_charge_time = 0.85
				_charge_direction = -1 if player_ref.position.x < position.x else 1
		3:
			var heading := (player_ref.global_position + Vector3.UP - global_position).normalized()
			heading.z = 0
			_fan(heading, 5 + phase * 2, 1.3, 12 + phase)
	SoundManager.play("boss_explosion", 1.25, -7)
	FXManager.shake(0.15, 0.15)

func _colossus_slam() -> void:
	_colossus.slam()
	var foot_y := global_position.y - 2.6
	FXManager.spawn_shockwave(Vector3(position.x, foot_y + 0.12, 0), TINTS[1], 6)
	FXManager.spawn_explosion(Vector3(position.x, foot_y + 0.3, 0), 0.5, TINTS[1])
	FXManager.shake(0.4, 0.35)
	for side in [-1.0, 1.0]:
		_bolt(Vector3(position.x, foot_y + 0.55, 0), Vector3(side, 0, 0), 11 + phase, 20)
	if is_instance_valid(player_ref) and absf(player_ref.position.x - position.x) < 5 and player_ref.position.y < foot_y + 0.5:
		GameManager.take_player_damage(24)
		if player_ref is CharacterBody3D:
			player_ref.velocity += Vector3(-8 if player_ref.position.x < position.x else 8, 7, 0)

func _ground_shock() -> void:
	var ground_y := global_position.y - 2.6
	FXManager.spawn_shockwave(Vector3(global_position.x, ground_y + 0.1, 0), TINTS[0], 5)
	SoundManager.play("boss_explosion", 1.5, -7)
	FXManager.shake(0.3, 0.3)
	for side in [-1.0, 1.0]:
		for height in [0.55, 1.05]:
			_bolt(Vector3(global_position.x, ground_y + height, 0), Vector3(side, 0, 0), 12, 18)

func _telegraph() -> void:
	var max_states := 5 if boss_profile == 0 else 4
	attack_state = (attack_state + 1) % max_states
	_charging = true
	state_timer = maxf(1.15, 1.6 - phase * 0.15)
	var names_vanguard := [
		"ROTARY CANNON // DASH & WEAVE",
		"MISSILE PODS LOCKING // PREPARE EVASION",
		"HEAVY MORTAR // JUMP OR DASH",
		"THRUSTER STOMP // JUMP TO DODGE",
		"ESCORT UPLINK // REINFORCEMENTS"
	]
	var names_colossus := [
		"BEAST RUSH // DASH",
		"FURNACE SLAM // JUMP",
		"POUNCE // MOVE",
		"MOLTEN SHARDS // FIND A GAP"
	]
	var names_seraph := [
		"INFERNO VOLLEY // EVADE",
		"WING SWEEP // DASH",
		"SOLAR MISSILES // DASH OR INTERCEPT",
		"SERAPH ESCORT"
	]
	if boss_profile == 0:
		_warning.text = names_vanguard[attack_state]
	elif boss_profile == 1:
		_warning.text = names_colossus[attack_state]
	else:
		_warning.text = names_seraph[attack_state]

	SoundManager.play("alarm", 1.15, -9)
	if boss_profile == 0 and attack_state == 1:
		SoundManager.play("alarm", 1.35, -4)
	elif boss_profile == 0 and attack_state == 2:
		SoundManager.play("alarm", 1.2, -4)
	elif attack_state == 2 and boss_profile == 2:
		SoundManager.play("rocket_launch", 1.1, -3)

func _execute_attack() -> void:
	if not is_instance_valid(player_ref) or is_dead:
		return
	if boss_profile == 1:
		_colossus_attack()
		return
	var target := player_ref.global_position + Vector3.UP * 0.9
	var heading := (target - global_position).normalized()
	heading.z = 0

	if boss_profile == 0:
		match attack_state:
			0:
				_cannon_burst()
				_exposed = 1.2
			1:
				var missile_count := 3 + phase * 2
				_fire_homing_missiles(missile_count)
				_exposed = 1.8
			2:
				_fire_apex_mortar()
				_exposed = 1.6
			3:
				_vanguard_stomp()
				_exposed = 1.0
			4:
				_tactical_reinforcements()
				_exposed = 1.4
		SoundManager.play("enemy_laser", 0.75, -3)
		FXManager.shake(0.16, 0.14)
		return

	# Seraph boss profile == 2
	match attack_state:
		0:
			_fan(heading, 3 + phase, 0.70, 11.0 + phase * 0.8)
			_exposed = 1.2
		1:
			_fan(heading, 4 + phase, 0.85, 12.0)
			_exposed = 1.4
		2:
			var missile_count := 2 + phase
			_fire_seraph_missiles(missile_count)
			_exposed = 1.6
		3:
			var support_count := 0
			for drone in get_tree().get_nodes_in_group("boss_support"):
				if is_instance_valid(drone):
					support_count += 1
			if support_count < 1:
				var drone := DRONE.instantiate()
				drone.position = global_position + Vector3(-3, 1.2, 0)
				drone.add_to_group("boss_support")
				get_parent().add_child(drone)
			_exposed = 1.4
	SoundManager.play("enemy_laser", 0.75 + boss_profile * 0.1, -3)
	FXManager.shake(0.15, 0.14)

func _cannon_burst() -> void:
	for volley in range(3 + phase):
		if is_dead or not is_instance_valid(player_ref):
			return
		for muzzle in _muzzles:
			var heading := (player_ref.global_position + Vector3.UP * 0.9 - muzzle.global_position).normalized()
			heading.z = 0
			_bolt(muzzle.global_position, heading.normalized(), 18, 12)
		await get_tree().create_timer(0.11, false).timeout

func _fire_homing_missiles(count: int) -> void:
	var left_pod := visual.find_child("ShoulderRocketPod_L*", true, false) as Node3D
	var right_pod := visual.find_child("ShoulderRocketPod_R*", true, false) as Node3D
	var left_pos: Vector3 = left_pod.global_position if left_pod else (global_position + Vector3(-0.8, 1.8, 0))
	var right_pos: Vector3 = right_pod.global_position if right_pod else (global_position + Vector3(0.8, 1.8, 0))

	for i in range(count):
		if is_dead or not is_instance_valid(player_ref):
			return
		var use_left := (i % 2 == 0)
		var origin := left_pos if use_left else right_pos
		var arc_angle := randf_range(PI * 0.28, PI * 0.42)
		var x_dir := -1.0 if use_left else 1.0
		var launch_dir := Vector3(x_dir * cos(arc_angle), sin(arc_angle), 0).normalized()

		var missile := HOMING_MISSILE.instantiate()
		get_parent().add_child(missile)
		missile.global_position = origin
		missile.init_missile(launch_dir, 12.0, 12.0 + phase, 13.0 + phase)

		FXManager.spawn_muzzle_flash(origin, launch_dir, Color(1.0, 0.5, 0.1))
		SoundManager.play("rocket_launch", randf_range(1.1, 1.3), -2.0)
		FXManager.shake(0.1, 0.08)

		await get_tree().create_timer(0.16, false).timeout

func _fire_seraph_missiles(count: int) -> void:
	var left_nozzle := visual.find_child("ThrusterSocket_L*", true, false) as Node3D
	var right_nozzle := visual.find_child("ThrusterSocket_R*", true, false) as Node3D
	var left_pos: Vector3 = left_nozzle.global_position if left_nozzle else (global_position + Vector3(-1.4, 0.5, 0))
	var right_pos: Vector3 = right_nozzle.global_position if right_nozzle else (global_position + Vector3(1.4, 0.5, 0))

	for i in range(count):
		if is_dead or not is_instance_valid(player_ref):
			return
		var use_left := (i % 2 == 0)
		var origin := left_pos if use_left else right_pos
		var arc_angle := randf_range(PI * 0.25, PI * 0.45)
		var x_dir := -1.0 if use_left else 1.0
		var launch_dir := Vector3(x_dir * cos(arc_angle), sin(arc_angle), 0).normalized()

		var missile := HOMING_MISSILE.instantiate()
		get_parent().add_child(missile)
		missile.global_position = origin
		missile.init_missile(launch_dir, 12.0, 12.0 + phase, 13.0 + phase)

		FXManager.spawn_muzzle_flash(origin, launch_dir, TINTS[boss_profile])
		SoundManager.play("rocket_launch", randf_range(1.15, 1.35), -2.0)
		FXManager.shake(0.1, 0.08)

		await get_tree().create_timer(0.18, false).timeout

func _fire_apex_mortar() -> void:
	if is_dead or not is_instance_valid(player_ref):
		return
	var aperture := visual.find_child("ChestBeamAperture*", true, false) as Node3D
	var origin: Vector3 = aperture.global_position if aperture else (global_position + Vector3(0, 0.5, 0))
	var target_x := player_ref.global_position.x
	var target_pos := Vector3(target_x, 0.0, 0)

	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.0
	ring.outer_radius = 1.2
	marker.mesh = ring
	marker.material_override = preload("res://src/projectiles/shot_visual.gd").luminous(TINTS[0], 2.0)
	get_parent().add_child(marker)
	marker.position = Vector3(target_x, 0.06, 0)

	var to_target := target_pos - origin
	var mortar_dir := Vector3(to_target.x * 0.4, 8.0, 0).normalized()
	_bolt(origin, mortar_dir, 14.0, 16.0)
	FXManager.spawn_muzzle_flash(origin, mortar_dir, TINTS[0])
	SoundManager.play("explosion", 1.1, 0.0)
	FXManager.shake(0.25, 0.2)

	var tw := marker.create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func():
		if is_instance_valid(marker):
			FXManager.spawn_explosion(marker.position, 1.8, TINTS[0])
			FXManager.spawn_shockwave(marker.position, TINTS[0], 4.0)
			SoundManager.play("boss_explosion", 1.2, 0.0)
			FXManager.shake(0.35, 0.25)
			if is_instance_valid(player_ref) and absf(player_ref.global_position.x - target_x) < 2.0 and player_ref.global_position.y < 1.4:
				GameManager.take_player_damage(18.0)
			marker.queue_free()
	)

func _vanguard_stomp() -> void:
	if is_on_floor():
		velocity.y = 13.0
		_stomp_pending = true
		_impact_push = clampf((player_ref.position.x - position.x) * 0.5, -3, 3)
		SoundManager.play("thruster", 0.9, 2.0)

func _spawn_sidekick(scene: PackedScene, spawn_pos: Vector3) -> Node3D:
	var sidekick := scene.instantiate() as Node3D
	sidekick.position = spawn_pos
	sidekick.position.z = 0.0
	sidekick.add_to_group("boss_sidekicks")
	get_parent().add_child(sidekick)
	FXManager.spawn_shockwave(spawn_pos, TINTS[boss_profile], 2.5)
	FXManager.spawn_muzzle_flash(spawn_pos, Vector3.UP, TINTS[boss_profile])
	return sidekick

func _count_alive_sidekicks() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("boss_sidekicks"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			count += 1
	return count

func _spawn_initial_squad() -> void:
	# Keep arena clean at start so player can focus on boss duel
	pass

func _deploy_phase_reinforcements(p: int) -> void:
	if _count_alive_sidekicks() >= 1:
		return
	if p == 2:
		_spawn_sidekick(DRONE, home_position + Vector3(-4.0, 2.5, 0))
	elif p == 3:
		_spawn_sidekick(CRAWLER, Vector3(home_position.x + 4.0, home_position.y - 2.6, 0))

func _tactical_reinforcements() -> void:
	var alive := _count_alive_sidekicks()
	if alive < 1:
		var scene: PackedScene = DRONE if randf() < 0.5 else CRAWLER
		var spawn_pos := home_position + Vector3(-4.0 if randf() < 0.5 else 4.0, 2.5 if scene == DRONE else home_position.y - 2.6, 0)
		_spawn_sidekick(scene, spawn_pos)
		_warning.text = "ESCORT ARRIVED // SUPPRESSION ACTIVE"
	else:
		var heading := (player_ref.global_position + Vector3.UP * 0.8 - global_position).normalized()
		heading.z = 0
		_fan(heading, 4 + phase, 0.75, 12)

func _activate_shield(duration: float) -> void:
	_shield_active = true
	_shield_timer = duration
	if not _shield_mesh:
		_shield_mesh = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 2.4
		s.height = 4.8
		_shield_mesh.mesh = s
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(0.2, 0.6, 1.0, 0.38)
		_shield_mesh.material_override = mat
		visual.add_child(_shield_mesh)
		_shield_mesh.position = Vector3(0, 0.2, 0)
	_shield_mesh.visible = true
	_shield_mesh.scale = Vector3.ONE * 0.5
	var tween := create_tween()
	tween.tween_property(_shield_mesh, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_warning.text = "KINETIC BARRIER DEPLOYED"
	SoundManager.play("shield_hit", 1.0, 4.0)

func _fan(heading: Vector3, count: int, spread: float, speed: float) -> void:
	for i in count:
		var direction := heading.rotated(Vector3.BACK, lerpf(-spread / 2, spread / 2, float(i) / float(count - 1)))
		_bolt(_muzzles[i % _muzzles.size()].global_position if not _muzzles.is_empty() else global_position, direction, speed, 11)

func _bolt(origin: Vector3, heading: Vector3, speed: float, damage: float) -> void:
	var bolt := PROJECTILE.instantiate()
	get_parent().add_child(bolt)
	bolt.global_position = origin
	bolt.init_projectile(heading, speed, damage, TINTS[boss_profile], true)
	FXManager.spawn_muzzle_flash(origin, heading, TINTS[boss_profile])
	if boss_profile == 0 and _vanguard:
		_vanguard.kick()
		_impact_push = clampf(_impact_push - heading.x * 0.12, -2, 2)
	elif boss_profile == 2 and _seraph:
		_seraph.kick()

func take_damage(amount: float) -> void:
	if not active or is_dead:
		return
	if _shield_active:
		SoundManager.play("shield_hit", 1.2, 0.0)
		FXManager.spawn_hit_spark(global_position + Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 1.5), 0), Color(0.3, 0.7, 1.0))
		return

	var effective_damage := amount
	if boss_profile == 0:
		var is_overheated := _exposed > 0.0
		var is_above := is_instance_valid(player_ref) and player_ref.global_position.y > global_position.y + 1.4
		var is_flanking := false
		if is_instance_valid(player_ref):
			var rel_x := player_ref.global_position.x - global_position.x
			is_flanking = (rel_x * _facing_x) < -0.2

		if is_overheated:
			effective_damage *= 1.5
			SoundManager.play("hitmarker", 1.3, 1.0)
			FXManager.spawn_hit_spark(global_position + Vector3(0, 0.5, 0), Color(1.0, 0.85, 0.2))
		elif is_above or is_flanking:
			effective_damage *= 1.2
			SoundManager.play("hit", 1.1, 0.0)
			FXManager.spawn_hit_spark(global_position, Color(1.0, 0.5, 0.1))
		else:
			effective_damage *= 1.0
			SoundManager.play("hit", 0.9, 0.0)
			FXManager.spawn_hit_spark(global_position, Color(1.0, 0.5, 0.1))
	elif boss_profile == 2:
		if _exposed > 0.0:
			effective_damage *= 1.45
			SoundManager.play("hitmarker", 1.3, 1.0)
			FXManager.spawn_hit_spark(global_position, Color(1.0, 0.85, 0.2))
		else:
			effective_damage *= 1.0
	else:
		if _exposed > 0.0:
			effective_damage *= 1.35

	if boss_profile < 2 and amount >= 40 and is_instance_valid(player_ref):
		_impact_push = clampf(_impact_push + (1 if player_ref.position.x < position.x else -1) * (0.35 if boss_profile == 1 else 0.7), -2.5, 2.5)

	health = maxf(0, health - effective_damage)
	GameManager.update_boss_health(health, max_health)

	var next_phase := 3 if health <= max_health * 0.35 else (2 if health <= max_health * 0.70 else 1)
	if next_phase > phase and health > 0:
		phase = next_phase
		phase_2 = true
		GameManager.notify("%s // PHASE %02d" % [TITLES[boss_profile], phase], TINTS[boss_profile])
		FXManager.spawn_shockwave(global_position, TINTS[boss_profile], 5.0)
		if boss_profile == 0:
			_activate_shield(1.4)
			_deploy_phase_reinforcements(phase)

	if health <= 0:
		_die()

func _clear_markers() -> void:
	for marker in _markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()

func _die() -> void:
	is_dead = true
	_clear_markers()
	if _shield_mesh and is_instance_valid(_shield_mesh):
		_shield_mesh.queue_free()

	for sidekick in get_tree().get_nodes_in_group("boss_sidekicks"):
		if is_instance_valid(sidekick):
			if sidekick.has_method("take_damage"):
				sidekick.take_damage(999.0)
			else:
				sidekick.queue_free()

	_spawn_armor_debris()
	$CollisionShape3D.set_deferred("disabled", true)
	_warning.text = "REACTOR COLLAPSE"
	GameManager.add_score(4000 + boss_profile * 2000)
	SoundManager.play("boss_explosion", 0.9, 4)
	for i in range(5):
		FXManager.spawn_explosion(global_position + Vector3(randf_range(-1.5, 1.5), randf_range(-1, 1), 0), 1.1, TINTS[boss_profile])
		await get_tree().create_timer(0.18, false).timeout
	FXManager.spawn_shockwave(global_position, TINTS[boss_profile], 7)
	visible = false
	await get_tree().create_timer(0.4, false).timeout
	GameManager.submit_score(GameManager.score)
	GameManager.emit_signal("level_completed")
	queue_free()

func _spawn_armor_debris() -> void:
	for i in range(12 if boss_profile == 2 else 8):
		var debris := RigidBody3D.new()
		debris.add_to_group("boss_debris")
		debris.mass = 2.0
		debris.collision_layer = 4
		debris.collision_mask = 1
		debris.continuous_cd = true
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.28, 0.14, 0.38) if boss_profile == 2 else Vector3(0.24, 0.12, 0.34)
		collision.shape = shape
		debris.add_child(collision)
		var fragment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		fragment.mesh = mesh
		var mat := StandardMaterial3D.new()
		if boss_profile == 2:
			mat.albedo_color = Color(0.12, 0.15, 0.18)
			mat.emission_enabled = (i % 3 == 0)
			mat.emission = Color(1.0, 0.40, 0.08)
			mat.emission_energy_multiplier = 2.5
		elif boss_profile == 1:
			mat.albedo_color = Color(0.65, 0.66, 0.6)
		else:
			mat.albedo_color = Color(0.12, 0.16, 0.17)
		mat.metallic = 0.8
		mat.roughness = 0.45
		fragment.material_override = mat
		debris.add_child(fragment)
		get_parent().add_child(debris)
		debris.global_position = global_position + Vector3(randf_range(-0.8, 0.8), randf_range(-1, 1), 0.5)
		debris.linear_velocity = Vector3(randf_range(-5, 5), randf_range(4, 9), randf_range(-3, 3))
		debris.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		var tween := debris.create_tween()
		tween.tween_interval(5)
		tween.tween_callback(debris.queue_free)
