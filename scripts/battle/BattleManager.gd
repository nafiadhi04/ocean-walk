extends Node

# ============================================================
# BattleManager.gd
# Autoload singleton — state machine battle utama.
# Mengelola ATB turn order, eksekusi aksi, sinyal ke UI.
# ============================================================

## State battle
enum BattleState {
	INACTIVE,      ## Tidak dalam battle
	INTRO,         ## Animasi masuk battle
	ATB_RUNNING,   ## ATB berjalan, menunggu giliran
	PLAYER_ACTION, ## Menunggu input player (pilih serangan + lane)
	ENEMY_ACTION,  ## AI musuh sedang bertindak
	RESOLVING,     ## Menghitung damage, animasi hit
	BATTLE_WON,    ## Semua musuh kalah
	BATTLE_LOST,   ## Semua player kalah
	OUTRO,         ## Animasi keluar battle
}

## --- Sinyal ---
signal battle_started()
signal battle_ended(player_won: bool)
signal turn_started(unit: BattleUnit)
signal action_executed(attacker: BattleUnit, attack: AttackData, hit_units: Array)
signal unit_hp_changed(unit: BattleUnit)
signal unit_died(unit: BattleUnit)
signal state_changed(new_state: int)
signal atb_updated()  ## Emit tiap frame saat ATB berjalan (untuk progress bar UI)

## --- State ---
var current_state: int = BattleState.INACTIVE
var lane_manager: LaneManager = null

## Party player (Array of BattleUnit)
var player_party: Array[BattleUnit] = []
## Semua musuh (Array of BattleUnit)
var enemy_units: Array[BattleUnit] = []

## Unit yang sedang menunggu input (player turn)
var active_player_unit: BattleUnit = null
## Antrian unit yang ATB-nya penuh
var turn_queue: Array[BattleUnit] = []

## Kecepatan global ATB (bisa diperlambat/dipercepat)
var atb_speed: float = 1.0
## Apakah ATB sedang dijalankan
var _atb_running: bool = false

## Data untuk pending action player
var _pending_attack: AttackData = null
var _pending_attack_index: int = -1

## Scene path yang akan dimuat
const BATTLE_SCENE_PATH := "res://scenes/battle/BattleScene.tscn"
## Scene sebelumnya (untuk kembali setelah battle)
var _previous_scene_path: String = ""


# ============================================================
# Inisialisasi battle
# ============================================================

## Mulai battle baru.
## party_stats: Array[CharacterStats] — data party player
## enemy_stats_list: Array[CharacterStats] — data musuh
## from_scene: path scene asal untuk kembali setelah battle
func start_battle(
		party_stats: Array,
		enemy_stats_list: Array,
		from_scene: String = "") -> void:
	if current_state != BattleState.INACTIVE:
		push_warning("BattleManager: Battle sudah berjalan!")
		return

	_previous_scene_path = from_scene
	_setup_units(party_stats, enemy_stats_list)
	_set_state(BattleState.INTRO)

	# Load battle scene
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
	battle_started.emit()


## Setup semua unit dari data stats
func _setup_units(party_stats: Array, enemy_stats_list: Array) -> void:
	player_party.clear()
	enemy_units.clear()
	turn_queue.clear()
	active_player_unit = null
	lane_manager = LaneManager.new()

	# Setup party player
	for i in party_stats.size():
		var stats := party_stats[i] as CharacterStats
		if not stats:
			continue
		var unit := BattleUnit.new()
		unit.setup(stats, i)
		unit.hp_changed.connect(func(_o, _n): unit_hp_changed.emit(unit))
		unit.unit_died.connect(func(): _on_unit_died(unit))
		player_party.append(unit)

	# Setup musuh
	for i in enemy_stats_list.size():
		var stats := enemy_stats_list[i] as CharacterStats
		if not stats:
			continue
		var unit := BattleUnit.new()
		unit.setup(stats, i)
		unit.hp_changed.connect(func(_o, _n): unit_hp_changed.emit(unit))
		unit.unit_died.connect(func(): _on_unit_died(unit))
		enemy_units.append(unit)
		lane_manager.register_enemy(unit)


# ============================================================
# ATB Loop
# ============================================================

func begin_atb() -> void:
	_atb_running = true
	_set_state(BattleState.ATB_RUNNING)


func _process(delta: float) -> void:
	if current_state != BattleState.ATB_RUNNING or not _atb_running:
		return

	# Tick semua unit yang belum ready
	var all_units := _get_all_units()
	for unit in all_units:
		if unit.is_alive and not unit.is_turn_ready:
			unit.tick_atb(delta, atb_speed)

	atb_updated.emit()

	# Cek apakah ada unit yang baru ready dan belum di queue
	for unit in all_units:
		if unit.is_alive and unit.is_turn_ready and unit not in turn_queue:
			turn_queue.append(unit)

	# Proses giliran berikutnya jika tidak sedang menunggu aksi
	if not turn_queue.is_empty():
		_process_next_turn()


func _process_next_turn() -> void:
	if turn_queue.is_empty():
		return

	# Ambil unit pertama dari queue
	var unit := turn_queue[0] as BattleUnit
	turn_queue.remove_at(0)

	if not unit.is_alive:
		# Skip unit mati
		return

	turn_started.emit(unit)

	if unit.stats.is_enemy:
		_set_state(BattleState.ENEMY_ACTION)
		_atb_running = false
		_execute_enemy_turn(unit)
	else:
		active_player_unit = unit
		_set_state(BattleState.PLAYER_ACTION)
		_atb_running = false


# ============================================================
# Player Action
# ============================================================

## Dipanggil dari UI saat player memilih serangan
func player_select_attack(attack_index: int) -> void:
	if current_state != BattleState.PLAYER_ACTION:
		return
	if not active_player_unit:
		return

	var attacks := active_player_unit.stats.attacks
	if attack_index < 0 or attack_index >= attacks.size():
		return
	if not active_player_unit.is_attack_available(attack_index):
		return

	_pending_attack_index = attack_index
	_pending_attack = attacks[attack_index] as AttackData


## Konfirmasi eksekusi serangan player (setelah preview lane)
func player_confirm_action() -> void:
	if current_state != BattleState.PLAYER_ACTION:
		return
	if not _pending_attack or not active_player_unit:
		return

	_set_state(BattleState.RESOLVING)
	_execute_attack(active_player_unit, _pending_attack)
	active_player_unit.use_attack(_pending_attack_index)
	active_player_unit.tick_cooldowns()
	active_player_unit.consume_turn()
	active_player_unit = null
	_pending_attack = null
	_pending_attack_index = -1

	_check_battle_end()


## Batalkan pilihan serangan, kembali ke pilih skill
func player_cancel_action() -> void:
	_pending_attack = null
	_pending_attack_index = -1


# ============================================================
# Enemy AI Turn
# ============================================================

func _execute_enemy_turn(unit: BattleUnit) -> void:
	# Pilih serangan dari pool secara acak
	var pool := unit.stats.enemy_attack_pool
	if pool.is_empty():
		# Tidak ada serangan, skip
		unit.consume_turn()
		_finish_turn()
		return

	# Filter serangan yang tersedia (tidak cooldown)
	var available: Array = []
	for i in pool.size():
		var atk := pool[i] as AttackData
		if atk and unit.is_attack_available(i):
			available.append({"index": i, "attack": atk})

	if available.is_empty():
		unit.consume_turn()
		_finish_turn()
		return

	var chosen: Dictionary = available[randi() % available.size()]
	var attack: AttackData = chosen["attack"]

	# Tambahkan delay kecil agar terasa natural (pakai timer)
	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(func():
		_execute_attack(unit, attack)
		unit.use_attack(chosen["index"])
		unit.tick_cooldowns()
		unit.consume_turn()
		_check_battle_end()
	)


# ============================================================
# Eksekusi Serangan
# ============================================================

func _execute_attack(attacker: BattleUnit, attack: AttackData) -> void:
	var hit_units: Array[BattleUnit] = []

	if attacker.stats.is_enemy:
		# Musuh menyerang semua party player
		hit_units = player_party.filter(func(u): return (u as BattleUnit).is_alive)
	else:
		# Player menyerang berdasarkan lane pattern
		hit_units = lane_manager.get_hit_units(attack.target_lanes)

	for target in hit_units:
		var raw := attacker.calculate_raw_damage(attack)
		# Multi-hit
		for _h in attack.hit_count:
			target.take_damage(raw, attack.attack_type)

	action_executed.emit(attacker, attack, hit_units)


# ============================================================
# Cek Kondisi Akhir Battle
# ============================================================

func _check_battle_end() -> void:
	var all_enemies_dead := lane_manager.get_alive_enemies().is_empty()
	var all_players_dead := player_party.filter(
		func(u): return (u as BattleUnit).is_alive).is_empty()

	if all_enemies_dead:
		_set_state(BattleState.BATTLE_WON)
		battle_ended.emit(true)
		return

	if all_players_dead:
		_set_state(BattleState.BATTLE_LOST)
		battle_ended.emit(false)
		return

	_finish_turn()


func _finish_turn() -> void:
	_set_state(BattleState.ATB_RUNNING)
	_atb_running = true


# ============================================================
# Akhiri Battle dan kembali ke scene sebelumnya
# ============================================================

func end_battle() -> void:
	_atb_running = false
	_set_state(BattleState.OUTRO)
	player_party.clear()
	enemy_units.clear()
	turn_queue.clear()
	active_player_unit = null
	lane_manager = null

	_set_state(BattleState.INACTIVE)

	if not _previous_scene_path.is_empty():
		get_tree().change_scene_to_file(_previous_scene_path)


# ============================================================
# Utilitas
# ============================================================

func _get_all_units() -> Array[BattleUnit]:
	var all: Array[BattleUnit] = []
	all.append_array(player_party)
	all.append_array(enemy_units)
	return all


func _on_unit_died(unit: BattleUnit) -> void:
	unit_died.emit(unit)
	turn_queue.erase(unit)
	if unit.stats.is_enemy:
		lane_manager.unregister_enemy(unit)


func _set_state(new_state: int) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)


## Kembalikan pending attack untuk preview di UI
func get_pending_attack() -> AttackData:
	return _pending_attack


## Cek apakah saat ini menunggu input player
func is_waiting_player_input() -> bool:
	return current_state == BattleState.PLAYER_ACTION
