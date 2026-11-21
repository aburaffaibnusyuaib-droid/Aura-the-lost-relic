@tool
extends Area2D

@export var titik_respawn: Marker2D

var sedang_proses_jatuh: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint() or sedang_proses_jatuh:
		return

	if body.is_in_group("Player") or body.name == "Player":
		proses_jatuh(body)


func proses_jatuh(body: Node2D) -> void:
	sedang_proses_jatuh = true

	# Jatuh ke jurang adalah kematian instan: HP 0 & langsung munculkan Popup Game Over
	if body.has_method("mati_instan"):
		body.mati_instan()
	elif body.has_method("jatuh_ke_jurang"):
		body.jatuh_ke_jurang()
	else:
		if "current_hp" in body:
			body.current_hp = 0
		if body.has_signal("hp_berubah"):
			body.hp_berubah.emit(0)
		if body.has_method("picu_game_over"):
			body.picu_game_over()
		elif body.has_method("respawn"):
			body.respawn()

	sedang_proses_jatuh = false
