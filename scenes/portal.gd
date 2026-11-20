extends Area2D

@export_file("*.tscn") var target_level: String = "res://scenes/level_2.tscn"
@export var puzzle_scene: PackedScene = preload("uid://c3qxbf3cjmti8")

var puzzle_sedang_terbuka: bool = false
var puzzle_selesai: bool = false
var sedang_transisi: bool = false

@onready var anim = _ambil_node_animasi()


func _ready() -> void:
	add_to_group("Portal")
	body_entered.connect(_on_body_entered)
	_putar_animasi("tertutup")


func _ambil_node_animasi() -> Node:
	if has_node("AnimatedSprite2D"):
		return get_node("AnimatedSprite2D")
	return find_child("*Sprite*", true, false)


func _putar_animasi(nama: String) -> void:
	if not anim or not anim.has_method("play"):
		return
	if "sprite_frames" in anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation(nama):
			anim.play(nama)


func _on_body_entered(body: Node2D) -> void:
	if puzzle_sedang_terbuka or sedang_transisi or puzzle_selesai:
		return

	if not (body.is_in_group("Player") or "has_key" in body or body.name.to_lower().contains("player")):
		return

	# Jika belum punya kunci: tolak mundur
	if not body.get("has_key"):
		if body is CharacterBody2D:
			var tolak = sign(body.global_position.x - global_position.x)
			if tolak == 0:
				tolak = 1.0
			body.velocity.x = tolak * 160.0
		return

	# Punya kunci: Kunci posisi pemain di lantai dan buka scene puzzle
	puzzle_sedang_terbuka = true
	body.set_physics_process(false)
	body.velocity = Vector2.ZERO

	munculkan_puzzle(body)


func munculkan_puzzle(player: CharacterBody2D) -> void:
	if not puzzle_scene:
		print("Scene puzzle tidak ditemukan!")
		return

	var puzzle_instance = puzzle_scene.instantiate()
	get_tree().root.add_child(puzzle_instance)

	if puzzle_instance.has_signal("puzzle_selesai"):
		puzzle_instance.puzzle_selesai.connect(func():
			puzzle_sedang_terbuka = false
			puzzle_selesai = true
			eksekusi_buka_dan_sedot(player)
		)


func eksekusi_buka_dan_sedot(player: CharacterBody2D) -> void:
	# 1. Buka gate portal
	_putar_animasi("terbuka")

	# 2. Jeda hening agar gerbang terlihat terbuka
	await get_tree().create_timer(0.8).timeout

	# 3. Kunci area portal & sedot karakter
	sedang_transisi = true
	set_deferred("monitoring", false)

	if player.has_method("masuk_portal"):
		player.masuk_portal(global_position)
		if player.has_signal("selesai_masuk_portal"):
			await player.selesai_masuk_portal
		else:
			await get_tree().create_timer(0.9).timeout

	# 4. Jalankan transisi layar cepat
	jalankan_transisi_fade()


func jalankan_transisi_fade() -> void:
	var canvas_fade = CanvasLayer.new()
	canvas_fade.layer = 100

	var overlay = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	canvas_fade.add_child(overlay)
	get_tree().root.add_child(canvas_fade)

	# Fade out cepat ke layar hitam
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2)
	await tween.finished

	# Deteksi path scene Level 2
	var path_level = target_level
	if not ResourceLoader.exists(path_level):
		if ResourceLoader.exists("res://scenes/level_2.tscn"):
			path_level = "res://scenes/level_2.tscn"
		elif ResourceLoader.exists("res://scenes/level2.tscn"):
			path_level = "res://scenes/level2.tscn"

	if ResourceLoader.exists(path_level):
		get_tree().change_scene_to_file(path_level)
		
		# Langsung fade in cepat (0.15 detik) agar animasi spawn_drop langsung terlihat
		var tween_in = canvas_fade.create_tween()
		tween_in.tween_property(overlay, "modulate:a", 0.0, 0.15)
		tween_in.tween_callback(canvas_fade.queue_free)
	else:
		push_error("Scene tujuan tidak ditemukan: " + path_level)
		canvas_fade.queue_free()
