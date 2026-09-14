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

# Combat & Heat mechanics
var fire_cooldowns: Array[float] = [0.14, 0.32, 0.70]
var fire_heat_cost: Array[float] = [8.0, 18.0, 45.0]
var heat: float = 0.0
var max_heat: float = 100.0
var heat_dissipation_rate: float = 40.0
var is_overheated: bool = false
var overheat_timer: float = 0.0

var fire_timer: float = 0.0
var secondary_cooldown: float = 0.0
const SECONDARY_MAX_COOLDOWN: float = 3.5

var can_double_jump: bool = false
var is_dashing: bool = false
var dash_time_left: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0
var current_anim: String = ""

var invulnerable_timer: float = 0.0
var aim_direction: Vector3 = Vector3.RIGHT

# Preloaded projectile scenes
var proj_pulse: PackedScene = preload("res://src/projectiles/projectile.tscn")
var proj_spread: PackedScene = preload("res://src/projectiles/spread_projectile.tscn")
var proj_beam: PackedScene = preload("res://src/projectiles/beam_projectile.tscn")

@onready var visual_root: Node3D = $VisualRoot
@onready var muzzle: Marker3D = $VisualRoot/Muzzle
var anim_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var blaster_instance: Node3D = null
var aim_target: Marker3D = null
var aim_arm_modifier: LookAtModifier3D = null
var aim_forearm_modifier: LookAtModifier3D = null
var muzzle_flash_light: OmniLight3D = null

var aim_timer: float = 0.0
const AIM_HOLD_DURATION: float = 2.0

func _ready() -> void:
	add_to_group("player")
	GameManager.connect("player_died", _on_player_died)
	_find_animation_player()
	_setup_weapon_aim()
	_play_anim("idle")

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

func _setup_weapon_aim() -> void:
	var stack: Array[Node] = [visual_root]
	while stack.size() > 0:
		var curr = stack.pop_back()
		if curr is Skeleton3D:
			skeleton = curr
			break
		for c in curr.get_children():
			stack.push_back(c)

	if not skeleton:
		return

	# Hand attachment for blaster
	var hand_attachment := BoneAttachment3D.new()
	hand_attachment.name = "RightHandBlaster"
	hand_attachment.bone_name = "mixamorig_RightHand"
	skeleton.add_child(hand_attachment)

	var blaster_scene = load("res://assets/models/blaster_rifle.glb")
	if blaster_scene:
		blaster_instance = blaster_scene.instantiate()
		blaster_instance.name = "BlasterModel"
		blaster_instance.scale = Vector3(100.0, 100.0, 100.0)
		hand_attachment.add_child(blaster_instance)

		# Muzzle Marker at the tip of the blaster barrel
		var barrel_muzzle := Marker3D.new()
		barrel_muzzle.name = "GunMuzzle"
		barrel_muzzle.position = Vector3(0.0, 0.055, -0.45)
		blaster_instance.add_child(barrel_muzzle)
		muzzle = barrel_muzzle

		# Muzzle flash light
		muzzle_flash_light = OmniLight3D.new()
		muzzle_flash_light.light_color = Color(0.3, 0.9, 1.0)
		muzzle_flash_light.light_energy = 0.0
		muzzle_flash_light.omni_range = 3.5
		barrel_muzzle.add_child(muzzle_flash_light)

	# Create AimTarget in the world for LookAtModifier3D
	aim_target = Marker3D.new()
	aim_target.name = "AimTarget"
	add_child(aim_target)
	aim_target.top_level = true

	# LookAtModifier3D for Right Upper Arm
	aim_arm_modifier = LookAtModifier3D.new()
	aim_arm_modifier.name = "AimArmModifier"
	aim_arm_modifier.bone_name = "mixamorig_RightArm"
	aim_arm_modifier.forward_axis = LookAtModifier3D.BONE_AXIS_PLUS_Y
	aim_arm_modifier.target_node = aim_target.get_path()
	aim_arm_modifier.influence = 0.85
	skeleton.add_child(aim_arm_modifier)

	# LookAtModifier3D for Right Forearm
	aim_forearm_modifier = LookAtModifier3D.new()
	aim_forearm_modifier.name = "AimForearmModifier"
	aim_forearm_modifier.bone_name = "mixamorig_RightForeArm"
	aim_forearm_modifier.forward_axis = LookAtModifier3D.BONE_AXIS_PLUS_Y
	aim_forearm_modifier.target_node = aim_target.get_path()
	aim_forearm_modifier.influence = 1.0
	skeleton.add_child(aim_forearm_modifier)

func _physics_process(delta: float) -> void:
	if GameManager.health <= 0:
		return

	# Timers & Heat Dissipation
	if fire_timer > 0.0: fire_timer -= delta
	if dash_cooldown_timer > 0.0: dash_cooldown_timer -= delta
	if secondary_cooldown > 0.0: secondary_cooldown -= delta

	if is_overheated:
		overheat_timer -= delta
		heat = (overheat_timer / 1.2) * max_heat
		if overheat_timer <= 0.0:
			is_overheated = false
			SoundManager.play("shield_hit", 1.4, -2.0)
	else:
		heat = maxf(heat - heat_dissipation_rate * delta, 0.0)

	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		visual_root.visible = fmod(invulnerable_timer, 0.1) > 0.05
	else:
		visual_root.visible = true

	# 360° Mouse Aiming
	_update_aim()

	# Gravity & Grounding
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		can_double_jump = true

	# Jump & Thruster Jump
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			SoundManager.play("thruster", 1.2, -2.0)
		elif can_double_jump:
			velocity.y = double_jump_velocity
			can_double_jump = false
			SoundManager.play("thruster", 1.6, -1.0)
			FXManager.spawn_hit_spark(global_position + Vector3(0, -0.2, 0), Color(0.2, 0.8, 1.0))

	# Dash
	var input_x := Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		is_dashing = true
		dash_time_left = dash_duration
		dash_cooldown_timer = dash_cooldown
		dash_direction = input_x if input_x != 0.0 else (1.0 if visual_root.scale.x > 0 else -1.0)
		SoundManager.play("dash", 1.1, 0.0)
		FXManager.shake(0.2, 0.15)
		FXManager.spawn_hit_spark(global_position, Color(0.3, 0.9, 1.0))

	if is_dashing:
		dash_time_left -= delta
		velocity.x = dash_direction * dash_speed
		velocity.y = 0.0
		if dash_time_left <= 0.0:
			is_dashing = false
	else:
		if input_x != 0.0:
			velocity.x = move_toward(velocity.x, input_x * move_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0

	# Weapon Switching
	if Input.is_action_just_pressed("weapon_1"): GameManager.select_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"): GameManager.select_weapon(1)
	elif Input.is_action_just_pressed("weapon_3"): GameManager.select_weapon(2)

	# Firing Primary
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0 and not is_dashing and not is_overheated:
		_shoot()

	# Secondary EMP Grenade (Key: E or Q)
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_Q):
		if secondary_cooldown <= 0.0 and not is_dashing:
			_launch_secondary_emp()

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
	
	if muzzle:
		muzzle.look_at(muzzle.global_position + aim_direction, Vector3.UP)

func _update_weapon_aim(delta: float) -> void:
	if not aim_target or not aim_arm_modifier or not aim_forearm_modifier:
		return

	if aim_timer > 0.0:
		aim_timer -= delta

	# Decay muzzle flash light
	if muzzle_flash_light and muzzle_flash_light.light_energy > 0.0:
		muzzle_flash_light.light_energy = maxf(muzzle_flash_light.light_energy - delta * 30.0, 0.0)

	# Position AimTarget in world space along aim_direction from operative's chest/shoulder
	var aim_origin := global_position + Vector3(0.0, 1.15, 0.0)
	var target_pos := aim_origin + aim_direction * 4.5
	aim_target.global_position = target_pos

	# Aim influence: when mouse is active or shooting/aiming, full 1.0 influence!
	# Otherwise, blends to 0.25 (low-ready tactical stance)
	var is_actively_aiming := mouse_active or aim_timer > 0.0 or Input.is_action_pressed("shoot")
	var target_influence := 1.0 if is_actively_aiming else 0.25
	aim_arm_modifier.influence = lerpf(aim_arm_modifier.influence, target_influence * 0.85, 20.0 * delta)
	aim_forearm_modifier.influence = lerpf(aim_forearm_modifier.influence, target_influence, 20.0 * delta)

func _shoot() -> void:
	aim_timer = AIM_HOLD_DURATION
	if aim_arm_modifier:
		aim_arm_modifier.influence = 0.85
	if aim_forearm_modifier:
		aim_forearm_modifier.influence = 1.0
	if muzzle_flash_light:
		match GameManager.current_weapon:
			0: muzzle_flash_light.light_color = Color(0.2, 0.9, 1.0)
			1: muzzle_flash_light.light_color = Color(1.0, 0.6, 0.1)
			2: muzzle_flash_light.light_color = Color(0.2, 1.0, 0.8)
		muzzle_flash_light.light_energy = 3.5

	var current_w := GameManager.current_weapon
	fire_timer = fire_cooldowns[current_w]
	heat += fire_heat_cost[current_w]
	if heat >= max_heat:
		is_overheated = true
		overheat_timer = 1.2
		SoundManager.play("alarm", 1.3, 2.0)
		FXManager.spawn_hit_spark(global_position + Vector3(0, 1.2, 0), Color(1.0, 0.3, 0.0))

	var spawn_pos := muzzle.global_position if muzzle else global_position + aim_direction * 0.8
	spawn_pos.z = 0.0

	match current_w:
		0:
			var p = proj_pulse.instantiate()
			get_parent().add_child(p)
			p.global_position = spawn_pos
			p.init_projectile(aim_direction, 36.0, 28.0, Color(0.1, 0.9, 1.0), false, false)
			SoundManager.play("laser_pulse", 1.0 + randf_range(-0.05, 0.05), -2.0)
			FXManager.shake(0.1, 0.08)

		1:
			var angles := [-0.22, -0.11, 0.0, 0.11, 0.22]
			for angle in angles:
				var p = proj_spread.instantiate()
				get_parent().add_child(p)
				p.global_position = spawn_pos
				var spread_dir := aim_direction.rotated(Vector3(0, 0, 1), angle)
				p.init_projectile(spread_dir, 28.0, 18.0, Color(1.0, 0.5, 0.05), false, false)
			SoundManager.play("laser_spread", 1.0, 0.0)
			FXManager.shake(0.22, 0.12)

		2:
			var p = proj_beam.instantiate()
			get_parent().add_child(p)
			p.global_position = spawn_pos
			p.init_projectile(aim_direction, 55.0, 85.0, Color(0.3, 1.0, 0.9), false, true)
			SoundManager.play("laser_beam", 0.95, 2.0)
			FXManager.shake(0.48, 0.22)

func _launch_secondary_emp() -> void:
	secondary_cooldown = SECONDARY_MAX_COOLDOWN
	SoundManager.play("dash", 0.8, 2.0)
	FXManager.shake(0.3, 0.18)
	
	# Launch EMP shockwave projectile
	var p = proj_spread.instantiate()
	get_parent().add_child(p)
	p.global_position = global_position + aim_direction * 0.8
	p.init_projectile(aim_direction, 22.0, 90.0, Color(0.2, 0.7, 1.0), false, true)
	p.scale = Vector3(2.2, 2.2, 2.2)

func _on_player_died() -> void:
	FXManager.spawn_explosion(global_position, 2.0, Color(0.2, 0.8, 1.0))
	visible = false
