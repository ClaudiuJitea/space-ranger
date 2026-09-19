extends Node

## Presentation for the reference-authored mechanical enemies.
## Reads combat state; does not change movement, damage, health or attack timing.
@export var model_path: NodePath
@export_enum("crawler", "turret", "gunship", "boss") var kind := "crawler"
var enemy: CharacterBody3D
var model: Node3D
var legs: Array[Node3D] = []
var locomotion: RefCounted
var head: Node3D
var head_rest := Vector3.ZERO
var time := 0.0
var recoil := 0.0
var previous_counter := 0.0

func _ready() -> void:
	enemy = get_parent() as CharacterBody3D
	model = get_node_or_null(model_path) as Node3D
	if model == null:
		return
	if kind == "crawler":
		for pattern in ["Rear_near*", "Rear_far*", "Front_near*", "Front_far*"]:
			var leg := model.find_child(pattern, true, false) as Node3D
			if leg:
				legs.append(leg)
		locomotion = preload("res://src/entities/enemies/crawler_locomotion.gd").new()
		locomotion.bind(enemy, model, legs)
	elif kind == "turret":
		head = model.find_child("AimingHead*", true, false) as Node3D
		if head:
			head.reparent(enemy.get_node("SwivelHead"), true)
			head_rest = head.position
		previous_counter = float(enemy.get("burst_left"))
	elif kind == "gunship":
		previous_counter = float(enemy.get("fire_timer"))
	else:
		previous_counter = float(enemy.get("attack_state"))

func _process(delta: float) -> void:
	if model == null or enemy == null:
		return
	time += delta
	recoil = move_toward(recoil, 0.0, delta * 0.45)
	match kind:
		"crawler":
			locomotion.update(delta)
		"turret":
			var counter := float(enemy.get("burst_left"))
			if counter < previous_counter:
				recoil = 0.035
			previous_counter = counter
			if head:
				head.position = head_rest + Vector3(-recoil, 0, 0)
		"gunship":
			var counter := float(enemy.get("fire_timer"))
			if counter > previous_counter + 0.1:
				recoil = 0.045
			previous_counter = counter
			model.position.x = -recoil
			model.rotation.z = lerpf(model.rotation.z, -enemy.velocity.x * 0.013, delta * 3.0)
		"boss":
			var counter := float(enemy.get("attack_state"))
			if counter != previous_counter:
				recoil = 0.07
			previous_counter = counter
			model.position.x = -recoil
