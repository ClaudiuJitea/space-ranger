extends Node3D

## Shared mission systems; each mission supplies its own route and palette.
const PLATFORM := preload("res://src/environment/platform.tscn")
const PICKUP := preload("res://src/entities/pickups/pickup.tscn")
const CRATE := preload("res://src/environment/prop_crate.tscn")
const BARREL := preload("res://src/environment/explosive_barrel.tscn")
const TERMINAL := preload("res://src/environment/prop_terminal.tscn")
const HAZARD := preload("res://src/environment/hazard_laser.tscn")
const PILLAR := preload("res://assets/models/platform_pillar.glb")
const BOSS := preload("res://src/entities/enemies/boss.tscn")
const FOES := [preload("res://src/entities/enemies/enforcer.tscn"), preload("res://src/entities/enemies/crawler.tscn"), preload("res://src/entities/enemies/turret.tscn"), preload("res://src/entities/enemies/drone.tscn"), preload("res://src/entities/enemies/gunship.tscn")]
const NAMES := ["APEX PROTOCOL", "NIGHTGLASS REACTOR", "EMBERFALL CITADEL"]
const BOSS_NAMES := ["APEX IRON VANGUARD", "RIFT ALPHA MATRIARCH", "EMBERFALL SERAPH"]
const COLORS := [Color(0.15, 0.8, 1), Color(0.65, 0.35, 1), Color(1, 0.43, 0.1)]
@onready var player: CharacterBody3D = $Player
@onready var hud: Control = $HUD
@onready var platforms: Node3D = $Platforms
@onready var enemies: Node3D = $Enemies
@onready var props: Node3D = $Props
@onready var pickups: Node3D = $Pickups
@onready var hazards: Node3D = $Hazards
@onready var background_decor: Node3D = $BackgroundDecor
var boss: CharacterBody3D
var mission_index := 1
var arena_entry := 224.0
var route_length := 256.0
var boss_triggered := false
var completed := false
var relay_positions: Array[float] = []
var route_floors: Dictionary = {}
var gate: StaticBody3D
var gate_open := false
var _gate_visual: Node3D
var _gate_label: Label3D
var _progress: Label
var _poll := 0.0
var _regular_foes: Array[Node] = []

func _spawn(scene: PackedScene, parent: Node3D, location: Vector3, properties := {}) -> Node3D:
	var instance := scene.instantiate() as Node3D
	instance.position = location
	for property in properties:
		instance.set(property, properties[property])
	parent.add_child(instance)
	return instance

func _platform(name_text: String, location: Vector3, is_route := true) -> void:
	var instance := _spawn(PLATFORM, platforms, location)
	instance.name = name_text
	instance.set_meta("main_route", is_route)
	if not is_route:
		return
	route_floors[location.x] = minf(location.y, float(route_floors.get(location.x, location.y)))

func _floor_at(x: float) -> float:
	var closest := INF
	var height := 0.0
	for key in route_floors:
		if absf(float(key) - x) < closest:
			closest = absf(float(key) - x)
			height = route_floors[key]
	return height

func _footing(x: float) -> Vector3:
	var nearest := x
	var distance := INF
	for key in route_floors:
		if absf(float(key) - x) < distance:
			distance = absf(float(key) - x)
			nearest = float(key)
	return Vector3(nearest, _floor_at(nearest), 0)

func _route(start: int, finish: int, style: int) -> void:
	var profiles := [[0, 0, 1.4, 2.8, 2.8, 1.4, 0, 0], [0, 1.5, 3, 4.5, 6, 4.5, 3, 1.5], [0, 1.5, 3, 3, 1.5, 0, -1, -1]]
	var index := 0
	for x in range(start, finish + 1, 4):
		if index % 16 != 11:
			_platform("Route_%d" % x, Vector3(x, profiles[style][index % 8], 0))
		index += 1

func setup_mission(index: int, entry: float, length: float, relays: Array[float]) -> void:
	mission_index = index
	arena_entry = entry
	route_length = length
	relay_positions = relays
	for platform in platforms.get_children():
		if platform is StaticBody3D and platform.get_meta("main_route", true):
			var p: Vector3 = platform.position
			route_floors[p.x] = minf(p.y, float(route_floors.get(p.x, p.y)))
	var spawn_position := GameManager.prepare_mission(scene_file_path, 0 if index == 1 else (1 if index == 2 else 3))
	player.position = spawn_position
	player.last_safe_position = spawn_position
	var target_boss_hp: float = 1600.0 if index == 1 else (2400.0 if index == 2 else 2800.0)
	boss = enemies.get_node_or_null("Boss") as CharacterBody3D
	if not boss:
		boss = _spawn(BOSS, enemies, Vector3(entry + 14, 2.8 if index < 3 else 3.2, 0), {"boss_profile": index - 1, "max_health": target_boss_hp}) as CharacterBody3D
		boss.name = "Boss"
	else:
		boss.position = Vector3(entry + 14, 2.8 if index < 3 else 3.2, 0)
		boss.boss_profile = index - 1
		boss.max_health = target_boss_hp
		boss.health = target_boss_hp
	var camera := $Camera3D as Camera3D
	camera.set("boss_trigger_x", arena_entry)
	camera.set("boss_focus_x", arena_entry + 15)
	_configure_hud()
	_build_mission_features()
	for foe in enemies.get_children():
		if foe != boss:
			_regular_foes.append(foe)
	GameManager.boss_defeated.connect(_clear_arena)
	GameManager.level_completed.connect(_complete_mission)
	SoundManager.set_music_mood("explore")
	_update_objective()
	GameManager.notify.call_deferred("MISSION %02d // %s" % [index, NAMES[index - 1]], COLORS[index - 1])
	if "--screenshot" in OS.get_cmdline_user_args():
		_capture_and_quit()
	elif "--fps" in OS.get_cmdline_user_args():
		_report_fps()
	elif "--gate-screenshot" in OS.get_cmdline_user_args():
		_capture_gate()
	elif "--boss-screenshot" in OS.get_cmdline_user_args():
		_capture_boss()
	elif "--player-screenshot" in OS.get_cmdline_user_args():
		_capture_player()

func _configure_hud() -> void:
	hud.mission_name = NAMES[mission_index - 1]
	hud.boss_display_name = "TARGET: %s" % BOSS_NAMES[mission_index - 1]
	hud.boss_name_label.text = hud.boss_display_name
	hud.next_level_path = "res://src/levels/level_%02d.tscn" % (mission_index + 1) if mission_index < 3 else ""
	hud.next_mission_name = NAMES[mission_index] if mission_index < 3 else ""
	hud.final_mission = mission_index == 3
	hud.get_node("VictoryPanel/VBox/Eyebrow").text = "MISSION // %s" % hud.mission_name
	hud.get_node("GameOverPanel/VBox/Eyebrow").text = "MISSION // %s" % hud.mission_name
	hud.victory_detail = "%s NEUTRALIZED // SECTOR SECURED" % BOSS_NAMES[mission_index - 1]
	hud.get_node("VictoryPanel/VBox/Subtitle").text = hud.victory_detail
	hud.get_node("VictoryPanel/VBox/Title").text = "CAMPAIGN COMPLETE" if mission_index == 3 else "SECTOR SECURED"
	hud.get_node("VictoryPanel/VBox/Actions/RestartVictoryBtn").text = "NEXT // %s" % ("NIGHTGLASS" if mission_index == 1 else "EMBERFALL") if mission_index < 3 else "REPLAY CAMPAIGN"
	hud.get_node("TopCenter").offset_top = 68
	hud.get_node("TopCenter").offset_bottom = 118
	_progress = Label.new()
	_progress.name = "MissionProgress"
	_progress.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress.offset_left = -210
	_progress.offset_right = 210
	_progress.offset_top = 44
	_progress.offset_bottom = 60
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_override("font", preload("res://assets/fonts/ShareTechMono-Regular.ttf"))
	_progress.add_theme_font_size_override("font_size", 10)
	_progress.add_theme_color_override("font_color", COLORS[mission_index - 1])
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_progress)

func _build_mission_features() -> void:
	for x in relay_positions:
		var relay := StaticBody3D.new()
		relay.set_script(preload("res://src/environment/mission_relay.gd"))
		relay.set("mission", self)
		relay.set("relay_id", "relay_%d" % int(x))
		relay.set("relay_number", relay_positions.find(x) + 1)
		relay.set("relay_total", relay_positions.size())
		relay.position = Vector3(x, _floor_at(x), 0)
		props.add_child(relay)
	for x in [48.0, arena_entry * 0.46, arena_entry * 0.74, arena_entry - 12]:
		var checkpoint := Area3D.new()
		checkpoint.set_script(preload("res://src/environment/mission_checkpoint.gd"))
		checkpoint.set("mission", self)
		checkpoint.position = _footing(x)
		for relay_x in relay_positions:
			if absf(checkpoint.position.x - relay_x) < 4:
				checkpoint.position = _footing(relay_x - 8)
		props.add_child(checkpoint)
		_spawn(TERMINAL, props, checkpoint.position + Vector3(-1.2, 0, 0))
	_build_gate()
	for x in range(12, int(route_length), 24):
		_spawn(PILLAR, background_decor, Vector3(x, 3 + (x % 5), -4.5))

func populate_encounters(start: int, finish: int) -> void:
	var number := 0
	for x in range(start, finish, 14):
		# Leave a breath of empty deck every fifth beat so the run isn't a hallway of trash mobs.
		if number % 5 == 4:
			_spawn(CRATE, props, Vector3(x + 2, _floor_at(x + 2), 0), {"supply_type": number % 2})
			number += 1
			continue
		var kind := (number + mission_index - 1) % FOES.size()
		var altitude := 0.15
		if kind == 3: altitude = 3.3
		if kind == 4: altitude = 5.5
		_spawn(FOES[kind], enemies, Vector3(x, _floor_at(x) + altitude, 0))
		if kind == 2 or number % 3 == 1:
			_spawn(BARREL, props, Vector3(x + 2.4, _floor_at(x + 2), 0))
		if number % 4 == 0:
			_spawn(CRATE, props, Vector3(x + 4, _floor_at(x + 4), 0), {"supply_type": (number / 4) % 2})
		if number % 3 == 0:
			_spawn(PICKUP, pickups, Vector3(x + 7, _floor_at(x + 7) + 1.2, 0), {"pickup_type": number % 2})
		if number % 5 == 2:
			_spawn(HAZARD, hazards, Vector3(x + 5, _floor_at(x + 5), 0), {"is_pulsing": true, "pulse_on_time": 1.1, "pulse_off_time": 1.7})
		if number % 6 == 3 and kind != 4:
			var wingman := (kind + 2) % FOES.size()
			var wing_alt := 3.3 if wingman == 3 else (5.5 if wingman == 4 else 0.15)
			_spawn(FOES[wingman], enemies, Vector3(x + 3.5, _floor_at(x + 3) + wing_alt, 0))
		number += 1

func _build_gate() -> void:
	gate = StaticBody3D.new()
	gate.name = "ArenaGate"
	gate.position = Vector3(arena_entry - 2, 0, 0)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 24, 2)
	collider.shape = shape
	collider.position.y = 10
	gate.add_child(collider)
	props.add_child(gate)
	_gate_visual = Node3D.new()
	gate.add_child(_gate_visual)
	for z in [-0.65, 0, 0.65]:
		var beam := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.04
		mesh.bottom_radius = 0.04
		mesh.height = 10
		beam.mesh = mesh
		beam.position = Vector3(0, 5, z)
		beam.material_override = preload("res://src/projectiles/shot_visual.gd").luminous(COLORS[mission_index - 1], 1.5)
		_gate_visual.add_child(beam)
	_gate_label = Label3D.new()
	_gate_label.position = Vector3(-0.6, 3.3, 0)
	_gate_label.font = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
	_gate_label.font_size = 26
	_gate_label.pixel_size = 0.008
	_gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_gate_label.no_depth_test = true
	_gate_label.modulate = COLORS[mission_index - 1]
	gate.add_child(_gate_label)
	_update_gate()

func _relay_count() -> int:
	var count := 0
	for x in relay_positions:
		if GameManager.mission_relays.has("relay_%d" % int(x)):
			count += 1
	return count

func _update_gate() -> void:
	gate_open = _relay_count() == relay_positions.size()
	gate.get_child(0).set_deferred("disabled", gate_open and not boss_triggered)
	_gate_visual.visible = not gate_open or boss_triggered

func register_relay(id: String, award_score := true) -> void:
	if GameManager.mission_relays.has(id):
		return
	GameManager.mission_relays.append(id)
	if award_score:
		GameManager.add_score(500)
	# Network progress must survive an anchor that was reached before pressing F.
	if GameManager.mission_checkpoint.get("path", "") == scene_file_path:
		GameManager.mission_checkpoint["relays"] = GameManager.mission_relays.duplicate()
	GameManager.notify("RELAY SYNCED // %d/%d" % [GameManager.mission_relays.size(), relay_positions.size()], COLORS[mission_index - 1])
	_update_gate()
	_update_objective()
	if gate_open:
		GameManager.notify("ARENA ACCESS OPEN // SUIT ANCHOR AHEAD", Color(0.15, 1, 0.65))

func _input(event: InputEvent) -> void:
	if not is_instance_valid(gate) or not is_instance_valid(player):
		return
	if gate_open or boss_triggered or GameManager.health <= 0:
		return
	if absf(player.position.x - gate.position.x) <= 3.5 and event.is_action_pressed("interact"):
		for x in relay_positions:
			register_relay("relay_%d" % int(x), false)
		GameManager.notify("LOCAL OVERRIDE ACCEPTED // ARENA ACCESS OPEN", Color(0.15, 1, 0.65))
		SoundManager.play("pickup_shield", 1.1, -4)
		get_viewport().set_input_as_handled()

func _update_gate_prompt() -> void:
	_gate_label.visible = not gate_open and not boss_triggered and absf(player.position.x - gate.position.x) < 18
	if not _gate_label.visible:
		return
	var missing := ""
	for x in relay_positions:
		if not GameManager.mission_relays.has("relay_%d" % int(x)):
			missing += (", " if not missing.is_empty() else "") + "%d m" % int(x)
	_gate_label.text = "ARENA LOCKED // RELAYS %d/%d\nMISSING: %s\n%s" % [_relay_count(), relay_positions.size(), missing, "[F] LOCAL OVERRIDE" if absf(player.position.x - gate.position.x) <= 3.5 else "APPROACH GATE TO OVERRIDE"]

func register_checkpoint(location: Vector3) -> void:
	if location.x <= GameManager.mission_checkpoint.get("position", Vector3.ZERO).x:
		return
	GameManager.heal_player(25)
	GameManager.recharge_shield(40)
	GameManager.store_checkpoint(scene_file_path, location)
	player.last_safe_position = location
	GameManager.notify("SUIT ANCHOR SECURED // REDEPLOY POINT UPDATED", COLORS[mission_index - 1])
	SoundManager.play("respawn", 1.15, -5)

func _update_objective() -> void:
	if boss_triggered:
		hud.objective_label.text = "OBJECTIVE // DESTROY %s" % BOSS_NAMES[mission_index - 1]
	elif gate_open:
		hud.objective_label.text = "OBJECTIVE // BREACH THE BOSS ARENA"
	else:
		for x in relay_positions:
			if not GameManager.mission_relays.has("relay_%d" % int(x)):
				hud.objective_label.text = "RELAYS %d/%d // SYNC BEACON AT %d m" % [GameManager.mission_relays.size(), relay_positions.size(), x]
				break

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(_progress):
		return
	_update_gate_prompt()
	var progress := 1.0 if completed else clampf(player.position.x / route_length, 0, 1)
	_progress.text = "MISSION %02d // ROUTE %03d%% // RELAYS %d/%d" % [mission_index, roundi(progress * 100), GameManager.mission_relays.size(), relay_positions.size()]
	$SpaceBackdrop.position.x = player.position.x * 0.88
	if gate_open and not boss_triggered and player.position.x >= arena_entry:
		_trigger_boss_fight()
	_poll -= delta
	if _poll <= 0:
		_poll = 0.3
		for foe in _regular_foes:
			if is_instance_valid(foe) and foe is Node3D:
				foe.process_mode = Node.PROCESS_MODE_INHERIT if absf(foe.position.x - player.position.x) < 38 else Node.PROCESS_MODE_DISABLED

func _trigger_boss_fight() -> void:
	if boss_triggered:
		return
	boss_triggered = true
	for foe in enemies.get_children():
		if foe != boss and foe is Node3D and foe.position.x >= arena_entry - 4:
			foe.queue_free()
	gate.get_child(0).set_deferred("disabled", false)
	_gate_visual.show()
	boss.activate_boss()
	_update_objective()
	GameManager.notify("%s // ARENA SEALED" % BOSS_NAMES[mission_index - 1], COLORS[mission_index - 1])
	FXManager.shake(0.45, 0.4)

func _clear_arena() -> void:
	if not boss_triggered:
		return
	gate.get_child(0).set_deferred("disabled", true)
	_gate_visual.hide()
	for foe in enemies.get_children():
		if foe != boss:
			foe.queue_free()
	for hazard in hazards.get_children():
		hazard.queue_free()

func _complete_mission() -> void:
	completed = true
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	hud.objective_label.text = "CAMPAIGN COMPLETE // ALL SECTORS SECURED" if mission_index == 3 else "MISSION COMPLETE // SECTOR SECURED"

func restart_mission() -> void:
	GameManager.retry_pending = true
	get_tree().paused = false
	get_tree().reload_current_scene()

func _capture_and_quit() -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/level_%02d_screenshot.png" % mission_index)
	get_tree().quit()

func _capture_boss() -> void:
	await get_tree().create_timer(0.2).timeout
	for x in relay_positions:
		register_relay("relay_%d" % int(x))
	player.position = Vector3(arena_entry + (7 if mission_index == 2 else 10), 0.2, 0)
	GameManager.hurt_invuln_timer = 99
	player.set_physics_process(false)
	player.visual_root.visible = true
	_trigger_boss_fight()
	await get_tree().create_timer(3.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/boss_%02d_screenshot.png" % mission_index)
	get_tree().quit()

func _report_fps() -> void:
	await get_tree().create_timer(1.0).timeout
	var frame_count := Engine.get_frames_drawn()
	var started := Time.get_ticks_msec()
	await get_tree().create_timer(5.0).timeout
	var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
	print("AVERAGE GAMEPLAY FPS: %.1f" % ((Engine.get_frames_drawn() - frame_count) / elapsed))
	get_tree().quit()

func _capture_gate() -> void:
	await get_tree().create_timer(0.2).timeout
	register_relay("relay_%d" % int(relay_positions.back()))
	player.position = Vector3(gate.position.x - 2, _floor_at(gate.position.x - 2) + 0.05, 0)
	for foe in _regular_foes:
		if is_instance_valid(foe):
			foe.set_physics_process(false)
	await get_tree().create_timer(3.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/gate_%02d_screenshot.png" % mission_index)
	get_tree().quit()

func _capture_player() -> void:
	# Settle onto platform
	await get_tree().create_timer(1.0).timeout
	var camera := $Camera3D as Camera3D
	camera.set_physics_process(false)
	hud.visible = false
	player.set_process_unhandled_input(false)
	player.mouse_active = false
	player.aim_direction = Vector3.RIGHT
	player.aim_solver.aim_direction = Vector3.RIGHT
	player.recoil_kick = 0.0
	player.recoil_pitch = 0.0

	var setup_cam_close = func():
		camera.global_position = player.global_position + Vector3(0.4, 1.25, 2.5)
		camera.look_at(player.global_position + Vector3(0.3, 1.15, 0.0), Vector3.UP)
		camera.fov = 36.0

	# 1. PX-9 Pulse Blaster
	player._equip_weapon_model(0, true)
	setup_cam_close.call()
	for _i in range(12):
		player.aim_direction = Vector3.RIGHT
		player.aim_solver.aim_direction = Vector3.RIGHT
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/player_two_handed_blaster.png")

	# 2. Scattergun
	player._equip_weapon_model(1, true)
	setup_cam_close.call()
	for _i in range(12):
		player.aim_direction = Vector3.RIGHT
		player.aim_solver.aim_direction = Vector3.RIGHT
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/player_two_handed_scattergun.png")

	# 3. Railgun
	player._equip_weapon_model(2, true)
	setup_cam_close.call()
	for _i in range(12):
		player.aim_direction = Vector3.RIGHT
		player.aim_solver.aim_direction = Vector3.RIGHT
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/player_two_handed_railgun.png")

	# 4. Rocket Launcher
	player._equip_weapon_model(3, true)
	setup_cam_close.call()
	for _i in range(12):
		player.aim_direction = Vector3.RIGHT
		player.aim_solver.aim_direction = Vector3.RIGHT
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/player_two_handed_launcher.png")

	# 5. Full gameplay view with Blaster
	player._equip_weapon_model(0, true)
	camera.global_position = player.global_position + Vector3(-0.8, 2.8, 6.8)
	camera.look_at(player.global_position + Vector3(0.4, 1.0, 0.0), Vector3.UP)
	camera.fov = 42.0
	for _i in range(12):
		player.aim_direction = Vector3.RIGHT
		player.aim_solver.aim_direction = Vector3.RIGHT
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/player_two_handed_gameplay.png")

	get_tree().quit()

