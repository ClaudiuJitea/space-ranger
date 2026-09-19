extends Node3D
## Quadruped trot: diagonal feet alternate swing/stance; body and head follow the hunt.
var boss: CharacterBody3D
var model_root: Node3D
var torso: Node3D
var head: Node3D
var tail: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var rest: Dictionary = {}
var age := 0.0
var gait_phase := 0.0
var slam_kick := 0.0
var facing := -1.0
func bind(body: CharacterBody3D, model: Node3D) -> void:
	boss = body
	model_root = model
	torso = model.find_child("ColossusTorso*", true, false) as Node3D
	head = model.find_child("ColossusHead*", true, false) as Node3D
	tail = model.find_child("ColossusTail*", true, false) as Node3D
	for pattern in ["ColossusArm_L*", "ColossusArm_R*"]:
		var part := model.find_child(pattern, true, false) as Node3D
		if part: arms.append(part)
	for pattern in ["ColossusLeg_L*", "ColossusLeg_R*"]:
		var part := model.find_child(pattern, true, false) as Node3D
		if part: legs.append(part)
	for part in [torso, head, tail] + arms + legs:
		if part: rest[part] = part.transform
func slam() -> void:
	slam_kick = 0.2
func _process(delta: float) -> void:
	if not is_instance_valid(boss) or not torso: return
	age += delta
	slam_kick = move_toward(slam_kick, 0, delta * 0.7)
	var speed := absf(boss.velocity.x)
	var running := clampf(speed / 3.4, 0, 1)
	gait_phase += delta * (3.0 + speed * 1.8) * running
	var airborne: bool = boss.active and not boss.is_on_floor()
	var winding: bool = boss._charging
	if is_instance_valid(boss.player_ref) and not winding and boss._charge_time <= 0 and absf(boss.player_ref.position.x - boss.position.x) > 0.7:
		facing = -1 if boss.player_ref.position.x < boss.position.x else 1
	elif boss._charge_time > 0:
		facing = boss._charge_direction
	model_root.rotation.y = lerp_angle(model_root.rotation.y, 0 if facing < 0 else PI, minf(1, delta * 9))
	torso.transform = rest[torso]
	torso.position.y += sin(age * 2.3) * 0.022 + absf(sin(gait_phase)) * running * 0.07 - slam_kick - (0.15 if winding else 0)
	torso.rotation.x += (0.08 if winding else 0) + sin(gait_phase * 2) * running * 0.025
	var torso_rest: Transform3D = rest[torso]
	for i in arms.size():
		_foot(arms[i], gait_phase + i * PI, running, airborne, 2.05, winding)
		arms[i].position.y -= torso.position.y - torso_rest.origin.y
	for i in legs.size():
		_foot(legs[i], gait_phase + (1 - i) * PI, running, airborne, 1.73, winding)
	if head:
		head.transform = rest[head]
		head.rotation.x += sin(age * 2.3) * 0.025 - running * 0.045
	if tail:
		tail.transform = rest[tail]
		tail.rotation.y += sin(age * 2.8) * (0.1 + running * 0.08)
func _foot(part: Node3D, phase: float, amount: float, airborne: bool, reach: float, crouching: bool) -> void:
	part.transform = rest[part]
	if airborne:
		part.rotation.x += 0.35
		part.position.y += 0.16
		return
	var swing := sin(phase) * 0.20 * amount
	part.rotation.x += swing
	# Lift swing feet; keep stance feet at deck height despite pivot rotation.
	part.position.y += maxf(0, cos(phase)) * 0.15 * amount - reach * (1 - cos(swing))
	if crouching:
		part.rotation.x -= 0.08
