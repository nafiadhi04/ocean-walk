extends Node3D

# ============================================================
# camera.gd
# First-person camera dengan mouse look + realistic camera wobble
# Wobble mensimulasikan handheld camera saat berjalan
# ============================================================

@export_group("Mouse Sensitivity")
@export var mouse_sensitivity: float = 0.15

@export_group("Angle Limits")
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

@export_group("Camera Wobble")
@export var wobble_speed: float = 6.5
@export var wobble_strength_h: float = 0.018  # horizontal sway
@export var wobble_strength_v: float = 0.012  # vertical bob
@export var wobble_roll: float = 0.008        # roll miring kiri-kanan
@export var wobble_smoothing: float = 8.0     # seberapa cepat masuk/keluar wobble

# Node reference
@onready var camera: Camera3D = $Camera3D

# Internal state
var _yaw: float = 0.0
var _pitch: float = 0.0

# Wobble state
var _wobble_time: float = 0.0
var _wobble_current: Vector3 = Vector3.ZERO   # x=pitch, y=yaw, z=roll
var _wobble_target: Vector3 = Vector3.ZERO
var _player_ref: CharacterBody3D = null
var _is_player_moving: bool = false
var _player_speed: float = 0.0

# Breath idle state (sangat halus saat diam)
var _breath_time: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_find_player()


func _find_player() -> void:
	var scene := get_tree().current_scene
	if scene:
		var p := scene.get_node_or_null("Player")
		if p is CharacterBody3D:
			_player_ref = p as CharacterBody3D


func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_yaw   -= event.relative.x * mouse_sensitivity
			_pitch -= event.relative.y * mouse_sensitivity
			_pitch  = clampf(_pitch, min_pitch, max_pitch)
			rotation_degrees.y = _yaw
			if camera:
				camera.rotation_degrees.x = _pitch

	# Toggle mouse capture
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			elif event.physical_keycode == KEY_F11:
				if not OS.has_feature("editor"):
					var mode := DisplayServer.window_get_mode()
					if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
						DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					else:
						DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(delta: float) -> void:
	_update_player_state()
	_update_wobble(delta)
	_apply_wobble(delta)


func _update_player_state() -> void:
	if _player_ref == null:
		_find_player()
		return
	# Akses langsung - lebih cepat dari has_method() + call() setiap frame
	_is_player_moving = _player_ref.get_is_moving()
	_player_speed = _player_ref.get_current_speed()


func _update_wobble(delta: float) -> void:
	if _is_player_moving and _player_speed > 0.2:
		# Walking/running wobble - frekuensi langkah
		var step_freq := _player_speed * 0.55
		_wobble_time += delta * step_freq

		# Pola langkah kaki nyata:
		# - horizontal: sinusoidal kiri-kanan per langkah
		# - vertikal: naik-turun dua kali per siklus langkah (double bounce)
		# - roll: miring berlawanan dari horizontal
		var speed_factor := clampf(_player_speed / 4.0, 0.0, 1.5)

		_wobble_target.x = sin(_wobble_time * 2.0) * wobble_strength_v * speed_factor
		_wobble_target.y = sin(_wobble_time)        * wobble_strength_h * speed_factor
		_wobble_target.z = sin(_wobble_time)        * wobble_roll       * speed_factor
	else:
		# Idle: breathing motion sangat halus
		_breath_time += delta * 0.45
		_wobble_target.x = sin(_breath_time) * 0.003
		_wobble_target.y = sin(_breath_time * 0.7) * 0.002
		_wobble_target.z = 0.0


func _apply_wobble(delta: float) -> void:
	if camera == null:
		return

	# Smooth lerp ke target wobble
	_wobble_current = _wobble_current.lerp(_wobble_target, wobble_smoothing * delta)

	# Apply sebagai offset rotation di atas pitch yang sudah ada dari mouse
	# Gunakan basis lokal kamera agar tidak konflik dengan mouse look
	var base_pitch := _pitch
	camera.rotation_degrees.x = base_pitch + rad_to_deg(_wobble_current.x)
	camera.rotation_degrees.y = rad_to_deg(_wobble_current.y)
	camera.rotation_degrees.z = rad_to_deg(_wobble_current.z)


func get_yaw_degrees() -> float:
	return _yaw


func get_camera_forward() -> Vector3:
	if camera:
		return -camera.global_transform.basis.z
	return Vector3.FORWARD
