extends Node3D

@export var star_count: int = 120
@export var asteroid_count: int = 18

func _ready() -> void:
	_generate_stars()
	_generate_distant_asteroids()

func _generate_stars() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.95, 1.0)
	
	for i in range(star_count):
		var star := MeshInstance3D.new()
		star.mesh = sphere
		star.material_override = mat
		star.position = Vector3(
			randf_range(-40.0, 140.0),
			randf_range(-25.0, 45.0),
			randf_range(-15.0, -35.0)
		)
		var s := randf_range(0.4, 1.4)
		star.scale = Vector3(s, s, s)
		add_child(star)

func _generate_distant_asteroids() -> void:
	var mat_rock := StandardMaterial3D.new()
	mat_rock.albedo_color = Color(0.12, 0.14, 0.18)
	mat_rock.metallic = 0.3
	mat_rock.roughness = 0.85

	for i in range(asteroid_count):
		var rock := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := randf_range(1.5, 4.0)
		box.size = Vector3(s, s * randf_range(0.7, 1.3), s * randf_range(0.7, 1.3))
		rock.mesh = box
		rock.material_override = mat_rock
		rock.position = Vector3(
			randf_range(-30.0, 130.0),
			randf_range(-15.0, 35.0),
			randf_range(-12.0, -25.0)
		)
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_child(rock)

func _process(delta: float) -> void:
	for child in get_children():
		if child is MeshInstance3D and child.position.z < -10.0:
			child.rotate_y(0.015 * delta)
