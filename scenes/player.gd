extends CharacterBody2D

# Sinyal komunikasi ke UI (HUD) dan sistem transisi portal
signal hp_berubah(sisa_hp: int)
signal status_kunci_berubah(punya_kunci: bool)
signal selesai_masuk_portal

# Preload scene proyektil tembakan aura
const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")

# Pengaturan pergerakan dasar karakter
@export_group("Pergerakan")
@export var kecepatan_jalan: float = 320.0
@export var kekuatan_lompat: float = -650.0
@export var kecepatan_panjat: float = 180.0
@export var kekuatan_dorong: float = 140.0

# Pengaturan mekanik seluncuran es
@export_group("Seluncuran Es")
@export var kecepatan_luncur: float = 480.0
@export var kekuatan_lompat_luncur: float = -650.0
@export var kemiringan_luncur_derajat: float = 28.0
@export var offset_animasi_luncur: Vector2 = Vector2(0.0, 4.0)

# Pengaturan posisi pegangan tangan saat gelayutan di tali
@export_group("Gelayutan Tali")
@export var offset_tangan_tali: Vector2 = Vector2(0.0, -28.0)

# Pengaturan status nyawa, jeda tembak, dan kepemilikan kunci
@export_group("Status & Senjata")
@export var max_hp: int = 3
@export var jeda_tembak: float = 0.40
@export var koreksi_tinggi_attack: float = 14.0
@export var has_key: bool = false

# Variabel status nyawa dan gravitasi dunia
var current_hp: int = 3
var gravitasi: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Variabel status interaksi tangga dan dorong objek
var di_area_tangga: bool = false
var sedang_memanjat: bool = false
var sedang_mendorong: bool = false

# Variabel status zona seluncuran es
var jumlah_zona_luncur: int = 0
var sedang_meluncur: bool = false
var arah_luncur_aktif: float = 1.0

# Variabel status damage, serangan, dan animasi spawn awal
var sedang_kena_damage: bool = false
var sedang_menyerang: bool = false
var bisa_nembak: bool = true
var sedang_spawn: bool = false

# Variabel status gelayutan pada tali ayun
var sedang_gelayutan: bool = false
var tali_aktif: Node2D = null
var cooldown_tali: float = 0.0

# Variabel arah hadap, titik respawn, dan layer tabrakan lantai
var arah_hadap: float = 1.0
var posisi_awal: Vector2
var mask_lantai_awal: int = 1

# Referensi node sprite animasi utama karakter
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


# Inisialisasi awal saat karakter masuk ke dalam scene
func _ready() -> void:
	add_to_group("Player")
	mask_lantai_awal = collision_mask

	# Daftarkan tombol tembak (J dan F) secara otomatis jika belum diatur di InputMap
	if not InputMap.has_action("tembak"):
		InputMap.add_action("tembak")
		var key_j = InputEventKey.new()
		key_j.physical_keycode = KEY_J
		InputMap.action_add_event("tembak", key_j)

		var key_f = InputEventKey.new()
		key_f.physical_keycode = KEY_F
		InputMap.action_add_event("tembak", key_f)

	# Konfigurasi fisik dan kemiringan lantai untuk CharacterBody2D
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	floor_max_angle = deg_to_rad(65.0)
	floor_constant_speed = true
	floor_snap_length = 18.0

	# Simpan posisi awal sebagai titik respawn dan isi penuh HP
	posisi_awal = global_position
	current_hp = max_hp

	# Atur mode pengulangan (loop) untuk setiap animasi yang tersedia
	if anim and anim.sprite_frames:
		anim.sprite_frames.set_animation_loop("idle", true)
		anim.sprite_frames.set_animation_loop("move", true)
		anim.sprite_frames.set_animation_loop("push", true)
		anim.sprite_frames.set_animation_loop("climb", true)
		anim.sprite_frames.set_animation_loop("fall", true)
		anim.sprite_frames.set_animation_loop("jump", false)
		anim.sprite_frames.set_animation_loop("hurt", false)
		if anim.sprite_frames.has_animation("seluncur"):
			anim.sprite_frames.set_animation_loop("seluncur", true)
		if anim.sprite_frames.has_animation("slide"):
			anim.sprite_frames.set_animation_loop("slide", true)
		if anim.sprite_frames.has_animation("swing"):
			anim.sprite_frames.set_animation_loop("swing", true)
		if anim.sprite_frames.has_animation("attack"):
			anim.sprite_frames.set_animation_loop("attack", false)
		if anim.sprite_frames.has_animation("sucked"):
			anim.sprite_frames.set_animation_loop("sucked", false)
		if anim.sprite_frames.has_animation("spawn_drop"):
			anim.sprite_frames.set_animation_loop("spawn_drop", false)

	if anim:
		anim.play("idle")

	# Kirim status awal nyawa dan kunci ke tampilan HUD
	hp_berubah.emit(current_hp)
	status_kunci_berubah.emit(has_key)


# Loop utama pemrosesan fisik dan kontrol karakter setiap frame
func _physics_process(delta: float) -> void:
	# Kurangi waktu jeda sebelum karakter boleh menangkap tali kembali
	if cooldown_tali > 0.0:
		cooldown_tali -= delta

	# Kunci kontrol pemain saat animasi jatuh dari portal awal (spawn_drop) sedang berjalan
	if sedang_spawn:
		if not is_on_floor():
			velocity.y += gravitasi * delta
		else:
			velocity.x = 0.0
		move_and_slide()
		return

	# Kunci kontrol pemain saat karakter sedang terpental karena terkena damage
	if sedang_kena_damage:
		atur_tabrakan_lantai(true)
		velocity.y += gravitasi * delta
		move_and_slide()
		return

	# 1. Mekanik gelayutan pada tali ayun
	if sedang_gelayutan:
		atur_tabrakan_lantai(true)
		if not is_instance_valid(tali_aktif):
			lepas_tali(false)
		else:
			velocity = Vector2.ZERO
			var titik_pegang: Vector2 = tali_aktif.get_posisi_pegangan() if tali_aktif.has_method("get_posisi_pegangan") else tali_aktif.global_position
			var selisih_sprite: Vector2 = (anim.global_position - global_position) if anim else Vector2.ZERO
			global_position = titik_pegang - selisih_sprite - offset_tangan_tali

			# Sesuaikan kemiringan tubuh karakter mengikuti lengkungan ujung tali
			if anim:
				anim.offset = Vector2.ZERO
				if tali_aktif.has_method("get_sudut_ujung"):
					anim.rotation = tali_aktif.get_sudut_ujung() * 0.75
				else:
					anim.rotation = tali_aktif.rotation * 0.75

			# Baca input kiri/kanan untuk memompa ayunan tali
			var input_ayun := Input.get_axis("jalan_kiri", "jalan_kanan")
			if input_ayun < 0:
				arah_hadap = -1.0
				if anim:
					anim.flip_h = true
			elif input_ayun > 0:
				arah_hadap = 1.0
				if anim:
					anim.flip_h = false

			if tali_aktif.has_method("beri_dorongan"):
				tali_aktif.beri_dorongan(input_ayun, delta)

			ganti_animasi("swing")

			# Tekan tombol lompat untuk melepaskan tali dan melontar ke depan
			if Input.is_action_just_pressed("jump"):
				lepas_tali(true)
			return

	# Baca input pergerakan horizontal dan vertikal pemain
	var arah_x := Input.get_axis("jalan_kiri", "jalan_kanan")
	var arah_y := Input.get_axis("leader_up", "leader_down")

	# 2. Mekanik memanjat tangga (dapat menembus pijakan atas tanpa One-Way Collision)
	if di_area_tangga and arah_y != 0.0 and not sedang_meluncur:
		sedang_memanjat = true

	if sedang_memanjat:
		if not di_area_tangga:
			sedang_memanjat = false
			atur_tabrakan_lantai(true)
		elif Input.is_action_just_pressed("jump"):
			sedang_memanjat = false
			atur_tabrakan_lantai(true)
			velocity.y = kekuatan_lompat
		else:
			# Matikan tabrakan lantai sementara saat memanjat naik agar tembus ke pijakan atas
			if arah_y < 0.0:
				atur_tabrakan_lantai(false)
			# Cek ruang kosong di bawah saat turun tangga agar bisa menembus pijakan atas ke bawah
			elif arah_y > 0.0:
				atur_tabrakan_lantai(true)
				var ruang_kosong_di_bawah := not test_move(global_transform.translated(Vector2(0.0, 56.0)), Vector2.ZERO)
				if ruang_kosong_di_bawah:
					atur_tabrakan_lantai(false)
				elif is_on_floor():
					sedang_memanjat = false
					atur_tabrakan_lantai(true)
					move_and_slide()
					return

			velocity.y = arah_y * kecepatan_panjat
			velocity.x = arah_x * (kecepatan_jalan * 0.5)

			ganti_animasi("climb")
			if anim:
				anim.offset = Vector2.ZERO
				if arah_y != 0.0 or arah_x != 0.0:
					anim.play()
				else:
					anim.pause()

			move_and_slide()
			return
	else:
		atur_tabrakan_lantai(true)

	# 3. Mekanik meluncur otomatis saat berada di zona seluncuran es
	sedang_meluncur = (jumlah_zona_luncur > 0 and (is_on_floor() or velocity.y >= -20.0))

	if sedang_meluncur:
		sedang_mendorong = false
		sedang_menyerang = false
		arah_hadap = arah_luncur_aktif

		if anim:
			anim.flip_h = (arah_hadap < 0)
			anim.offset = offset_animasi_luncur
			anim.rotation = lerp_angle(anim.rotation, deg_to_rad(kemiringan_luncur_derajat) * arah_luncur_aktif, delta * 16.0)

		mainkan_animasi_seluncur()

		var kontrol_halus := arah_x * 80.0
		velocity.x = (arah_luncur_aktif * kecepatan_luncur) + kontrol_halus
		velocity.y += gravitasi * delta

		# Melompat saat sedang meluncur untuk keluar dari seluncuran
		if Input.is_action_just_pressed("jump"):
			sedang_meluncur = false
			jumlah_zona_luncur = 0
			if anim:
				anim.rotation = 0.0
				anim.offset = Vector2.ZERO
			velocity.y = kekuatan_lompat_luncur
			velocity.x = arah_luncur_aktif * (kecepatan_luncur * 0.92)
			ganti_animasi("jump")
			move_and_slide()
			return

		move_and_slide()
		return
	else:
		if anim and not sedang_gelayutan:
			anim.rotation = lerp_angle(anim.rotation, 0.0, delta * 18.0)
			if not sedang_menyerang:
				anim.offset = Vector2.ZERO

	# 4. Pergerakan normal berjalan, melompat, dan menembak
	if arah_x < 0:
		arah_hadap = -1.0
		if not sedang_menyerang and anim:
			anim.flip_h = true
	elif arah_x > 0:
		arah_hadap = 1.0
		if not sedang_menyerang and anim:
			anim.flip_h = false

	if Input.is_action_just_pressed("tembak") and bisa_nembak and not sedang_memanjat:
		eksekusi_tembakan()

	if not is_on_floor():
		velocity.y += gravitasi * delta

	velocity.x = arah_x * kecepatan_jalan

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = kekuatan_lompat

	move_and_slide()

	# Deteksi dorongan terhadap objek fisik seperti kardus (RigidBody2D)
	sedang_mendorong = false
	for i in get_slide_collision_count():
		var tabrakan := get_slide_collision(i)
		var objek := tabrakan.get_collider()

		if objek is RigidBody2D:
			if absf(tabrakan.get_normal().x) > 0.5:
				sedang_mendorong = true
				objek.linear_velocity.x = arah_x * kekuatan_dorong

	update_animasi(arah_x)


# Mengatur aktif atau tidaknya tabrakan lantai agar karakter tidak nyangkut di dalam tile saat memanjat
func atur_tabrakan_lantai(aktif: bool) -> void:
	if aktif:
		if collision_mask == 0 and test_move(global_transform, Vector2.ZERO):
			return
		collision_mask = mask_lantai_awal
	else:
		collision_mask = 0


# Memainkan animasi seluncuran sesuai nama animasi yang tersedia
func mainkan_animasi_seluncur() -> void:
	if not anim or not anim.sprite_frames:
		return
	if anim.sprite_frames.has_animation("seluncur"):
		ganti_animasi("seluncur")
	elif anim.sprite_frames.has_animation("slide"):
		ganti_animasi("slide")
	else:
		ganti_animasi("fall")


# Kode masuk area seluncuran es
func masuk_zona_luncur(arah: float = 1.0) -> void:
	jumlah_zona_luncur += 1
	arah_luncur_aktif = signf(arah) if arah != 0.0 else 1.0
	sedang_meluncur = true
	sedang_mendorong = false
	arah_hadap = arah_luncur_aktif
	if anim:
		anim.flip_h = (arah_hadap < 0)
		anim.offset = offset_animasi_luncur
	mainkan_animasi_seluncur()


# Kode keluar area seluncuran es
func keluar_zona_luncur() -> void:
	jumlah_zona_luncur = maxi(jumlah_zona_luncur - 1, 0)
	if jumlah_zona_luncur == 0:
		sedang_meluncur = false
		if anim and not sedang_menyerang:
			anim.offset = Vector2.ZERO


# Kode menangkap tali ayun saat menyentuh area tali
func tangkap_tali(tali: Node2D) -> void:
	if not is_instance_valid(tali):
		return
	if sedang_gelayutan or cooldown_tali > 0.0 or sedang_kena_damage or sedang_spawn:
		return

	var kecepatan_masuk_x := velocity.x
	sedang_gelayutan = true
	sedang_meluncur = false
	jumlah_zona_luncur = 0
	sedang_memanjat = false
	sedang_mendorong = false
	atur_tabrakan_lantai(true)
	tali_aktif = tali

	if "pemain_menempel" in tali:
		tali.pemain_menempel = self

	if tali.has_method("mulai_ayunan_dari_lompatan"):
		tali.mulai_ayunan_dari_lompatan(kecepatan_masuk_x, arah_hadap)

	velocity = Vector2.ZERO
	ganti_animasi("swing")


# Kode melepas genggaman tali dan melontarkan karakter
func lepas_tali(dengan_lompatan: bool = true) -> void:
	if not sedang_gelayutan:
		return

	var lontaran := Vector2.ZERO
	if is_instance_valid(tali_aktif):
		if dengan_lompatan and tali_aktif.has_method("get_kecepatan_lontar"):
			lontaran = tali_aktif.get_kecepatan_lontar()
		if "pemain_menempel" in tali_aktif:
			tali_aktif.pemain_menempel = null

	sedang_gelayutan = false
	tali_aktif = null
	cooldown_tali = 0.35

	if anim:
		anim.rotation = 0.0
		anim.offset = Vector2.ZERO

	if dengan_lompatan:
		velocity = lontaran
		ganti_animasi("jump")


# Memainkan animasi jatuh dari portal saat awal masuk level
func mainkan_spawn_drop(durasi: float = 1.0) -> void:
	sedang_spawn = true
	velocity = Vector2.ZERO
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("spawn_drop"):
		anim.play("spawn_drop")
	await get_tree().create_timer(durasi).timeout
	if not is_inside_tree():
		return
	sedang_spawn = false
	ganti_animasi("idle")


# Menjalankan animasi serangan dan memunculkan proyektil peluru aura
func eksekusi_tembakan() -> void:
	bisa_nembak = false
	sedang_menyerang = true

	if anim:
		anim.flip_h = (arah_hadap < 0)
		anim.offset.y = koreksi_tinggi_attack
	ganti_animasi("attack")

	var peluru = PROJECTILE_SCENE.instantiate()
	peluru.atur_arah(arah_hadap)

	var anim_pos := anim.position if anim else Vector2.ZERO
	var spawn_x: float = global_position.x + anim_pos.x + (45.0 * arah_hadap)
	var spawn_y: float = global_position.y + anim_pos.y - 12.0
	peluru.global_position = Vector2(spawn_x, spawn_y)
	get_parent().add_child(peluru)

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("attack"):
		await anim.animation_finished
	else:
		await get_tree().create_timer(0.3).timeout

	if not is_inside_tree():
		return

	if anim:
		anim.offset.y = 0.0
	sedang_menyerang = false

	await get_tree().create_timer(jeda_tembak).timeout
	if is_inside_tree():
		bisa_nembak = true


# Mengatur pergantian animasi karakter sesuai kondisi gerak
func update_animasi(arah_x: float) -> void:
	if sedang_menyerang or sedang_kena_damage or sedang_spawn or sedang_gelayutan:
		return

	if sedang_meluncur:
		mainkan_animasi_seluncur()
		return

	if anim:
		anim.offset = Vector2.ZERO

	if not is_on_floor():
		if velocity.y < 0:
			ganti_animasi("jump")
		else:
			ganti_animasi("fall")
	else:
		if sedang_mendorong and arah_x != 0:
			ganti_animasi("push")
		elif arah_x != 0:
			ganti_animasi("move")
		else:
			ganti_animasi("idle")


# Memutar animasi tertentu jika animasi tersebut belum sedang diputar
func ganti_animasi(nama: String) -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(nama) and anim.animation != nama:
		anim.play(nama)


# Memberikan pantulan ke atas setelah karakter menginjak kepala musuh
func pantulkan(kekuatan: float = 340.0) -> void:
	velocity.y = -kekuatan


# Mengurangi HP karakter dan memberikan efek knockback saat menerima damage
func terima_damage(jumlah: int = 1, arah_serang: Vector2 = Vector2.ZERO) -> void:
	if sedang_kena_damage:
		return

	if sedang_gelayutan:
		lepas_tali(false)

	sedang_memanjat = false
	atur_tabrakan_lantai(true)
	sedang_meluncur = false
	jumlah_zona_luncur = 0
	current_hp -= jumlah
	hp_berubah.emit(current_hp)

	if current_hp <= 0:
		respawn()
		return

	sedang_kena_damage = true
	if anim:
		anim.rotation = 0.0
		anim.offset = Vector2.ZERO
	ganti_animasi("hurt")

	var arah_knockback = -arah_hadap
	if arah_serang != Vector2.ZERO:
		arah_knockback = signf(global_position.x - arah_serang.x)

	velocity = Vector2(arah_knockback * 160.0, -260.0)

	if anim:
		var tween = create_tween()
		tween.tween_property(anim, "modulate:a", 0.3, 0.1)
		tween.tween_property(anim, "modulate:a", 1.0, 0.1)

	await get_tree().create_timer(0.4).timeout
	if is_inside_tree():
		sedang_kena_damage = false


# Menandai bahwa karakter telah mengambil kunci level
func ambil_kunci() -> void:
	has_key = true
	status_kunci_berubah.emit(true)


# Mengembalikan karakter ke titik awal dan mereset seluruh status
func respawn() -> void:
	if sedang_gelayutan:
		lepas_tali(false)

	velocity = Vector2.ZERO
	global_position = posisi_awal
	current_hp = max_hp
	sedang_meluncur = false
	jumlah_zona_luncur = 0
	sedang_memanjat = false
	sedang_kena_damage = false
	sedang_menyerang = false
	sedang_spawn = false
	cooldown_tali = 0.0
	collision_mask = mask_lantai_awal

	if anim:
		anim.rotation = 0.0
		anim.offset = Vector2.ZERO
	ganti_animasi("idle")

	hp_berubah.emit(current_hp)
	status_kunci_berubah.emit(has_key)


# Animasi karakter tersedot masuk ke dalam portal akhir level
func masuk_portal(posisi_tengah_portal: Vector2) -> void:
	if sedang_gelayutan:
		lepas_tali(false)

	sedang_memanjat = false
	collision_mask = mask_lantai_awal
	sedang_meluncur = false
	jumlah_zona_luncur = 0
	set_physics_process(false)
	velocity = Vector2.ZERO
	sedang_menyerang = false
	sedang_kena_damage = false
	sedang_spawn = false
	bisa_nembak = false

	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

	if anim:
		anim.rotation = 0.0
		anim.offset = Vector2.ZERO
		if anim.sprite_frames and anim.sprite_frames.has_animation("sucked"):
			anim.play("sucked")

	var durasi: float = 0.85
	var tween = create_tween().set_parallel(true)

	tween.tween_property(self, "global_position", posisi_tengah_portal, durasi)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, durasi)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished
	visible = false
	selesai_masuk_portal.emit()


# Kode jatuh ke jurang
func kena_jurang(body: Node2D) -> void:
	if body == self:
		respawn()


# Kode terkena duri
func kena_duri(body: Node2D) -> void:
	if body == self:
		terima_damage(1)


# Kode masuk area tangga
func masuk_area_tangga(body: Node2D) -> void:
	if body == self:
		di_area_tangga = true


# Kode keluar area tangga
func keluar_area_tangga(body: Node2D) -> void:
	if body == self:
		di_area_tangga = false
		sedang_memanjat = false
		atur_tabrakan_lantai(true)


# Sinyal otomatis saat karakter menyentuh FallZone
func _on_fall_zone_body_entered(body: Node2D) -> void:
	if body == self or body.name == "Player" or body.is_in_group("Player"):
		if body.has_method("respawn"):
			body.respawn()
		elif has_node("SpawnPoint"):
			body.velocity = Vector2.ZERO
			body.global_position = $SpawnPoint.global_position


# Sinyal otomatis saat karakter menyentuh area Spike
func _on_spike_body_entered(body: Node2D) -> void:
	kena_duri(body)
