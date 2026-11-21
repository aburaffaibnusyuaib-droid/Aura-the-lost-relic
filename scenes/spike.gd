@tool
extends Area2D

@export var damage: int = 1


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("masuk_duri"):
			body.masuk_duri(self)
		elif body.has_method("kena_jebakan_duri"):
			body.kena_jebakan_duri(self)


func _on_body_exited(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("keluar_duri"):
			body.keluar_duri()
		elif body.has_method("lepas_jebakan_duri"):
			body.lepas_jebakan_duri()
