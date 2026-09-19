extends Node3D

func _ready() -> void:
	print("=== LookAtModifier3D properties ===")
	for p in ClassDB.class_get_property_list("LookAtModifier3D", true):
		print("  ", p.name, " : ", type_string(p.type), " default=", p.get("default_value"))
	print("=== LookAtModifier3D enums ===")
	for e in ClassDB.class_get_enum_list("LookAtModifier3D", true):
		print("  enum ", e, " = ", ClassDB.class_get_enum_constants("LookAtModifier3D", e, true))
	print("=== SkeletonModifier3D properties ===")
	for p in ClassDB.class_get_property_list("SkeletonModifier3D", true):
		print("  ", p.name, " : ", type_string(p.type))
	print("=== LookAtModifier3D methods ===")
	for m in ClassDB.class_get_method_list("LookAtModifier3D", true):
		print("  ", m.name)
	get_tree().quit()
