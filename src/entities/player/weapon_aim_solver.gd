extends SkeletonModifier3D
class_name WeaponAimSolver

## Poses the operative's right arm with an analytic two-bone IK solve and drives
## the held weapon so that its barrel always follows `aim_direction`.
##
## The weapon models in `assets/models/weapon_*.glb` (blaster, scattergun,
## railgun, launcher) are authored with the barrel along their local -Y and the
## sights along their local -Z, with the pistol-grip centre near (0, 0.05, 0).
## `MOUNT_ROTATION` rotates a model into the hand bone's frame so that the
## pistol grip sits in the fist the way a right hand really holds it: palm
## against the front of the grip, fingers wrapping across it, thumb over the
## top of the receiver.
##
## The weapon node is a plain scene child (not a BoneAttachment3D): its world
## transform is written straight from the solved hand pose, so the hand, the
## drawn model and the muzzle marker can never drift apart.

const MOUNT_ROTATION := Vector3(0.0, 0.0, -PI * 0.5)
const MODEL_SCALE := 100.0 # skeleton space is centimetres, the model is metres

## Rotates the model's own axes (barrel -Y, sights -Z) into the standard
## -Z-forward / +Y-up frame.
static var MODEL_AXIS_FIX := Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0))

## Distance of the pistol grip in front of the shoulder joint (metres).
@export var reach: float = 0.37
## Height of the pistol grip relative to the shoulder joint (metres).
@export var grip_drop: float = -0.085
## Center the hold between shoulders for a two-handed rifle stance.
@export var center_rifle_hold: bool = false
## Support hand (two-handed holding) configuration
@export var two_handed: bool = true
@export var support_grip: Vector3 = Vector3(0.0, -0.16, 0.02)
@export var support_fist_offset: Vector3 = Vector3(0.0, 0.04, 0.015)
## Centre of the closed fist, expressed in hand-bone space (metres).
@export var fist_offset: Vector3 = Vector3(0.0, 0.045, 0.02)
## Centre of the pistol grip, expressed in weapon model space (metres).
## The weapon set is authored with the grip centre near (0, 0.05, 0).
@export var grip_local: Vector3 = Vector3(0.0, 0.05, 0.0)
## Elbow pole direction weights (down / back / towards the camera).
@export var elbow_drop: float = 0.55
@export var elbow_back: float = 0.85
@export var elbow_side: float = 0.0
## 0 = keep the animation pose, 1 = fully aim the weapon at `aim_direction`.
@export_range(0.0, 1.0) var aim_weight: float = 1.0
## When true, `pose_capture` receives the global bone poses the renderer uses.
## Note: the engine restores the animation poses right after the skeleton
## update, so this is the only way to observe what the GPU is actually sent.
var capture_pose := false
var pose_capture: Array[Transform3D] = []

## Aim direction in world space; the barrel follows this exactly.
var aim_direction: Vector3 = Vector3.RIGHT
## Weapon model root; its world transform is rewritten on every skeleton update.
var weapon: Node3D = null
## Backward kick in metres (weapon +Z, opposite the barrel), decays player-side.
var recoil_offset: float = 0.0
## Extra upward barrel pitch in radians from recoil.
var recoil_pitch: float = 0.0

var _skeleton: Skeleton3D = null
var _arm := -1
var _forearm := -1
var _hand := -1
var _upper_len := 0.0
var _fore_len := 0.0
var _left_arm := -1
var _left_forearm := -1
var _left_hand := -1
var _left_upper_len := 0.0
var _left_fore_len := 0.0
var _mount_basis := Basis()
var _mount_origin := Vector3()
var _weapon_basis := Basis()
var _solved := false


func setup(p_skeleton: Skeleton3D, p_weapon: Node3D) -> void:
	_skeleton = p_skeleton
	weapon = p_weapon
	_arm = _skeleton.find_bone("mixamorig_RightArm")
	_forearm = _skeleton.find_bone("mixamorig_RightForeArm")
	_hand = _skeleton.find_bone("mixamorig_RightHand")
	if _arm < 0 or _forearm < 0 or _hand < 0:
		push_error("WeaponAimSolver: Mixamo right-arm bones are missing from the skeleton")
		return
	# The arm chain's rest offsets are pure +Y, so bone lengths come straight
	# from the bind pose.
	_upper_len = _skeleton.get_bone_rest(_forearm).origin.length()
	_fore_len = _skeleton.get_bone_rest(_hand).origin.length()

	_left_arm = _skeleton.find_bone("mixamorig_LeftArm")
	_left_forearm = _skeleton.find_bone("mixamorig_LeftForeArm")
	_left_hand = _skeleton.find_bone("mixamorig_LeftHand")
	if _left_arm >= 0 and _left_forearm >= 0 and _left_hand >= 0:
		_left_upper_len = _skeleton.get_bone_rest(_left_forearm).origin.length()
		_left_fore_len = _skeleton.get_bone_rest(_left_hand).origin.length()

	_mount_basis = Basis.from_euler(MOUNT_ROTATION)
	# Shift the model root so the pistol grip (model space) lands in the middle
	# of the fist (hand space).
	_mount_origin = (fist_offset - _mount_basis * grip_local) * MODEL_SCALE


## True once the rig was resolved and a pose has been produced.
func is_ready() -> bool:
	return _solved


func _process_modification() -> void:
	if _skeleton == null or _arm < 0:
		return

	var skeleton_basis := _skeleton.global_transform.basis
	var aim := (skeleton_basis.inverse() * aim_direction).normalized()
	var up := (skeleton_basis.inverse() * Vector3.UP).normalized()
	if aim.length_squared() < 0.5:
		return
	# Keep the up reference perpendicular to the aim (and fall back to the
	# previous roll when the player aims straight up or down).
	var up_ref := up - aim * up.dot(aim)
	if up_ref.length_squared() < 0.0001:
		up_ref = (-_weapon_basis.z if _solved else Vector3.BACK) - aim * (-_weapon_basis.z if _solved else Vector3.BACK).dot(aim)
		if up_ref.length_squared() < 0.0001:
			up_ref = Vector3.BACK - aim * Vector3.BACK.dot(aim)
	up_ref = up_ref.normalized()

	# Animated (bind) bone transforms for this frame.
	var arm_rest := _skeleton.get_bone_global_pose(_arm)
	var fore_rest := _skeleton.get_bone_global_pose(_forearm)
	var hand_rest := _skeleton.get_bone_global_pose(_hand)
	var shoulder := arm_rest.origin

	# --- Goal: weapon transform -------------------------------------------
	# Standard frame (-Z forward, +Y up) rotated so the model's barrel (-Y)
	# points along the aim and its sights (-Z) point up. Recoil adds a slight
	# upward pitch around the weapon's X axis.
	var aim_pitched := aim.rotated(_weapon_basis.x if _solved else Vector3.RIGHT, recoil_pitch)
	_weapon_basis = Basis.looking_at(aim_pitched, up_ref) * MODEL_AXIS_FIX
	# Hand basis that puts the mounted weapon on exactly that transform.
	var hand_goal := _weapon_basis * _mount_basis.inverse()
	# Recoil shoves the weapon backward along its own +Z (opposite the barrel).
	var grip_origin := shoulder
	if center_rifle_hold:
		var left_sh := shoulder
		if _left_arm >= 0:
			left_sh = _skeleton.get_bone_global_pose(_left_arm).origin
		else:
			var la := _skeleton.find_bone("mixamorig_LeftArm")
			if la >= 0:
				left_sh = _skeleton.get_bone_global_pose(la).origin
		# Bias toward right shoulder/pectoral pocket (0.40 from right to left)
		grip_origin = shoulder.lerp(left_sh, 0.40)
	var grip_pos := grip_origin + aim * (reach * MODEL_SCALE) + up * (grip_drop * MODEL_SCALE)
	var wrist_goal := grip_pos - hand_goal * (fist_offset * MODEL_SCALE)
	wrist_goal += _weapon_basis.z * (recoil_offset * MODEL_SCALE)

	# --- Analytic two-bone IK ---------------------------------------------
	var to_wrist := wrist_goal - shoulder
	var dist := clampf(
		to_wrist.length(),
		absf(_upper_len - _fore_len) + 0.5,
		_upper_len + _fore_len - 0.5
	)
	var dir := aim if to_wrist.length_squared() < 0.001 else to_wrist.normalized()
	var along := (_upper_len * _upper_len - _fore_len * _fore_len + dist * dist) / (2.0 * dist)
	var spread := sqrt(maxf(_upper_len * _upper_len - along * along, 0.0))
	var pole := -up * elbow_drop - aim * elbow_back + _weapon_basis.x * elbow_side
	pole -= aim * pole.dot(aim)
	if pole.length_squared() < 0.0001:
		pole = up.cross(aim)
	pole = pole.normalized()
	var elbow := shoulder + dir * along + pole * spread

	# --- Drive the bone chain (upper arm -> forearm -> hand) ---------------
	var arm_follow := arm_rest.basis
	var arm_delta := _blend(_aim_basis(arm_follow, (elbow - shoulder).normalized()) * arm_follow.inverse())
	var arm_final := arm_delta * arm_follow
	_write_bone(_arm, arm_follow, arm_final)

	var fore_follow := arm_delta * fore_rest.basis
	var fore_delta := _blend(_aim_basis(fore_follow, (wrist_goal - elbow).normalized()) * fore_follow.inverse())
	var fore_final := fore_delta * fore_follow
	_write_bone(_forearm, fore_follow, fore_final)

	var hand_follow := fore_delta * arm_delta * hand_rest.basis
	var hand_delta := _blend(hand_goal * hand_follow.inverse())
	var hand_final := hand_delta * hand_follow
	_write_bone(_hand, hand_follow, hand_final)

	# --- Place the weapon on the solved hand ------------------------------
	if weapon != null:
		var wrist := shoulder + arm_final.y.normalized() * _upper_len + fore_final.y.normalized() * _fore_len
		var hand_global := Transform3D(hand_final, wrist)
		var mount := Transform3D(
			_mount_basis.scaled(Vector3(MODEL_SCALE, MODEL_SCALE, MODEL_SCALE)),
			_mount_origin
		)
		weapon.global_transform = _skeleton.global_transform * (hand_global * mount)

	# --- Two-handed support hand IK ---------------------------------------
	if two_handed and _left_arm >= 0 and _left_forearm >= 0 and _left_hand >= 0 and weapon != null:
		_solve_support_hand()

	if capture_pose:
		pose_capture.clear()
		for i in _skeleton.get_bone_count():
			pose_capture.append(_skeleton.get_bone_global_pose(i))
	_solved = true


func _solve_support_hand() -> void:
	var left_shoulder_pose := _skeleton.get_bone_global_pose(_left_arm)
	var left_fore_pose := _skeleton.get_bone_global_pose(_left_forearm)
	var left_hand_pose := _skeleton.get_bone_global_pose(_left_hand)
	var left_shoulder := left_shoulder_pose.origin

	var weapon_pose := _skeleton.global_transform.affine_inverse() * weapon.global_transform
	var grip := weapon_pose * support_grip

	var hand_basis := weapon_pose.basis.orthonormalized() * Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5))
	var wrist_goal := grip - hand_basis * (support_fist_offset * MODEL_SCALE)

	var to_wrist := wrist_goal - left_shoulder
	var dist := clampf(
		to_wrist.length(),
		absf(_left_upper_len - _left_fore_len) + 0.5,
		_left_upper_len + _left_fore_len - 0.5
	)
	var dir := to_wrist.normalized()
	wrist_goal = left_shoulder + dir * dist

	var along := (_left_upper_len * _left_upper_len - _left_fore_len * _left_fore_len + dist * dist) / (2.0 * dist)
	var spread := sqrt(maxf(_left_upper_len * _left_upper_len - along * along, 0.0))

	var up := (_skeleton.global_transform.basis.inverse() * Vector3.UP).normalized()
	var pole := -up - weapon_pose.basis.x.normalized() * 0.35 - dir * 0.15
	pole = (pole - dir * pole.dot(dir)).normalized()
	if pole.length_squared() < 0.0001:
		pole = -up
	var elbow := left_shoulder + dir * along + pole * spread

	var arm_follow := left_shoulder_pose.basis
	var arm_delta := _blend(_aim_basis(arm_follow, (elbow - left_shoulder).normalized()) * arm_follow.inverse())
	var arm_final := arm_delta * arm_follow
	_write_bone(_left_arm, arm_follow, arm_final)

	var fore_follow := arm_delta * left_fore_pose.basis
	var fore_delta := _blend(_aim_basis(fore_follow, (wrist_goal - elbow).normalized()) * fore_follow.inverse())
	var fore_final := fore_delta * fore_follow
	_write_bone(_left_forearm, fore_follow, fore_final)

	var hand_follow := fore_delta * arm_delta * left_hand_pose.basis
	var hand_delta := _blend(hand_basis * hand_follow.inverse())
	var hand_final := hand_delta * hand_follow
	_write_bone(_left_hand, hand_follow, hand_final)

	_close_hands()


func _close_hands() -> void:
	for side in ["Left", "Right"]:
		for finger in ["Index", "Middle", "Ring", "Pinky"]:
			for joint in range(1, 4):
				var bone := _skeleton.find_bone("mixamorig_%sHand%s%d" % [side, finger, joint])
				if bone < 0:
					continue
				var pose := _skeleton.get_bone_pose(bone)
				pose.basis = Basis.from_euler(Vector3(0.55 if joint == 1 else 0.85, 0, 0))
				_skeleton.set_bone_pose(bone, pose)
		for joint in range(1, 4):
			var bone := _skeleton.find_bone("mixamorig_%sHandThumb%d" % [side, joint])
			if bone < 0:
				continue
			var pose := _skeleton.get_bone_pose(bone)
			pose.basis = Basis.from_euler(Vector3(0.35 if joint == 1 else 0.5, 0.2 if side == "Right" else -0.2, 0))
			_skeleton.set_bone_pose(bone, pose)


## Rotation that swings `following` around until its +Y axis points along `dir`,
## keeping the existing roll.
func _aim_basis(following: Basis, dir: Vector3) -> Basis:
	return Basis(Quaternion(following.y.normalized(), dir)) * following


## Blends a global rotation delta against the animation pose by `aim_weight`.
func _blend(delta: Basis) -> Basis:
	var q := Quaternion(delta.orthonormalized())
	if aim_weight >= 0.999:
		return Basis(q)
	return Basis(Quaternion.IDENTITY.slerp(q, aim_weight))


## Writes the local pose that turns `following` into `final_basis`, leaving the
## bone's translation and scale untouched.
func _write_bone(bone: int, following: Basis, final_basis: Basis) -> void:
	var pose := _skeleton.get_bone_pose(bone)
	pose.basis = pose.basis * (following.inverse() * final_basis)
	_skeleton.set_bone_pose(bone, pose)
