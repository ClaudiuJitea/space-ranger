extends CharacterBody3D

@export var move_speed: float = 11.5
@export var acceleration: float = 70.0
@export var friction: float = 60.0
@export var jump_velocity: float = 14.0
@export var double_jump_velocity: float = 11.5
@export var gravity: float = 32.0

@export var dash_speed: float = 28.0
@export var dash_duration: float = 0.22
@export var dash_cooldown: float = 0.7

# Combat & Heat mechanics (per weapon: cooldown / heat cost).
# Heat is the ammo economy: heat gain per second must outpace the
# heat_dissipation_rate for sustained fire to eventually overheat the suit.
# Pulse 61/s (spray-limited), Scatter 54/s, Railgun 50/s, Launcher 50/s.
var fire_cooldowns: Array[float] = [0.13, 0.55, 0.9, 0.60]
var fire_heat_cost: Array[float] = [8.0, 30.0, 45.0, 32.0]
var heat: float = 0.0
var max_heat: float = 100.0
var heat_dissipation_rate: float = 40.0
var is_overheated: bool = false
var overheat_timer: float = 0.0

var fire_timer: float = 0.0
var secondary_cooldown: float = 0.0
const SECONDARY_MAX_COOLDOWN: float = 3.5

# Platforming feel: coyote time + jump buffering
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.12
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var can_double_jump: bool = false
var is_dashing: bool = false
var dash_time_left: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0
var current_anim: String = ""

var aim_direction: Vector3 = Vector3.RIGHT

# Preloaded projectile scenes (per weapon slot)
var weapon_scenes: Array[PackedScene] = [
	preload("res://src/projectiles/projectile.tscn"),
	preload("res://src/projectiles/spread_projectile.tscn"),
	preload("res://src/projectiles/beam_projectile.tscn"),
	preload("res://src/projectiles/rocket_projectile.tscn"),
]
var proj_spread: PackedScene = preload("res://src/projectiles/spread_projectile.tscn")
var weapon_model_scenes: Array[PackedScene] = [
	preload("res://assets/models/weapon_blaster.glb"),
	preload("res://assets/models/weapon_scattergun.glb"),
	preload("res://assets/models/weapon_railgun.glb"),
	preload("res://assets/models/weapon_launcher.glb"),
]

@onready var visual_root: Node3D = $VisualRoot
var anim_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var weapon_root: Node3D = null
var weapon_instances: Array[Node3D] = []
var aim_solver: WeaponAimSolver = null
var muzzle_flash_light: OmniLight3D = null
var active_muzzle: Node3D = null

# Recoil state (visual kick fed to the aim solver)
var recoil_kick: float = 0.0
var recoil_pitch: float = 0.0

# Per-weapon support hand grip positions (model space, in metres)
const WEAPON_SUPPORT_GRIPS: Array[Vector3] = [
	Vector3(0.0, -0.24, 0.015),  # Slot 0: PX-9 Pulse Blaster (angled tactical foregrip)
	Vector3(0.0, -0.26, -0.010), # Slot 1: Scattergun (pump-action foregrip slide)
	Vector3(0.0, -0.22, -0.025), # Slot 2: Railgun (chassis underside grip)
	Vector3(0.0, -0.26, 0.010),  # Slot 3: Rocket Launcher (front grip handle)
]

var aim_timer: float = 0.0
const AIM_HOLD_DURATION: float = 2.0
const AIM_WEIGHT_IDLE: float = 1.0
const AIM_WEIGHT_FIRING: float = 1.0

# Pit recovery: below this height the suit recalls the operative to the last
# safe footing for a hull cost instead of falling forever.
const KILL_Y: float = -14.0
var last_safe_position: Vector3 = Vector3.ZERO
var _safe_pos_timer: float = 0.0
var _was_on_floor: bool = false
var _step_timer: float = 0.0
var _emp_was_cooling: bool = false

func _ready() -> void:
	add_to_group("player")
	GameManager.connect("player_died", _on_player_died)
	GameManager.player_node = self
	last_safe_position = global_position
	_find_animation_player()
	_setup_weapon_rig()
	_play_anim("idle")

func _exit_tree() -> void:
	if GameManager.player_node == self:
		GameManager.player_node = null

func _find_animation_player() -> void:
	# Locate AnimationPlayer in the imported glb child tree
	var stack: Array[Node] = [visual_root]
	while stack.size() > 0:
		var curr = stack.pop_back()
		if curr is AnimationPlayer:
			anim_player = curr
			break
		for c in curr.get_children():
			stack.push_back(c)

	if anim_player:
		for anim_name in anim_player.get_animation_list():
			var anim := anim_player.get_animation(anim_name)
			if anim_name.to_lower() in ["idle", "run", "walk"]:
				anim.loop_mode = Animation.LOOP_LINEAR

func _setup_weapon_rig() -> void:
	var stack: Array[Node] = [visual_root]
	while stack.size() > 0:
		var curr = stack.pop_back()
		if curr is Skeleton3D:
			skeleton = curr
			break
		for c in curr.get_children():
			stack.push_back(c)

	if not skeleton:
		push_warning("Player: no Skeleton3D found in the character model, weapon rig disabled")
		return

	# The weapon lives next to the skeleton and has its world transform written
	# by the solver every frame, so the barrel and the hand stay in lockstep.
	weapon_root = Node3D.new()
	weapon_root.name = "WeaponRoot"
	visual_root.add_child(weapon_root)

	# Instantiate every weapon once; swapping just toggles visibility.
	# Each model sits under a holder node: the aim solver writes the holder's
	# world transform, so the model's own local scale stays free for the
	# equip flourish tween.
	for i in range(weapon_model_scenes.size()):
		var holder := Node3D.new()
		holder.name = "WeaponPivot_%d" % i
		weapon_root.add_child(holder)
		var inst: Node3D = weapon_model_scenes[i].instantiate()
		inst.name = "Weapon_%d" % i
		holder.add_child(inst)
		weapon_instances.append(holder)

	muzzle_flash_light = OmniLight3D.new()
	muzzle_flash_light.light_color = Color(0.3, 0.9, 1.0)
	muzzle_flash_light.light_energy = 0.0
	muzzle_flash_light.omni_range = 4.5
	muzzle_flash_light.shadow_enabled = false

	# Two-bone IK solve that raises the right arm and points the barrel along
	# the player's aim direction, with matching two-handed support hand IK.
	aim_solver = WeaponAimSolver.new()
	aim_solver.name = "WeaponAimSolver"
	aim_solver.center_rifle_hold = true
	aim_solver.reach = 0.17
	aim_solver.grip_drop = -0.05
	aim_solver.two_handed = true
	aim_solver.support_grip = WEAPON_SUPPORT_GRIPS[0]
	aim_solver.aim_weight = AIM_WEIGHT_IDLE
	skeleton.add_child(aim_solver)
	aim_solver.setup(skeleton, weapon_instances[0])

	_equip_weapon_model(GameManager.current_weapon, true)
	GameManager.connect("weapon_changed", _on_weapon_changed)

func _find_muzzle(of: Node3D) -> Node3D:
	var found := of.find_child("Muzzle", true, false)
	if found:
		return found as Node3D
	# glTF import keeps the authoring names; accept the "Muzzle_*" marker
	# variants while ignoring mesh parts like the muzzle brake.
	for child in of.find_children("Muzzle_*", "", true, false):
		if child is Node3D and not (child is MeshInstance3D):
			return child as Node3D
	return null

func _equip_weapon_model(index: int, instant: bool = false) -> void:
	for i in range(weapon_instances.size()):
		weapon_instances[i].visible = (i == index)
	var inst := weapon_instances[index]
	active_muzzle = _find_muzzle(inst)
	if active_muzzle:
		if muzzle_flash_light.get_parent() == null:
			active_muzzle.add_child(muzzle_flash_light)
		elif muzzle_flash_light.get_parent() != active_muzzle:
			muzzle_flash_light.reparent(active_muzzle)
	aim_solver.weapon = inst
	if index >= 0 and index < WEAPON_SUPPORT_GRIPS.size():
		aim_solver.support_grip = WEAPON_SUPPORT_GRIPS[index]
	GameManager.current_weapon = index
	# Small draw-back flourish; recoil decays to zero in _physics_process.
	recoil_kick = 0.18
	recoil_pitch = 0.05

	# Swap flourish: pop the new weapon in with a scale punch. The tween plays
	# on the model child, so the solver driving the holder's transform never
	# stomps it.
	var model := inst.get_child(0) as Node3D
	if instant or model == null:
		if model:
			model.scale = Vector3.ONE
	else:
		model.scale = Vector3(0.2, 0.2, 0.2)
		var tw := create_tween()
		tw.tween_property(model, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_weapon_changed(index: int, _wname: String) -> void:
	if not skeleton:
		return
	if weapon_instances.size() > 0 and not weapon_instances[index].visible:
		_equip_weapon_model(index)

func _physics_process(delta: float) -> void:
	if GameManager.health <= 0:
		return

	_was_on_floor = is_on_floor()

	# Timers & Heat Dissipation
	if fire_timer > 0.0: fire_timer -= delta
	if dash_cooldown_timer > 0.0: dash_cooldown_timer -= delta
	if secondary_cooldown > 0.0: secondary_cooldown -= delta
	if coyote_timer > 0.0: coyote_timer -= delta
	if jump_buffer_timer > 0.0: jump_buffer_timer -= delta
	recoil_kick = lerpf(recoil_kick, 0.0, 14.0 * delta)
	recoil_pitch = lerpf(recoil_pitch, 0.0, 12.0 * delta)

	if is_overheated:
		overheat_timer -= delta
		heat = (overheat_timer / 1.2) * max_heat
		if overheat_timer <= 0.0:
			is_overheated = false
			SoundManager.play("shield_hit", 1.4, -2.0)
			GameManager.notify("HEAT VENTED — WEAPONS ONLINE", Color(0.4, 0.85, 1.0))
	else:
		heat = maxf(heat - heat_dissipation_rate * delta, 0.0)

	# Damage i-frames (managed by GameManager): blink the whole rig
	if GameManager.hurt_invuln_timer > 0.0:
		visual_root.visible = fmod(GameManager.hurt_invuln_timer, 0.1) > 0.05
	else:
		visual_root.visible = true

	# 360° Mouse Aiming
	_update_aim()

	# Gravity & Grounding (with coyote time)
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		can_double_jump = true
	else:
		coyote_timer -= delta
		velocity.y -= gravity * delta

	# Jump (buffered) & Thruster Jump
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER
	if jump_buffer_timer > 0.0:
		if is_on_floor() or coyote_timer > 0.0:
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			SoundManager.play("thruster", 1.2, -2.0)
		elif can_double_jump:
			velocity.y = double_jump_velocity
			can_double_jump = false
			jump_buffer_timer = 0.0
			SoundManager.play("thruster", 1.6, -1.0)
			FXManager.spawn_hit_spark(global_position + Vector3(0, -0.2, 0), Color(0.2, 0.8, 1.0))

	# Variable jump height: releasing jump trims upward momentum for responsive platforming
	if DisplayServer.get_name() != "headless" and Input.is_action_just_released("jump") and velocity.y > jump_velocity * 0.4:
		velocity.y = jump_velocity * 0.4

	# Dash
	var input_x := Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		is_dashing = true
		dash_time_left = dash_duration
		dash_cooldown_timer = dash_cooldown
		dash_direction = input_x if input_x != 0.0 else (1.0 if aim_direction.x >= 0.0 else -1.0)
		SoundManager.play("dash", 1.1, 0.0)
		FXManager.add_trauma(0.15)
		FXManager.spawn_hit_spark(global_position, Color(0.3, 0.9, 1.0))
		# Emergency heat vent: high-risk high-reward maneuver
		if heat > 65.0:
			heat = maxf(0.0, heat - 28.0)
			SoundManager.play("shield_hit", 1.6, -3.0)
			GameManager.notify("EMERGENCY HEAT VENT // -28 HU", Color(0.3, 0.9, 1.0))
			FXManager.spawn_hit_spark(global_position + Vector3(0, 0.6, 0), Color(0.2, 0.85, 1.0))

	# Dash jump cancel: convert horizontal burst into forward aerial momentum
	if is_dashing and Input.is_action_just_pressed("jump"):
		is_dashing = false
		dash_time_left = 0.0
		velocity.x = dash_direction * (move_speed * 1.45)
		velocity.y = jump_velocity
		SoundManager.play("thruster", 1.4, 0.0)
		FXManager.spawn_hit_spark(global_position, Color(0.2, 0.9, 1.0))
		FXManager.add_trauma(0.18)

	if is_dashing:
		dash_time_left -= delta
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0
		if dash_time_left <= 0.0:
			is_dashing = false
	else:
		if input_x != 0.0:
			var current_accel := acceleration
			if input_x * velocity.x < -0.1:
				current_accel *= 2.2 # Instant snappy turnaround boost
			velocity.x = move_toward(velocity.x, input_x * move_speed, current_accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	velocity.z = 0.0
	var fall_speed := velocity.y
	move_and_slide()
	global_position.z = 0.0

	# Remember solid footing for pit recovery (sampled a few times a second).
	if is_on_floor():
		_safe_pos_timer -= delta
		if _safe_pos_timer <= 0.0:
			_safe_pos_timer = 0.25
			last_safe_position = global_position
		# Landing feedback: dust puff + thud, stronger the harder the fall.
		if not _was_on_floor:
			_on_landed(fall_speed)
		# Footsteps, rate scaled by run speed.
		if not is_dashing and absf(velocity.x) > 2.0:
			_step_timer -= delta
			if _step_timer <= 0.0:
				_step_timer = 0.34
				SoundManager.play("footstep", randf_range(0.9, 1.15), -10.0)

	# Pit recovery: recall to the last safe footing at a hull cost.
	if global_position.y < KILL_Y:
		_fall_recover()

	# Weapon Switching (slots + mouse wheel cycling)
	if Input.is_action_just_pressed("weapon_1"): GameManager.select_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"): GameManager.select_weapon(1)
	elif Input.is_action_just_pressed("weapon_3"): GameManager.select_weapon(2)
	elif Input.is_action_just_pressed("weapon_4"): GameManager.select_weapon(3)
	if Input.is_action_just_pressed("weapon_next"): GameManager.cycle_weapon()
	elif Input.is_action_just_pressed("weapon_prev"): GameManager.cycle_weapon_backwards()

	# Firing Primary
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0 and not is_dashing and not is_overheated:
		_shoot()

	# Secondary EMP Grenade (input action: E / Q)
	if Input.is_action_just_pressed("emp") and secondary_cooldown <= 0.0 and not is_dashing:
		_launch_secondary_emp()
	elif secondary_cooldown > 0.0:
		_emp_was_cooling = true
	elif _emp_was_cooling:
		_emp_was_cooling = false
		GameManager.notify("EMP GRENADE RECHARGED", Color(0.4, 0.85, 1.0))

	# Animation & Orientation
	_update_animation(input_x)
	_update_visuals(delta)
	_update_weapon_aim(delta)

var mouse_active: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_active = true
		aim_timer = AIM_HOLD_DURATION
	elif event is InputEventMouseButton and event.is_pressed():
		mouse_active = true
		aim_timer = AIM_HOLD_DURATION

func _update_aim() -> void:
	var input_x := Input.get_axis("move_left", "move_right")
	if not mouse_active:
		if input_x != 0.0:
			aim_direction = Vector3.RIGHT if input_x > 0.0 else Vector3.LEFT
		return

	var camera := get_viewport().get_camera_3d()
	if not camera: return
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	if abs(ray_dir.z) > 0.0001:
		var t := -ray_origin.z / ray_dir.z
		var world_pos := ray_origin + ray_dir * t
		var dir := (world_pos - global_position)
		dir.z = 0.0
		if dir.length_squared() > 0.1:
			aim_direction = dir.normalized()

func _update_animation(input_x: float) -> void:
	if not anim_player:
		return

	if is_dashing:
		_play_anim("dash", 0.08, 2.5)
	elif not is_on_floor():
		if velocity.y > 1.0:
			_play_anim("jump", 0.12, 0.7)
		else:
			_play_anim("fall", 0.15, 0.4)
	else:
		if abs(velocity.x) > 0.8:
			_play_anim("run", 0.15, 1.25)
		else:
			_play_anim("idle", 0.2, 1.0)

func _play_anim(anim_name: String, blend: float = 0.15, speed: float = 1.0) -> void:
	if not anim_player:
		return

	var target_anim := ""
	for candidate in [anim_name, anim_name.capitalize(), anim_name.to_lower(), anim_name.to_upper()]:
		if anim_player.has_animation(candidate):
			target_anim = candidate
			break

	if target_anim.is_empty():
		var lower := anim_name.to_lower()
		if lower in ["jump", "fall", "dash"]:
			for candidate in ["Run", "run", "Walk", "walk"]:
				if anim_player.has_animation(candidate):
					target_anim = candidate
					break

	if target_anim.is_empty():
		return

	if current_anim != target_anim or not anim_player.is_playing():
		current_anim = target_anim
		anim_player.play(target_anim, blend, speed)
	else:
		anim_player.speed_scale = speed

func _update_visuals(delta: float) -> void:
	# Face aim direction cleanly via Y rotation:
	# Model forward is -Z. When facing right (+X), rotate by -100 deg (chest angled toward camera).
	# When facing left (-X), rotate by +100 deg (chest angled toward camera).
	var target_yaw := -deg_to_rad(100.0) if aim_direction.x >= 0.0 else deg_to_rad(100.0)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, 25.0 * delta)
	visual_root.scale = Vector3.ONE

	# Subtle dynamic lean in movement direction
	var target_tilt := -velocity.x * 0.015
	visual_root.rotation.z = lerpf(visual_root.rotation.z, target_tilt, 12.0 * delta)

func _update_weapon_aim(delta: float) -> void:
	if not aim_solver:
		return

	if aim_timer > 0.0:
		aim_timer -= delta

	# Decay muzzle flash light
	if muzzle_flash_light and muzzle_flash_light.light_energy > 0.0:
		muzzle_flash_light.light_energy = maxf(muzzle_flash_light.light_energy - delta * 30.0, 0.0)

	# Drive the IK solver: the weapon is always carried raised, and locks onto
	# the aim direction while the player aims or fires.
	aim_solver.aim_direction = aim_direction
	aim_solver.recoil_offset = recoil_kick
	aim_solver.recoil_pitch = recoil_pitch
	var is_actively_aiming := mouse_active or aim_timer > 0.0 or Input.is_action_pressed("shoot")
	var target_weight := AIM_WEIGHT_FIRING if is_actively_aiming else AIM_WEIGHT_IDLE
	aim_solver.aim_weight = lerpf(aim_solver.aim_weight, target_weight, 22.0 * delta)

func _muzzle_pos() -> Vector3:
	if active_muzzle:
		var pos := active_muzzle.global_position
		return pos
	return global_position + Vector3.UP * 1.05 + aim_direction * 0.8

func _rocket_lock(origin: Vector3, direction: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var forward := direction.normalized()
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		var target := candidate as Node3D
		var point := target.global_position
		if target is CharacterBody3D:
			point.y += 0.85
		var to_target := point - origin
		to_target.z = 0.0
		var distance := to_target.length()
		if distance < 0.1 or distance > 60.0:
			continue
		var alignment := forward.dot(to_target / distance)
		if alignment < 0.28:
			continue
		# Strongly prefer what the reticle is pointing at, then nearest distance.
		var score := distance * (1.6 - alignment)
		if candidate.is_in_group("bosses"):
			score *= 0.55
		if score < best_score:
			best_score = score
			best = target
	return best

func _shoot() -> void:
	aim_timer = AIM_HOLD_DURATION
	if aim_solver:
		aim_solver.aim_weight = AIM_WEIGHT_FIRING

	var current_w := GameManager.current_weapon
	fire_timer = fire_cooldowns[current_w]
	heat += fire_heat_cost[current_w]
	if heat >= max_heat:
		is_overheated = true
		overheat_timer = 1.2
		SoundManager.play("alarm", 1.3, 2.0)
		FXManager.spawn_hit_spark(global_position + Vector3(0, 1.2, 0), Color(1.0, 0.3, 0.0))
		GameManager.notify("⚠ SUIT OVERHEAT — VENTING", Color(1.0, 0.35, 0.1))

	# Recoil kick (visual + slight pitch) scaled per weapon
	var kick_strength: float = [0.28, 0.6, 0.75, 0.9][current_w]
	recoil_kick = kick_strength * 0.35
	recoil_pitch = kick_strength * 0.1

	var spawn_pos := _muzzle_pos()
	var flash_color: Color = GameManager.WEAPON_COLORS[current_w]
	if muzzle_flash_light:
		muzzle_flash_light.light_color = flash_color
		muzzle_flash_light.light_energy = 4.5
	FXManager.spawn_muzzle_flash(spawn_pos, aim_direction, flash_color, ["pulse", "scatter", "rail", "rocket"][current_w], active_muzzle)

	match current_w:
		0:
			var p = weapon_scenes[0].instantiate()
			get_parent().add_child(p)
			p.global_position = spawn_pos
			p.init_projectile(aim_direction, 38.0, 26.0, flash_color, false, false)
			SoundManager.play("laser_pulse", 1.0 + randf_range(-0.05, 0.05), -2.0)
			FXManager.shake(0.08, 0.06)

		1:
			var pellets := 6
			for i in range(pellets):
				var angle := lerpf(-0.30, 0.30, float(i) / float(pellets - 1)) + randf_range(-0.03, 0.03)
				var p = weapon_scenes[1].instantiate()
				get_parent().add_child(p)
				p.global_position = spawn_pos
				var spread_dir := aim_direction.rotated(Vector3(0, 0, 1), angle)
				p.init_projectile(spread_dir, 30.0, 15.0, flash_color, false, false)
			# Chunky scattergun shove: kick the player back a touch
			velocity.x -= aim_direction.x * 5.5
			if not is_on_floor():
				velocity.y -= aim_direction.y * 3.0
			SoundManager.play("laser_spread", 0.85, 0.0)
			FXManager.shake(0.28, 0.14)

		2:
			var p = weapon_scenes[2].instantiate()
			get_parent().add_child(p)
			p.global_position = spawn_pos
			p.init_projectile(aim_direction, 58.0, 85.0, flash_color, false, true)
			SoundManager.play("laser_beam", 0.95, 2.0)
			FXManager.shake(0.5, 0.24)

		3:
			var p = weapon_scenes[3].instantiate()
			get_parent().add_child(p)
			p.global_position = spawn_pos
			var lock := _rocket_lock(spawn_pos, aim_direction)
			var launch_direction := aim_direction
			if lock:
				var lock_point := lock.global_position + (Vector3.UP * 0.85 if lock is CharacterBody3D else Vector3.ZERO)
				launch_direction = (lock_point - spawn_pos).normalized()
				p.set_target(lock)
			p.init_projectile(launch_direction, 30.0, 85.0, flash_color, false, false)
			velocity.x -= aim_direction.x * 2.5
			SoundManager.play("rocket_launch", 1.0 + randf_range(-0.05, 0.05), 0.0)
			FXManager.shake(0.35, 0.18)

func _launch_secondary_emp() -> void:
	secondary_cooldown = SECONDARY_MAX_COOLDOWN
	SoundManager.play("dash", 0.8, 2.0)
	FXManager.shake(0.3, 0.18)
	FXManager.spawn_emp_burst(global_position + aim_direction * 0.8, 2.0)

	# Launch EMP shockwave projectile
	var p = proj_spread.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + aim_direction * 0.8
	p.init_projectile(aim_direction, 22.0, 90.0, Color(0.2, 0.7, 1.0), false, true)
	if p.has_method("set_fx_profile"):
		p.set_fx_profile("emp")
	p.scale = Vector3(2.2, 2.2, 2.2)

	# Launch Twin Havoc Homing Micro-Rockets alongside the EMP burst
	for angle in [-0.22, 0.22]:
		var rocket = weapon_scenes[3].instantiate()
		get_parent().add_child(rocket)
		rocket.global_position = global_position + Vector3(0, 1.2, 0)
		var r_dir := aim_direction.rotated(Vector3(0, 0, 1), angle)
		var lock := _rocket_lock(rocket.global_position, aim_direction)
		if lock:
			var lock_point := lock.global_position + (Vector3.UP * 0.85 if lock is CharacterBody3D else Vector3.ZERO)
			r_dir = (lock_point - rocket.global_position).normalized()
			rocket.set_target(lock)
		rocket.init_projectile(r_dir, 26.0, 75.0, Color(1.0, 0.6, 0.15), false, false)
	SoundManager.play("rocket_launch", 1.25, 2.0)

## Landing feedback scaled by impact speed — readable, never punishing.
func _on_landed(fall_speed: float) -> void:
	if fall_speed < -16.0:
		SoundManager.play("landing_hard", 1.0, -2.0)
		FXManager.shake(0.22, 0.14)
		FXManager.spawn_hit_spark(global_position + Vector3(0, -0.6, 0), Color(0.7, 0.8, 0.9))
	elif fall_speed < -7.0:
		SoundManager.play("landing", 1.0, -6.0)
		FXManager.spawn_hit_spark(global_position + Vector3(0, -0.6, 0), Color(0.6, 0.7, 0.85))

## Fell out of the world: pay hull, blink back to the last safe footing.
func _fall_recover() -> void:
	GameManager.take_player_damage(25.0)
	if GameManager.health <= 0.0:
		return # death flow takes over
	global_position = last_safe_position + Vector3(0, 0.4, 0)
	velocity = Vector3.ZERO
	is_dashing = false
	GameManager.hurt_invuln_timer = maxf(GameManager.hurt_invuln_timer, 1.2)
	SoundManager.play("respawn", 1.0, 0.0)
	FXManager.spawn_hit_spark(global_position, Color(0.3, 0.9, 1.0))
	GameManager.notify("EMERGENCY RECALL — HULL -25", Color(1.0, 0.6, 0.2))

func _on_player_died() -> void:
	FXManager.spawn_explosion(global_position, 2.0, Color(0.2, 0.8, 1.0))
	visible = false
