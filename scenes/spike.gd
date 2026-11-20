extends Area2D

@export var damage: int = 1
@export var daya_mental: float = -280.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)

		# Pantulkan Rhein sedikit ke atas agar tidak terperangkap di duri
		if "velocity" in body:
			body.velocity.y = daya_mental
