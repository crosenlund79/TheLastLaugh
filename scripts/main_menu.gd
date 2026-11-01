extends Control
## Title screen: Play, Settings, Quit.

var main_box: VBoxContainer
var settings_box: VBoxContainer
var _t := 0.0
var _title: Label
var _balloons: Array = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Music.target_distortion = 0.0
	Music.target_volume = 1.0
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.01, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for i in 14:
		var b := ColorRect.new()
		b.color = Color.from_hsv(randf(), 0.7, 0.7, 0.25)
		b.size = Vector2(1, 1) * randf_range(20, 60)
		b.position = Vector2(randf() * 1280, randf() * 720)
		add_child(b)
		_balloons.append(b)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	_title = _label(vb, "THE LAST LAUGH", 84, Color(1, 0.35, 0.55))
	_label(vb, "a dark carnival survival prototype", 22, Color(0.75, 0.6, 1.0))
	_label(vb, " ", 12, Color.WHITE)
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 10)
	vb.add_child(main_box)
	_button(main_box, "Play", func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
	_button(main_box, "Settings", func():
		main_box.visible = false
		settings_box.visible = true)
	_button(main_box, "Quit", func(): get_tree().quit())
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 10)
	settings_box.visible = false
	vb.add_child(settings_box)
	_slider(settings_box, "Master volume", GameState.master_volume, 1.0, func(v): GameState.master_volume = v)
	_slider(settings_box, "Music volume", GameState.music_volume, 1.0, func(v): GameState.music_volume = v)
	_slider(settings_box, "Effects volume", GameState.sfx_volume, 1.0, func(v): GameState.sfx_volume = v)
	_slider(settings_box, "Mouse sensitivity", GameState.mouse_sensitivity, 3.0, func(v): GameState.mouse_sensitivity = maxf(v, 0.05))
	_button(settings_box, "Back", func():
		GameState.save_settings()
		settings_box.visible = false
		main_box.visible = true)
	var help := _label(vb, "WASD move · Mouse look · Shift sprint · Ctrl/C crouch · Space jump\nLMB shoot · R reload · 1-3 / wheel switch · E interact · Esc pause", 15, Color(0.7, 0.7, 0.8))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	_t += delta
	_title.rotation = sin(_t * 1.3) * 0.02
	_title.pivot_offset = _title.size * 0.5
	for i in _balloons.size():
		var b: ColorRect = _balloons[i]
		b.position.y -= delta * (15 + i * 2)
		b.position.x += sin(_t + i) * 0.3
		if b.position.y < -80:
			b.position.y = 760
			b.position.x = randf() * 1280


func _label(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	parent.add_child(b)


func _slider(parent: Control, text: String, value: float, maxv: float, cb: Callable) -> void:
	var hb := HBoxContainer.new()
	parent.add_child(hb)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(160, 0)
	hb.add_child(l)
	var s := HSlider.new()
	s.max_value = maxv
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(220, 24)
	s.value_changed.connect(func(v):
		cb.call(v)
		GameState.apply_audio())
	hb.add_child(s)
