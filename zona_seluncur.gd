extends Area2D

## Isi 1.0 jika tebing miring ke kanan, atau -1.0 jika tebing miring ke kiri
@export_enum("Kanan:1", "Kiri:-1") var arah_luncur: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("masuk_zona_luncur"):
			body.masuk_zona_luncur(float(arah_luncur))


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("keluar_zona_luncur"):
			body.keluar_zona_luncur()
