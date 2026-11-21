@tool
extends Node2D

# Pengaturan intro transisi kamera dan spawn karakter di Level 1
@export_group("Kamera Masuk Level")
@export var ikuti_zoom_bawaan_kamera: bool = true
@export var zoom_normal_manual: Vector2 = Vector2(0.9, 0.9)
@export var pengali_zoom_masuk: float = 1.40
@export var durasi_zoom_keluar: float = 1.10
@export var efek_getar_mendarat: bool = true

@export_group("Transisi & Spawn Karakter")
@export var gunakan_spawn_point_awal: bool = true
@export var durasi_fade_layar: float = 0.50
@export var jeda_sebelum_jatuh: float = 0.35
@export var durasi_animasi_spawn: float = 0.80

@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var black_overlay: ColorRect = get_node_or_null("TransitionLayer/BlackOverlay")

var posisi_awal_kardus: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	simpan_posisi_semua_kardus()
	eksekusi_transisi_level1()


func simpan_posisi_semua_kardus() -> void:
	posisi_awal_kardus.clear()
	for anak in get_children():
		if anak is RigidBody2D or anak.name.to_lower().contains("kardus"):
			posisi_awal_kardus[anak] = anak.global_position


func eksekusi_transisi_level1() -> void:
	if not player:
		return

	# 1. Posisikan Rhein di SpawnPoint jika tersedia
	if gunakan_spawn_point_awal and spawn_point:
		player.global_position = spawn_point.global_position
		if "posisi_awal" in player:
			player.posisi_awal = spawn_point.global_position

	# 2. Kunci kendali pemain selama intro berlangsung
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	if "sedang_spawn" in player:
		player.sedang_spawn = true

	var anim: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")

	# 3. Tahan frame pertama spawn_drop selagi layar gelap membuka
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("spawn_drop"):
		anim.play("spawn_drop")
		anim.frame = 0
		anim.pause()

	# 4. Zoom-in kamera menyorot dekat ke Rhein
	var kamera := cari_kamera()
	var zoom_tujuan: Vector2 = zoom_normal_manual
	if kamera:
		if ikuti_zoom_bawaan_kamera:
			zoom_tujuan = kamera.zoom
		kamera.zoom = zoom_tujuan * pengali_zoom_masuk
		kamera.reset_smoothing()

	# 5. Pudarkan overlay hitam (fade-in)
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

	# 6. Jeda sebelum Rhein mulai turun
	await get_tree().create_timer(jeda_sebelum_jatuh).timeout
	if not is_inside_tree() or not is_instance_valid(player):
		return

	# 7. Zoom-out kamera kembali ke normal dan jalankan animasi jatuh
	if kamera:
		var tween_zoom := create_tween()
		tween_zoom.tween_property(kamera, "zoom", zoom_tujuan, durasi_zoom_keluar)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("spawn_drop"):
		anim.play("spawn_drop")
		await get_tree().create_timer(durasi_animasi_spawn).timeout
		if not is_inside_tree() or not is_instance_valid(player):
			return

	# 8. Sentakan kamera ringan saat mendarat
	if efek_getar_mendarat and kamera:
		getar_kamera_ringan(kamera, 4.0, 0.15)

	# 9. Kembalikan kontrol penuh kepada pemain
	if "sedang_spawn" in player:
		player.sedang_spawn = false
	player.set_physics_process(true)
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")


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


func cari_kamera() -> Camera2D:
	if player:
		var cam_player := player.get_node_or_null("Camera2D") as Camera2D
		if cam_player:
			return cam_player
	var cam_scene := get_node_or_null("Camera2D") as Camera2D
	if cam_scene:
		return cam_scene
	return get_viewport().get_camera_2d()


func _on_fall_zone_body_entered(body: Node2D) -> void:
	if posisi_awal_kardus.has(body):
		reset_kardus(body)
	elif body.name.to_lower().contains("kardus"):
		reset_kardus(body)


func reset_kardus(target_kardus: Node2D) -> void:
	if not is_instance_valid(target_kardus):
		return
	var pos_asal: Vector2 = posisi_awal_kardus.get(target_kardus, target_kardus.global_position)
	if target_kardus is RigidBody2D:
		target_kardus.set_deferred("freeze", true)
		target_kardus.linear_velocity = Vector2.ZERO
		target_kardus.angular_velocity = 0.0
		target_kardus.rotation = 0.0
		target_kardus.global_position = pos_asal
		target_kardus.set_deferred("freeze", false)
	else:
		target_kardus.rotation = 0.0
		target_kardus.global_position = pos_asal
