extends Area2D

@export_file("*.tscn") var target_level: String = "res://scenes/level_2.tscn"
@export var puzzle_scene: PackedScene = preload("uid://c3qxbf3cjmti8")
@export var gunakan_white_flash: bool = false
@export var durasi_white_flash: float = 1.3

var puzzle_sedang_terbuka: bool = false
var puzzle_selesai: bool = false
var sedang_transisi: bool = false

@onready var anim = _ambil_node_animasi()


func _ready() -> void:
	add_to_group("Portal")
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	body.velocity = Vector2.ZERO

	munculkan_puzzle(body)


func munculkan_puzzle(player: CharacterBody2D) -> void:
	if not puzzle_scene:
		print("Scene puzzle tidak ditemukan!")
		puzzle_sedang_terbuka = false
		return

	# Bekukan seluruh dunia game (Rhein, musuh, proyektil, hazard)
	get_tree().paused = true

	var puzzle_instance = puzzle_scene.instantiate()
	puzzle_instance.process_mode = Node.PROCESS_MODE_ALWAYS

	# Tambahkan popup ke current_scene (bukan root) agar siklus hidup terisolasi rapi
	var scene_root = get_tree().current_scene
	if not is_instance_valid(scene_root):
		scene_root = get_tree().root
	scene_root.add_child(puzzle_instance)

	# Pastikan popup dan komponen papan terlihat serta memproses input selama game dipause
	puzzle_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	if "visible" in puzzle_instance:
		puzzle_instance.visible = true

	var papan_anak = puzzle_instance.get_node_or_null("PapanPipa")
	if not papan_anak:
		papan_anak = puzzle_instance.get_node_or_null("PapanPuzzle")
	if papan_anak:
		papan_anak.process_mode = Node.PROCESS_MODE_ALWAYS
		if "visible" in papan_anak:
			papan_anak.visible = true

	# Cari sumber sinyal puzzle_selesai (pada root maupun child)
	var target_sig_source: Object = null
	if puzzle_instance.has_signal("puzzle_selesai"):
		target_sig_source = puzzle_instance
	elif puzzle_instance.has_node("PapanPuzzle") and puzzle_instance.get_node("PapanPuzzle").has_signal("puzzle_selesai"):
		target_sig_source = puzzle_instance.get_node("PapanPuzzle")
	elif puzzle_instance.has_node("PapanPipa") and puzzle_instance.get_node("PapanPipa").has_signal("puzzle_selesai"):
		target_sig_source = puzzle_instance.get_node("PapanPipa")

	if target_sig_source:
		target_sig_source.puzzle_selesai.connect(func():
			# Hapus popup bersih dan pulihkan pause game
			if is_instance_valid(puzzle_instance):
				puzzle_instance.queue_free()
			get_tree().paused = false
			puzzle_sedang_terbuka = false
			puzzle_selesai = true
			eksekusi_buka_dan_sedot(player)
		, CONNECT_ONE_SHOT)
	else:
		push_error("Sinyal puzzle_selesai tidak ditemukan pada popup puzzle!")
		get_tree().paused = false
		puzzle_sedang_terbuka = false


func eksekusi_buka_dan_sedot(player: CharacterBody2D) -> void:
	# 1. Buka gate portal
	_putar_animasi("terbuka")

	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_portal"):
		am.play_portal()

	# 2. Jeda hening agar gerbang terlihat terbuka
	await get_tree().create_timer(0.8, true).timeout

	# 3. Kunci area portal & sedot karakter
	sedang_transisi = true
	set_deferred("monitoring", false)

	if player.has_method("masuk_portal"):
		player.masuk_portal(global_position)
		if player.has_signal("selesai_masuk_portal"):
			await player.selesai_masuk_portal
		else:
			await get_tree().create_timer(0.9).timeout

	# 4. Jalankan transisi layar
	jalankan_transisi_fade()


func jalankan_transisi_fade() -> void:
	var is_white_flash = gunakan_white_flash or target_level.to_lower().contains("credits")
	var canvas_fade = CanvasLayer.new()
	canvas_fade.layer = 100
	canvas_fade.process_mode = Node.PROCESS_MODE_ALWAYS

	var overlay = ColorRect.new()
	overlay.color = Color.WHITE if is_white_flash else Color.BLACK
	overlay.modulate.a = 0.0
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	canvas_fade.add_child(overlay)
	get_tree().root.add_child(canvas_fade)

	var tween = create_tween()
	var durasi_fade: float = durasi_white_flash if is_white_flash else 0.25
	var trans_type = Tween.TRANS_QUAD if is_white_flash else Tween.TRANS_LINEAR
	var ease_type = Tween.EASE_IN if is_white_flash else Tween.EASE_OUT

	tween.tween_property(overlay, "modulate:a", 1.0, durasi_fade)\
		.set_trans(trans_type).set_ease(ease_type)
	await tween.finished

	# Deteksi path level tujuan
	var path_level: String = target_level
	if path_level.begins_with("uid://"):
		var uid_val := ResourceUID.text_to_id(path_level)
		if ResourceUID.has_id(uid_val):
			path_level = ResourceUID.get_id_path(uid_val)

	if not ResourceLoader.exists(path_level):
		if ResourceLoader.exists("res://scenes/credits.tscn"):
			path_level = "res://scenes/credits.tscn"
		elif ResourceLoader.exists("res://scenes/level_3.tscn"):
			path_level = "res://scenes/level_3.tscn"
		elif ResourceLoader.exists("res://scenes/level_2.tscn"):
			path_level = "res://scenes/level_2.tscn"

	if ResourceLoader.exists(path_level):
		get_tree().change_scene_to_file(path_level)
		
		var durasi_in = 0.6 if is_white_flash else 0.15
		var tween_in = canvas_fade.create_tween()
		tween_in.tween_property(overlay, "modulate:a", 0.0, durasi_in)
		tween_in.tween_callback(canvas_fade.queue_free)
	else:
		push_error("Scene tujuan tidak ditemukan: " + path_level)
		canvas_fade.queue_free()
