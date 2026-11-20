extends Node2D

@export_group("Pengaturan Tali")
@export var panjang_tali: float = 200.0
@export var lebar_tali: float = 12.0
@export var warna_tali: Color = Color(0.62, 0.42, 0.24, 1.0)
@export var sudut_maksimal_derajat: float = 50.0
@export var kekuatan_pompa: float = 4.8
@export var gravitasi_bandul: float = 9.8

var sudut_sekarang: float = 0.0
var kecepatan_sudut: float = 0.0
var lengkungan_sekarang: float = 0.0
var pemain_menempel: CharacterBody2D = null

@onready var line: Line2D = $Line2D
@onready var grab_area: Area2D = $GrabArea


func _ready() -> void:
	z_index = 20
	z_as_relative = false

	line.position = Vector2.ZERO
	line.rotation = 0.0
	line.scale = Vector2.ONE
	line.width = lebar_tali
	line.width_curve = null
	line.texture = null
	line.default_color = warna_tali
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

	grab_area.monitoring = true
	grab_area.monitorable = true
	if not grab_area.body_entered.is_connected(_on_grab_area_body_entered):
		grab_area.body_entered.connect(_on_grab_area_body_entered)

	perbarui_kurva_tali()


func _physics_process(delta: float) -> void:
	if pemain_menempel == null and abs(sudut_sekarang) < 0.004 and abs(kecepatan_sudut) < 0.008 and abs(lengkungan_sekarang) < 0.2:
		sudut_sekarang = 0.0
		kecepatan_sudut = 0.0
		lengkungan_sekarang = 0.0
		perbarui_kurva_tali()
		return

	var percepatan_sudut: float = -gravitasi_bandul * sin(sudut_sekarang)
	kecepatan_sudut += percepatan_sudut * delta

	var redaman: float = 0.994 if pemain_menempel != null else 0.945
	kecepatan_sudut *= redaman
	sudut_sekarang += kecepatan_sudut * delta

	var batas_rad := deg_to_rad(sudut_maksimal_derajat)
	if abs(sudut_sekarang) > batas_rad:
		sudut_sekarang = sign(sudut_sekarang) * batas_rad
		kecepatan_sudut *= 0.55

	var target_lengkungan: float = -kecepatan_sudut * panjang_tali * 0.24
	if pemain_menempel != null:
		target_lengkungan *= 1.3
	lengkungan_sekarang = lerp(lengkungan_sekarang, target_lengkungan, delta * 10.0)

	perbarui_kurva_tali()


func perbarui_kurva_tali() -> void:
	var titik_atas := Vector2.ZERO
	var titik_bawah := Vector2(-sin(sudut_sekarang), cos(sudut_sekarang)) * panjang_tali

	var arah_tegak_lurus := Vector2(cos(sudut_sekarang), sin(sudut_sekarang))
	var titik_tengah := (titik_atas + titik_bawah) * 0.5 + (arah_tegak_lurus * lengkungan_sekarang)

	line.clear_points()
	var jumlah_segmen := 12
	for i in range(jumlah_segmen + 1):
		var t: float = float(i) / float(jumlah_segmen)
		var p: Vector2 = ((1.0 - t) * (1.0 - t) * titik_atas) + (2.0 * (1.0 - t) * t * titik_tengah) + (t * t * titik_bawah)
		line.add_point(p)

	grab_area.position = titik_bawah
	grab_area.rotation = sudut_sekarang


func _on_grab_area_body_entered(body: Node2D) -> void:
	if pemain_menempel != null:
		return
	if body.is_in_group("Player") or body.name == "Player":
		if body.has_method("tangkap_tali"):
			body.tangkap_tali(self)


func mulai_ayunan_dari_lompatan(kecepatan_x_player: float, arah_hadap: float) -> void:
	var dorongan_awal: float = kecepatan_x_player / max(panjang_tali, 100.0)
	if abs(dorongan_awal) < 0.85:
		dorongan_awal = arah_hadap * 1.75
	kecepatan_sudut += dorongan_awal * 1.4


func beri_dorongan(arah_x: float, delta: float) -> void:
	if arah_x != 0.0:
		kecepatan_sudut += arah_x * kekuatan_pompa * delta


func get_posisi_pegangan() -> Vector2:
	return grab_area.global_position


func get_sudut_ujung() -> float:
	return sudut_sekarang - (lengkungan_sekarang / max(panjang_tali, 100.0)) * 0.85


func get_kecepatan_lontar() -> Vector2:
	var arah_ayun: float = sign(kecepatan_sudut)
	if arah_ayun == 0.0:
		arah_ayun = sign(-sudut_sekarang) if sudut_sekarang != 0.0 else 1.0
	var tenaga_horizontal: float = clamp(abs(kecepatan_sudut) * panjang_tali * 1.35, 360.0, 620.0)
	return Vector2(arah_ayun * tenaga_horizontal, -600.0)
