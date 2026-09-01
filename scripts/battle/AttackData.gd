class_name AttackData
extends Resource

# ============================================================
# AttackData.gd
# Resource data untuk satu serangan/skill.
# Definisikan pola lane unik di sini.
# ============================================================

## Tipe serangan
enum AttackType {
	PHYSICAL,  ## Dihitung dari attack vs defense
	MAGICAL,   ## Dihitung dari magic_attack vs magic_defense
}

## Pola target lane yang diserang
## Contoh preset umum:
##   [3]        -> lane tengah saja
##   [1,2,3,4,5] -> semua lane
##   [2,4]      -> lane genap (berjarak)
##   [1,3,5]    -> lane ganjil (berjarak)
##   [1,2]      -> dua lane bersebelahan kiri
##   [1]        -> lane paling kiri saja
@export_group("Identity")
@export var attack_name: String = "Strike"
@export var description: String = ""
@export var icon: Texture2D = null

@export_group("Damage")
@export var attack_type: AttackType = AttackType.PHYSICAL
## Multiplier damage (1.0 = 100% stat, 1.5 = 150%)
@export var power: float = 1.0
## Jumlah hit (multi-hit)
@export var hit_count: int = 1

@export_group("Lane Pattern")
## Lane yang menjadi target serangan ini [1..5].
## Contoh: [1,3,5] menyerang lane 1, 3, dan 5 sekaligus.
@export var target_lanes: Array[int] = [1, 2, 3, 4, 5]
## Nama pola untuk ditampilkan di UI
@export var pattern_label: String = "All Lanes"

@export_group("Cost & Cooldown")
## Mana/SP yang dibutuhkan (0 = gratis)
@export var mp_cost: int = 0
## Turn cooldown setelah digunakan (0 = tidak ada)
@export var cooldown_turns: int = 0

@export_group("Visual")
## Warna highlight lane saat preview serangan
@export var lane_highlight_color: Color = Color(1.0, 0.85, 0.2, 0.6)


## Validasi apakah lane pattern ini valid (semua nilai 1-5, tidak duplikat)
func is_valid() -> bool:
	if target_lanes.is_empty():
		return false
	var seen := {}
	for lane in target_lanes:
		if lane < 1 or lane > 5:
			return false
		if lane in seen:
			return false
		seen[lane] = true
	return true


## Kembalikan string representasi pola untuk debug
func get_pattern_string() -> String:
	var sorted := target_lanes.duplicate()
	sorted.sort()
	return "Lane " + ", ".join(sorted.map(func(x): return str(x)))
