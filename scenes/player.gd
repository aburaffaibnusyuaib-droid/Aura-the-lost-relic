@tool
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
var daftar_tangga: Array[Area2D] = []
var tangga_aktif: Area2D = null
var mask_normal: int = 1
var sedang_di_duri: bool = false
var timer_damage_duri: float = 0.0
var terjebak_duri: bool:
	get: return sedang_di_duri
	set(val): sedang_di_duri = val
var duri_aktif: Area2D = null

# Variabel status zona seluncuran es
var jumlah_zona_luncur: int = 0
var sedang_meluncur: bool = false
var arah_luncur_aktif: float = 1.0

# Variabel status damage, serangan, dan animasi spawn awal
var sedang_kena_damage: bool = false
var sedang_kebal: bool = false
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
	mask_normal = collision_mask
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
	if Engine.is_editor_hint():
		return
	if not InputMap.has_action("jalan_kanan"):
		return
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

	# Kunci kontrol saat pemain terkena jebakan duri (Spike trap: no jump, no horizontal, no bounce)
	if sedang_di_duri:
		velocity.x = 0.0
		velocity.y = maxf(velocity.y, 0.0)
		if not is_on_floor():
			velocity.y += gravitasi * delta
		move_and_slide()

		if current_hp > 0:
			timer_damage_duri += delta
			if timer_damage_duri >= 0.45:
				timer_damage_duri = 0.0
				terima_damage_duri(1)
		return

	# Kunci kontrol pemain saat karakter sedang terpental karena terkena damage normal
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

	# Bersihkan daftar tangga dari node yang sudah tidak valid
	var valid_tangga: Array[Area2D] = []
	for t in daftar_tangga:
		if is_instance_valid(t):
			valid_tangga.append(t)
	daftar_tangga = valid_tangga
	di_area_tangga = (daftar_tangga.size() > 0)
	tangga_aktif = daftar_tangga[0] if di_area_tangga else null

	# Baca input pergerakan horizontal dan vertikal pemain
	var arah_x := Input.get_axis("jalan_kiri", "jalan_kanan")
	var arah_y := Input.get_axis("leader_up", "leader_down")

	# 2. Mekanik memanjat tangga custom (anti-nyangkut di tanah, blokir total jump, mulus naik/turun)
	var posisi_kaki: float = global_position.y + 186.0
	var center_x_tangga: float = global_position.x
	var t_atas: float = INF
	var t_bawah: float = -INF
	var batas_platform_atas: float = INF

	if tangga_aktif:
		center_x_tangga = tangga_aktif.get_center_x() if tangga_aktif.has_method("get_center_x") else tangga_aktif.global_position.x
		t_atas = tangga_aktif.get_batas_atas() if tangga_aktif.has_method("get_batas_atas") else (tangga_aktif.global_position.y - 64.0)
		t_bawah = tangga_aktif.get_batas_bawah() if tangga_aktif.has_method("get_batas_bawah") else (tangga_aktif.global_position.y + 64.0)
		batas_platform_atas = t_atas + 24.0

	# Clean Entry: Hanya masuk memanjat jika berada di area tangga
	if di_area_tangga and not sedang_memanjat and not terjebak_duri and not sedang_meluncur and not sedang_spawn and not sedang_kena_damage and not sedang_gelayutan:
		if is_on_floor():
			# Masuk dari platform atas tangga dengan menekan tombol bawah (S)
			if arah_y > 0.0:
				if absf(posisi_kaki - batas_platform_atas) <= 32.0 or posisi_kaki < t_bawah - 40.0:
					sedang_memanjat = true
					global_position.y += 6.0
					collision_mask = mask_normal & ~1
					velocity = Vector2.ZERO
			elif arah_y < 0.0:
				# Berdiri di dasar tangga dan menekan tombol atas (W)
				sedang_memanjat = true
				collision_mask = mask_normal & ~1
				velocity = Vector2.ZERO
		else:
			# Melompat atau jatuh ke tangga di udara dan menekan tombol vertikal
			if arah_y != 0.0:
				sedang_memanjat = true
				collision_mask = mask_normal & ~1
				velocity = Vector2.ZERO

	if sedang_memanjat:
		# Jika keluar dari seluruh area tangga, lepaskan status panjat
		if not di_area_tangga or not is_instance_valid(tangga_aktif):
			coba_lepas_tangga()
		else:
			# ATURAN KETAT: JUMP DILOCK / DIBLOKIR 100% TOTAL selama memanjat tangga
			# Nonaktifkan terrain layer 1 agar tubuh Rhein tidak terbentur platform
			collision_mask = mask_normal & ~1

			# 1. Menanjak ke atas mencapai permukaan platform atas (arah_y < 0)
			if arah_y < 0.0 and posisi_kaki <= batas_platform_atas + 4.0:
				if coba_lepas_tangga():
					global_position.y = batas_platform_atas - 186.0
					velocity = Vector2.ZERO
					ganti_animasi("idle")
					move_and_slide()
					return
			# 2. Menuruni tangga mencapai tanah dasar (arah_y > 0)
			elif arah_y > 0.0 and (posisi_kaki >= t_bawah - 6.0 or (test_move(global_transform, Vector2(0, 4)) and posisi_kaki >= t_bawah - 24.0)):
				if coba_lepas_tangga():
					global_position.y = t_bawah - 186.0
					velocity = Vector2.ZERO
					ganti_animasi("idle")
					move_and_slide()
					return
			# 3. Pemain sengaja melangkah keluar horizontal dari samping tangga
			elif arah_x != 0.0 and absf(global_position.x - center_x_tangga) > 28.0:
				if coba_lepas_tangga():
					velocity.x = arah_x * kecepatan_jalan
					move_and_slide()
					return

			# Pergerakan vertikal & pergeseran horizontal saat memanjat
			velocity.y = arah_y * kecepatan_panjat
			if arah_x != 0.0:
				velocity.x = arah_x * (kecepatan_jalan * 0.4)
			else:
				velocity.x = 0.0
				# Auto-centering X halus tanpa snap/kepental
				var col_shape = tangga_aktif.get_node_or_null("CollisionShape2D")
				var pusat_x: float = col_shape.global_position.x if col_shape else tangga_aktif.global_position.x
				if absf(pusat_x - global_position.x) < 32.0:
					global_position.x = move_toward(global_position.x, pusat_x, 120.0 * delta)

			ganti_animasi("climb")
			if anim:
				anim.offset = Vector2.ZERO
				if arah_y != 0.0:
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
			var am := get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_jump"):
				am.play_jump()
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
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_jump"):
			am.play_jump()

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
		if is_inside_tree() and test_move(global_transform, Vector2.ZERO):
			return
		collision_mask = mask_normal
	else:
		collision_mask = mask_normal & ~1


# Menguji apakah aman melepaskan status tangga tanpa terjepit di dalam dinding atau tanah
func coba_lepas_tangga() -> bool:
	var mask_lama := collision_mask
	collision_mask = mask_normal
	if is_inside_tree() and test_move(global_transform, Vector2.ZERO):
		collision_mask = mask_lama
		return false
	sedang_memanjat = false
	return true


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

	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_shoot"):
		am.play_shoot()

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
	if sedang_kena_damage or sedang_kebal:
		return

	if sedang_gelayutan:
		lepas_tali(false)

	sedang_memanjat = false
	atur_tabrakan_lantai(true)
	sedang_meluncur = false
	jumlah_zona_luncur = 0
	current_hp -= jumlah
	hp_berubah.emit(current_hp)

	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_hurt"):
		am.play_hurt()

	if current_hp <= 0:
		picu_game_over()
		return

	sedang_kena_damage = true
	if anim:
		anim.rotation = 0.0
		anim.offset = Vector2.ZERO
	ganti_animasi("hurt")

	var arah_knockback = -arah_hadap
	if arah_serang != Vector2.ZERO:
		arah_knockback = signf(global_position.x - arah_serang.x)
		if arah_knockback == 0.0:
			arah_knockback = -arah_hadap

	velocity = Vector2(arah_knockback * 260.0, -320.0)

	# Aktifkan kebal (i-frames) selama 1.0 detik dengan efek kedip alpha
	aktifkan_kebal(1.0)

	# Kembalikan kontrol pemain setelah stun knockback singkat (0.35 detik)
	await get_tree().create_timer(0.35).timeout
	if is_inside_tree():
		sedang_kena_damage = false


# Alias bahasa Inggris untuk kompatibilitas hazard
func take_damage(jumlah: int = 1, arah_serang: Vector2 = Vector2.ZERO) -> void:
	terima_damage(jumlah, arah_serang)


# Mengaktifkan status kebal (i-frames) dengan efek kedip alpha yang jelas
func aktifkan_kebal(durasi: float = 1.0) -> void:
	sedang_kebal = true
	if anim:
		var tween = create_tween()
		var kedip_loops = int(durasi / 0.2)
		for i in range(kedip_loops):
			tween.tween_property(anim, "modulate:a", 0.25, 0.1)
			tween.tween_property(anim, "modulate:a", 1.0, 0.1)
		await tween.finished
	else:
		await get_tree().create_timer(durasi).timeout

	if is_inside_tree():
		sedang_kebal = false
		if anim:
			anim.modulate.a = 1.0


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
	daftar_tangga.clear()
	di_area_tangga = false
	sedang_di_duri = false
	timer_damage_duri = 0.0
	terjebak_duri = false
	duri_aktif = null
	sedang_kena_damage = false
	sedang_kebal = false
	sedang_menyerang = false
	sedang_spawn = false
	cooldown_tali = 0.0
	collision_mask = mask_normal

	if anim:
		anim.rotation = 0.0
		anim.offset = Vector2.ZERO
		anim.modulate = Color(1.0, 1.0, 1.0, 1.0)
	ganti_animasi("idle")

	hp_berubah.emit(current_hp)
	status_kunci_berubah.emit(has_key)


# Menampilkan popup Game Over saat nyawa habis dan membekukan simulasi dunia
func picu_game_over() -> void:
	sedang_kena_damage = false
	sedang_kebal = false
	velocity = Vector2.ZERO
	if anim:
		anim.rotation = 0.0
		anim.offset = Vector2.ZERO
		anim.modulate.a = 1.0

	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if not tree:
		return

	var go_scene := load("res://scenes/game_over_popup.tscn")
	if go_scene:
		var scene_aktif := tree.current_scene if tree.current_scene else tree.root
		if scene_aktif and not scene_aktif.has_node("GameOverPopup"):
			var popup = go_scene.instantiate()
			scene_aktif.add_child(popup)
			tree.paused = true
			return


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
	sedang_kebal = false
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
		jatuh_ke_jurang()


# Sinyal otomatis saat karakter menyentuh FallZone
func _on_fall_zone_body_entered(body: Node2D) -> void:
	if body == self or body.name == "Player" or body.is_in_group("Player"):
		jatuh_ke_jurang()


# Kematian instan (jatuh ke jurang atau kondisi lethal): HP langsung 0 & Game Over seketika
func mati_instan() -> void:
	current_hp = 0
	hp_berubah.emit(0)
	velocity = Vector2.ZERO
	picu_game_over()


# Logika penanganan jatuh ke jurang (instan kalah & munculkan popup game over)
func jatuh_ke_jurang() -> void:
	mati_instan()


# Penanganan saat karakter terjerat jebakan duri
func masuk_duri(duri: Area2D = null) -> void:
	if sedang_di_duri:
		return
	sedang_di_duri = true
	duri_aktif = duri
	timer_damage_duri = 0.0
	if sedang_memanjat:
		sedang_memanjat = false
		collision_mask = mask_normal
	if sedang_gelayutan:
		lepas_tali(false)
	sedang_meluncur = false
	jumlah_zona_luncur = 0
	velocity.x = 0.0
	velocity.y = maxf(velocity.y, 0.0)

	# Langsung kurangi -1 HP pada sentuhan pertama
	terima_damage_duri(1)


# Penanganan saat karakter terbebas dari jebakan duri
func keluar_duri() -> void:
	sedang_di_duri = false
	timer_damage_duri = 0.0
	duri_aktif = null


# Alias kompatibilitas
func kena_jebakan_duri(duri: Area2D = null) -> void:
	masuk_duri(duri)


func lepas_jebakan_duri() -> void:
	keluar_duri()


# Menerima damage duri berkala tanpa pantulan dan tanpa masa kebal lolos
func terima_damage_duri(jumlah: int = 1) -> void:
	if current_hp <= 0:
		return

	current_hp -= jumlah
	hp_berubah.emit(current_hp)

	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_hurt"):
		am.play_hurt()

	if current_hp <= 0:
		sedang_di_duri = false
		picu_game_over()
		return

	ganti_animasi("hurt")
	if anim:
		var tween = create_tween()
		tween.tween_property(anim, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.1)
		tween.tween_property(anim, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)


# Kompatibilitas sinyal duri lama
func kena_duri(body: Node2D = null) -> void:
	if body == self or body == null:
		masuk_duri()


# Kode masuk area tangga (menerima sinyal dari body maupun area)
func masuk_area_tangga(tangga_obj: Variant = null) -> void:
	var area: Area2D = null
	if tangga_obj is Area2D:
		area = tangga_obj
	elif tangga_obj is CollisionObject2D and tangga_obj.get_parent() is Area2D:
		area = tangga_obj.get_parent()

	if area and not daftar_tangga.has(area):
		daftar_tangga.append(area)
	di_area_tangga = (daftar_tangga.size() > 0)


# Kode keluar area tangga (menerima sinyal dari body maupun area)
func keluar_area_tangga(tangga_obj: Variant = null) -> void:
	var area: Area2D = null
	if tangga_obj is Area2D:
		area = tangga_obj
	elif tangga_obj is CollisionObject2D and tangga_obj.get_parent() is Area2D:
		area = tangga_obj.get_parent()

	if area:
		daftar_tangga.erase(area)
	else:
		var ld = get_node_or_null("LeaderDetector")
		if ld:
			daftar_tangga.clear()
			for a in ld.get_overlapping_areas():
				if a.is_in_group("ladder") or a.is_in_group("leader") or a.name.to_lower().contains("ladder") or a.name.to_lower().contains("leader"):
					daftar_tangga.append(a)

	di_area_tangga = (daftar_tangga.size() > 0)
	if not di_area_tangga and sedang_memanjat:
		coba_lepas_tangga()


# Mendapatkan batas atas dan bawah dari area tangga yang sedang dinaiki
func get_info_tangga_aktif() -> Dictionary:
	if tangga_aktif and is_instance_valid(tangga_aktif):
		var atas: float = tangga_aktif.get_batas_atas() if tangga_aktif.has_method("get_batas_atas") else tangga_aktif.global_position.y - 64.0
		var bawah: float = tangga_aktif.get_batas_bawah() if tangga_aktif.has_method("get_batas_bawah") else tangga_aktif.global_position.y + 64.0
		return {"atas": atas, "bawah": bawah}

	var ld = get_node_or_null("LeaderDetector")
	var batas_atas := INF
	var batas_bawah := -INF
	if ld:
		for a in ld.get_overlapping_areas():
			if a.is_in_group("ladder") or a.is_in_group("leader") or a.name.to_lower().contains("ladder") or a.name.to_lower().contains("leader"):
				if a.has_method("get_batas_atas") and a.has_method("get_batas_bawah"):
					var a_atas: float = a.get_batas_atas()
					var a_bawah: float = a.get_batas_bawah()
					if a_atas < batas_atas:
						batas_atas = a_atas
					if a_bawah > batas_bawah:
						batas_bawah = a_bawah
				else:
					for c in a.get_children():
						if c is CollisionShape2D and c.shape is RectangleShape2D:
							var atas: float = c.global_position.y - (c.shape.size.y * 0.5)
							var bawah: float = c.global_position.y + (c.shape.size.y * 0.5)
							if atas < batas_atas:
								batas_atas = atas
							if bawah > batas_bawah:
								batas_bawah = bawah
	return {"atas": batas_atas, "bawah": batas_bawah}


# Alias sinyal tangga untuk kompatibilitas penamaan
func _on_ladder_area_entered(area: Variant = null) -> void:
	masuk_area_tangga(area)


func _on_ladder_area_exited(area: Variant = null) -> void:
	keluar_area_tangga(area)


# Sinyal otomatis saat karakter menyentuh area Spike
func _on_spike_body_entered(body: Node2D) -> void:
	kena_duri(body)
