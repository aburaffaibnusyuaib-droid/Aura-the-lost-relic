extends AnimatableBody2D

@export var jarak_gerak: Vector2 = Vector2(750.0, 0.0)
@export var durasi_satu_arah: float = 3.5
@export var jeda_ujung: float = 0.5


func _ready() -> void:
	sync_to_physics = true
	var posisi_awal: Vector2 = position
	var posisi_tujuan: Vector2 = posisi_awal + jarak_gerak

	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(self, "position", posisi_tujuan, durasi_satu_arah)
	tween.tween_interval(jeda_ujung)
	tween.tween_property(self, "position", posisi_awal, durasi_satu_arah)
	tween.tween_interval(jeda_ujung)
