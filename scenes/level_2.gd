extends Node2D

# Pengaturan animasi kamera saat baru masuk ke Level 2
@export_group("Kamera Masuk Level")
# Otomatis mengikuti skala zoom bawaan Camera2D milik Player
@export var ikuti_zoom_bawaan_kamera: bool = true
@export var zoom_normal_manual: Vector2 = Vector2(1.0, 1.0)
# Skala pembesaran awal kamera saat Rhein baru turun dari portal (1.42 = 42% lebih dekat)
@export var pengali_zoom_masuk: float = 1.42
@export var durasi_zoom_keluar: float = 1.10
@export var efek_getar_mendarat: bool = true

# Pengaturan transisi layar gelap dan animasi spawn_drop Rhein
@export_group("Transisi & Spawn Karakter")
@export var gunakan_spawn_point_awal: bool = true
@export var durasi_fade_layar: float = 0.50
@export var jeda_sebelum_jatuh: float = 0.35
@export var durasi_animasi_spawn: float = 0.80

@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var kardus: RigidBody2D = get_node_or_null("Kardus")
@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var black_overlay: ColorRect = get_node_or_null("TransitionLayer/BlackOverlay")

# Menyimpan posisi awal seluruh kardus di Level 2 untuk sistem anti-stuck jurang
var posisi_awal_kardus: Dictionary = {}


# Inisialisasi awal saat scene Level 2 dimulai
func _ready() -> void:
	simpan_posisi_semua_kardus()
	eksekusi_transisi_level2()


# Mencatat koordinat awal objek Kardus (mendukung satu maupun banyak kardus)
func simpan_posisi_semua_kardus() -> void:
	posisi_awal_kardus.clear()
	if kardus:
		posisi_awal_kardus[kardus] = kardus.global_position

	for anak in get_children():
		if anak is RigidBody2D or anak.name.to_lower().contains("kardus"):
			if not posisi_awal_kardus.has(anak):
				posisi_awal_kardus[anak] = anak.global_position


# Menjalankan koreografi pembuka Level 2: fade layar, zoom kamera, animasi spawn_drop, dan efek mendarat
func eksekusi_transisi_level2() -> void:
	if not player:
		return

	# 1. Tempatkan Rhein di SpawnPoint saat awal masuk level jika tersedia
	if gunakan_spawn_point_awal and spawn_point:
		player.global_position = spawn_point.global_position
		if "posisi_awal" in player:
			player.posisi_awal = spawn_point.global_position

	# 2. Kunci input kontrol agar physics_process tidak menimpa animasi spawn_drop ke idle
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	if "sedang_spawn" in player:
		player.sedang_spawn = true

	var anim: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")

	# 3. Pasang frame pertama spawn_drop dan tahan selagi layar gelap membuka
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("spawn_drop"):
		anim.play("spawn_drop")
		anim.frame = 0
		anim.pause()

	# 4. Atur kamera menyorot dekat (zoom-in) ke arah Rhein sejak frame pertama
	var kamera := cari_kamera()
	var zoom_tujuan: Vector2 = zoom_normal_manual
	if kamera:
		if ikuti_zoom_bawaan_kamera:
			zoom_tujuan = kamera.zoom
		kamera.zoom = zoom_tujuan * pengali_zoom_masuk
		kamera.reset_smoothing()

	# 5. Pudarkan layar gelap TransitionLayer/BlackOverlay secara halus (fade-in)
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

	# 6. Tunggu sejenak hingga layar portal terbuka terang di depan mata pemain
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

	# 8. Berikan sentakan kamera ringan saat Rhein mendarat untuk menambah kesan bobot
	if efek_getar_mendarat and kamera:
		getar_kamera_ringan(kamera, 4.5, 0.16)

	# 9. Kembalikan kendali penuh kepada pemain dan ubah pose ke idle
	if "sedang_spawn" in player:
		player.sedang_spawn = false
	player.set_physics_process(true)
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")


# Efek getar mikro pada kamera saat mendarat tanpa mengubah posisi permanen kamera
func getar_kamera_ringan(kamera: Camera2D, kekuatan: float, durasi: float) -> void:
	if not is_instance_valid(kamera):
		return
	var offset_asal: Vector2 = kamera.offset
	var tween_getar := create_tween()
	var jumlah_langkah: int = 4
	var jeda_langkah: float = durasi / float(jumlah_langkah)

	for i in range(jumlah_langkah):
		var faktor: float = 1.0 - (float(i) / float(jumlah_langkah))
		var geser := Vector2(
			randf_range(-kekuatan, kekuatan) * faktor,
			randf_range(-kekuatan, kekuatan) * faktor
		)
		tween_getar.tween_property(kamera, "offset", offset_asal + geser, jeda_langkah)

	tween_getar.tween_property(kamera, "offset", offset_asal, 0.04)


# Mencari node Camera2D aktif baik di dalam Player maupun langsung di scene Level 2
func cari_kamera() -> Camera2D:
	if player:
		var cam_player := player.get_node_or_null("Camera2D") as Camera2D
		if cam_player:
			return cam_player
	var cam_scene := get_node_or_null("Camera2D") as Camera2D
	if cam_scene:
		return cam_scene
	return get_viewport().get_camera_2d()


# Sinyal FallZone untuk mereset kardus jika terdorong ke jurang
func _on_fall_zone_body_entered(body: Node2D) -> void:
	if posisi_awal_kardus.has(body):
		reset_kardus(body)
	elif body == kardus or body.name.to_lower().contains("kardus"):
		reset_kardus(body)


# Mengembalikan posisi, rotasi, dan kecepatan fisik kardus dengan animasi muncul halus
func reset_kardus(target_kardus: Node2D = null) -> void:
	var objek: Node2D = target_kardus if target_kardus != null else kardus
	if not is_instance_valid(objek):
		return

	var pos_asal: Vector2 = posisi_awal_kardus.get(objek, objek.global_position)

	if objek is RigidBody2D:
		objek.set_deferred("freeze", true)
		objek.linear_velocity = Vector2.ZERO
		objek.angular_velocity = 0.0
		objek.rotation = 0.0
		objek.global_position = pos_asal
		objek.set_deferred("freeze", false)
	else:
		objek.rotation = 0.0
		objek.global_position = pos_asal

	# Efek muncul halus agar respawn kardus terlihat rapi
	objek.modulate.a = 0.0
	var tween_kardus := create_tween()
	tween_kardus.tween_property(objek, "modulate:a", 1.0, 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Teruskan sinyal masuk area tangga dari Level 2 ke script Player
func masuk_area_tangga(body: Node2D) -> void:
	if player and body == player and player.has_method("masuk_area_tangga"):
		player.masuk_area_tangga(body)


# Teruskan sinyal keluar area tangga dari Level 2 ke script Player
func keluar_area_tangga(body: Node2D) -> void:
	if player and body == player and player.has_method("keluar_area_tangga"):
		player.keluar_area_tangga(body)
