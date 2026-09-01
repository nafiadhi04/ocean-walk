class_name LaneManager
extends RefCounted

# ============================================================
# LaneManager.gd
# Mengelola 5 lane battle: penempatan musuh, validasi attack
# pattern, dan query unit yang terkena serangan.
# ============================================================

## Total lane yang tersedia
const LANE_COUNT: int = 5

## lane_slots[i] = Array of BattleUnit yang ada di lane i+1
## Index 0 = lane 1, index 4 = lane 5
var lane_slots: Array = []

## Semua enemy units yang terdaftar
var enemy_units: Array[BattleUnit] = []


func _init() -> void:
	lane_slots.clear()
	for i in LANE_COUNT:
		lane_slots.append([])


## Daftarkan musuh ke lane-lane yang ia tempati
func register_enemy(unit: BattleUnit) -> void:
	if not unit or not unit.stats:
		return
	enemy_units.append(unit)
	for lane in unit.occupied_lanes:
		var idx := lane - 1
		if idx >= 0 and idx < LANE_COUNT:
			if unit not in lane_slots[idx]:
				lane_slots[idx].append(unit)


## Hapus musuh dari semua lane (saat mati atau melarikan diri)
func unregister_enemy(unit: BattleUnit) -> void:
	enemy_units.erase(unit)
	for i in LANE_COUNT:
		lane_slots[i].erase(unit)


## Kembalikan semua BattleUnit musuh yang terkena attack pattern.
## Satu musuh multi-lane hanya muncul sekali meski terkena di banyak lane.
func get_hit_units(target_lanes: Array[int]) -> Array[BattleUnit]:
	var hit: Array[BattleUnit] = []
	for lane in target_lanes:
		var idx := lane - 1
		if idx < 0 or idx >= LANE_COUNT:
			continue
		for unit in lane_slots[idx]:
			var bu := unit as BattleUnit
			if bu and bu.is_alive and bu not in hit:
				hit.append(bu)
	return hit


## Cek apakah lane tertentu kosong (tidak ada musuh hidup)
func is_lane_empty(lane: int) -> bool:
	var idx := lane - 1
	if idx < 0 or idx >= LANE_COUNT:
		return true
	for unit in lane_slots[idx]:
		var bu := unit as BattleUnit
		if bu and bu.is_alive:
			return false
	return true


## Kembalikan semua lane yang masih ada musuh hidup
func get_occupied_lanes() -> Array[int]:
	var result: Array[int] = []
	for i in LANE_COUNT:
		for unit in lane_slots[i]:
			var bu := unit as BattleUnit
			if bu and bu.is_alive:
				result.append(i + 1)
				break
	return result


## Kembalikan semua musuh yang masih hidup
func get_alive_enemies() -> Array[BattleUnit]:
	var alive: Array[BattleUnit] = []
	for unit in enemy_units:
		if unit.is_alive:
			alive.append(unit)
	return alive


## Kembalikan semua musuh (hidup atau mati) — untuk UI
func get_all_enemies() -> Array[BattleUnit]:
	return enemy_units.duplicate()


## Cek apakah attack pattern menyentuh setidaknya satu musuh hidup
func pattern_hits_any(target_lanes: Array[int]) -> bool:
	return not get_hit_units(target_lanes).is_empty()


## Kembalikan dictionary lane -> Array[BattleUnit] untuk keperluan UI highlight
func get_lane_map() -> Dictionary:
	var map: Dictionary = {}
	for i in LANE_COUNT:
		map[i + 1] = lane_slots[i].filter(func(u): return (u as BattleUnit).is_alive)
	return map


## Reset semua lane (untuk battle baru)
func reset() -> void:
	enemy_units.clear()
	lane_slots.clear()
	for i in LANE_COUNT:
		lane_slots.append([])


## Pindahkan musuh ke lane baru (misal AI bergerak)
func move_enemy(unit: BattleUnit, new_lanes: Array[int]) -> void:
	# Hapus dari lane lama
	for i in LANE_COUNT:
		lane_slots[i].erase(unit)
	# Set lane baru
	unit.occupied_lanes = new_lanes.duplicate()
	for lane in new_lanes:
		var idx := lane - 1
		if idx >= 0 and idx < LANE_COUNT:
			lane_slots[idx].append(unit)
