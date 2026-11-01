extends CanvasLayer
## HUD, inner thoughts, pause menu, death and results screens.

var player = null
var root: Control
var health_bar: ProgressBar
var health_lbl: Label
var ammo_lbl: Label
var weapon_lbl: Label
var objective_lbl: Label
var prompt_lbl: Label
var thought_lbl: Label
var toast_lbl: Label
var stealth_lbl: Label
var crosshair: Label
var dmg_flash: ColorRect
var fog_tint: ColorRect
var daze: ColorRect
var pause_panel: Control
var death_panel: Control
var results_panel: Control
var results_text: Label
var post: ColorRect
var radio_box: PanelContainer
var radio_lbl: Label
var _radio_t := 0.0
var _fog_amt := 0.0

const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float fog_amt = 0.0;
uniform float dread = 0.0;
uniform float daze = 0.0;
uniform float hurt = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float w = fog_amt * 0.006 + daze * 0.012;
	uv += vec2(sin(uv.y * 18.0 + TIME * 2.0), cos(uv.x * 14.0 + TIME * 1.7)) * w;
	float ca = 0.0008 + fog_amt * 0.004 + daze * 0.006 + dread * 0.0012;
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lum) * vec3(0.92, 0.88, 1.12), dread * 0.38);
	c = mix(c, c * vec3(1.15, 0.75, 1.3) + vec3(0.03, 0.0, 0.05), fog_amt * 0.55);
	vec2 d = SCREEN_UV - 0.5;
	float r = length(d * vec2(1.0, 0.85));
	c *= 1.0 - smoothstep(0.3, 0.85, r) * (0.35 + dread * 0.35 + fog_amt * 0.3);
	float pulse = 0.6 + 0.4 * sin(TIME * 6.0);
	c = mix(c, vec3(0.45, 0.0, 0.05), hurt * pulse * smoothstep(0.25, 0.75, r));
	c += (hash(SCREEN_UV * 731.0 + TIME) - 0.5) * (0.025 + dread * 0.035);
	COLOR = vec4(c, 1.0);
}
"""

var _thoughts: Array = []
var _thought_t := 0.0
var _toast_t := 0.0
var _flash := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	post.material = sm
	root.add_child(post)

	fog_tint = _rect(Color(0.5, 0.1, 0.7, 0.0))
	daze = _rect(Color(0.3, 0.9, 0.5, 0.0))
	dmg_flash = _rect(Color(0.8, 0.0, 0.05, 0.0))

	crosshair = _label("+", 26, Color(1, 1, 1, 0.8))
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(crosshair, Control.PRESET_CENTER, Vector2(-20, -20), Vector2(40, 36))

	objective_lbl = _label("", 20, Color(1, 0.85, 0.4))
	_place(objective_lbl, Control.PRESET_TOP_LEFT, Vector2(24, 18), Vector2(900, 30))
	stealth_lbl = _label("", 16, Color(0.7, 0.7, 0.9))
	_place(stealth_lbl, Control.PRESET_TOP_LEFT, Vector2(24, 50), Vector2(300, 26))

	thought_lbl = _label("", 22, Color(0.85, 0.75, 1.0))
	thought_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(thought_lbl, Control.PRESET_CENTER_TOP, Vector2(-500, 100), Vector2(1000, 40))

	prompt_lbl = _label("", 20, Color(1, 1, 1))
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(prompt_lbl, Control.PRESET_CENTER, Vector2(-400, 40), Vector2(800, 30))

	toast_lbl = _label("", 16, Color(0.8, 1, 0.8))
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(toast_lbl, Control.PRESET_CENTER, Vector2(-300, 80), Vector2(600, 30))

	health_bar = ProgressBar.new()
	health_bar.max_value = 100
	health_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.15, 0.25)
	health_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.1, 0.7)
	health_bar.add_theme_stylebox_override("background", bg)
	root.add_child(health_bar)
	_place(health_bar, Control.PRESET_BOTTOM_LEFT, Vector2(24, -56), Vector2(240, 24))
	health_lbl = _label("", 16, Color(1, 1, 1))
	_place(health_lbl, Control.PRESET_BOTTOM_LEFT, Vector2(30, -56), Vector2(200, 24))

	weapon_lbl = _label("", 18, Color(1, 0.9, 0.6))
	weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(weapon_lbl, Control.PRESET_BOTTOM_RIGHT, Vector2(-424, -96), Vector2(400, 28))
	ammo_lbl = _label("", 30, Color(1, 1, 1))
	ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(ammo_lbl, Control.PRESET_BOTTOM_RIGHT, Vector2(-324, -66), Vector2(300, 44))

	radio_box = PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.02, 0.08, 0.04, 0.85)
	rsb.border_color = Color(0.3, 1, 0.5, 0.8)
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(6)
	rsb.content_margin_left = 14
	rsb.content_margin_right = 14
	rsb.content_margin_top = 8
	rsb.content_margin_bottom = 8
	radio_box.add_theme_stylebox_override("panel", rsb)
	radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radio_box)
	_place(radio_box, Control.PRESET_CENTER_BOTTOM, Vector2(-380, -170), Vector2(760, 70))
	radio_lbl = _label("", 17, Color(0.6, 1, 0.65), radio_box)
	radio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_box.visible = false

	_build_pause()
	_build_death()
	_build_results()


func _place(c: Control, preset: int, pos: Vector2, sz: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + sz.x
	c.offset_bottom = pos.y + sz.y


func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


func _label(text: String, size: int, col: Color, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else root).add_child(l)
	return l


func _panel(title: String) -> VBoxContainer:
	var bgc := ColorRect.new()
	bgc.color = Color(0.03, 0.0, 0.06, 0.82)
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bgc)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgc.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)
	var t := _label(title, 44, Color(1, 0.4, 0.6), vb)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bgc.visible = false
	vb.set_meta("panel", bgc)
	return vb


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _slider(parent: Control, text: String, value: float, maxv: float, cb: Callable) -> void:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	var l := _label(text, 16, Color(0.9, 0.9, 1), hb)
	l.custom_minimum_size = Vector2(140, 0)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = maxv
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(200, 24)
	s.value_changed.connect(cb)
	hb.add_child(s)


func _build_pause() -> void:
	var vb := _panel("PAUSED")
	pause_panel = vb.get_meta("panel")
	_button(vb, "Resume", toggle_pause)
	_button(vb, "Restart", _restart)
	_slider(vb, "Master volume", GameState.master_volume, 1.0, func(v): GameState.master_volume = v; GameState.save_settings())
	_slider(vb, "Music volume", GameState.music_volume, 1.0, func(v): GameState.music_volume = v; GameState.save_settings())
	_slider(vb, "Effects volume", GameState.sfx_volume, 1.0, func(v): GameState.sfx_volume = v; GameState.save_settings())
	_slider(vb, "Mouse sensitivity", GameState.mouse_sensitivity, 3.0, func(v): GameState.mouse_sensitivity = maxf(v, 0.05); GameState.save_settings())
	_button(vb, "Main Menu", _main_menu)
	_button(vb, "Quit", func(): get_tree().quit())


func _build_death() -> void:
	var vb := _panel("YOU DIED")
	death_panel = vb.get_meta("panel")
	var l := _label("The carnival claims another guest.", 20, Color(0.9, 0.8, 1), vb)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(vb, "Try Again", _restart)
	_button(vb, "Main Menu", _main_menu)


func _build_results() -> void:
	var vb := _panel("YOU ESCAPED")
	results_panel = vb.get_meta("panel")
	results_text = _label("", 18, Color(1, 1, 1), vb)
	_button(vb, "Play Again", _restart)
	_button(vb, "Main Menu", _main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not death_panel.visible and not results_panel.visible:
		toggle_pause()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused and player and not player.dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _process(delta: float) -> void:
	if player:
		health_bar.value = player.health
		health_lbl.text = "  %d" % int(ceilf(player.health))
		if player.current == "":
			weapon_lbl.text = "Unarmed"
			ammo_lbl.text = "--"
		else:
			weapon_lbl.text = player.WEAPONS[player.current].name + ("  (reloading)" if player.reload_t > 0.0 else "")
			ammo_lbl.text = "%d / %d" % [player.mag[player.current], player.reserve[player.current]]
		var hunted := false
		for p in GameState.people:
			if is_instance_valid(p) and p.hostile and not p.dead and p.alert_t > 0.0:
				hunted = true
				break
		if hunted:
			stealth_lbl.text = "[ HUNTED ]"
			stealth_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		elif player.noise_level < 0.25:
			stealth_lbl.text = "[ hidden ]"
			stealth_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
		elif player.noise_level < 0.6:
			stealth_lbl.text = "[ visible ]"
			stealth_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
		else:
			stealth_lbl.text = "[ LOUD ]"
			stealth_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
		daze.color.a = clampf(player.disorient * 0.08, 0.0, 0.2)
	if _radio_t > 0.0:
		_radio_t -= delta
		radio_box.modulate.a = clampf(_radio_t, 0.0, 1.0)
		if _radio_t <= 0.0:
			radio_box.visible = false
	var sm: ShaderMaterial = post.material
	sm.set_shader_parameter("fog_amt", _fog_amt)
	sm.set_shader_parameter("dread", GameState.dread)
	if player:
		sm.set_shader_parameter("daze", clampf(player.disorient, 0.0, 1.5))
		sm.set_shader_parameter("hurt", clampf(1.0 - player.health / 45.0, 0.0, 1.0) if not player.dead else 0.0)
	_flash = maxf(0.0, _flash - delta * 1.5)
	dmg_flash.color.a = _flash * 0.5
	# thoughts
	if _thought_t > 0.0:
		_thought_t -= delta
		thought_lbl.modulate.a = clampf(_thought_t, 0.0, 1.0)
	elif not _thoughts.is_empty():
		thought_lbl.text = "\"" + _thoughts.pop_front() + "\""
		_thought_t = 4.5
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_lbl.modulate.a = clampf(_toast_t, 0.0, 1.0)


func set_prompt(t: String) -> void:
	prompt_lbl.text = t


func set_objective(t: String) -> void:
	objective_lbl.text = "OBJECTIVE: " + t


func set_fog(a: float) -> void:
	_fog_amt = a


func show_radio(speaker: String, text: String) -> void:
	radio_lbl.text = "[RADIO] %s:\n\"%s\"  *kssshhh*" % [speaker, text]
	radio_box.visible = true
	_radio_t = 7.0
	Sfx.play_ui("radio", -2.0)


func show_thought(t: String) -> void:
	_thoughts.append(t)


func toast(t: String) -> void:
	toast_lbl.text = t
	_toast_t = 2.5


func flash_damage(amount: float) -> void:
	_flash = maxf(_flash, amount)


func show_death() -> void:
	await get_tree().create_timer(1.6).timeout
	death_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_results(score: Dictionary) -> void:
	var s: Dictionary = score.stats
	var t: float = score.time
	var txt := "Escape time:              %d:%02d\n" % [int(t) / 60, int(t) % 60]
	txt += "People rescued:           %d\n" % s.rescued
	txt += "Affected by the fog:      %d\n" % s.affected
	txt += "Innocent people killed:   %d\n" % s.innocents_killed
	txt += "Left behind:              %d of %d\n\n" % [s.remaining, s.total]
	for line in score.lines:
		txt += "%-36s %+d\n" % [line[0], line[1]]
	txt += "\nFINAL SCORE:  %d" % score.total
	if s.remaining - s.affected > 0:
		txt += "\n\n%d unaffected people are still inside the carnival." % (s.trapped)
	results_text.text = txt
	results_panel.visible = true
	pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
