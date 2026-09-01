extends CharacterBody3D

# ============================================================
# player.gd
# First-person player controller untuk Endless Ocean Walk
# Dengan footstep timer, ripple spawning, dan audio footstep
# ============================================================

@export_group("Movement")
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var acceleration: float = 8.0
@export var deceleration: float = 12.0

@export_group("Ocean Sync")
@export var water_level: float = 0.0
@export var player_height_offset: float = 1.65

@export_group("Footstep")
@export var footstep_interval: float = 0.28

# Node references
@onready var camera_rig: Node3D = $CameraRig

# Ripple scene preload
const RIPPLE_SCENE := preload("res://scenes/Ripple.tscn")

# Footstep audio streams
var _footstep_streams: Array[AudioStream] = []
var _footstep_player: AudioStreamPlayer = null

# Internal state
var _current_speed: float = 0.0
var _is_moving: bool = false
var _bob_time: float = 0.0
var _bob_offset: float = 0.0
var _ocean_ref: Node3D = null
var _footstep_timer: float = 0.0
var _ripple_parent: Node3D = null
var _left_foot: bool = true
var _last_footstep_idx: int = -1  # hindari suara sama berulang


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	position.y = water_level + player_height_offset
	_find_ocean()
	_ripple_parent = get_tree().current_scene
	_setup_footstep_audio()


func _setup_footstep_audio() -> void:
	var paths := [
		"res://audio/footstep_water_1.mp3",
		"res://audio/footstep_water_2.mp3",
		"res://audio/footstep_water_3.mp3",
	]
	for path in paths:
		var s := load(path) as AudioStream
		if s:
			_footstep_streams.append(s)

	_footstep_player = AudioStreamPlayer.new()
	# Polyphonic - bisa play banyak suara sekaligus tanpa cancel
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 4
	_footstep_player.stream = poly
	_footstep_player.bus = "Master"
	add_child(_footstep_player)
	_footstep_player.play()  # harus play dulu agar get_stream_playback() valid


func _on_footstep_finished() -> void:
	pass


func _find_ocean() -> void:
	var main := get_tree().current_scene
	if main:
		_ocean_ref = main.get_node_or_null("Ocean") as Node3D


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_sync_water_height(delta)
	_handle_visual_bob(delta)
	_handle_footstep(delta)
	move_and_slide()


func _handle_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")

	_is_moving = input_dir.length() > 0.1

	var move_dir := Vector3.ZERO
	if camera_rig and _is_moving:
		var cam_basis := camera_rig.global_transform.basis
		var forward := -cam_basis.z
		var right := cam_basis.x
		forward.y = 0.0
		right.y = 0.0
		if forward.length_squared() > 0.001:
			forward = forward.normalized()
		if right.length_squared() > 0.001:
			right = right.normalized()
		move_dir = forward * -input_dir.y + right * input_dir.x

	var is_running := Input.is_physical_key_pressed(KEY_SHIFT)
	var target_speed := 0.0
	if _is_moving:
		target_speed = run_speed if is_running else walk_speed

	var accel := acceleration if _is_moving else deceleration
	_current_speed = move_toward(_current_speed, target_speed, accel * delta)

	if move_dir.length_squared() > 0.001:
		var flat_dir := move_dir.normalized()
		velocity.x = flat_dir.x * _current_speed
		velocity.z = flat_dir.z * _current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	velocity.y = 0.0


func _sync_water_height(delta: float) -> void:
	var target_y := water_level + player_height_offset

	if _ocean_ref != null and _ocean_ref.has_method("get_wave_height"):
		var wave_h: float = _ocean_ref.call("get_wave_height", global_position)
		target_y = wave_h + player_height_offset

	position.y = lerp(position.y, target_y + _bob_offset, 18.0 * delta)
	velocity.y = 0.0


func _handle_visual_bob(delta: float) -> void:
	if _is_moving:
		_bob_time += delta * _current_speed * 2.2
		_bob_offset = sin(_bob_time) * 0.022
	else:
		_bob_time += delta * 0.6
		_bob_offset = sin(_bob_time) * 0.005


func _handle_footstep(delta: float) -> void:
	if not _is_moving or _current_speed < 0.5:
		_footstep_timer = 0.0
		return

	var speed_ratio := _current_speed / walk_speed
	var interval := footstep_interval / maxf(speed_ratio, 0.5)

	_footstep_timer += delta
	if _footstep_timer >= interval:
		_footstep_timer = 0.0
		_play_footstep()
		_spawn_ripple()


func _play_footstep() -> void:
	if _footstep_player == null or _footstep_streams.is_empty():
		return

	var playback := _footstep_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if playback == null:
		return

	# Pilih variasi acak, hindari suara yang sama 2x berturut-turut
	var idx := _last_footstep_idx
	if _footstep_streams.size() > 1:
		while idx == _last_footstep_idx:
			idx = randi() % _footstep_streams.size()
	else:
		idx = 0
	_last_footstep_idx = idx

	var vol_db := -6.0 if _current_speed <= walk_speed else -3.0
	var pitch := randf_range(0.92, 1.08)
	# play_stream langsung ke slot baru - tidak cancel suara sebelumnya
	playback.play_stream(_footstep_streams[idx], 0.0, vol_db, pitch)


func _spawn_ripple() -> void:
	if _ripple_parent == null or RIPPLE_SCENE == null:
		return

	var ripple := RIPPLE_SCENE.instantiate() as Node3D
	if ripple == null:
		return

	_ripple_parent.add_child(ripple)

	# Hitung posisi Y dari wave
	var spawn_y := 0.02
	if _ocean_ref != null and _ocean_ref.has_method("get_wave_height"):
		var wave_h: float = _ocean_ref.call("get_wave_height", global_position)
		spawn_y = wave_h + 0.02

	# Offset kiri/kanan bergantian tiap langkah
	# Gunakan basis kamera rig untuk arah right yang benar
	var foot_offset := 0.22
	var right_dir := Vector3.RIGHT
	if camera_rig:
		right_dir = camera_rig.global_transform.basis.x
		right_dir.y = 0.0
		if right_dir.length_squared() > 0.001:
			right_dir = right_dir.normalized()

	var side := foot_offset if _left_foot else -foot_offset
	var spawn_pos := global_position + right_dir * side
	ripple.global_position = Vector3(spawn_pos.x, spawn_y, spawn_pos.z)

	# Toggle kaki untuk langkah berikutnya
	_left_foot = not _left_foot


func get_is_moving() -> bool:
	return _is_moving


func get_current_speed() -> float:
	return _current_speed
