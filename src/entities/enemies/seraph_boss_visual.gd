extends Node3D

## Articulated aerodynamic quad-wings, turbine vectoring, and solar singularity core kinematics.
var boss: CharacterBody3D
var model_root: Node3D
var torso: Node3D
var head: Node3D
var wing_upper_l: Node3D
var wing_upper_r: Node3D
var wing_lower_l: Node3D
var wing_lower_r: Node3D
var thruster_l: Node3D
var thruster_r: Node3D
var talon_l: Node3D
var talon_r: Node3D
var rest: Dictionary = {}
var flames: Array[Node3D] = []
var age := 0.0
var wing_flex := 0.0
var recoil := 0.0
var core_flare := 0.0
var banking := 0.0

func bind(body: CharacterBody3D, model: Node3D) -> void:
	boss = body
	model_root = model
	
	torso = model.find_child("SeraphTorso*", true, false) as Node3D
	head = model.find_child("SeraphHead*", true, false) as Node3D
	wing_upper_l = model.find_child("WingUpper_L*", true, false) as Node3D
	wing_upper_r = model.find_child("WingUpper_R*", true, false) as Node3D
	wing_lower_l = model.find_child("WingLower_L*", true, false) as Node3D
	wing_lower_r = model.find_child("WingLower_R*", true, false) as Node3D
	thruster_l = model.find_child("Thruster_L*", true, false) as Node3D
	thruster_r = model.find_child("Thruster_R*", true, false) as Node3D
	talon_l = model.find_child("Talon_L*", true, false) as Node3D
	talon_r = model.find_child("Talon_R*", true, false) as Node3D
	
	for part in [torso, head, wing_upper_l, wing_upper_r, wing_lower_l, wing_lower_r, thruster_l, thruster_r, talon_l, talon_r]:
		if part:
			rest[part] = part.transform
			
	# Mount inferno jet exhaust plumes on the turbine nozzles
	for pattern in ["ThrusterSocket_L*", "ThrusterSocket_R*"]:
		var nozzle := model.find_child(pattern, true, false) as Node3D
		if nozzle:
			var flame := preload("res://src/projectiles/muzzle_burst.gd").flare(0.95, 0.14, Color(1.0, 0.40, 0.08))
			nozzle.add_child(flame)
			flame.rotation.x = PI / 2
			flames.append(flame)
			
	# Accent warm rim light for the wings and hull
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 1.8, 2.2)
	rim.light_color = Color(1.0, 0.55, 0.15)
	rim.light_energy = 1.4
	rim.omni_range = 8.0
	model.add_child(rim)

	# Optical sensor lens glow on the head
	if head:
		var eye_light := OmniLight3D.new()
		eye_light.position = Vector3(0, 0.18, 0.45)
		eye_light.light_color = Color(1.0, 0.10, 0.02)
		eye_light.light_energy = 1.6
		eye_light.omni_range = 3.5
		head.add_child(eye_light)

	# Searing emberfall core radiance
	if torso:
		var core_light_node := OmniLight3D.new()
		core_light_node.position = Vector3(0, 0.18, 0.65)
		core_light_node.light_color = Color(1.0, 0.45, 0.10)
		core_light_node.light_energy = 3.2
		core_light_node.omni_range = 7.5
		torso.add_child(core_light_node)

func kick() -> void:
	recoil = minf(0.12, recoil + 0.035)

func _process(delta: float) -> void:
	if not is_instance_valid(boss) or not model_root or not torso:
		return
		
	age += delta
	recoil = move_toward(recoil, 0, delta * 0.4)
	core_flare = move_toward(core_flare, 0, delta * 0.6)
	
	# Determine facing and flight velocity
	var vx := boss.velocity.x
	var target_bank := clampf(vx * -0.045, -0.25, 0.25)
	banking = lerpf(banking, target_bank, minf(1.0, delta * 6.0))
	model_root.rotation.z = banking
	
	# Hover breathing and aerodynamic flex
	var hover_bob := sin(age * 2.2) * 0.04
	torso.transform = rest[torso]
	torso.position.y += hover_bob
	
	# Wing articulation based on attack state and flight mode
	var attack: int = int(boss.get("attack_state"))
	var charging: bool = bool(boss.get("_charging"))
	var breath := sin(age * 2.4) * 0.06
	
	# Target angles for upper and lower wings
	var u_rot_z := breath
	var u_rot_y := 0.0
	var u_rot_x := sin(age * 1.8) * 0.03
	var l_rot_z := -breath * 0.75
	var l_rot_y := 0.0
	
	if charging:
		match attack:
			0: # INFERNO VOLLEY: Wings spread wide and swept back, locking onto target
				u_rot_y = -0.32
				u_rot_z = -0.15 + breath * 0.5
				l_rot_y = -0.25
			1: # WING SWEEP: Wings sweep aggressively forward into a razor shield
				u_rot_y = 0.42
				u_rot_z = 0.12
				l_rot_y = 0.35
			2: # SOLAR STRIKES: Wings arch skyward like an archangel channeling orbital fire
				u_rot_z = 0.48 + breath
				u_rot_y = -0.10
				u_rot_x = 0.15
				l_rot_z = 0.28
			3: # SERAPH ESCORT: Wings fold slightly inward in defensive posture
				u_rot_y = 0.20
				u_rot_z = -0.22
	
	# Apply wing kinematics
	if wing_upper_l:
		wing_upper_l.transform = rest[wing_upper_l]
		wing_upper_l.rotation.z += u_rot_z
		wing_upper_l.rotation.y += -u_rot_y
		wing_upper_l.rotation.x += u_rot_x + recoil
	if wing_upper_r:
		wing_upper_r.transform = rest[wing_upper_r]
		wing_upper_r.rotation.z += -u_rot_z
		wing_upper_r.rotation.y += u_rot_y
		wing_upper_r.rotation.x += u_rot_x + recoil
		
	if wing_lower_l:
		wing_lower_l.transform = rest[wing_lower_l]
		wing_lower_l.rotation.z += l_rot_z
		wing_lower_l.rotation.y += -l_rot_y
	if wing_lower_r:
		wing_lower_r.transform = rest[wing_lower_r]
		wing_lower_r.rotation.z += -l_rot_z
		wing_lower_r.rotation.y += l_rot_y
		
	# Turbine thrust vectoring
	if thruster_l:
		thruster_l.transform = rest[thruster_l]
		thruster_l.rotation.z += clampf(banking * 0.6, -0.18, 0.18)
		thruster_l.rotation.x += (0.12 if charging else 0.0) + sin(age * 3.0) * 0.02
	if thruster_r:
		thruster_r.transform = rest[thruster_r]
		thruster_r.rotation.z += clampf(banking * 0.6, -0.18, 0.18)
		thruster_r.rotation.x += (0.12 if charging else 0.0) + sin(age * 3.0) * 0.02
		
	# Head tracking towards player
	if head and is_instance_valid(boss.player_ref):
		head.transform = rest[head]
		var head_dir: Vector3 = (boss.player_ref.global_position - head.global_position).normalized()
		head.rotation.y = clampf(-head_dir.x * 0.35, -0.45, 0.45)
		head.rotation.x = clampf(head_dir.y * 0.25, -0.30, 0.30)
		if charging and attack == 2:
			head.rotation.x = 0.35 # Tilt head up towards the heavens for solar strikes
			
	# Talons folded under the hull with slight suspension bounce
	for talon in [talon_l, talon_r]:
		if talon:
			talon.transform = rest[talon]
			talon.rotation.x += sin(age * 2.0) * 0.04
			
	# Update exhaust flame scale and flicker
	var thrust_intensity := (1.4 if charging else 0.9) + sin(age * 32.0) * 0.12
	for flame in flames:
		flame.scale = Vector3(1.0, 1.0, thrust_intensity)
