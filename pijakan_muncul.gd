extends StaticBody2D

@onready var col: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	visible = false
	col.disabled = true
	modulate.a = 0.0


func muncul(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	visible = true

	scale = Vector2(0.5, 0.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished
	col.disabled = false


func _on_spike_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
