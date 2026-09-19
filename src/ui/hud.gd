extends Control

## Tactical HUD: vitals, score, weapon slots, heat, EMP, boss bar, plus a
## mouse-following crosshair, pooled hit markers and a damage vignette.

@onready var health_bar: SegmentedTelemetryBar = $TopLeft/VBox/HealthContainer/HealthBar
@onready var shield_bar: SegmentedTelemetryBar = $TopLeft/VBox/ShieldContainer/ShieldBar
@onready var health_label: Label = $TopLeft/VBox/HealthContainer/HealthLabel
@onready var shield_label: Label = $TopLeft/VBox/ShieldContainer/ShieldLabel
@onready var score_label: Label = $TopRight/ScoreContainer/ScoreLabel
@onready var combo_label: Label = $TopRight/ScoreContainer/ComboLabel
@onready var hostiles_label: Label = $TopRight/ScoreContainer/HostilesLabel
@onready var shield_alert: Label = $TopLeft/VBox/ShieldAlert
@onready var objective_label: Label = $ObjectiveStrip/ObjectiveLabel

@onready var weapon_label: Label = $BottomLeft/WeaponContainer/WeaponLabel
@onready var weapon_icon: Label = $BottomLeft/WeaponContainer/WeaponIcon
@onready var heat_bar: SegmentedTelemetryBar = $BottomLeft/WeaponContainer/HeatBar
@onready var emp_label: Label = $BottomLeft/WeaponContainer/EMPLabel

@onready var boss_container: VBoxContainer = $TopCenter/BossContainer
@onready var boss_bar: ProgressBar = $TopCenter/BossContainer/BossBar
@onready var boss_name_label: Label = $TopCenter/BossContainer/BossNameLabel

@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var end_scrim: ColorRect = $EndScrim

@export_file("*.tscn") var next_level_path: String = ""
@export var next_mission_name := "NIGHTGLASS REACTOR"
@export var final_mission := false
@export var mission_name: String = "APEX PROTOCOL"
@export var boss_display_name: String = "TARGET: APEX COMBAT DREADNOUGHT"
@export var victory_detail: String = "APEX DREADNOUGHT NEUTRALIZED  ·  ROUTE OPEN"
@export var objective_text: String = "PUSH EAST  //  NEUTRALIZE THE APEX CORE"

var target_health: float = 100.0
var target_shield: float = 80.0
var target_boss_health: float = 1000.0
var player_ref: Node3D = null

# --- Runtime-built HUD extras ---
var crosshair: Control = null
var vignette: ColorRect = null
var vignette_mat: ShaderMaterial = null
var _hit_markers: Array[Label] = []
var _marker_free: Array[bool] = []
var slot_panels: Array[PanelContainer] = []
var slot_labels: Array[Label] = []
var weapon_silhouette: WeaponSilhouette = null
var ability_indicator: AbilityIndicator = null
var _displayed_score := 0.0
var _target_score := 0
var _score_tick: ColorRect = null
var _hull_flash := 0.0
var _hostile_poll := 0.0

const SLOT_NAMES: Array[String] = ["PX-9", "TITAN-8", "LR-77", "HV-4"]

func _ready() -> void:
	boss_container.visible = false
	victory_panel.visible = false
	game_over_panel.visible = false
	end_scrim.visible = false
	boss_name_label.text = boss_display_name
	objective_label.text = "OBJECTIVE  //  %s" % objective_text
	$VictoryPanel/VBox/Subtitle.text = victory_detail
	$VictoryPanel/VBox/Eyebrow.text = "VANGUARD OS  //  %s SECURED" % mission_name
	$GameOverPanel/VBox/Eyebrow.text = "VANGUARD OS  //  %s TERMINATED" % mission_name

	GameManager.connect("health_changed", _on_health_changed)
	GameManager.connect("shield_changed", _on_shield_changed)
	GameManager.connect("score_changed", _on_score_changed)
	GameManager.connect("weapon_changed", _on_weapon_changed)
	GameManager.connect("boss_health_changed", _on_boss_health_changed)
	GameManager.connect("boss_defeated", _on_boss_defeated)
	GameManager.connect("player_died", _on_player_died)
	GameManager.connect("level_completed", _on_level_completed)
	GameManager.connect("hull_damaged", _on_hull_damaged)
	GameManager.connect("notify_requested", _on_notify_requested)
	FXManager.connect("enemy_hitmarked", _on_enemy_hitmarked)

	_build_vignette()
	_build_cinematic_overlay()
	_build_crosshair()
	_build_weapon_slots()
	_build_weapon_readouts()
	_build_hit_markers()
	_build_toasts()
	_build_menu_buttons()
	_build_end_reports()
	health_bar.solid_fill = true

	_on_health_changed(GameManager.health, GameManager.max_health)
	_on_shield_changed(GameManager.shield, GameManager.max_shield)
	_on_score_changed(GameManager.score, GameManager.combo)
	_on_weapon_changed(GameManager.current_weapon, GameManager.WEAPON_NAMES[GameManager.current_weapon])

# ------------------------------------------------------------------ extras

func _build_cinematic_overlay() -> void:
	# A faint lens treatment and vector suit chrome unify the 3D view and UI.
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float edge = smoothstep(0.48, 0.82, distance(UV, vec2(0.5)));
	float scan = sin(UV.y * 900.0) * 0.5 + 0.5;
	vec3 tint = vec3(0.01, 0.035, 0.055) * edge;
	float alpha = edge * 0.22 + scan * 0.012;
	COLOR = vec4(tint, alpha);
}
"""
	var lens := ColorRect.new()
	lens.name = "CinematicLens"
	lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = shader
	lens.material = material
	add_child(lens)
	move_child(lens, 0)

	var chrome := Control.new()
	chrome.name = "SuitVisorChrome"
	chrome.set_script(preload("res://src/ui/hud_chrome.gd"))
	add_child(chrome)
	move_child(chrome, 1)

func _build_vignette() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float edge = smoothstep(0.35, 0.75, d);
	COLOR = vec4(0.75, 0.05, 0.05, edge * intensity);
}
"""
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = shader
	vignette = ColorRect.new()
	vignette.name = "DamageVignette"
	vignette.material = vignette_mat
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 1.0
	add_child(vignette)
	move_child(vignette, 0) # keep vignette under panels but over 3D

func _build_crosshair() -> void:
	crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_script(preload("res://src/ui/crosshair.gd"))
	add_child(crosshair)

func _build_weapon_slots() -> void:
	var rack := Control.new()
	rack.name = "WeaponRack"
	rack.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	rack.anchor_top = 1.0
	rack.anchor_bottom = 1.0
	rack.offset_top = -78.0
	rack.offset_bottom = -25.0
	rack.offset_left = -270.0
	rack.offset_right = 270.0
	rack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rack)
	var bar := HBoxContainer.new()
	bar.name = "Slots"
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 5)
	rack.add_child(bar)

	_add_rack_rule(bar, false)

	for i in range(GameManager.WEAPON_NAMES.size()):
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(84, 44)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.026, 0.034, 0.043, 0.96)
		style.border_width_bottom = 2
		style.border_color = Color(0.22, 0.27, 0.32, 0.8)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		panel.add_theme_stylebox_override("panel", style)
		var lbl := Label.new()
		lbl.text = "%02d\n%s" % [i + 1, SLOT_NAMES[i]]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.46, 0.5, 0.55, 0.65))
		panel.add_child(lbl)
		bar.add_child(panel)
		slot_panels.append(panel)
		slot_labels.append(lbl)
	_add_rack_rule(bar, true)

func _add_rack_rule(parent: HBoxContainer, trailing: bool) -> void:
	var marks := HBoxContainer.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.custom_minimum_size = Vector2(82, 44)
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	marks.add_theme_constant_override("separation", 7)
	if trailing:
		var dots_r := Label.new()
		dots_r.text = "⋮"
		dots_r.add_theme_font_size_override("font_size", 16)
		dots_r.add_theme_color_override("font_color", Color(0.3, 0.78, 0.92, 0.85))
		marks.add_child(dots_r)
	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(66, 1)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.color = Color(0.42, 0.72, 0.82, 0.68)
	marks.add_child(rule)
	if not trailing:
		var dots_l := Label.new()
		dots_l.text = "⋮"
		dots_l.add_theme_font_size_override("font_size", 16)
		dots_l.add_theme_color_override("font_color", Color(0.3, 0.78, 0.92, 0.85))
		marks.add_child(dots_l)
	parent.add_child(marks)

func _build_weapon_readouts() -> void:
	weapon_silhouette = WeaponSilhouette.new()
	weapon_silhouette.name = "WeaponSilhouette"
	$BottomLeft/WeaponContainer.add_child(weapon_silhouette)
	$BottomLeft/WeaponContainer.move_child(weapon_silhouette, 1)
	weapon_silhouette.position = Vector2(14, 14)
	weapon_silhouette.size = Vector2(158, 62)
	emp_label.visible = false
	ability_indicator = AbilityIndicator.new()
	ability_indicator.name = "EMPIndicator"
	$BottomLeft/WeaponContainer.add_child(ability_indicator)
	ability_indicator.position = Vector2(16, 104)
	ability_indicator.size = Vector2(426, 36)

	_score_tick = ColorRect.new()
	_score_tick.color = Color(0.1, 0.9, 1.0, 0.0)
	_score_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_tick.custom_minimum_size = Vector2(2, 3)
	$TopRight/ScoreContainer.add_child(_score_tick)

func _build_hit_markers() -> void:
	for i in range(6):
		var lbl := Label.new()
		lbl.text = "✕"
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		_hit_markers.append(lbl)
		_marker_free.append(true)

func _on_enemy_hitmarked(world_pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var screen := cam.unproject_position(world_pos)
	for i in range(_hit_markers.size()):
		if _marker_free[i]:
			var lbl := _hit_markers[i]
			_marker_free[i] = false
			lbl.visible = true
			lbl.position = screen + Vector2(-8, -22)
			lbl.modulate.a = 1.0
			lbl.scale = Vector2(1.4, 1.4)
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(lbl, "position:y", lbl.position.y - 26.0, 0.35)
			tw.tween_property(lbl, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
			tw.tween_property(lbl, "scale", Vector2.ONE, 0.2)
			tw.chain().tween_callback(func():
				lbl.visible = false
				_marker_free[i] = true)
			return

func _on_hull_damaged(_amount: float) -> void:
	if vignette == null:
		return
	_hull_flash = 1.0

# ------------------------------------------------------------------ toasts

var _toast_box: VBoxContainer = null

func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.name = "ToastStack"
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_left = -205.0
	_toast_box.offset_right = 205.0
	_toast_box.offset_top = 128.0
	_toast_box.offset_bottom = 340.0
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.add_theme_constant_override("separation", 8)
	add_child(_toast_box)

func _on_notify_requested(text: String, color: Color) -> void:
	if _toast_box == null:
		return
	# Objectives live in the persistent top command rail. Routing objective
	# notifications there prevents a second temporary bar from covering it.
	if text.begins_with("OBJECTIVE:"):
		objective_label.text = "OBJECTIVE  //  %s" % text.trim_prefix("OBJECTIVE:").strip_edges()
		var objective_tw := objective_label.create_tween()
		objective_label.modulate = Color(0.4, 0.9, 1.0)
		objective_tw.tween_property(objective_label, "modulate", Color.WHITE, 0.5)
		return
	SoundManager.play("notify", 1.0 + randf_range(-0.05, 0.05), -6.0)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _message_padding(16, 12))
	var chrome := _add_message_chrome(panel, color)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	var heading := "SUIT TELEMETRY"
	var detail := text
	var hint := ""
	var weapon_index := -1
	if text.begins_with("WEAPON ACQUIRED ["):
		var end := text.find("]")
		var key := text.substr(17, end - 17)
		weapon_index = int(key) - 1
		heading = "ARSENAL // WEAPON ACQUIRED"
		detail = text.substr(end + 1).strip_edges()
		hint = "[%s] EQUIP" % key
	elif text.begins_with("AMMO RECLAIMED"):
		heading = "ARSENAL // AMMO RECLAIMED"
		detail = text.get_slice("—", 1).strip_edges()
	elif text.begins_with("HULL PATCHED"):
		heading = "REPAIR // HULL RESTORED"
		detail = "+15 HULL INTEGRITY"
	elif text.begins_with("SHIELD RECHARGE"):
		heading = "DEFENSE // SHIELD RECHARGED"
		detail = "+40 SHIELD CAPACITY"
	if weapon_index >= 0 and weapon_index < SLOT_NAMES.size():
		var icon := WeaponSilhouette.new()
		icon.weapon_index = weapon_index
		icon.accent = color
		icon.set_deferred("custom_minimum_size", Vector2(96, 40))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	row.add_child(copy)
	copy.add_child(_message_label(heading, 10, color))
	var body := _message_label(detail, 15, Color(0.9, 0.95, 1.0))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(body)
	if not hint.is_empty():
		copy.add_child(_message_label(hint, 10, Color(0.55, 0.68, 0.76)))
	_toast_box.add_child(panel)
	panel.modulate.a = 0.0
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).free()
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)
	tw.tween_property(chrome, "remaining", 0.0, 3.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)

func _message_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size <= 12:
		label.add_theme_font_override("font", preload("res://assets/fonts/ShareTechMono-Regular.ttf"))
	return label

func _message_padding(horizontal: float, vertical: float) -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

func _add_message_chrome(panel: PanelContainer, accent: Color, report := false) -> Control:
	var chrome := Control.new()
	chrome.set_script(preload("res://src/ui/message_chrome.gd"))
	chrome.set("accent", accent)
	chrome.set("report", report)
	# A top-level layout child would compete with the report's content.
	var backing := Control.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(backing)
	backing.add_child(chrome)
	var padding := panel.get_theme_stylebox("panel")
	chrome.offset_left = -padding.get_content_margin(SIDE_LEFT)
	chrome.offset_top = -padding.get_content_margin(SIDE_TOP)
	chrome.offset_right = padding.get_content_margin(SIDE_RIGHT)
	chrome.offset_bottom = padding.get_content_margin(SIDE_BOTTOM)
	return chrome

func _build_end_reports() -> void:
	for panel in [game_over_panel, victory_panel]:
		var failed: bool = panel == game_over_panel
		var accent := Color(1.0, 0.29, 0.19) if failed else Color(0.15, 0.9, 0.7)
		panel.add_theme_stylebox_override("panel", _message_padding(30, 24))
		_add_message_chrome(panel, accent, true)
		panel.move_child(panel.get_child(panel.get_child_count() - 1), 0)
		var vbox := panel.get_node("VBox") as VBoxContainer
		var status := _message_label("●  SR-07 / SIGNAL LOST" if failed else "●  SR-07 / UPLINK CONFIRMED", 12, accent)
		vbox.add_child(status)
		vbox.move_child(status, 0)
		var eyebrow := vbox.get_node("Eyebrow") as Label
		eyebrow.text = "MISSION // %s" % mission_name
		eyebrow.add_theme_font_size_override("font_size", 11)
		eyebrow.add_theme_color_override("font_color", Color(0.5, 0.66, 0.75))
		var title := vbox.get_node("Title") as Label
		title.text = "RANGER DOWN" if failed else "SECTOR SECURED"
		title.add_theme_font_size_override("font_size", 34)
		var subtitle := vbox.get_node("Subtitle") as Label
		subtitle.text = "CRITICAL SUIT BREACH // LIFE SUPPORT OFFLINE" if failed else victory_detail
		subtitle.add_theme_font_size_override("font_size", 12)
		var rule := HSeparator.new()
		rule.modulate = Color(accent, 0.35)
		vbox.add_child(rule)
		vbox.move_child(rule, subtitle.get_index() + 1)
		var telemetry := _message_label("HULL  000   /   SHIELD  OFFLINE   /   LINK  SEVERED" if failed else "OBJECTIVE  COMPLETE   /   ROUTE  OPEN", 11, accent)
		telemetry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(telemetry)
		vbox.move_child(telemetry, rule.get_index() + 1)

## "REDEPLOY / RETURN TO MENU" row for the game-over and victory panels.
func _build_menu_buttons() -> void:
	for panel in [game_over_panel, victory_panel]:
		var vbox := panel.get_node("VBox") as VBoxContainer
		var menu_btn := Button.new()
		menu_btn.text = "EXIT TO COMMAND"
		menu_btn.custom_minimum_size = Vector2(190, 42)
		menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_style_end_button(menu_btn, false)
		menu_btn.pressed.connect(_on_menu_pressed)
		var actions := vbox.get_node("Actions") as HBoxContainer
		actions.add_child(menu_btn)

	var retry := $GameOverPanel/VBox/Actions/RestartBtn as Button
	_style_end_button(retry, true, Color(1.0, 0.24, 0.16))
	var advance := $VictoryPanel/VBox/Actions/RestartVictoryBtn as Button
	_style_end_button(advance, true, Color(0.15, 0.9, 0.7))
	advance.text = "NEXT // %s" % next_mission_name if not next_level_path.is_empty() else "RUN MISSION AGAIN"

func _style_end_button(button: Button, primary: bool, accent := Color(0.0, 0.82, 1.0)) -> void:
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE if primary else Color(0.68, 0.76, 0.86))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _end_button_box(
		Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.94) if primary else Color(0.025, 0.045, 0.07, 0.92),
		accent if primary else Color(0.2, 0.36, 0.48, 0.9), 2 if primary else 1))
	button.add_theme_stylebox_override("hover", _end_button_box(Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 1.0), accent, 2))
	button.add_theme_stylebox_override("pressed", _end_button_box(Color(accent.r * 0.1, accent.g * 0.1, accent.b * 0.1, 1.0), Color.WHITE, 2))
	button.add_theme_stylebox_override("focus", _end_button_box(Color.TRANSPARENT, accent, 2))

func _end_button_box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = width + 2
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = border
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	return style

func _on_menu_pressed() -> void:
	get_tree().paused = false
	SoundManager.set_music_mood("menu")
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")

# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	health_bar.value = lerpf(health_bar.value, target_health, 12.0 * delta)
	shield_bar.value = lerpf(shield_bar.value, target_shield, 15.0 * delta)
	if boss_container.visible:
		boss_bar.value = lerpf(boss_bar.value, target_boss_health, 10.0 * delta)
	_displayed_score = lerpf(_displayed_score, float(_target_score), minf(1.0, 10.0 * delta))
	if absf(_displayed_score - float(_target_score)) < 0.5:
		_displayed_score = float(_target_score)
	score_label.text = "%06d" % int(round(_displayed_score))
	_hostile_poll -= delta
	if _hostile_poll <= 0.0:
		_hostile_poll = 0.25
		var active_hostiles := 0
		for hostile in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(hostile) and not hostile.is_queued_for_deletion():
				active_hostiles += 1
		hostiles_label.text = "HOSTILES   %02d" % active_hostiles

	# Low health warning pulse on the vignette
	if vignette_mat:
		var base := 0.0
		if target_health < 30.0 and target_health > 0.0:
			base = 0.35 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
		_hull_flash = maxf(_hull_flash - delta * 2.2, 0.0)
		vignette_mat.set_shader_parameter("intensity", maxf(base, _hull_flash))

	# Fetch player state for heat and secondary EMP
	if not player_ref:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	if player_ref and is_instance_valid(player_ref):
		if "heat" in player_ref and heat_bar:
			heat_bar.value = player_ref.heat
			if player_ref.is_overheated:
				heat_bar.modulate = Color(1.0, 0.2, 0.2)
			else:
				heat_bar.modulate = Color(1.0, 0.65, 0.2)

		if "secondary_cooldown" in player_ref and ability_indicator:
			ability_indicator.seconds = player_ref.secondary_cooldown
			ability_indicator.ratio = 1.0 - clampf(player_ref.secondary_cooldown / player_ref.SECONDARY_MAX_COOLDOWN, 0.0, 1.0)

# ------------------------------------------------------------------ signals

func _on_health_changed(curr: float, max_v: float) -> void:
	if curr < target_health:
		health_bar.flash_damage()
	target_health = curr
	health_bar.max_value = max_v
	health_label.text = "%d / %d" % [int(curr), int(max_v)]

func _on_shield_changed(curr: float, max_v: float) -> void:
	if curr < target_shield:
		shield_bar.flash_damage()
	target_shield = curr
	shield_bar.max_value = max_v
	shield_label.text = "%d / %d" % [int(curr), int(max_v)]
	shield_alert.visible = true
	if curr <= 0.0:
		shield_alert.text = "                 ▲  SHIELD OFFLINE"
		shield_alert.add_theme_color_override("font_color", Color(1.0, 0.68, 0.2))
	else:
		shield_alert.text = "                    SHIELD NOMINAL"
		shield_alert.add_theme_color_override("font_color", Color(0.22, 0.78, 1.0, 0.78))

func _on_score_changed(new_score: int, combo: int) -> void:
	var increased := new_score > _target_score
	_target_score = new_score
	if increased and _score_tick:
		_score_tick.color.a = 0.9
		_score_tick.scale.x = 0.05
		var score_tw := create_tween().set_parallel(true)
		score_tw.tween_property(_score_tick, "scale:x", 1.0, 0.26).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		score_tw.tween_property(_score_tick, "color:a", 0.0, 0.42)
	if combo > 1:
		combo_label.visible = true
		combo_label.text = "COMBAT MULTIPLIER x%d" % combo
		var tween := create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.15, 1.15), 0.08)
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.08)
	else:
		combo_label.visible = false

func _on_weapon_changed(index: int, w_name: String) -> void:
	weapon_label.text = w_name
	match index:
		0: weapon_icon.text = "SLOT 01 // KINETIC"
		1: weapon_icon.text = "SLOT 02 // SCATTER"
		2: weapon_icon.text = "SLOT 03 // PHOTON"
		3: weapon_icon.text = "SLOT 04 // HAVOC"

	var color: Color = GameManager.WEAPON_COLORS[index]
	if weapon_silhouette:
		weapon_silhouette.weapon_index = index
		weapon_silhouette.accent = color
	heat_bar.fill_color = color
	for i in range(slot_panels.size()):
		var panel: PanelContainer = slot_panels[i]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		var locked: bool = not GameManager.unlocked_weapons[i]
		var active: bool = (i == index)
		var lbl: Label = slot_labels[i]
		if active:
			style.bg_color = Color(color.r * 0.08 + 0.02, color.g * 0.08 + 0.02, color.b * 0.08 + 0.02, 0.98)
			style.border_color = color
			lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
			lbl.text = "%02d\n%s" % [i + 1, SLOT_NAMES[i]]
			panel.scale = Vector2.ONE
		else:
			style.bg_color = Color(0.026, 0.034, 0.043, 0.96)
			style.border_color = Color(0.22, 0.27, 0.32, 0.8)
			if locked:
				lbl.add_theme_color_override("font_color", Color(0.38, 0.41, 0.45, 0.52))
				lbl.text = "%02d\nLOCKED" % (i + 1)
			else:
				lbl.add_theme_color_override("font_color", Color(0.62, 0.67, 0.72))
				lbl.text = "%02d\n%s" % [i + 1, SLOT_NAMES[i]]
			panel.scale = Vector2.ONE

func _on_boss_health_changed(curr: float, max_v: float) -> void:
	boss_container.visible = true
	boss_bar.max_value = max_v
	target_boss_health = curr

func _on_boss_defeated() -> void:
	boss_container.visible = false

func _on_player_died() -> void:
	_show_end_panel(game_over_panel)
	$GameOverPanel/VBox/ScoreFinal.text = "FINAL SCORE  //  %06d" % GameManager.score
	_show_end_record($GameOverPanel/VBox, GameManager.score)

func _on_level_completed() -> void:
	_show_end_panel(victory_panel)
	$VictoryPanel/VBox/ScoreVictory.text = "MISSION SCORE  //  %06d" % GameManager.score
	_show_end_record($VictoryPanel/VBox, GameManager.score)

func _show_end_panel(panel: PanelContainer) -> void:
	_toast_box.hide()
	if crosshair:
		crosshair.hide()
	end_scrim.visible = true
	end_scrim.modulate.a = 0.0
	panel.visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(end_scrim, "modulate:a", 1.0, 0.28)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var primary: Button = panel.get_node("VBox/Actions").get_child(0) as Button
	if primary:
		primary.grab_focus()

## Adds a best-score line to an end panel, flagging a fresh personal record.
func _show_end_record(vbox: VBoxContainer, final_score: int) -> void:
	var old := vbox.get_node_or_null("BestRecord")
	if old:
		old.queue_free()
	var lbl := Label.new()
	lbl.name = "BestRecord"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if final_score > 0 and final_score >= GameManager.high_score:
		lbl.text = "★ NEW PERSONAL RECORD — BEST %06d" % GameManager.high_score
		lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	else:
		lbl.text = "BEST: %06d" % GameManager.high_score
		lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	lbl.add_theme_font_size_override("font_size", 13)
	# Keep it under the score line, above the buttons.
	vbox.add_child(lbl)
	vbox.move_child(lbl, vbox.get_node("Actions").get_index())

func _on_restart_pressed() -> void:
	var mission := get_tree().current_scene
	if mission and mission.has_method("restart_mission"):
		mission.restart_mission()
		return
	GameManager.reset_game()
	get_tree().reload_current_scene()

func _on_victory_action_pressed() -> void:
	if not next_level_path.is_empty():
		SoundManager.set_music_mood("explore")
		get_tree().change_scene_to_file(next_level_path)
	elif final_mission:
		GameManager.reset_game()
		get_tree().change_scene_to_file("res://src/levels/level_01.tscn")
	else:
		_on_restart_pressed()
