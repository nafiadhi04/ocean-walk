extends Node3D

# ============================================================
# main.gd
# Scene controller utama + audio ambient
# ============================================================

@onready var ocean: MeshInstance3D = $Ocean
@onready var player: CharacterBody3D = $Player
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var _hint_label: Label = null
var _hint_timer: float = 0.0
var _hint_visible: bool = true

# Ambient fade in
var _ambient_fade_time: float = 0.0
const AMBIENT_FADE_DURATION: float = 3.0
const AMBIENT_TARGET_VOLUME_DB: float = -10.0


func _ready() -> void:
	_create_ui_hints()
	_setup_ambient()


func _setup_ambient() -> void:
	var stream := load("res://audio/ambient_ocean.mp3") as AudioStreamMP3
	if stream == null:
		push_error("main.gd: ambient_ocean.mp3 tidak ditemukan")
		return

	stream.loop = true
	audio_player.stream = stream
	audio_player.volume_db = -80.0  # mulai dari silent
	audio_player.bus = "Master"
	audio_player.play()


func _create_ui_hints() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_hint_label = Label.new()
	_hint_label.text = "WASD - Berjalan    Shift - Lari    Mouse - Lihat    ESC - Cursor    F11 - Fullscreen"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_hint_label.position = Vector2(20, 20)
	canvas.add_child(_hint_label)

	var title_label := Label.new()
	title_label.text = "ENDLESS OCEAN WALK"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.7))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.position = Vector2(20, 44)
	canvas.add_child(title_label)

	# Crosshair tengah layar
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 20)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	canvas.add_child(crosshair)


func _process(delta: float) -> void:
	_handle_hint_fade(delta)
	_handle_ambient_fade(delta)


func _handle_ambient_fade(delta: float) -> void:
	if _ambient_fade_time >= AMBIENT_FADE_DURATION:
		return
	_ambient_fade_time += delta
	var t := clampf(_ambient_fade_time / AMBIENT_FADE_DURATION, 0.0, 1.0)
	# Lerp dalam linear lalu convert ke dB
	var linear := t
	audio_player.volume_db = lerp(-80.0, AMBIENT_TARGET_VOLUME_DB, linear)


func _handle_hint_fade(delta: float) -> void:
	if not _hint_visible:
		return
	_hint_timer += delta
	if _hint_timer > 6.0 and _hint_label:
		var alpha: float = clampf(1.0 - (_hint_timer - 6.0) / 3.0, 0.0, 0.65)
		_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, alpha))
		if alpha <= 0.0:
			_hint_visible = false
