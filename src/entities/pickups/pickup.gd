extends Area3D

@export_enum("Energy:0", "Shield:1", "Weapon:2") var pickup_type: int = 0
@export var weapon_to_unlock: int = 1 # 1 = Scattergun, 2 = Railgun, 3 = Launcher

@onready var visual: Node3D = $Visual
@onready var light: OmniLight3D = $Light

var bob_offset: float = 0.0
var base_y: float = 0.0
var _collected: bool = false

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	base_y = visual.position.y
	bob_offset = randf() * TAU
	_setup_visual()

func _setup_visual() -> void:
	# Hide all sub-models except the selected type
	var m_energy = visual.get_node_or_null("EnergyModel")
	var m_shield = visual.get_node_or_null("ShieldModel")
	var m_weapon = visual.get_node_or_null("WeaponModel")

	if m_energy: m_energy.visible = (pickup_type == 0)
	if m_shield: m_shield.visible = (pickup_type == 1)

	match pickup_type:
		0:
			if light: light.light_color = Color(1.0, 0.8, 0.1)
		1:
			if light: light.light_color = Color(0.1, 0.8, 1.0)
		2:
			if weapon_to_unlock >= 0 and weapon_to_unlock < GameManager.WEAPON_COLORS.size():
				if light: light.light_color = GameManager.WEAPON_COLORS[weapon_to_unlock]
			else:
				if light: light.light_color = Color(1.0, 0.45, 0.0)
			# Show the real weapon inside the pickup instead of a generic crate.
			var weapon_scene := _weapon_model_scene()
			if weapon_scene and m_weapon:
				m_weapon.visible = false
				var holder := Node3D.new()
				holder.name = "WeaponDisplay"
				visual.add_child(holder)
				var inst: Node3D = weapon_scene.instantiate()
				# Weapon models are authored barrel along -Y; pitch it flat so
				# it reads as a gun while the pickup spins it around Y.
				inst.rotation = Vector3(PI * 0.5, 0.0, 0.0)
				inst.scale = Vector3.ONE * 0.6
				holder.add_child(inst)

func _weapon_model_scene() -> PackedScene:
	match weapon_to_unlock:
		1: return preload("res://assets/models/weapon_scattergun.glb")
		2: return preload("res://assets/models/weapon_railgun.glb")
		3: return preload("res://assets/models/weapon_launcher.glb")
	return null

func _process(delta: float) -> void:
	# Rotate continuously
	visual.rotate_y(2.2 * delta)
	visual.rotate_x(0.8 * delta)

	# Bobbing motion
	bob_offset += delta * 3.0
	visual.position.y = base_y + sin(bob_offset) * 0.18

func _on_body_entered(body: Node) -> void:
	if _collected or GameManager.health <= 0:
		return
	if body.is_in_group("player"):
		_collected = true
		match pickup_type:
			0: # Energy
				GameManager.add_score(250)
				GameManager.heal_player(15.0)
				SoundManager.play("pickup_energy", 1.0, 0.0)
				FXManager.spawn_hit_spark(global_position, Color(1.0, 0.85, 0.2))
				GameManager.notify("HULL PATCHED  +15", Color(1.0, 0.8, 0.2))
			1: # Shield
				GameManager.recharge_shield(40.0)
				SoundManager.play("pickup_shield", 1.0, 0.0)
				FXManager.spawn_hit_spark(global_position, Color(0.2, 0.8, 1.0))
				GameManager.notify("SHIELD RECHARGE  +40", Color(0.2, 0.8, 1.0))
			2: # Weapon Upgrade
				var had_it: bool = GameManager.unlocked_weapons[weapon_to_unlock]
				GameManager.unlock_weapon(weapon_to_unlock)
				GameManager.add_score(500)
				SoundManager.play("pickup_weapon", 1.0, 2.0)
				if weapon_to_unlock < GameManager.WEAPON_COLORS.size():
					FXManager.spawn_shockwave(global_position, GameManager.WEAPON_COLORS[weapon_to_unlock], 2.5)
				FXManager.spawn_hit_spark(global_position, Color(1.0, 0.5, 0.1))
				var slot_hint: String = str(weapon_to_unlock + 1)
				if had_it:
					GameManager.notify("AMMO RECLAIMED — %s" % GameManager.WEAPON_NAMES[weapon_to_unlock],
						GameManager.WEAPON_COLORS[weapon_to_unlock])
				else:
					GameManager.notify("WEAPON ACQUIRED [%s]  %s" % [slot_hint, GameManager.WEAPON_NAMES[weapon_to_unlock]],
						GameManager.WEAPON_COLORS[weapon_to_unlock])

		queue_free()
