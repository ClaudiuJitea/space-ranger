extends Area3D

var _collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var anim_player: AnimationPlayer = find_child("*AnimationPlayer*", true, false)
	if anim_player:
		for anim_name in anim_player.get_animation_list():
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)

func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	SoundManager.play("powerup", 1.25, 2.0)
	GameManager.add_score(2500)
	GameManager.recharge_shield(GameManager.max_shield)
	GameManager.notify("CYBER-RELIC DECRYPTED // +2500 PTS", Color(0.85, 0.3, 1.0))
	FXManager.spawn_shockwave(global_position, Color(0.85, 0.25, 1.0), 3.8)
	FXManager.spawn_hit_spark(global_position + Vector3(0, 0.8, 0), Color(0.9, 0.4, 1.0))
	FXManager.add_trauma(0.12)
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.35, 1.35, 1.35), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y + 0.8, 0.25)
	tw.chain().tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	tw.chain().tween_callback(queue_free)
