extends CanvasLayer

signal puzzle_selesai

@onready var papan: Control = $PapanPipa


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if papan and papan.has_signal("puzzle_selesai"):
		if not papan.puzzle_selesai.is_connected(_on_papan_selesai):
			papan.puzzle_selesai.connect(_on_papan_selesai)

	visibility_changed.connect(_on_visibility_changed)
	if visible and papan and papan.has_method("buat_papan_baru"):
		papan.buat_papan_baru()
		if papan.has_method("mainkan_animasi_buka"):
			papan.mainkan_animasi_buka()


func _on_papan_selesai() -> void:
	puzzle_selesai.emit()
	# Hapus popup dari layar secara otomatis agar tidak terbawa masuk ke Level 3
	await get_tree().process_frame
	if is_inside_tree():
		queue_free()


func _on_visibility_changed() -> void:
	if visible and papan and papan.has_method("buat_papan_baru"):
		papan.buat_papan_baru()
		if papan.has_method("mainkan_animasi_buka"):
			papan.mainkan_animasi_buka()
