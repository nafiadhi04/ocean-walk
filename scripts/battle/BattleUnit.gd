class_name BattleUnit
extends RefCounted

# ============================================================
# BattleUnit.gd
# Representasi runtime sebuah unit (player atau musuh) di battle.
# Menyimpan HP aktif, ATB gauge, cooldown, dan referensi ke stats.
# ============================================================

## Sinyal saat HP berubah
signal hp_changed(old_hp: int, new_hp: int)
## Sinyal saat unit mati
signal unit_died()
## Sinyal saat ATB penuh (giliran siap)
signal turn_ready()

## Stats dasar unit (CharacterStats resource)
var stats: CharacterStats = null

## HP saat ini
var current_hp: int = 0
## MP/SP saat ini
var current_mp: int = 0
## ATB gauge saat ini [0.0 .. 1.0]
var atb_gauge: float = 0.0
## Apakah unit sudah siap bertindak
var is_turn_ready: bool = false
## Apakah unit masih hidup
var is_alive: bool = true

## Lane yang ditempati (untuk musuh multi-lane)
var occupied_lanes: Array[int] = []

## Cooldown per attack index: { attack_index: turns_remaining }
var attack_cooldowns: Dictionary = {}

## Referensi ke node visual di scene (BattleUnitNode)
var visual_node: Node = null

## Index slot party (untuk player unit, 0-based)
var party_index: int = -1

## Label identifikasi untuk debug
var unit_id: String = ""


func setup(character_stats: CharacterStats, slot_index: int = -1) -> void:
	stats = character_stats
	current_hp = stats.max_hp
	current_mp = 0
	atb_gauge = 0.0
	is_turn_ready = false
	is_alive = true
	party_index = slot_index
	unit_id = stats.character_name + ("_%d" % slot_index if slot_index >= 0 else "")

	# Setup lanes untuk musuh
	if stats.is_enemy:
		occupied_lanes = stats.enemy_lanes.duplicate()
	else:
		occupied_lanes = []


## Tick ATB gauge setiap frame. Kembalikan true jika baru saja penuh.
func tick_atb(delta: float, base_rate: float = 1.0) -> bool:
	if not is_alive or is_turn_ready:
		return false
	atb_gauge += delta * stats.speed * base_rate
	if atb_gauge >= 1.0:
		atb_gauge = 1.0
		is_turn_ready = true
		turn_ready.emit()
		return true
	return false


## Reset ATB setelah bertindak
func consume_turn() -> void:
	atb_gauge = 0.0
	is_turn_ready = false


## Terima damage. Kembalikan damage aktual yang diterima.
func take_damage(raw_damage: int, attack_type: AttackData.AttackType) -> int:
	if not is_alive:
		return 0

	var reduction: int
	if attack_type == AttackData.AttackType.PHYSICAL:
		reduction = stats.defense
	else:
		reduction = stats.magic_defense

	var actual: int = max(1, raw_damage - reduction)
	var old_hp: int = current_hp
	current_hp = max(0, current_hp - actual)
	hp_changed.emit(old_hp, current_hp)

	if current_hp <= 0:
		is_alive = false
		unit_died.emit()

	return actual


## Hitung damage mentah dari serangan ini (sebelum dikurangi defense target)
func calculate_raw_damage(attack: AttackData) -> int:
	var base_stat: int
	if attack.attack_type == AttackData.AttackType.PHYSICAL:
		base_stat = stats.attack
	else:
		base_stat = stats.magic_attack
	return int(base_stat * attack.power)


## Cek apakah serangan tersedia (tidak dalam cooldown)
func is_attack_available(attack_index: int) -> bool:
	if not attack_cooldowns.has(attack_index):
		return true
	return attack_cooldowns[attack_index] <= 0


## Tandai serangan digunakan, set cooldown
func use_attack(attack_index: int) -> void:
	var attacks := stats.attacks
	if attack_index >= attacks.size():
		return
	var atk := attacks[attack_index] as AttackData
	if atk and atk.cooldown_turns > 0:
		attack_cooldowns[attack_index] = atk.cooldown_turns


## Kurangi semua cooldown 1 turn (panggil tiap akhir giliran unit ini)
func tick_cooldowns() -> void:
	for key in attack_cooldowns.keys():
		if attack_cooldowns[key] > 0:
			attack_cooldowns[key] -= 1


## Apakah unit menempati lane tertentu (untuk cek hit)
func occupies_lane(lane: int) -> bool:
	if stats.is_enemy:
		return lane in occupied_lanes
	return false


## Pulihkan HP (healing)
func heal(amount: int) -> int:
	if not is_alive:
		return 0
	var old_hp := current_hp
	current_hp = min(stats.max_hp, current_hp + amount)
	var healed := current_hp - old_hp
	if healed > 0:
		hp_changed.emit(old_hp, current_hp)
	return healed


func get_hp_percent() -> float:
	if stats.max_hp <= 0:
		return 0.0
	return float(current_hp) / float(stats.max_hp)
