extends Area3D

@export var damage_per_sec: float = 40.0
@export var is_pulsing: bool = false
@export var pulse_on_time: float = 2.0
@export var pulse_off_time: float = 1.5

var is_active: bool = true
var pulse_timer: float = 0.0
var _damage_tick_timer: float = 0.0

@onready var beam_mesh: MeshInstance3D = $BeamMesh
@onready var beam_light: OmniLight3D = $BeamLight
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	connect("body_entered", _on_body_entered)
	pulse_timer = pulse_on_time

func _process(delta: float) -> void:
	if is_pulsing:
		pulse_timer -= delta
		if pulse_timer <= 0.0:
			is_active = not is_active
			pulse_timer = pulse_on_time if is_active else pulse_off_time
			beam_mesh.visible = is_active
			beam_light.visible = is_active
			collision_shape.disabled = not is_active
			if is_active:
				SoundManager.play("alarm", 1.4, -6.0)

	if is_active:
		# Pulsing visual intensity
		var flicker := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.01)
		beam_light.light_energy = 4.0 * flicker

		# Continuous damage while the player stays inside the beam
		_damage_tick_timer -= delta
		if _damage_tick_timer <= 0.0:
			_damage_tick_timer = 0.5
			for body in get_overlapping_bodies():
				if body.is_in_group("player"):
					GameManager.take_player_damage(damage_per_sec * 0.5)
					FXManager.spawn_hit_spark(body.global_position, Color(1.0, 0.1, 0.1))
					FXManager.shake(0.25, 0.15)

func _on_body_entered(body: Node) -> void:
	if is_active and body.is_in_group("player"):
		GameManager.take_player_damage(damage_per_sec * 0.5)
		FXManager.spawn_hit_spark(body.global_position, Color(1.0, 0.1, 0.1))
		FXManager.shake(0.25, 0.15)
		_damage_tick_timer = 0.5
