extends Area2D

var sudah_diambil: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if sudah_diambil:
		return

	if body.is_in_group("Player") or body.name.to_lower().contains("player"):
		sudah_diambil = true

		# Berikan kunci ke pemain
		if body.has_method("ambil_kunci"):
			body.ambil_kunci()

		set_deferred("monitoring", false)

		# Animasi melayang ke atas lalu menghilang
		var tween = create_tween().set_parallel(true)
		tween.tween_property(self, "position:y", position.y - 28.0, 0.35)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.35)
		tween.tween_property(self, "modulate:a", 0.0, 0.35)

		await tween.finished
		queue_free()
