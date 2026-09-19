extends RefCounted

## Distance-driven quadruped gait. Stance paws stay in world space; two-link
## inverse kinematics bends the authored hip and knee without scaling armor.
var enemy: CharacterBody3D
var model: Node3D
var limbs: Array[Dictionary] = []
var phase := 0.0
var clock := 0.0
var last_facing := 1.0
var last_state := -1
var skull: Node3D
var skull_rest := Transform3D.IDENTITY
var body_rest := Vector3.ZERO

func bind(body: CharacterBody3D, mesh: Node3D, hips: Array[Node3D]) -> void:
	enemy = body
	model = mesh
	body_rest = model.position
	skull = model.find_child("PredatorSkull*", true, false) as Node3D
	if skull:
		skull_rest = skull.transform
	for i in hips.size():
		var hip := hips[i]
		var shin := hip.find_child("Shin*", true, false) as Node3D
		var paw := hip.find_child("Paw*", true, false) as Node3D
		if shin == null or paw == null:
			push_error("Crawler needs articulated Shin and Paw pivots")
			continue
		var upper := Vector2(shin.position.x, shin.position.y)
		var lower := Vector2(paw.position.x, paw.position.y)
		var rest := model.to_local(paw.global_position)
		rest.x = -0.43 if i < 2 else 0.30
		limbs.append({"hip": hip, "shin": shin, "paw": paw,
			"a": upper.length(), "b": lower.length(),
			"upper_angle": upper.angle(), "lower_angle": lower.angle(),
			"rest": rest, "planted": false, "anchor": paw.global_position,
			"start": rest, "target": rest, "swing": 0.0})

func update(delta: float) -> void:
	clock += delta
	var speed := absf(enemy.velocity.x)
	var facing := float(enemy.get("facing"))
	var state := int(enemy.get("state"))
	var timer := float(enemy.get("state_timer"))
	# No phase discontinuities when accelerating; gait advances by distance.
	phase = fposmod(phase + speed * delta / (0.70 if speed <= 1.4 else 0.95), 1.0)
	var moving := speed > 0.12 and state in [0, 1, 4]
	var crouch := 0.0
	var pitch := 0.0
	if state == 2:
		crouch = smoothstep(0.0, 1.0, 1.0 - timer / 0.45) * 0.15
		pitch = 0.10 * crouch / 0.15
	elif state == 3:
		pitch = -0.10 * sin(clampf(1.0 - timer / 0.32, 0.0, 1.0) * PI)
	elif state == 4:
		crouch = 0.10 * exp(-maxf(0.0, 0.7 - timer) * 10.0)
	var bounce := sin(phase * TAU * 2.0) * 0.018 if moving else sin(clock * 2.2) * 0.004
	model.position = body_rest + Vector3(0, -0.07 - crouch + bounce, 0)
	model.rotation.z = lerp_angle(model.rotation.z, pitch + (cos(phase * TAU) * 0.015 if moving else 0.0), 1.0 - exp(-delta * 16.0))
	if skull:
		skull.transform = skull_rest
		skull.position.y += crouch * 0.35
		skull.rotation.z = -model.rotation.z * 0.7 - crouch * 0.25
	for i in limbs.size():
		var limb := limbs[i]
		var rest: Vector3 = limb.rest
		var target := rest
		# Diagonal pairs at speed, four evenly spaced footfalls when creeping.
		var offsets := [0.0, 0.5, 0.5, 0.0] if speed > 1.4 else [0.0, 0.5, 0.75, 0.25]
		var cycle := fposmod(phase + float(offsets[i]), 1.0)
		var duty := 0.50 if speed > 1.4 else 0.68
		var changed := facing != last_facing or state != last_state
		if state == 3:
			limb.planted = false
			var progress := clampf(1.0 - timer / 0.32, 0.0, 1.0)
			target.x += (0.14 if i >= 2 else -0.15) * sin(progress * PI)
			target.y += (0.16 if i < 2 else 0.08) * sin(progress * PI)
		elif moving and cycle >= duty:
			var swing := (cycle - duty) / (1.0 - duty)
			if bool(limb.planted) or changed:
				limb.start = model.to_local(limb.paw.global_position)
			limb.planted = false
			var end := rest + Vector3(0.22, 0, 0)
			end = _ground_target(end)
			target = (limb.start as Vector3).lerp(end, smoothstep(0.0, 1.0, swing))
			target.y += sin(swing * PI) * (0.11 if speed > 1.4 else 0.065)
		else:
			if not bool(limb.planted) or changed:
				var contact := rest + Vector3(0.22 if moving else 0.0, 0, 0)
				limb.anchor = model.to_global(_ground_target(contact))
				limb.planted = true
			target = model.to_local(limb.anchor)
		limb.target = target
		_solve(limb, target)
	last_facing = facing
	last_state = state

func _ground_target(local: Vector3) -> Vector3:
	var world := model.to_global(local)
	var query := PhysicsRayQueryParameters3D.create(world + Vector3.UP * 0.45, world + Vector3.DOWN * 0.45, 1, [enemy.get_rid()])
	var hit := enemy.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		world.y = (hit.position as Vector3).y + 0.065
	else:
		world.y = enemy.global_position.y + 0.065
	return model.to_local(world)

func _solve(limb: Dictionary, target: Vector3) -> void:
	var hip: Node3D = limb.hip
	var shin: Node3D = limb.shin
	var paw: Node3D = limb.paw
	var offset := Vector2(target.x - hip.position.x, target.y - hip.position.y)
	var a: float = limb.a
	var b: float = limb.b
	var distance := clampf(offset.length(), absf(a - b) + 0.005, a + b - 0.005)
	var upper := offset.angle() - acos(clampf((a * a + distance * distance - b * b) / (2.0 * a * distance), -1.0, 1.0))
	var bend := PI - acos(clampf((a * a + b * b - distance * distance) / (2.0 * a * b), -1.0, 1.0))
	hip.rotation.z = upper - float(limb.upper_angle)
	shin.rotation.z = upper + bend - float(limb.lower_angle) - hip.rotation.z
	# Keep claws level during support, rather than rotating with the shin.
	paw.rotation.z = -model.rotation.z - hip.rotation.z - shin.rotation.z
