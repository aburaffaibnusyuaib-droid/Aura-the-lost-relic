extends Area2D

@export var daftar_pijakan: Array[NodePath] = []
@export var durasi_sorot_kamera: float = 1.5
@export var jeda_antar_pijakan: float = 0.3

var bisa_interaksi: bool = false
var sudah_aktif: bool = false
var player: CharacterBody2D = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	label.visible = false
	anim_sprite.play("idle")


func _input(event: InputEvent) -> void:
	if bisa_interaksi and not sudah_aktif:
		if event.is_action_pressed("interaksi"):
			get_viewport().set_input_as_handled()
			tarik_tuas()


func _on_body_entered(body: Node2D) -> void:
	if (body.is_in_group("Player") or body.name == "Player") and not sudah_aktif:
		player = body
		bisa_interaksi = true
		label.visible = true
		# Animasi kecil muncul pada teks petunjuk
		label.modulate.a = 0.0
		create_tween().tween_property(label, "modulate:a", 1.0, 0.2)


func _on_body_exited(body: Node2D) -> void:
	if body == player:
		bisa_interaksi = false
		label.visible = false


func tarik_tuas() -> void:
	sudah_aktif = true
	bisa_interaksi = false
	label.visible = false

	# Ubah tuas ke hijau menyala
	anim_sprite.play("aktif")

	# Kumpulkan semua node pijakan yang valid
	var valid_nodes: Array[Node2D] = []
	for path in daftar_pijakan:
		var node := get_node_or_null(path)
		if node is Node2D:
			valid_nodes.append(node)

	# Hitung titik tengah lokasi pijakan yang akan muncul
	var target_sorot: Vector2 = global_position
	if valid_nodes.size() > 0:
		var total_pos: Vector2 = Vector2.ZERO
		for n in valid_nodes:
			total_pos += n.global_position
		target_sorot = total_pos / valid_nodes.size()

	# --- Sorot Kamera ke Pijakan Baru ---
	var kamera: Camera2D = get_viewport().get_camera_2d()
	if kamera:
		var pos_kamera_awal: Vector2 = kamera.global_position
		kamera.top_level = true
		kamera.global_position = pos_kamera_awal

		var tween_cam := create_tween()
		tween_cam.tween_property(kamera, "global_position", target_sorot, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await tween_cam.finished

	# Munculkan pijakan secara berurutan
	for i in range(valid_nodes.size()):
		var node := valid_nodes[i]
		if node.has_method("muncul"):
			node.muncul(i * jeda_antar_pijakan)

	# Tunggu pemain melihat pijakan muncul, lalu kembalikan kamera ke Rhein
	await get_tree().create_timer(durasi_sorot_kamera).timeout
	if kamera and is_instance_valid(player):
		var tween_back := create_tween()
		tween_back.tween_property(kamera, "global_position", player.global_position, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await tween_back.finished
		kamera.top_level = false
		kamera.position = Vector2.ZERO
