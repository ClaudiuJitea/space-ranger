extends Node3D

@export var damage: float = 22.0
@export var pulse_interval: float = 3.2
@export var charge_duration: float = 0.85
@export var pulse_radius: float = 3.2

var _timer: float = 0.0
var _charging: bool = false
@onready var pulse_light: OmniLight3D = $BeaconLight
@onready var trigger_area: Area3D = $DamageArea

func _ready() -> void:
	var anim_player: AnimationPlayer = find_child("*AnimationPlayer*", true, false)
	if anim_player:
		for anim_name in anim_player.get_animation_list():
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)

func _physics_process(delta: float) -> void:
	_timer += delta
	if not _charging and _timer >= pulse_interval - charge_duration:
		_charging = true
		_start_telegraph()
	elif _timer >= pulse_interval:
		_timer = 0.0
		_charging = false
		_fire_pulse()

func _start_telegraph() -> void:
	SoundManager.play("plasma_burst", 1.6, -6.0)
	var tw := create_tween()
	tw.tween_property(pulse_light, "light_energy", 4.5, charge_duration)
	tw.parallel().tween_property(pulse_light, "omni_range", 6.0, charge_duration)

func _fire_pulse() -> void:
	pulse_light.light_energy = 0.8
	pulse_light.omni_range = 3.5
	SoundManager.play("explosion", 1.8, -2.0)
	FXManager.spawn_shockwave(global_position + Vector3(0, 2.5, 0), Color(1.0, 0.55, 0.1), pulse_radius * 1.5)
	FXManager.spawn_hit_spark(global_position + Vector3(0, 2.5, 0), Color(1.0, 0.7, 0.2))
	FXManager.add_trauma(0.18)

	for body in trigger_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			GameManager.take_player_damage(damage)
			FXManager.spawn_shield_impact(body.global_position)
