extends Area2D

@export var speed: float = 520.0
@export var damage: int = 1
@export var masa_hidup: float = 2.0

var arah_gerak: float = 1.0
var sudah_menabrak: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = get_node_or_null("VisibleOnScreenNotifier2D")


func _ready() -> void:
	add_to_group("Projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if notifier:
		notifier.screen_exited.connect(queue_free)

	# Pastikan visual sprite langsung membalik saat scene siap
	if sprite:
		sprite.flip_h = (arah_gerak < 0)

	get_tree().create_timer(masa_hidup).timeout.connect(hancurkan_proyektil)


func _physics_process(delta: float) -> void:
	# Meluncur sesuai arah hadap (-1 = ke kiri, 1 = ke kanan)
	position.x += arah_gerak * speed * delta


func atur_arah(arah_baru: float) -> void:
	arah_gerak = arah_baru
	if sprite:
		sprite.flip_h = (arah_gerak < 0)


func _on_body_entered(body: Node2D) -> void:
	if sudah_menabrak:
		return

	# Jangan tabrak karakter pemain sendiri
	if body.is_in_group("Player") or body.name.to_lower().contains("player"):
		return

	if body.has_method("terkena_tembakan"):
		sudah_menabrak = true
		body.terkena_tembakan(damage)
		hancurkan_proyektil()
		return

	if body is TileMap or body is StaticBody2D:
		sudah_menabrak = true
		hancurkan_proyektil()


func _on_area_entered(area: Area2D) -> void:
	if sudah_menabrak:
		return

	var target = area.get_parent()
	if target == null or target.is_in_group("Player") or target.name.to_lower().contains("player"):
		return

	if target.has_method("terkena_tembakan"):
		sudah_menabrak = true
		target.terkena_tembakan(damage)
		hancurkan_proyektil()


func _on_screen_exited() -> void:
	queue_free()


func hancurkan_proyektil() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.05)
	await tween.finished
	queue_free()
