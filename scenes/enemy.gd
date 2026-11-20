extends CharacterBody2D

@export_group("Stats & Perilaku")
@export var speed: float = 60.0
@export var damage: int = 1
@export var max_hp: int = 5
## Jarak tempuh bolak-balik dari titik spawn (dalam piksel). 
## Ubah nilainya di Inspector sesuai panjang jembatan.
@export var jarak_patroli_maks: float = 460.0 

@export_group("Tema Visual Level")
@export_enum("Level 1 (Batu Gelap)", "Level 2 (Es Dingin)", "Level 3 (Kuil Purba)") var tipe_level: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var main_collision: CollisionShape2D = $CollisionShape2D
@onready var body_hitbox: Area2D = get_node_or_null("BodyHitbox") if has_node("BodyHitbox") else get_node_or_null("BodyHitBox")
@onready var stomp_detector: Area2D = $StompDetector

var arah: int = 1
var gravitasi: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var titik_awal_x: float = 0.0
var is_mati: bool = false
var is_recoil: bool = false
var bisa_balik: bool = true


func _ready() -> void:
	# Simpan posisi spawn horizontal sebagai titik acuan rentang patroli
	titik_awal_x = global_position.x
	
	terapkan_tema_level()
	
	if body_hitbox:
		body_hitbox.body_entered.connect(_on_body_hitbox_entered)
	if stomp_detector:
		stomp_detector.body_entered.connect(_on_stomp_detector_entered)
		
	if sprite and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")


func _physics_process(delta: float) -> void:
	if is_mati:
		return

	# Terapkan gravitasi lantai
	if not is_on_floor():
		velocity.y += gravitasi * delta

	if not is_recoil:
		# Hitung selisih jarak dari titik spawn awal
		var sudah_lewat_batas: bool = false
		if arah > 0 and (global_position.x - titik_awal_x) >= jarak_patroli_maks:
			sudah_lewat_batas = true
		elif arah < 0 and (titik_awal_x - global_position.x) >= jarak_patroli_maks:
			sudah_lewat_batas = true

		# Deteksi apakah ujung jembatan habis
		var ujung_lantai_habis: bool = not ledge_check.is_colliding()

		# Putar arah jika jembatan habis ATAU sudah melangkah sejauh jarak batas
		if is_on_floor() and (ujung_lantai_habis or sudah_lewat_batas) and bisa_balik:
			balik_arah()

		velocity.x = arah * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 2.5)

	move_and_slide()


func balik_arah() -> void:
	bisa_balik = false
	arah *= -1
	sprite.flip_h = (arah < 0)
	
	# Pindahkan posisi sensor jurang ke sisi depan hadapan baru
	ledge_check.position.x = abs(ledge_check.position.x) * arah

	# Beri jeda 0.35 detik agar sensor tidak membaca ulang tepi yang sama
	await get_tree().create_timer(0.35).timeout
	bisa_balik = true


# 1. MEKANIK DIINJAK DARI ATAS (STOMP)
func _on_stomp_detector_entered(body: Node2D) -> void:
	if is_mati:
		return

	if body.is_in_group("Player") or body.name == "Player":
		# Pemain hanya berhasil menginjak jika sedang meluncur/jatuh ke bawah
		if body.velocity.y > 0:
			if body.has_method("pantulkan"):
				body.pantulkan(340.0)
			else:
				body.velocity.y = -340.0
			hancur_musuh()


# 2. MEKANIK TABRAKAN SISI BADAN
func _on_body_hitbox_entered(body: Node2D) -> void:
	if is_mati:
		return

	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("terima_damage"):
			var arah_pantul: Vector2 = (body.global_position - global_position).normalized()
			arah_pantul.y = -0.4
			body.terima_damage(damage, arah_pantul.normalized() * 320.0)


# 3. MEKANIK DITEMBAK PROYEKTIL AURA
func terkena_tembakan(jumlah_damage: int = 1) -> void:
	if is_mati:
		return

	max_hp -= jumlah_damage
	
	if max_hp <= 0:
		hancur_musuh()
	else:
		is_recoil = true
		if sprite.sprite_frames.has_animation("hurt"):
			sprite.play("hurt")
		
		# Efek kedip merah saat terkena benturan
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(2.5, 0.4, 0.4, 1.0), 0.08)
		tween.tween_property(sprite, "modulate", dapatkan_warna_tema(), 0.08)
		
		await sprite.animation_finished
		is_recoil = false
		if not is_mati and sprite.sprite_frames.has_animation("walk"):
			sprite.play("walk")


func hancur_musuh() -> void:
	is_mati = true
	velocity = Vector2.ZERO
	
	# Matikan seluruh sistem tabrakan agar tidak menghalangi pemain lagi
	if body_hitbox:
		body_hitbox.set_deferred("monitoring", false)
	if stomp_detector:
		stomp_detector.set_deferred("monitoring", false)
	main_collision.set_deferred("disabled", true)
	
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	
	# Puing batu memudar perlahan
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished
	queue_free()


func terapkan_tema_level() -> void:
	sprite.modulate = dapatkan_warna_tema()


func dapatkan_warna_tema() -> Color:
	match tipe_level:
		0: return Color(1.0, 1.0, 1.0, 1.0)       # Normal (Level 1)
		1: return Color(0.65, 0.85, 1.0, 1.0)     # Nuansa Es Biru Dingin (Level 2)
		2: return Color(1.0, 0.75, 0.75, 1.0)     # Nuansa Kuil Kuno Kemerahan (Level 3)
		_: return Color(1.0, 1.0, 1.0, 1.0)
