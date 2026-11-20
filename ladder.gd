extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("masuk_area_tangga"):
		body.masuk_area_tangga(body)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("keluar_area_tangga"):
		body.keluar_area_tangga(body)
