extends Node
var failed := false
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	await frames(5)
	check(SoundManager._recorded_sfx.size() == SoundManager.SFX_KEYS.size(), "All 30 cues must use the downloaded recordings")
	check(SoundManager._recorded_music.size() == 3, "All music layers must use downloaded recordings")
	for cue in SoundManager.COMBAT_CUES:
		var stream: AudioStream = SoundManager._sounds[cue]
		check(stream is AudioStreamMP3 and stream.get_length() > 0, "%s must resolve to a valid recorded MP3" % cue)
		check(stream == SoundManager._sounds[SoundManager.COMBAT_CUES[cue]], "%s must reuse its downloaded source" % cue)
		SoundManager._last_played.clear()
		for player in SoundManager.audio_players: player.stop()
		SoundManager.play(cue)
		check(SoundManager.audio_players[0].stream == stream, "Combat event must select downloaded playback")
	for layer in SoundManager._music:
		var stream: AudioStreamMP3 = SoundManager._music[layer].stream
		check(stream.loop, "Recorded music must loop")
	SoundManager.set_music_mood("menu")
	check(SoundManager.music_mood == "menu", "Deferred music must retain the opening-screen mood")
	GameManager.reset_game()
	var level: Node3D = load("res://src/levels/level_04.tscn").instantiate()
	add_child(level)
	await frames(10)
	level.player.set_physics_process(false)
	for foe in level.enemies.get_children(): foe.set_physics_process(false)
	var player: CharacterBody3D = level.player
	for slot in range(4):
		player._equip_weapon_model(slot, true)
		player.aim_direction = Vector3.RIGHT
		player.aim_solver.aim_direction = Vector3.RIGHT
		await frames(4)
		check(player.active_muzzle != null, "Player gun %d must retain a muzzle socket" % slot)
		check(player.aim_solver.is_ready() and player.weapon_instances[slot].global_transform.is_finite(), "Player gun must retain aiming and valid transforms")
		check((-player.weapon_instances[slot].global_basis.y.normalized()).dot(Vector3.RIGHT) > 0.95, "Refitted barrels must align with the aim direction")
		var origin: Vector3 = player._muzzle_pos()
		check(origin.distance_to(player.active_muzzle.global_position) < 0.001, "Gun must fire from the actual muzzle")
		check(origin.distance_to(player.global_position) < 3, "Gun mount must remain at hand scale")
		GameManager.current_weapon = slot
		player.heat = 0
		player._shoot()
		check(player.fire_timer > 0, "Each refitted gun must still fire")
	for kind in ["enforcer", "drone", "crawler", "turret", "gunship", "armed_hound", "interceptor"]:
		var enemy: CharacterBody3D = load("res://src/entities/enemies/%s.tscn" % kind).instantiate()
		level.enemies.add_child(enemy)
		enemy.set_physics_process(false)
		await frames(4)
		if kind in ["enforcer", "drone"]:
			check(enemy.find_children("Icosphere*", "MeshInstance3D", true, false).is_empty(), "Humanoid export must exclude Blender rig helper spheres")
			var animator = enemy.get_node("ModelAnimation")
			check(animator.player != null and animator.player.has_animation("Idle"), "Humanoid must retain locomotion clips")
			check(animator.aim_solver.is_ready() and animator.muzzle != null, "Enemy rifle must retain aiming and muzzle")
		elif kind == "crawler":
			check(enemy.get_node("ModelAnimation").legs.size() == 4, "Crawler must retain four gait pivots")
		elif kind == "turret":
			var visual = enemy.get_node("ModelAnimation")
			check(visual.head != null and visual.head.get_parent() == enemy.get_node("SwivelHead"), "Turret armor and weapon must track swivel head")
		elif kind == "armed_hound":
			check(enemy.legs.size() == 4 and enemy.muzzle != null, "Hound must retain gait and weapon socket")
		elif kind == "interceptor":
			check(enemy.rotors.size() == 2, "Wasp must retain spinning fans")
		enemy.queue_free()
		await frames(2)
	level.queue_free()
	await frames(3)
	print("ARSENAL AND DOWNLOADED AUDIO CHECKS: ", "FAILED" if failed else "PASSED")
	get_tree().quit(1 if failed else 0)
