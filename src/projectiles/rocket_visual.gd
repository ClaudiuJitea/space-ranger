extends Node3D

## Blender-authored HV-4 body; nozzle effects remain animated by Godot.
const MISSILE := preload("res://assets/models/projectiles/hv4_havoc_missile.glb")

func _ready() -> void:
	var model := MISSILE.instantiate()
	model.name = "HavocMissileModel"
	add_child(model)
	var socket := model.find_child("ExhaustSocket", true, false) as Node3D
	var exhaust := preload("res://src/projectiles/muzzle_burst.gd").flare(0.55, 0.08, Color(1, 0.55, 0.1), true)
	exhaust.name = "EngineExhaust"
	exhaust.position = to_local(socket.global_position) if socket else Vector3(0, 0, 0.326)
	add_child(exhaust)
