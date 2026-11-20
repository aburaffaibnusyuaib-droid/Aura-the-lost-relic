extends CanvasLayer

# Ambil node UI tanpa terikat hirarki folder container
@onready var heart1: TextureRect = find_child("Heart1", true, false)
@onready var heart2: TextureRect = find_child("Heart2", true, false)
@onready var heart3: TextureRect = find_child("Heart3", true, false)
@onready var key_icon: TextureRect = find_child("KeyIcon", true, false)

const WARNA_KUNCI_KOSONG = Color(0.3, 0.3, 0.3, 0.35)
const WARNA_KUNCI_DAPAT = Color(1.0, 1.0, 1.0, 1.0)


func _ready() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		hubungkan_ke_player(player)
		var hp_awal: int = player.get("current_hp") if "current_hp" in player else 3
		var kunci_awal: bool = bool(player.get("has_key")) if "has_key" in player else false
		perbarui_hp(hp_awal)
		perbarui_status_kunci(kunci_awal)
	else:
		perbarui_hp(3)
		perbarui_status_kunci(false)


# Sambungkan sinyal pemain ke fungsi pembaruan UI
func hubungkan_ke_player(player: CharacterBody2D) -> void:
	if player.has_signal("hp_berubah") and not player.hp_berubah.is_connected(perbarui_hp):
		player.hp_berubah.connect(perbarui_hp)
	if player.has_signal("status_kunci_berubah") and not player.status_kunci_berubah.is_connected(perbarui_status_kunci):
		player.status_kunci_berubah.connect(perbarui_status_kunci)


# Sembunyikan ikon hati sesuai sisa darah
func perbarui_hp(sisa_hp: int) -> void:
	if heart1:
		heart1.visible = (sisa_hp >= 1)
	if heart2:
		heart2.visible = (sisa_hp >= 2)
	if heart3:
		heart3.visible = (sisa_hp >= 3)


# Ubah transparansi dan beri efek scale pop pada kunci
func perbarui_status_kunci(punya_kunci: bool) -> void:
	if not key_icon:
		return

	if punya_kunci:
		key_icon.modulate = WARNA_KUNCI_DAPAT
		key_icon.pivot_offset = key_icon.size * 0.5
		var tween := create_tween()
		tween.tween_property(key_icon, "scale", Vector2(1.25, 1.25), 0.1)
		tween.tween_property(key_icon, "scale", Vector2.ONE, 0.1)
	else:
		key_icon.modulate = WARNA_KUNCI_KOSONG
		key_icon.scale = Vector2.ONE
