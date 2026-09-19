extends Node3D

const MENU_STYLE := preload("res://src/ui/suit_menu_style.gd")
const UI_THEME := preload("res://src/ui/space_ui_theme.tres")
const MENU_CHROME := preload("res://src/ui/main_menu_chrome.gd")
const MENU_ICON := preload("res://src/ui/main_menu_icon.gd")
const DISPLAY_FONT := preload("res://assets/fonts/Exo2-Variable.ttf")

## Hero-shot title screen: ranger on the command dais, planet-lit, UI overlay.

@onready var camera: Camera3D = $MenuCamera

const CAM_HOME_POS := Vector3(1.72, 1.62, 5.95)
const CAM_HOME_LOOK := Vector3(0.48, 1.12, -0.42)
const CAM_HOME_FOV := 36.0

var _t: float = 0.0
var _focus_target: Control = null
var _menu_root: Control = null
var _transitioning := false
var _title_box: Control = null
var _title_plate: Control = null
var _chrome: Control = null
var _deck_holo: Node3D = null
var _deck_gunship: Node3D = null
var _ranger_hero: Node3D = null
var _ranger_aim: WeaponAimSolver = null
var _holo_base := Vector3.ZERO
var _gunship_base := Vector3.ZERO

var _cam_target_pos := CAM_HOME_POS
var _cam_target_look := CAM_HOME_LOOK
var _cam_target_fov := CAM_HOME_FOV
var _current_look := CAM_HOME_LOOK

func _ready() -> void:
	SoundManager.set_music_mood("menu")
	_init_title_dock_animations()
	_tune_title_dock_lighting()
	_setup_cinematic_lighting()
	_mount_hero_ranger()
	_dress_command_deck()
	_build_ui()
	var args := OS.get_cmdline_user_args()
	if "--controls-screenshot" in args:
		_capture_panel_and_quit(_controls_panel, "/tmp/controls_screenshot.png")
	elif "--settings-screenshot" in args:
		_capture_panel_and_quit(_settings_panel, "/tmp/settings_screenshot.png")
	elif "--screenshot" in args:
		_capture_and_quit()

func _tune_title_dock_lighting() -> void:
	var dock := get_node_or_null("TitleDock")
	if not dock:
		return
	for light in dock.find_children("*", "Light3D", true, false):
		if light is OmniLight3D or light is SpotLight3D:
			# The old accent lamp sat on the projector and blew it out to white.
			light.light_color = Color(0.18, 0.55, 0.78)
			light.light_energy = 0.06
			light.shadow_enabled = false
		elif light is Light3D:
			light.light_energy = clampf(light.light_energy * 0.08, 0.25, 1.1)
			light.shadow_enabled = true
	_retint_title_dock(dock)
	# Hide the drone satellite: replaced by the Ranger hero
	var sat := dock.find_child("Sentinel_Satellite_Root", true, false)
	if sat:
		sat.visible = false

func _holo_mat(albedo: Color, emission: Color, energy: float, transparent := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.metallic = 0.12
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _retint_title_dock(dock: Node) -> void:
	# Dark machined stage, restrained teal neon. The planet should light the ranger, not bleach the floor.
	var neon := _holo_mat(Color(0.04, 0.12, 0.16, 1.0), Color(0.18, 0.48, 0.58), 0.7, false)
	var panel := _holo_mat(Color(0.03, 0.10, 0.14, 0.22), Color(0.16, 0.48, 0.58), 0.28)
	var core := _holo_mat(Color(0.05, 0.16, 0.20, 0.42), Color(0.18, 0.52, 0.62), 0.55)
	var ring := _holo_mat(Color(0.12, 0.42, 0.55, 0.28), Color(0.20, 0.58, 0.70), 0.35)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.022, 0.026, 0.032)
	metal.metallic = 0.42
	metal.roughness = 0.62
	var metal_mid := StandardMaterial3D.new()
	metal_mid.albedo_color = Color(0.03, 0.036, 0.044)
	metal_mid.metallic = 0.38
	metal_mid.roughness = 0.58
	for mesh in dock.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mesh.name)
		if nm.contains("Holo_HUD") or nm.contains("Holo_Line"):
			mesh.material_override = ring
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif nm.contains("Holo_Console") or nm.contains("Holo_Brick") or nm.contains("Holo_Panel"):
			mesh.material_override = panel
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif nm.contains("Holo_Energy") or nm.contains("Holo_Core") or nm.contains("Holo_Data"):
			mesh.material_override = core
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif nm.contains("Neon_") or nm.contains("Hero_Dais_Ring") or nm.contains("Hero_Dais_Core") or nm.contains("Holo_Pedestal_Ring"):
			mesh.material_override = neon
		else:
			mesh.material_override = metal if nm.contains("Command_") else metal_mid

func _mount_hero_ranger() -> void:
	var dock := get_node_or_null("TitleDock")
	if dock == null:
		return
	for node in dock.find_children("*", "Node", true, false):
		var nm := String(node.name)
		if nm.begins_with("vanguard") or nm.begins_with("mixamorig") or nm == "Ranger_Blaster_Rifle" or nm == "Character":
			node.visible = false

	var hero: Node3D = (load("res://assets/models/player.glb") as PackedScene).instantiate()
	hero.name = "MenuRanger"
	dock.add_child(hero)
	# Dais is at Blender (0.55, 0.35, 0.12) → glTF Y-up (0.55, 0.12, -0.35)
	hero.position = Vector3(0.55, 0.12, -0.35)
	hero.rotation.y = PI * 0.92
	hero.scale = Vector3.ONE
	var ap: AnimationPlayer = hero.find_child("*AnimationPlayer*", true, false)
	if ap:
		for anim_name in ap.get_animation_list():
			var anim := ap.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
		var played := false
		for anim_name in ap.get_animation_list():
			if anim_name.to_lower() == "idle":
				ap.play(anim_name)
				played = true
				break
		if not played and not ap.get_animation_list().is_empty():
			ap.play(ap.get_animation_list()[0])
	_ranger_hero = hero
	_put_blaster_in_hand(hero)

func _loop_imported_anims(root: Node) -> void:
	var ap: AnimationPlayer = root.find_child("*AnimationPlayer*", true, false)
	if ap == null:
		return
	for anim_name in ap.get_animation_list():
		var anim := ap.get_animation(anim_name)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
	if not ap.get_animation_list().is_empty():
		ap.play(ap.get_animation_list()[0])

func _place_prop(dock: Node, path: String, pos: Vector3, rot: Vector3, scale := 1.0) -> Node3D:
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	dock.add_child(inst)
	inst.position = pos
	inst.rotation = rot
	inst.scale = Vector3.ONE * scale
	_loop_imported_anims(inst)
	return inst

func _put_blaster_in_hand(hero: Node3D) -> void:
	var skel: Skeleton3D = hero.find_child("*Skeleton3D*", true, false)
	if skel == null:
		return
	# Same PX-9 rig as in-mission: solver writes the gun's world transform in
	# Mixamo centimetre space so the grip sits in the fist.
	var holder := Node3D.new()
	holder.name = "MenuPX9"
	hero.add_child(holder)
	var gun: Node3D = preload("res://assets/models/weapon_blaster.glb").instantiate()
	gun.name = "Weapon_0"
	holder.add_child(gun)
	var solver := WeaponAimSolver.new()
	solver.name = "MenuWeaponAim"
	solver.center_rifle_hold = true
	solver.reach = 0.17
	solver.grip_drop = -0.05
	solver.two_handed = true
	solver.support_grip = Vector3(0.0, -0.24, 0.015)
	solver.aim_weight = 1.0
	skel.add_child(solver)
	solver.setup(skel, holder)
	_ranger_aim = solver

func _dress_command_deck() -> void:
	var dock := get_node_or_null("TitleDock")
	if dock == null:
		return
	# Keep the HUD scan-rings around the operative. Hide every other holo primitive
	# and the inset well so the dais reads as a stage, not a prop dump.
	for mesh in dock.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mesh.name)
		if nm.contains("Deck_Inset_Well"):
			mesh.visible = false
		elif nm.contains("Holo_HUD"):
			mesh.visible = true
		elif nm.contains("Holo_"):
			mesh.visible = false

	# Distant gunship as a small silhouette off the planet limb — never over the title.
	_deck_gunship = _place_prop(
		dock,
		"res://assets/models/concept_enemies_v2/gunship.glb",
		Vector3(6.4, 3.4, -15.5),
		Vector3(0.18, -PI * 0.62, 0.08),
		1.35
	)
	_gunship_base = _deck_gunship.position
	_add_dust_motes()

func _setup_cinematic_lighting() -> void:
	var key := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key:
		key.light_color = Color(1.0, 0.84, 0.62)
		key.light_energy = 1.35
		key.shadow_enabled = true
		key.global_position = Vector3(-11.0, 9.5, -16.0)
		key.look_at(Vector3(0.5, 1.05, -0.3), Vector3.UP)

	var rim := DirectionalLight3D.new()
	rim.name = "CyanRim"
	rim.light_color = Color(0.28, 0.78, 1.0)
	rim.light_energy = 1.15
	rim.shadow_enabled = false
	add_child(rim)
	rim.global_position = Vector3(5.5, 3.2, 3.8)
	rim.look_at(Vector3(0.5, 1.2, -0.4), Vector3.UP)

	var spot := SpotLight3D.new()
	spot.name = "DaisSpot"
	spot.light_color = Color(0.82, 0.94, 1.0)
	spot.light_energy = 1.7
	spot.spot_range = 7.0
	spot.spot_angle = 16.0
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = true
	spot.position = Vector3(0.85, 4.8, 1.4)
	add_child(spot)
	spot.look_at(Vector3(0.55, 0.15, -0.35), Vector3.UP)

	var fill := OmniLight3D.new()
	fill.name = "CameraFill"
	fill.light_color = Color(0.55, 0.72, 0.9)
	fill.light_energy = 0.14
	fill.omni_range = 6.0
	fill.shadow_enabled = false
	fill.position = Vector3(1.6, 1.6, 3.6)
	add_child(fill)

func _add_dust_motes() -> void:
	var dust := GPUParticles3D.new()
	dust.name = "PlanetDust"
	dust.amount = 48
	dust.lifetime = 9.0
	dust.preprocess = 4.0
	dust.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 8, 12))
	dust.position = Vector3(0.4, 1.35, 0.8)
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 6
	mesh.rings = 3
	dust.draw_pass_1 = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.92, 0.82, 0.62, 0.42)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.6, 1.4, 2.4)
	pm.direction = Vector3(0.18, 0.85, -0.12)
	pm.spread = 28.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.11
	pm.gravity = Vector3(0.02, 0.015, 0.0)
	pm.scale_min = 0.4
	pm.scale_max = 1.6
	pm.color = Color(0.95, 0.86, 0.68, 0.55)
	dust.process_material = pm
	add_child(dust)

func _init_title_dock_animations() -> void:
	var dock := get_node_or_null("TitleDock")
	if not dock:
		return
	var stack: Array[Node] = [dock]
	while stack.size() > 0:
		var curr = stack.pop_back()
		if curr is AnimationPlayer:
			for anim_name in curr.get_animation_list():
				var anim = curr.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
				curr.play(anim_name)
		for c in curr.get_children():
			stack.push_back(c)


func _capture_and_quit() -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/main_menu_screenshot.png")
	get_tree().quit()

func _capture_panel_and_quit(panel: PanelContainer, path: String) -> void:
	await get_tree().create_timer(0.25).timeout
	await _show_panel(panel)
	await get_tree().create_timer(0.2).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _process(delta: float) -> void:
	# Dynamic focal camera interpolation with subtle atmospheric breathing drift
	_t += delta
	var subtle_drift := Vector3(
		sin(_t * 0.18) * 0.12,
		sin(_t * 0.22) * 0.06,
		cos(_t * 0.15) * 0.08
	)
	var desired_pos := _cam_target_pos + subtle_drift
	camera.global_position = camera.global_position.lerp(desired_pos, 1.0 - exp(-delta * 4.5))
	_current_look = _current_look.lerp(_cam_target_look, 1.0 - exp(-delta * 4.5))
	camera.fov = lerpf(camera.fov, _cam_target_fov, 1.0 - exp(-delta * 4.0))
	camera.look_at(_current_look, Vector3.UP)
	if _ranger_aim and _ranger_hero:
		var facing := -_ranger_hero.global_transform.basis.z
		var right := _ranger_hero.global_transform.basis.x
		_ranger_aim.aim_direction = (facing * 0.82 + right * 0.42 + Vector3.UP * 0.06).normalized()
	if _deck_holo:
		_deck_holo.rotation.y = 0.4 + _t * 0.35
		_deck_holo.position.y = _holo_base.y + sin(_t * 0.9) * 0.04
	if _deck_gunship:
		_deck_gunship.position = _gunship_base + Vector3(sin(_t * 0.12) * 0.18, sin(_t * 0.16) * 0.08, 0.0)
		_deck_gunship.rotation.y = -PI * 0.62 + sin(_t * 0.08) * 0.03

# ------------------------------------------------------------------- UI ----

var _main_box: VBoxContainer = null
var _controls_panel: PanelContainer = null
var _settings_panel: PanelContainer = null
var _menu_scrim: ColorRect = null

func _game_button_style(fill: Color, border: Color, left_width: int, featured := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = left_width
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0.15, 0.8, 1.0, 0.25) if featured else Color(0, 0, 0, 0.4)
	style.shadow_size = 6 if featured else 2
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style

func _make_game_button(label_text: String, icon_type: String, featured := false) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(360, 56)
	btn.focus_mode = Control.FOCUS_ALL
	
	var normal_fill := Color(0.04, 0.16, 0.22, 0.72) if featured else Color(0.012, 0.03, 0.055, 0.78)
	var normal_border := Color(0.25, 0.88, 1.0, 0.95) if featured else Color(0.22, 0.42, 0.55, 0.55)
	var hover_fill := Color(0.06, 0.22, 0.30, 0.92)
	var hover_border := Color(0.45, 0.95, 1.0, 1.0)
	
	btn.add_theme_stylebox_override("normal", _game_button_style(normal_fill, normal_border, 4 if featured else 1, featured))
	btn.add_theme_stylebox_override("hover", _game_button_style(hover_fill, hover_border, 6, true))
	btn.add_theme_stylebox_override("pressed", _game_button_style(Color(0.08, 0.28, 0.36, 0.95), Color(0.7, 1.0, 1.0, 1.0), 6, true))
	btn.add_theme_stylebox_override("focus", _game_button_style(hover_fill, hover_border, 6, true))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16.0
	row.offset_right = -16.0
	row.add_theme_constant_override("separation", 16)
	btn.add_child(row)

	var icon := Control.new()
	icon.set_script(MENU_ICON)
	icon.set("icon_type", icon_type)
	icon.set("accent", featured)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var text_lbl := _make_title(label_text, 17, Color(0.78, 0.97, 1.0) if featured else Color(0.82, 0.90, 0.96))
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_lbl)

	var base_x := 0.0
	btn.mouse_entered.connect(func():
		SoundManager.play("ui_hover", 1.0, -8.0)
		var tw := btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "position:x", base_x - 10.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(text_lbl, "modulate", Color(0.35, 0.95, 1.0), 0.12)
	)
	btn.mouse_exited.connect(func():
		var tw := btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "position:x", base_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(text_lbl, "modulate", Color.WHITE, 0.12)
	)
	btn.pressed.connect(func():
		SoundManager.play("ui_click", 1.0, -4.0)
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.06)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)
	return btn

func _make_button(text: String, min_size := Vector2(280, 46)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	MENU_STYLE.button(btn)
	btn.mouse_entered.connect(func(): SoundManager.play("ui_hover", 1.0, -8.0))
	btn.pressed.connect(func(): SoundManager.play("ui_click", 1.0, -4.0))
	return btn

func _make_title(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	if size <= 12:
		lbl.add_theme_font_override("font", MENU_STYLE.MONO)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 2)
	return lbl

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MenuCanvas"
	add_child(canvas)

	var root := Control.new()
	_menu_root = root
	root.name = "MenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI_THEME
	canvas.add_child(root)

	# Tight cinematic lockup — type only, no empty title slab.
	var title_lock := PanelContainer.new()
	_title_plate = title_lock
	_title_box = title_lock
	title_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lock.clip_contents = false
	title_lock.offset_left = 52.0
	title_lock.offset_top = 58.0
	title_lock.grow_horizontal = Control.GROW_DIRECTION_END
	title_lock.grow_vertical = Control.GROW_DIRECTION_END
	var lock_style := StyleBoxEmpty.new()
	lock_style.content_margin_left = 0
	lock_style.content_margin_right = 0
	lock_style.content_margin_top = 0
	lock_style.content_margin_bottom = 0
	title_lock.add_theme_stylebox_override("panel", lock_style)
	root.add_child(title_lock)

	var lock_row := HBoxContainer.new()
	lock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_row.add_theme_constant_override("separation", 16)
	title_lock.add_child(lock_row)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(3, 0)
	accent.color = Color(0.24, 0.86, 1.0, 0.95)
	accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lock_row.add_child(accent)

	var title_col := VBoxContainer.new()
	title_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_col.add_theme_constant_override("separation", 6)
	lock_row.add_child(title_col)

	var eyebrow := _make_title("COMMAND DECK  //  SR-07", 11, Color(0.28, 0.84, 1.0, 0.92))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	eyebrow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_col.add_child(eyebrow)

	var title_lbl := _make_title("SPACE RANGER", 44, Color(0.96, 0.99, 1.0))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_lbl.clip_text = false
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title_lbl.add_theme_font_override("font", DISPLAY_FONT)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.06, 0.9))
	title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_constant_override("shadow_outline_size", 8)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.88))
	title_lbl.add_theme_constant_override("outline_size", 6)
	title_col.add_child(title_lbl)

	var subtitle_row := HBoxContainer.new()
	subtitle_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	subtitle_row.add_theme_constant_override("separation", 10)
	var sub_bar_l := ColorRect.new()
	sub_bar_l.custom_minimum_size = Vector2(22, 1)
	sub_bar_l.color = Color(0.24, 0.86, 1.0, 0.85)
	sub_bar_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	subtitle_row.add_child(sub_bar_l)
	var subtitle := _make_title("ECLIPSE PROTOCOL", 12, Color(0.38, 0.88, 1.0, 0.95))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	subtitle_row.add_child(subtitle)
	var sub_bar_r := ColorRect.new()
	sub_bar_r.custom_minimum_size = Vector2(22, 1)
	sub_bar_r.color = Color(0.24, 0.86, 1.0, 0.45)
	sub_bar_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	subtitle_row.add_child(sub_bar_r)
	title_col.add_child(subtitle_row)

	var best := _make_title("BEST RECORD   %06d" % GameManager.high_score, 11, Color(0.78, 0.88, 0.94, 0.8))
	best.name = "BestScore"
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	best.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_col.add_child(best)

	# --- Action Game Buttons (right-side holographic stack) --------------
	_main_box = VBoxContainer.new()
	_main_box.anchor_left = 1.0
	_main_box.anchor_right = 1.0
	_main_box.anchor_top = 0.5
	_main_box.anchor_bottom = 0.5
	_main_box.offset_left = -428.0
	_main_box.offset_right = -72.0
	_main_box.offset_top = -118.0
	_main_box.offset_bottom = 162.0
	_main_box.custom_minimum_size = Vector2(356, 260)
	_main_box.z_index = 4
	_main_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_box.add_theme_constant_override("separation", 14)
	root.add_child(_main_box)

	var launch := _make_game_button("DEPLOY MISSION", "deploy", true)
	launch.pressed.connect(_on_launch)
	_main_box.add_child(launch)

	var controls := _make_game_button("CONTROLS", "controls")
	controls.pressed.connect(func(): _show_panel(_controls_panel))
	_main_box.add_child(controls)

	var settings := _make_game_button("SETTINGS", "settings")
	settings.pressed.connect(func(): _show_panel(_settings_panel))
	_main_box.add_child(settings)

	var quit := _make_game_button("QUIT GAME", "quit")
	quit.pressed.connect(_on_quit)
	_main_box.add_child(quit)

	var version := _make_title("OPERATIVE: RANGER-H1 // READY", 10, Color(0.55, 0.7, 0.82, 0.78))
	version.offset_left = 64.0
	version.offset_right = 350.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_top = -54.0
	version.offset_bottom = -34.0
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(version)

	launch.grab_focus()
	_focus_target = launch

	_menu_scrim = ColorRect.new()
	_menu_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_scrim.color = Color(0.002, 0.005, 0.008, 0.68)
	_menu_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_scrim.visible = false
	root.add_child(_menu_scrim)

	_controls_panel = _build_controls_panel(root)
	_settings_panel = _build_settings_panel(root)

	# Clean cinematic fade & slide intro
	root.modulate.a = 0.0
	title_lock.modulate.a = 0.0
	title_lock.position.x -= 20.0
	var intro := root.create_tween().set_parallel(true)
	intro.tween_property(root, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	intro.tween_property(title_lock, "modulate:a", 1.0, 0.35).set_delay(0.1)
	intro.tween_property(title_lock, "position:x", title_lock.position.x + 20.0, 0.4).set_delay(0.1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	intro.tween_property(_main_box, "modulate:a", 1.0, 0.35).set_delay(0.05)

func _make_modal_panel(root: Control, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.z_index = 2
	panel.visible = false
	panel.clip_contents = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(width, 0)
	root.add_child(panel)
	MENU_STYLE.decorate(panel, Vector2(42, 36))
	return panel

func _modal_header(box: VBoxContainer, eyebrow: String, title: String) -> void:
	box.add_child(MENU_STYLE.eyebrow(eyebrow))
	var heading := _make_title(title, 26, Color(0.92, 0.97, 1.0))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(heading)
	box.add_child(MENU_STYLE.separator())

func _modal_back(box: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	var back := _make_button("BACK", Vector2(0, 44))
	back.pressed.connect(func(): _show_panel(null))
	box.add_child(back)

func _build_controls_panel(root: Control) -> PanelContainer:
	var panel := _make_modal_panel(root, 720)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_modal_header(box, "VANGUARD OS // FIELD MANUAL", "CONTROLS")

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	columns.add_child(right)

	var left_rows := [
		["A / D  ·  ← / →", "Run"],
		["SPACE  ·  W  ·  ↑", "Jump / double jump"],
		["SHIFT  ·  RMB", "Evasive dash"],
		["MOUSE", "360° aim"],
		["LMB  ·  J", "Fire"],
	]
	var right_rows := [
		["1 – 4  ·  WHEEL", "Weapons"],
		["E  ·  Q", "EMP grenade"],
		["F", "Terminal / relay"],
		["ESC  ·  P", "Pause"],
	]
	for row in left_rows:
		left.add_child(_control_row(row[0], row[1]))
	for row in right_rows:
		right.add_child(_control_row(row[0], row[1]))

	_modal_back(box)
	return panel

func _control_row(keys_text: String, action_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size.y = 28
	var keys := _make_title(keys_text, 12, MENU_STYLE.CYAN)
	keys.add_theme_font_override("font", MENU_STYLE.MONO)
	keys.custom_minimum_size = Vector2(168, 0)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var action := _make_title(action_text, 14, Color(0.72, 0.82, 0.92))
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(keys)
	row.add_child(action)
	return row

func _build_settings_panel(root: Control) -> PanelContainer:
	var panel := _make_modal_panel(root, 720)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_modal_header(box, "VANGUARD OS // SYSTEMS CONFIG", "SUIT SETTINGS")

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(columns)

	var audio := VBoxContainer.new()
	audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio.add_theme_constant_override("separation", 12)
	audio.add_child(MENU_STYLE.eyebrow("AUDIO / FEEL"))
	_add_slider(audio, "MASTER", "master", GameManager.settings_master_volume)
	_add_slider(audio, "MUSIC", "music", GameManager.settings_music_volume)
	_add_slider(audio, "SFX", "sfx", GameManager.settings_sfx_volume)
	_add_slider(audio, "SHAKE", "shake", GameManager.settings_shake_scale)
	columns.add_child(audio)

	var display := VBoxContainer.new()
	display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display.add_theme_constant_override("separation", 10)
	display.add_child(MENU_STYLE.eyebrow("DISPLAY"))
	_add_toggle(display, "MODE", "FULLSCREEN" if GameManager.settings_fullscreen else "WINDOWED", GameManager.settings_fullscreen, func(on: bool, value_lbl: Label):
		value_lbl.text = "FULLSCREEN" if on else "WINDOWED"
		GameManager.update_setting("fullscreen", 1.0 if on else 0.0)
	)
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		var env := world_env.environment
		_add_toggle(display, "SSAO", "ON" if env.ssao_enabled else "OFF", env.ssao_enabled, func(on: bool, value_lbl: Label):
			env.ssao_enabled = on
			value_lbl.text = "ON" if on else "OFF"
		)
		_add_toggle(display, "ATMOSPHERE", "ON" if env.volumetric_fog_enabled else "OFF", env.volumetric_fog_enabled, func(on: bool, value_lbl: Label):
			env.volumetric_fog_enabled = on
			value_lbl.text = "ON" if on else "OFF"
		)
	columns.add_child(display)

	_modal_back(box)
	return panel

func _add_toggle(parent: Control, label_text: String, value_text: String, pressed: bool, on_toggle: Callable) -> void:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = pressed
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MENU_STYLE.button(btn)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 12)
	btn.add_child(row)
	var name_lbl := _make_title(label_text, 13, Color(0.78, 0.88, 0.96))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var value_lbl := _make_title(value_text, 12, MENU_STYLE.CYAN)
	value_lbl.add_theme_font_override("font", MENU_STYLE.MONO)
	value_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_lbl)
	row.add_child(value_lbl)
	btn.toggled.connect(func(on: bool): on_toggle.call(on, value_lbl))
	parent.add_child(btn)

func _add_slider(parent: Control, label_text: String, key: String, value: float) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.custom_minimum_size.y = 32
	var lbl := _make_title(label_text, 13, Color(0.72, 0.82, 0.92))
	lbl.custom_minimum_size = Vector2(86, 0)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hbox.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.5 if key == "shake" else 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(120, 22)
	MENU_STYLE.slider(slider)
	var readout := MENU_STYLE.eyebrow("%03d%%" % roundi(value * 100))
	readout.custom_minimum_size.x = 46
	readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float):
		readout.text = "%03d%%" % roundi(v * 100)
		GameManager.update_setting(key, v)
		if key != "shake":
			SoundManager.apply_volumes(GameManager.settings_master_volume, GameManager.settings_music_volume, GameManager.settings_sfx_volume))
	hbox.add_child(slider)
	hbox.add_child(readout)
	parent.add_child(hbox)


func _show_panel(panel: PanelContainer) -> void:
	if _transitioning:
		return
	_transitioning = true
	var outgoing: Control = _main_box
	if _controls_panel.visible: outgoing = _controls_panel
	elif _settings_panel.visible: outgoing = _settings_panel
	var incoming: Control = _main_box if panel == null else panel
	if outgoing == incoming:
		_transitioning = false
		return

	# Dynamically shift 3D camera focal target to frame specific environment props
	if panel == null:
		_cam_target_pos = CAM_HOME_POS
		_cam_target_look = CAM_HOME_LOOK
		_cam_target_fov = CAM_HOME_FOV
	elif panel == _controls_panel:
		_cam_target_pos = Vector3(1.15, 1.48, 4.6)
		_cam_target_look = Vector3(0.35, 1.05, -0.35)
		_cam_target_fov = 32.0
	elif panel == _settings_panel:
		_cam_target_pos = Vector3(2.35, 1.7, 5.1)
		_cam_target_look = Vector3(0.7, 1.1, -0.2)
		_cam_target_fov = 34.0

	var out_tw := outgoing.create_tween().set_parallel(true)
	out_tw.tween_property(outgoing, "modulate:a", 0.0, 0.16)
	out_tw.tween_property(outgoing, "scale", Vector2(0.97, 0.97), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await out_tw.finished
	outgoing.visible = false
	outgoing.scale = Vector2.ONE
	if panel != null:
		_menu_scrim.visible = true
		_menu_scrim.modulate.a = 0.0
		create_tween().tween_property(_menu_scrim, "modulate:a", 1.0, 0.2)
	incoming.visible = true
	if panel == null:
		_main_box.get_child(0).grab_focus()
	else:
		var buttons := panel.find_children("*", "Button", true, false)
		if not buttons.is_empty():
			buttons[buttons.size() - 1].grab_focus()
	incoming.modulate.a = 0.0
	incoming.scale = Vector2(1.035, 1.035)
	incoming.pivot_offset = incoming.size * 0.5
	var in_tw := incoming.create_tween().set_parallel(true)
	in_tw.tween_property(incoming, "modulate:a", 1.0, 0.26)
	in_tw.tween_property(incoming, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await in_tw.finished
	if panel == null:
		_menu_scrim.visible = false
	_transitioning = false

func _on_launch() -> void:
	if _transitioning: return
	_transitioning = true
	_main_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SoundManager.play("ui_click", 0.82, -2.0)

	# Cinematic launch overlay: visor shutters, uplink scan and a camera push
	# toward the armed Ranger before the mission loads.
	var launch_layer := CanvasLayer.new()
	launch_layer.layer = 30
	add_child(launch_layer)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	launch_layer.add_child(overlay)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.01, 0.025, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var top_bar := ColorRect.new()
	top_bar.anchor_right = 1.0
	top_bar.color = Color(0.003, 0.008, 0.015, 0.96)
	overlay.add_child(top_bar)
	var bottom_bar := ColorRect.new()
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.color = top_bar.color
	overlay.add_child(bottom_bar)

	var scan := ColorRect.new()
	scan.anchor_top = 0.5
	scan.anchor_right = 1.0
	scan.anchor_bottom = 0.5
	scan.offset_right = -get_viewport().get_visible_rect().size.x
	scan.offset_top = -1.0
	scan.offset_bottom = 2.0
	scan.color = Color(0.25, 0.92, 1.0, 0.95)
	overlay.add_child(scan)

	var launch_label := Label.new()
	launch_label.set_anchors_preset(Control.PRESET_CENTER)
	launch_label.offset_left = -280.0
	launch_label.offset_right = 280.0
	launch_label.offset_top = -30.0
	launch_label.offset_bottom = 30.0
	launch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	launch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	launch_label.text = "MISSION 01  //  APEX PROTOCOL\nCOMBAT UPLINK  ·  ACQUIRING"
	launch_label.add_theme_font_override("font", MENU_STYLE.MONO)
	launch_label.add_theme_font_size_override("font_size", 14)
	launch_label.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	launch_label.modulate.a = 0.0
	overlay.add_child(launch_label)

	_cam_target_pos = Vector3(0.75, 1.48, 3.7)
	_cam_target_look = Vector3(0.55, 1.22, -0.35)
	_cam_target_fov = 31.0
	var lock_tw := create_tween().set_parallel(true)
	lock_tw.tween_property(_title_box, "position:x", _title_box.position.x - 90.0, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	lock_tw.tween_property(_title_box, "modulate:a", 0.0, 0.26)
	lock_tw.tween_property(_title_plate, "modulate:a", 0.0, 0.22)
	lock_tw.tween_property(_main_box, "position:x", _main_box.position.x + 90.0, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	lock_tw.tween_property(_main_box, "modulate:a", 0.0, 0.26)
	lock_tw.tween_property(top_bar, "offset_bottom", 48.0, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	lock_tw.tween_property(bottom_bar, "offset_top", -48.0, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	lock_tw.tween_property(scan, "offset_right", 0.0, 0.36).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	lock_tw.tween_property(launch_label, "modulate:a", 1.0, 0.22).set_delay(0.12)
	await lock_tw.finished

	SoundManager.play("dash", 1.25, -3.0)
	launch_label.text = "RANGER-H1  //  CLEARED\nINSERTION VECTOR LOCKED"
	_cam_target_pos = Vector3(0.55, 1.28, 2.55)
	_cam_target_look = Vector3(0.55, 1.20, -5.5)
	_cam_target_fov = 54.0
	var jump_tw := create_tween().set_parallel(true)
	jump_tw.tween_property(scan, "color:a", 0.0, 0.18)
	jump_tw.tween_property(launch_label, "modulate:a", 0.0, 0.38).set_delay(0.2)
	jump_tw.tween_property(shade, "color", Color(0.02, 0.35, 0.48, 0.22), 0.12)
	jump_tw.chain().tween_property(shade, "color", Color(0.0, 0.005, 0.012, 1.0), 0.48).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await jump_tw.finished
	get_tree().change_scene_to_file("res://src/levels/level_01.tscn")

func _on_quit() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _controls_panel.visible or _settings_panel.visible:
			_show_panel(null)
