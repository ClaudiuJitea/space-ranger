extends SkeletonModifier3D
class_name AirborneLegLock

## AirborneLegLock — Physics-driven suspended leg dynamics for flying humanoid enemies.
##
## Implements natural Newtonian hanging leg physics for humanoid flyers:
## - Hanging Equilibrium: Thighs angled slightly forward under gravity, knees relaxed
##   and bent backward (~28° flexion), feet dangling in soft plantar flexion (toes down).
## - Aerodynamic Drag: Trailing limbs pushed opposite to flight velocity.
## - Inertial Lag & Pendulum Momentum: Damped harmonic oscillators (2nd-order spring-damper)
##   causing legs to lag behind body acceleration and swing through upon braking.
## - Secondary Motion / Double-Pendulum Lag: Angular acceleration of the thighs whips through
##   the knee joint into the calves and feet with phase delay.
## - Gravity Alignment: Cancels body banking/pitching so hanging legs remain aligned with
##   true world down rather than rigidly locked to a tilted spine.
## - Anatomical Limits: Strictly enforces mechanical knee lock (flexion >= 0, no hyperextension).
## - Bilateral Asymmetry: Left and right legs have natural stagger offsets and detuned resonant
##   frequencies, preventing robotic lockstep motion.
## - Thruster Turbulence: Dynamic micro-flutter driven by jetpack exhaust downwash.
## - Impulse Reaction: Reactive flinch/jostle from weapon recoil and damage impacts.

class PhysicalLegChain:
	var is_left: bool
	
	# Dynamic states (angle in radians, angular velocity in rad/s)
	var thigh_sway: float = 0.0
	var thigh_sway_vel: float = 0.0
	var thigh_pitch: float = 0.0
	var thigh_pitch_vel: float = 0.0
	var prev_thigh_sway_vel: float = 0.0
	
	var knee_flex: float = 0.5
	var knee_flex_vel: float = 0.0
	var knee_sway: float = 0.0
	var knee_sway_vel: float = 0.0
	
	var foot_pitch: float = 0.4
	var foot_pitch_vel: float = 0.0
	var foot_sway: float = 0.0
	var foot_sway_vel: float = 0.0
	
	# Equilibrium offsets & resonance configuration
	var base_pitch: float = -0.22
	var base_spread: float = -0.05
	var base_knee_flex: float = 0.52
	var base_foot_pitch: float = 0.42
	var phase_offset: float = 0.0
	var omega_thigh: float = 7.2
	var omega_knee: float = 10.8
	var omega_foot: float = 13.5
	var zeta: float = 0.72

	func _init(p_is_left: bool) -> void:
		is_left = p_is_left
		if not is_left:
			# Natural asymmetric flight stagger: right leg slightly trailing, slightly straighter knee
			base_pitch = -0.14
			base_spread = 0.05
			base_knee_flex = 0.44
			base_foot_pitch = 0.36
			phase_offset = 2.1
			omega_thigh = 7.7
			omega_knee = 11.4
			omega_foot = 14.2
			zeta = 0.74
		thigh_pitch = base_pitch
		thigh_sway = base_spread
		knee_flex = base_knee_flex
		foot_pitch = base_foot_pitch

	func step_physics(dt: float, time: float, v_x: float, a_x: float, v_y: float, a_y: float, bank_z: float, bank_x: float, facing: float) -> void:
		dt = clampf(dt, 0.001, 0.05)
		
		# --- 1. Thigh Sway (Lateral pendulum swing along flight X) ---
		var inertia_sway := -clampf(a_x * 0.024, -0.35, 0.35)
		var drag_sway := -clampf(v_x * 0.048 * (1.0 + 0.07 * absf(v_x)), -0.42, 0.42)
		var gravity_bank := -bank_z * 0.88 * facing
		var hover_sway := sin(time * 1.85 + phase_offset) * 0.032
		var target_sway := clampf(base_spread + inertia_sway + drag_sway + gravity_bank + hover_sway, -0.58, 0.58)
		
		var alpha_sway := (omega_thigh * omega_thigh * (target_sway - thigh_sway)) - (2.0 * zeta * omega_thigh * thigh_sway_vel)
		thigh_sway_vel += alpha_sway * dt
		thigh_sway += thigh_sway_vel * dt
		
		# --- 2. Thigh Pitch (Forward/backward swing along body Z) ---
		var v_y_drag := (-v_y * 0.032) if v_y < 0.0 else (-v_y * 0.020)
		var pitch_comp := -bank_x * 0.82
		var hover_pitch := sin(time * 1.4 + phase_offset * 0.7) * 0.026
		var target_pitch := clampf(base_pitch + v_y_drag + pitch_comp + hover_pitch, -0.75, 0.45)
		
		var alpha_pitch := (omega_thigh * omega_thigh * (target_pitch - thigh_pitch)) - (2.0 * zeta * omega_thigh * thigh_pitch_vel)
		thigh_pitch_vel += alpha_pitch * dt
		thigh_pitch += thigh_pitch_vel * dt
		
		# Secondary angular acceleration from thigh motion (compound pendulum link)
		var thigh_ang_accel := (thigh_sway_vel - prev_thigh_sway_vel) / dt
		prev_thigh_sway_vel = thigh_sway_vel
		
		# --- 3. Knee Flexion (Anatomical backward hinge bend) ---
		var v_y_knee := (-v_y * 0.055) if v_y < 0.0 else (-v_y * 0.025)
		var a_y_knee := (a_y * 0.022) if a_y < 0.0 else (-a_y * 0.016)
		var v_x_tuck := clampf(absf(v_x) * 0.032, 0.0, 0.22)
		var downwash := sin(time * 15.2 + phase_offset * 2.0) * 0.015 * (1.0 + clampf(sqrt(a_x * a_x + a_y * a_y) * 0.05, 0.0, 1.0))
		var target_knee := clampf(base_knee_flex + v_y_knee + a_y_knee + v_x_tuck + downwash, 0.14, 1.80)
		
		# Knee responds to secondary thigh whip
		knee_sway_vel -= thigh_ang_accel * 0.18
		knee_flex_vel += absf(thigh_ang_accel) * 0.08
		
		var alpha_knee := (omega_knee * omega_knee * (target_knee - knee_flex)) - (2.0 * zeta * omega_knee * knee_flex_vel)
		knee_flex_vel += alpha_knee * dt
		knee_flex += knee_flex_vel * dt
		knee_flex = clampf(knee_flex, 0.12, 1.85)
		
		var alpha_knee_sway := (omega_knee * omega_knee * (drag_sway * 0.4 - knee_sway)) - (2.0 * zeta * omega_knee * knee_sway_vel)
		knee_sway_vel += alpha_knee_sway * dt
		knee_sway += knee_sway_vel * dt
		knee_sway = clampf(knee_sway, -0.35, 0.35)
		
		# --- 4. Foot / Ankle (Plantar flexion & drag trailing) ---
		var v_y_foot := (-v_y * 0.042) if v_y < 0.0 else (v_y * 0.028)
		var v_x_foot := clampf(absf(v_x) * 0.028, 0.0, 0.16)
		var foot_flutter := sin(time * 18.5 + phase_offset) * 0.018 * (1.0 + clampf(sqrt(a_x * a_x + a_y * a_y) * 0.05, 0.0, 1.0))
		var target_foot_pitch := clampf(base_foot_pitch + v_y_foot + v_x_foot + foot_flutter, -0.15, 0.90)
		
		var alpha_foot := (omega_foot * omega_foot * (target_foot_pitch - foot_pitch)) - (2.0 * zeta * omega_foot * foot_pitch_vel)
		foot_pitch_vel += alpha_foot * dt
		foot_pitch += foot_pitch_vel * dt
		foot_pitch = clampf(foot_pitch, -0.15, 0.90)
		
		var target_foot_sway := -clampf(v_x * 0.035, -0.22, 0.22)
		var alpha_foot_sway := (omega_foot * omega_foot * (target_foot_sway - foot_sway)) - (2.0 * zeta * omega_foot * foot_sway_vel)
		foot_sway_vel += alpha_foot_sway * dt
		foot_sway += foot_sway_vel * dt
		foot_sway = clampf(foot_sway, -0.25, 0.25)

	func apply_impulse(imp_x: float, imp_y: float, imp_z: float) -> void:
		var kick := randf_range(0.85, 1.15)
		thigh_sway_vel += imp_x * 0.28 * kick
		thigh_pitch_vel += imp_z * 0.22 * kick
		knee_flex_vel += (-imp_y * 0.35 + absf(imp_x) * 0.15) * kick
		knee_sway_vel += imp_x * 0.40 * kick
		foot_pitch_vel += -imp_y * 0.45 * kick
		foot_sway_vel += imp_x * 0.50 * kick

# --- Skeleton Modifier State ---
var skeleton: Skeleton3D
var left_leg: PhysicalLegChain = PhysicalLegChain.new(true)
var right_leg: PhysicalLegChain = PhysicalLegChain.new(false)

# Bone indices
var b_left_upleg := -1
var b_left_leg := -1
var b_left_foot := -1
var b_left_toe := -1

var b_right_upleg := -1
var b_right_leg := -1
var b_right_foot := -1
var b_right_toe := -1

var bone_rests: Dictionary = {}

var motion_time := 0.0
var flight_velocity := Vector3.ZERO
var flight_acceleration := Vector3.ZERO
var body_bank_euler := Vector3.ZERO
var last_delta := 0.016

func set_flight_motion(velocity: Vector3, delta: float) -> void:
	var accel := (velocity - flight_velocity) / maxf(delta, 0.001)
	set_flight_motion_full(velocity, accel, Vector3.ZERO, delta)

func set_flight_motion_full(velocity: Vector3, acceleration: Vector3, body_bank: Vector3, delta: float) -> void:
	motion_time += delta
	last_delta = delta
	flight_velocity = flight_velocity.lerp(velocity, clampf(14.0 * delta, 0.0, 1.0))
	flight_acceleration = flight_acceleration.lerp(acceleration, clampf(12.0 * delta, 0.0, 1.0))
	body_bank_euler = body_bank_euler.lerp(body_bank, clampf(10.0 * delta, 0.0, 1.0))

func apply_impulse(impulse: Vector3) -> void:
	var facing := 1.0
	if skeleton:
		facing = signf(skeleton.global_transform.basis.x.x)
	var imp_x := impulse.x * facing
	var imp_y := impulse.y
	var imp_z := impulse.z
	left_leg.apply_impulse(imp_x, imp_y, imp_z)
	right_leg.apply_impulse(imp_x, imp_y, imp_z)

func _ready() -> void:
	skeleton = get_parent() as Skeleton3D
	if skeleton == null:
		return
	_cache_bones()

func _cache_bones() -> void:
	b_left_upleg = skeleton.find_bone("mixamorig_LeftUpLeg")
	b_left_leg = skeleton.find_bone("mixamorig_LeftLeg")
	b_left_foot = skeleton.find_bone("mixamorig_LeftFoot")
	b_left_toe = skeleton.find_bone("mixamorig_LeftToeBase")

	b_right_upleg = skeleton.find_bone("mixamorig_RightUpLeg")
	b_right_leg = skeleton.find_bone("mixamorig_RightLeg")
	b_right_foot = skeleton.find_bone("mixamorig_RightFoot")
	b_right_toe = skeleton.find_bone("mixamorig_RightToeBase")

	var all_bones := [
		b_left_upleg, b_left_leg, b_left_foot, b_left_toe,
		b_right_upleg, b_right_leg, b_right_foot, b_right_toe
	]
	for b in all_bones:
		if b >= 0:
			bone_rests[b] = skeleton.get_bone_rest(b)

func _process_modification() -> void:
	if skeleton == null or b_left_upleg < 0:
		return

	var facing := signf(skeleton.global_transform.basis.x.x)
	if facing == 0.0:
		facing = 1.0

	var v_x := flight_velocity.x * facing
	var a_x := flight_acceleration.x * facing
	var v_y := flight_velocity.y
	var a_y := flight_acceleration.y
	var bank_z := body_bank_euler.z
	var bank_x := body_bank_euler.x

	# Update dynamic physics simulation for each leg
	left_leg.step_physics(last_delta, motion_time, v_x, a_x, v_y, a_y, bank_z, bank_x, facing)
	right_leg.step_physics(last_delta, motion_time, v_x, a_x, v_y, a_y, bank_z, bank_x, facing)

	# Apply solved physical poses to the skeletal bones
	_apply_leg_pose(left_leg, b_left_upleg, b_left_leg, b_left_foot, b_left_toe)
	_apply_leg_pose(right_leg, b_right_upleg, b_right_leg, b_right_foot, b_right_toe)

func _apply_leg_pose(leg: PhysicalLegChain, upleg_idx: int, leg_idx: int, foot_idx: int, toe_idx: int) -> void:
	# Thigh (UpLeg): local X is pitch (forward/back), local Z is sway (left/right)
	if upleg_idx >= 0 and bone_rests.has(upleg_idx):
		var rest: Transform3D = bone_rests[upleg_idx]
		var rot := Basis.from_euler(Vector3(leg.thigh_pitch, 0.0, leg.thigh_sway))
		var pose := rest
		pose.basis = rest.basis * rot
		skeleton.set_bone_pose(upleg_idx, pose)

	# Knee (Leg): local X is backward hinge flexion, local Z is secondary lateral sway
	if leg_idx >= 0 and bone_rests.has(leg_idx):
		var rest: Transform3D = bone_rests[leg_idx]
		var rot := Basis.from_euler(Vector3(leg.knee_flex, 0.0, leg.knee_sway))
		var pose := rest
		pose.basis = rest.basis * rot
		skeleton.set_bone_pose(leg_idx, pose)

	# Foot (Ankle): local X is plantar flexion (toe down), local Y is lateral foot tilt
	if foot_idx >= 0 and bone_rests.has(foot_idx):
		var rest: Transform3D = bone_rests[foot_idx]
		var rot := Basis.from_euler(Vector3(leg.foot_pitch, -leg.foot_sway, 0.0))
		var pose := rest
		pose.basis = rest.basis * rot
		skeleton.set_bone_pose(foot_idx, pose)

	# Toe: subtle passive curl following foot pitch
	if toe_idx >= 0 and bone_rests.has(toe_idx):
		var rest: Transform3D = bone_rests[toe_idx]
		var rot := Basis.from_euler(Vector3(leg.foot_pitch * 0.25, 0.0, 0.0))
		var pose := rest
		pose.basis = rest.basis * rot
		skeleton.set_bone_pose(toe_idx, pose)
