extends Node2D

# Pengaturan animasi kamera saat baru masuk ke Level 3
@export_group("Kamera Masuk Level")
# Otomatis memakai ukuran zoom bawaan Camera2D milik Player agar konsisten dengan Level 1 & 2
@export var ikuti_zoom_bawaan_kamera: bool = true
@export var zoom_normal_manual: Vector2 = Vector2(1.0, 1.0)
# Seberapa dekat kamera menyorot Rhein saat baru muncul (1.45 = 45% lebih dekat)
@export var pengali_zoom_masuk: float = 1.45
@export var durasi_zoom_keluar: float = 1.15

# Pengaturan durasi transisi layar dan animasi spawn_drop Rhein
@export_group("Transisi & Spawn Karakter")
@export var durasi_fade_layar: float = 0.45
@export var jeda_sebelum_jatuh: float = 0.35
@export var durasi_animasi_spawn: float = 0.85

@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var black_overlay: ColorRect = get_node_or_null("TransitionLayer/BlackOverlay")

# Menyimpan posisi awal seluruh kardus di Level 3 untuk sistem reset jika jatuh ke jurang
var posisi_awal_kardus: Dictionary = {}


# Inisialisasi awal saat scene Level 3 dimuat
func _ready() -> void:
	simpan_posisi_semua_kardus()
	eksekusi_transisi_level3()


# Mencatat posisi awal semua objek Kardus (RigidBody2D) yang ada di Level 3
func simpan_posisi_semua_kardus() -> void:
	posisi_awal_kardus.clear()
	for anak in get_children():
		if anak is RigidBody2D or anak.name.to_lower().contains("kardus"):
			posisi_awal_kardus[anak] = anak.global_position


# Menjalankan koreografi pembuka Level 3: fade layar, zoom kamera, dan animasi spawn_drop
func eksekusi_transisi_level3() -> void:
	if not player:
		return

	# 1. Tempatkan Rhein di SpawnPoint jika node SpawnPoint dipasang di Level 3
	if spawn_point:
		player.global_position = spawn_point.global_position
		if "posisi_awal" in player:
			player.posisi_awal = spawn_point.global_position

	# 2. Kunci input kontrol pemain agar physics_process tidak menimpa animasi ke idle
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	if "sedang_spawn" in player:
		player.sedang_spawn = true

	var anim: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")

	# 3. Pasang frame pertama spawn_drop dan tahan selagi layar hitam baru membuka
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("spawn_drop"):
		anim.play("spawn_drop")
		anim.frame = 0
		anim.pause()

	# 4. Atur kamera langsung menyorot dekat (zoom-in) ke arah Rhein tanpa geser lambat
	var kamera := cari_kamera()
	var zoom_tujuan: Vector2 = zoom_normal_manual
	if kamera:
		if ikuti_zoom_bawaan_kamera:
			zoom_tujuan = kamera.zoom
		kamera.zoom = zoom_tujuan * pengali_zoom_masuk
		kamera.reset_smoothing()

	# 5. Jalankan efek fade-in dari layar gelap (TransitionLayer/BlackOverlay)
	if black_overlay:
		black_overlay.visible = true
		black_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		black_overlay.modulate.a = 1.0
		var tween_layar := create_tween()
		tween_layar.tween_property(black_overlay, "modulate:a", 0.0, durasi_fade_layar)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween_layar.finished.connect(func():
			if is_instance_valid(black_overlay):
				black_overlay.visible = false
		)

	# 6. Tunggu sebentar sampai layar hitam terbuka terang di depan pemain
	await get_tree().create_timer(jeda_sebelum_jatuh).timeout
	if not is_inside_tree() or not is_instance_valid(player):
		return

	# 7. Putar animasi spawn_drop penuh bersamaan dengan kamera zoom-out halus ke jarak normal
	if kamera:
		var tween_zoom := create_tween()
		tween_zoom.tween_property(kamera, "zoom", zoom_tujuan, durasi_zoom_keluar)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("spawn_drop"):
		anim.play("spawn_drop")
		await get_tree().create_timer(durasi_animasi_spawn).timeout
		if not is_inside_tree() or not is_instance_valid(player):
			return

	# 8. Kembalikan kendali penuh kepada pemain dan ubah pose ke idle
	if "sedang_spawn" in player:
		player.sedang_spawn = false
	player.set_physics_process(true)
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")


# Mencari node Camera2D aktif baik di dalam Player maupun langsung di scene Level 3
func cari_kamera() -> Camera2D:
	if player:
		var cam_player := player.get_node_or_null("Camera2D") as Camera2D
		if cam_player:
			return cam_player
	var cam_scene := get_node_or_null("Camera2D") as Camera2D
	if cam_scene:
		return cam_scene
	return get_viewport().get_camera_2d()


# Sinyal FallZone untuk mengembalikan kardus ke posisi awal jika terdorong ke jurang
func _on_fall_zone_body_entered(body: Node2D) -> void:
	if posisi_awal_kardus.has(body):
		reset_kardus(body)
	elif body.name.to_lower().contains("kardus"):
		reset_kardus(body)


# Mengembalikan posisi dan kecepatan fisik kardus ke titik awalnya
func reset_kardus(target_kardus: Node2D) -> void:
	if not is_instance_valid(target_kardus):
		return
	var pos_asal: Vector2 = posisi_awal_kardus.get(target_kardus, target_kardus.global_position)
	if target_kardus is RigidBody2D:
		target_kardus.set_deferred("freeze", true)
		target_kardus.linear_velocity = Vector2.ZERO
		target_kardus.angular_velocity = 0.0
		target_kardus.global_position = pos_asal
		target_kardus.set_deferred("freeze", false)
	else:
		target_kardus.global_position = pos_asal


# Teruskan sinyal masuk area tangga dari Level 3 ke script Player
func masuk_area_tangga(body: Node2D) -> void:
	if player and body == player and player.has_method("masuk_area_tangga"):
		player.masuk_area_tangga(body)


# Teruskan sinyal keluar area tangga dari Level 3 ke script Player
func keluar_area_tangga(body: Node2D) -> void:
	if player and body == player and player.has_method("keluar_area_tangga"):
		player.keluar_area_tangga(body)
