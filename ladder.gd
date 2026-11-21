@tool
extends Area2D

@export var lebar_tangga: float = 26.0:
	set(val):
		lebar_tangga = val
		_perbarui_bentuk()

@export var tinggi_tangga: float = 128.0:
	set(val):
		tinggi_tangga = val
		_perbarui_bentuk()

@export var offset_y: float = 0.0:
	set(val):
		offset_y = val
		_perbarui_bentuk()


func _ready() -> void:
	add_to_group("ladder")
	add_to_group("leader")
	_perbarui_bentuk()

	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
		if not area_entered.is_connected(_on_area_entered):
			area_entered.connect(_on_area_entered)
		if not area_exited.is_connected(_on_area_exited):
			area_exited.connect(_on_area_exited)


func _perbarui_bentuk() -> void:
	var col = get_node_or_null("CollisionShape2D")
	if not col:
		return
	if not col.shape or not (col.shape is RectangleShape2D):
		col.shape = RectangleShape2D.new()
		col.shape.resource_local_to_scene = true
	elif not col.shape.resource_local_to_scene:
		col.shape = col.shape.duplicate()
		col.shape.resource_local_to_scene = true

	col.shape.size = Vector2(lebar_tangga, tinggi_tangga)
	col.position.y = offset_y


func get_batas_atas() -> float:
	var col = get_node_or_null("CollisionShape2D")
	if col and col.shape and col.shape is RectangleShape2D:
		return col.global_position.y - (col.shape.size.y * 0.5)
	return global_position.y + offset_y - (tinggi_tangga * 0.5)


func get_batas_bawah() -> float:
	var col = get_node_or_null("CollisionShape2D")
	if col and col.shape and col.shape is RectangleShape2D:
		return col.global_position.y + (col.shape.size.y * 0.5)
	return global_position.y + offset_y + (tinggi_tangga * 0.5)


func get_center_x() -> float:
	var col = get_node_or_null("CollisionShape2D")
	if col:
		return col.global_position.x
	return global_position.x


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("masuk_area_tangga"):
		body.masuk_area_tangga(self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("keluar_area_tangga"):
		body.keluar_area_tangga(self)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("masuk_area_tangga"):
		area.masuk_area_tangga(self)
	elif area.get_parent() and area.get_parent().has_method("masuk_area_tangga"):
		area.get_parent().masuk_area_tangga(self)


func _on_area_exited(area: Area2D) -> void:
	if area.has_method("keluar_area_tangga"):
		area.keluar_area_tangga(self)
	elif area.get_parent() and area.get_parent().has_method("keluar_area_tangga"):
		area.get_parent().keluar_area_tangga(self)
