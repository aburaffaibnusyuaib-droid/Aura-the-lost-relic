extends Area2D

@export var titik_respawn: Marker2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		# Kurangi nyawa/HP jika ada sistem damage (opsional)
		if body.has_method("take_damage"):
			body.take_damage(1)

		# Pindahkan Rhein ke titik respawn tanpa me-reset scene & item
		if titik_respawn:
			body.global_position = titik_respawn.global_position
			body.velocity = Vector2.ZERO
		else:
			get_tree().reload_current_scene()
