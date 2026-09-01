class_name CharacterStats
extends Resource

# ============================================================
# CharacterStats.gd
# Resource data statistik untuk karakter player dan musuh.
# Buat instance .tres baru di editor untuk tiap karakter/musuh.
# ============================================================

@export_group("Identity")
@export var character_name: String = "Unknown"
@export var character_sprite: Texture2D = null

@export_group("Base Stats")
## HP maksimal unit
@export var max_hp: int = 100
## Damage serangan fisik
@export var attack: int = 15
## Damage serangan magic
@export var magic_attack: int = 10
## Mengurangi damage fisik yang diterima
@export var defense: int = 5
## Mengurangi damage magic yang diterima
@export var magic_defense: int = 5
## Menentukan seberapa cepat ATB gauge terisi (1.0 = normal)
@export var speed: float = 1.0

@export_group("Battle")
## Daftar serangan yang dimiliki unit ini
@export var attacks: Array[Resource] = []
## Apakah ini musuh (false = player party)
@export var is_enemy: bool = false
## Lane yang ditempati (hanya untuk musuh). Array of int [1..5].
## Multi-lane: [2, 3] artinya menempati lane 2 dan 3.
@export var enemy_lanes: Array[int] = [1]
## Daftar serangan yang digunakan AI musuh (referensi ke AttackData)
@export var enemy_attack_pool: Array[Resource] = []
