extends Area3D

@export_enum("Energy:0", "Shield:1", "Weapon:2") var pickup_type: int = 0
@export var weapon_to_unlock: int = 1 # 1 = Scatter, 2 = Railgun

@onready var visual: Node3D = $Visual
@onready var light: OmniLight3D = $Light

var bob_offset: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	base_y = position.y
	bob_offset = randf() * TAU
	_setup_visual()

func _setup_visual() -> void:
	# Hide all sub-models except the selected type
	var m_energy = visual.get_node_or_null("EnergyModel")
	var m_shield = visual.get_node_or_null("ShieldModel")
	var m_weapon = visual.get_node_or_null("WeaponModel")

	if m_energy: m_energy.visible = (pickup_type == 0)
	if m_shield: m_shield.visible = (pickup_type == 1)
	if m_weapon: m_weapon.visible = (pickup_type == 2)

	match pickup_type:
		0:
			if light: light.light_color = Color(1.0, 0.8, 0.1)
		1:
			if light: light.light_color = Color(0.1, 0.8, 1.0)
		2:
			if light: light.light_color = Color(1.0, 0.45, 0.0)

func _process(delta: float) -> void:
	# Rotate continuously
	visual.rotate_y(2.2 * delta)
	visual.rotate_x(0.8 * delta)
	
	# Bobbing motion
	bob_offset += delta * 3.0
	position.y = base_y + sin(bob_offset) * 0.18
	position.z = 0.0

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		match pickup_type:
			0: # Energy
				GameManager.add_score(250)
				GameManager.heal_player(15.0)
				SoundManager.play("pickup_energy", 1.0, 0.0)
				FXManager.spawn_hit_spark(global_position, Color(1.0, 0.85, 0.2))
			1: # Shield
				GameManager.recharge_shield(40.0)
				SoundManager.play("pickup_shield", 1.0, 0.0)
				FXManager.spawn_hit_spark(global_position, Color(0.2, 0.8, 1.0))
			2: # Weapon Upgrade
				GameManager.unlock_weapon(weapon_to_unlock)
				GameManager.add_score(500)
				SoundManager.play("pickup_weapon", 1.0, 2.0)
				FXManager.spawn_hit_spark(global_position, Color(1.0, 0.5, 0.1))

		queue_free()
