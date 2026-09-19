extends WeaponAimSolver
class_name EnemyRifleAim

## Visual support-hand IK; combat direction and timing remain owned by the enemy.
var support_error := 0.0

func _init() -> void:
	two_handed = true
	support_grip = Vector3(0.0, -0.15, 0.032)
