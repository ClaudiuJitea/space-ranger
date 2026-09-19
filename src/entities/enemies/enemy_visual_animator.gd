extends Node

## Plays Blender-authored presentation clips without owning combat state.
## Gameplay scripts remain authoritative; this component is visual-only.

@export var model_path: NodePath
@export var weapon_path: NodePath
@export var airborne_leg_lock := false
var player: AnimationPlayer = null
var aim_solver: WeaponAimSolver = null
var muzzle: Node3D = null
var current_clip := ""
var recoil := 0.0
var leg_lock: AirborneLegLock = null

func _ready() -> void:
	call_deferred("_bind_imported_animation")

func _bind_imported_animation() -> void:
	var model := get_node_or_null(model_path)
	if model == null:
		return
	player = _find_player(model)
	if player:
		for animation_name in player.get_animation_list():
			if animation_name.to_lower() in ["idle", "walk", "run"]:
				player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		_play_state("Idle")
	if weapon_path.is_empty():
		return
	var skeleton := _find_skeleton(model)
	var weapon := get_node_or_null(weapon_path) as Node3D
	if skeleton == null or weapon == null:
		push_warning("EnemyVisualAnimator: missing skeleton or weapon")
		return
	aim_solver = EnemyRifleAim.new()
	aim_solver.name = "EnemyWeaponAim"
	skeleton.add_child(aim_solver)
	aim_solver.setup(skeleton, weapon)
	aim_solver.aim_weight = 1.0
	aim_solver.reach = 0.10
	aim_solver.grip_drop = -0.01
	aim_solver.center_rifle_hold = true
	if airborne_leg_lock:
		leg_lock = AirborneLegLock.new()
		leg_lock.name = "AirborneLegLock"
		skeleton.add_child(leg_lock)
	muzzle = _find_muzzle(weapon)

func update_visual(travel_speed: float, aim_direction: Vector3, airborne: bool = false, flight_velocity: Vector3 = Vector3.ZERO, flight_acceleration: Vector3 = Vector3.ZERO, body_bank: Vector3 = Vector3.ZERO) -> void:
	var clip := "Idle"
	if not airborne_leg_lock and travel_speed > 0.18:
		var run_threshold := 2.3 if current_clip == "Run" else 2.75
		clip = "Run" if travel_speed > run_threshold or airborne else "Walk"
	_play_state(clip)
	if player:
		if clip == "Walk":
			player.speed_scale = clampf(travel_speed / 2.0, 0.65, 1.45)
		elif clip == "Run":
			player.speed_scale = clampf(travel_speed / 3.0, 0.8, 1.2)
		else:
			player.speed_scale = 1.0
	if leg_lock:
		leg_lock.set_flight_motion_full(flight_velocity, flight_acceleration, body_bank, get_physics_process_delta_time())
	if aim_solver:
		aim_solver.aim_direction = aim_direction.normalized() if aim_direction.length_squared() > 0.01 else Vector3.RIGHT
		recoil = move_toward(recoil, 0.0, 0.7 * get_physics_process_delta_time())
		aim_solver.recoil_offset = recoil

func apply_leg_impulse(impulse: Vector3) -> void:
	if leg_lock:
		leg_lock.apply_impulse(impulse)

func get_muzzle_position() -> Vector3:
	if muzzle and aim_solver and aim_solver.is_ready():
		return muzzle.global_position
	var weapon := get_node_or_null(weapon_path) as Node3D
	return weapon.global_position if weapon else Vector3.ZERO

func kick_weapon() -> void:
	recoil = 0.07

func play_clip(keyword: String) -> void:
	if player == null:
		return
	for animation_name in player.get_animation_list():
		if animation_name.to_lower().contains(keyword.to_lower()):
			player.play(animation_name, 0.08)
			current_clip = animation_name
			return
	# The shared Vanguard import only includes locomotion clips. A shot still
	# has visible recoil through the hand solver without freezing the legs.
	if keyword.to_lower() == "attack":
		kick_weapon()

func _play_state(name: String) -> void:
	if player == null or current_clip == name or not player.has_animation(name):
		return
	player.play(name, 0.18)
	current_clip = name

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _find_muzzle(root: Node) -> Node3D:
	for child in root.get_children():
		if child is Node3D and child.name.to_lower() == "muzzle":
			return child as Node3D
		var found := _find_muzzle(child)
		if found:
			return found
	return null

func _find_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null
