extends CanvasLayer

signal puzzle_selesai

@onready var papan: Control = $PapanPuzzle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if papan and papan.has_signal("puzzle_selesai"):
		if not papan.puzzle_selesai.is_connected(_on_papan_puzzle_selesai):
			papan.puzzle_selesai.connect(_on_papan_puzzle_selesai)


func _on_papan_puzzle_selesai() -> void:
	puzzle_selesai.emit()
