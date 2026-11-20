extends CanvasLayer

signal puzzle_selesai

@onready var board: Control = $Board
@onready var line_trace: Line2D = $Board/LineTrace
@onready var points_parent: Node2D = $Board/Points

var edges_target: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, 2), # Atap ke Kiri & Kanan
	Vector2i(1, 3), Vector2i(2, 3), # Kiri & Kanan ke Tengah
	Vector2i(1, 4), Vector2i(2, 4)  # Kiri & Kanan ke Bawah
]

var edges_tergambar: Array[Vector2i] = []
var urutan_titik_aktif: Array[int] = []
var index_titik_terakhir: int = -1
var sedang_menarik: bool = false
var sudah_menang: bool = false
var radius_deteksi: float = 42.0

var overlay_draw: Node2D
var label_judul: Label
var label_status: Label
var indikator_kristal: Array[ColorRect] = []

var posisi_mouse_lokal: Vector2 = Vector2.ZERO
var waktu_animasi: float = 0.0
var waktu_menang: float = 0.0
var posisi_awal_board: Vector2 = Vector2.ZERO
var kunang_kunang: Array[Dictionary] = []
var efek_gelombang: Array[Dictionary] = []


func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if line_trace:
		line_trace.clear_points()
		line_trace.visible = false

	bangun_atmosfer_jungle()
	siapkan_kunang_kunang()
	animasi_masuk_board()


func bangun_atmosfer_jungle() -> void:
	# 1. Latar kabut rimba gelap di belakang prasasti
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.07, 0.06, 0.84)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)

	# 2. Kanvas Node2D khusus di atas $Board untuk ukiran, rune, dan efek energi
	overlay_draw = Node2D.new()
	overlay_draw.name = "JungleRuneOverlay"
	overlay_draw.z_index = 5
	overlay_draw.draw.connect(_on_overlay_draw)
	board.add_child(overlay_draw)

	# 3. Header Judul & Petunjuk di atas prasasti batu
	var header_box := VBoxContainer.new()
	header_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_box.offset_top = 18.0
	header_box.offset_bottom = 96.0
	header_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header_box.add_theme_constant_override("separation", 4)
	header_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_box)

	label_judul = Label.new()
	label_judul.text = "✦  SEGEL ALTAR RIMBA KUNO  ✦"
	label_judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_judul.add_theme_font_size_override("font_size", 24)
	label_judul.add_theme_color_override("font_color", Color(0.58, 0.96, 0.78))
	label_judul.add_theme_color_override("font_shadow_color", Color(0.02, 0.12, 0.08, 0.95))
	label_judul.add_theme_constant_override("shadow_offset_y", 2)
	header_box.add_child(label_judul)

	label_status = Label.new()
	label_status.text = "Tahan klik kiri dan hubungkan semua 6 jalur rune tanpa putus"
	label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_status.add_theme_font_size_override("font_size", 14)
	label_status.add_theme_color_override("font_color", Color(0.84, 0.94, 0.88))
	label_status.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label_status.add_theme_constant_override("shadow_offset_y", 1)
	header_box.add_child(label_status)

	# 4. Indikator 6 Kristal Progres di bagian bawah layar
	var footer_center := CenterContainer.new()
	footer_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer_center.offset_top = -72.0
	footer_center.offset_bottom = -20.0
	footer_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer_center)

	var pill_panel := PanelContainer.new()
	pill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style_pill := StyleBoxFlat.new()
	style_pill.bg_color = Color(0.05, 0.11, 0.09, 0.92)
	style_pill.border_color = Color(0.28, 0.78, 0.62, 0.75)
	style_pill.set_border_width_all(2)
	style_pill.set_corner_radius_all(12)
	style_pill.set_content_margin_all(10)
	pill_panel.add_theme_stylebox_override("panel", style_pill)
	footer_center.add_child(pill_panel)

	var hbox_prog := HBoxContainer.new()
	hbox_prog.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_prog.add_theme_constant_override("separation", 12)
	hbox_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_panel.add_child(hbox_prog)

	var lbl_prog := Label.new()
	lbl_prog.text = "SEGEL RUNE:"
	lbl_prog.add_theme_font_size_override("font_size", 13)
	lbl_prog.add_theme_color_override("font_color", Color(0.72, 0.90, 0.82))
	hbox_prog.add_child(lbl_prog)

	indikator_kristal.clear()
	for i in range(edges_target.size()):
		var permata := ColorRect.new()
		permata.custom_minimum_size = Vector2(14, 14)
		permata.pivot_offset = Vector2(7, 7)
		permata.rotation = deg_to_rad(45.0)
		permata.color = Color(0.16, 0.26, 0.24, 0.9)
		permata.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox_prog.add_child(permata)
		indikator_kristal.append(permata)


func animasi_masuk_board() -> void:
	await get_tree().process_frame
	if not is_instance_valid(board):
		return
	posisi_awal_board = board.position
	board.pivot_offset = board.size * 0.5
	board.scale = Vector2(0.86, 0.86)
	board.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(board, "scale", Vector2.ONE, 0.30)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(board, "modulate:a", 1.0, 0.22)


func siapkan_kunang_kunang() -> void:
	kunang_kunang.clear()
	var ukuran_layar: Vector2 = get_viewport().get_visible_rect().size
	if ukuran_layar == Vector2.ZERO:
		ukuran_layar = Vector2(1200.0, 750.0)

	for i in range(26):
		kunang_kunang.append({
			"pos": Vector2(randf_range(20.0, ukuran_layar.x - 20.0), randf_range(20.0, ukuran_layar.y - 20.0)),
			"vel": Vector2(randf_range(-16.0, 16.0), randf_range(-22.0, -8.0)),
			"radius": randf_range(2.0, 4.2),
			"phase": randf_range(0.0, TAU),
			"emas": randf() < 0.45
		})


func _process(delta: float) -> void:
	waktu_animasi += delta
	if sudah_menang:
		waktu_menang += delta

	# Update gelombang kejut saat titik rune aktif
	for i in range(efek_gelombang.size() - 1, -1, -1):
		var t_sekarang: float = efek_gelombang[i]["t"]
		t_sekarang += delta * 2.2
		if t_sekarang >= 1.0:
			efek_gelombang.remove_at(i)
		else:
			efek_gelombang[i]["t"] = t_sekarang

	# Update gerakan melayang kunang-kunang rimba
	var ukuran_layar: Vector2 = get_viewport().get_visible_rect().size
	if ukuran_layar == Vector2.ZERO:
		ukuran_layar = Vector2(1200.0, 750.0)

	for k in kunang_kunang:
		var pos_k: Vector2 = k["pos"]
		var vel_k: Vector2 = k["vel"]
		var phase_k: float = k["phase"]

		pos_k += vel_k * delta
		pos_k.x += sin(waktu_animasi * 1.6 + phase_k) * 14.0 * delta
		if pos_k.y < 10.0:
			pos_k.y = ukuran_layar.y - 10.0
			pos_k.x = randf_range(20.0, ukuran_layar.x - 20.0)
		k["pos"] = pos_k

	if is_instance_valid(overlay_draw):
		overlay_draw.queue_redraw()


func _input(event: InputEvent) -> void:
	if sudah_menang or not is_instance_valid(overlay_draw):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		posisi_mouse_lokal = overlay_draw.get_local_mouse_position()
		if event.is_pressed():
			sedang_menarik = true
			cek_sentuhan_titik(posisi_mouse_lokal)
			get_viewport().set_input_as_handled()
		else:
			if sedang_menarik:
				sedang_menarik = false
				if edges_tergambar.size() < edges_target.size() and not sudah_menang:
					reset_puzzle(urutan_titik_aktif.size() > 1)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		posisi_mouse_lokal = overlay_draw.get_local_mouse_position()
		if sedang_menarik:
			cek_sentuhan_titik(posisi_mouse_lokal)


func get_pos_titik_lokal(idx: int) -> Vector2:
	var titik_node := points_parent.get_child(idx) as Node2D
	if not titik_node:
		return Vector2.ZERO
	return overlay_draw.to_local(titik_node.global_position)


func is_edge_valid_next(dari: int, ke: int) -> bool:
	if dari == -1 or dari == ke:
		return false
	var edge := Vector2i(mini(dari, ke), maxi(dari, ke))
	return (edge in edges_target) and not (edge in edges_tergambar)


func ada_langkah_tersisa(dari: int) -> bool:
	var total_titik := points_parent.get_child_count()
	for i in range(total_titik):
		if is_edge_valid_next(dari, i):
			return true
	return false


func cek_sentuhan_titik(pos_lokal_mouse: Vector2) -> void:
	if sudah_menang:
		return

	var total_titik := points_parent.get_child_count()
	for i in range(total_titik):
		var pos_titik: Vector2 = get_pos_titik_lokal(i)
		if pos_lokal_mouse.distance_to(pos_titik) <= radius_deteksi:
			if index_titik_terakhir == -1:
				index_titik_terakhir = i
				urutan_titik_aktif.append(i)
				tambah_gelombang(pos_titik, Color(0.30, 0.95, 0.85))
				perbarui_status_teks()
			elif index_titik_terakhir != i:
				sambung_titik(index_titik_terakhir, i, pos_titik)
			break


func sambung_titik(dari: int, ke: int, pos_lokal_tujuan: Vector2) -> void:
	var edge := Vector2i(mini(dari, ke), maxi(dari, ke))

	if edge in edges_target and not (edge in edges_tergambar):
		edges_tergambar.append(edge)
		urutan_titik_aktif.append(ke)
		index_titik_terakhir = ke
		tambah_gelombang(pos_lokal_tujuan, Color(0.35, 1.0, 0.72))
		perbarui_indikator_kristal()

		if edges_tergambar.size() == edges_target.size():
			sudah_menang = true
			sedang_menarik = false
			label_status.text = "✦ SEGEL ALTAR TERBUKA! PORTAL RIMBA AKTIF ✦"
			label_status.add_theme_color_override("font_color", Color(0.45, 1.0, 0.72))

			for i in range(points_parent.get_child_count()):
				tambah_gelombang(get_pos_titik_lokal(i), Color(0.45, 1.0, 0.75))

			await get_tree().create_timer(0.95).timeout
			puzzle_selesai.emit()
			queue_free()
		else:
			perbarui_status_teks()


func perbarui_status_teks() -> void:
	if index_titik_terakhir != -1 and not ada_langkah_tersisa(index_titik_terakhir):
		label_status.text = "Jalur buntu! Lepas klik untuk mengulang (mulai dari simpul kiri atau kanan)"
		label_status.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	else:
		label_status.text = "Tersambung %d / %d jalur rune — teruskan tanpa melepas klik!" % [edges_tergambar.size(), edges_target.size()]
		label_status.add_theme_color_override("font_color", Color(0.55, 0.96, 0.86))


func perbarui_indikator_kristal() -> void:
	for i in range(indikator_kristal.size()):
		var permata := indikator_kristal[i]
		if i < edges_tergambar.size():
			permata.color = Color(0.32, 1.0, 0.76, 1.0)
			permata.scale = Vector2(1.22, 1.22)
		else:
			permata.color = Color(0.16, 0.26, 0.24, 0.9)
			permata.scale = Vector2.ONE


func tambah_gelombang(pos: Vector2, warna: Color) -> void:
	efek_gelombang.append({"pos": pos, "warna": warna, "t": 0.0})


func reset_puzzle(dengan_getar: bool = false) -> void:
	sedang_menarik = false
	index_titik_terakhir = -1
	edges_tergambar.clear()
	urutan_titik_aktif.clear()
	perbarui_indikator_kristal()

	if dengan_getar and is_instance_valid(board):
		label_status.text = "Jalur terputus! Coba mulai dari simpul kiri atau kanan"
		label_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		var tw := create_tween()
		tw.tween_property(board, "position:x", posisi_awal_board.x + 8.0, 0.04)
		tw.tween_property(board, "position:x", posisi_awal_board.x - 8.0, 0.04)
		tw.tween_property(board, "position:x", posisi_awal_board.x + 5.0, 0.04)
		tw.tween_property(board, "position:x", posisi_awal_board.x, 0.04)
	else:
		label_status.text = "Tahan klik kiri dan hubungkan semua 6 jalur rune tanpa putus"
		label_status.add_theme_color_override("font_color", Color(0.84, 0.94, 0.88))


func _on_overlay_draw() -> void:
	if not is_instance_valid(points_parent):
		return

	var total_titik := points_parent.get_child_count()
	if total_titik == 0:
		return

	var pos_titik_list: Array[Vector2] = []
	for i in range(total_titik):
		pos_titik_list.append(get_pos_titik_lokal(i))

	# 1. Gambar Ukiran Alur Batu (Target Edges yang belum terhubung)
	var fase_arus: float = fmod(waktu_animasi * 0.85, 1.0)
	for edge in edges_target:
		var p_awal: Vector2 = pos_titik_list[edge.x]
		var p_akhir: Vector2 = pos_titik_list[edge.y]
		var sudah_tersambung: bool = edge in edges_tergambar

		overlay_draw.draw_line(p_awal, p_akhir, Color(0.04, 0.06, 0.05, 0.75), 11.0)
		var warna_ukir: Color = Color(0.25, 0.75, 0.62, 0.45) if sudah_tersambung else Color(0.52, 0.64, 0.54, 0.42)
		overlay_draw.draw_line(p_awal, p_akhir, warna_ukir, 4.5)

		if not sudah_tersambung:
			var p_roh: Vector2 = p_awal.lerp(p_akhir, fase_arus)
			overlay_draw.draw_circle(p_roh, 2.6, Color(0.45, 0.95, 0.78, 0.55))

	# 2. Gambar Garis Bidik Elastis ke Kursor Mouse saat Menarik
	if sedang_menarik and index_titik_terakhir != -1 and not sudah_menang:
		var p_asal: Vector2 = pos_titik_list[index_titik_terakhir]
		var p_target: Vector2 = posisi_mouse_lokal
		var mengunci_target: bool = false

		for i in range(total_titik):
			if is_edge_valid_next(index_titik_terakhir, i):
				if posisi_mouse_lokal.distance_to(pos_titik_list[i]) <= radius_deteksi * 1.15:
					p_target = pos_titik_list[i]
					mengunci_target = true
					break

		var warna_bidik: Color = Color(0.45, 1.0, 0.75, 0.75) if mengunci_target else Color(0.30, 0.88, 0.95, 0.45)
		overlay_draw.draw_line(p_asal, p_target, warna_bidik * Color(1, 1, 1, 0.35), 14.0)
		overlay_draw.draw_line(p_asal, p_target, warna_bidik, 4.0)
		overlay_draw.draw_circle(p_target, 6.0 if mengunci_target else 4.0, warna_bidik)

	# 3. Gambar Berkas Energi Mana Zamrud-Cyan Berlapis pada Jalur yang Sudah Tersambung
	var denyut: float = 0.86 + 0.14 * sin(waktu_animasi * 6.0)
	var fase_percikan: float = fmod(waktu_animasi * 2.2, 1.0)

	for i in range(urutan_titik_aktif.size() - 1):
		var p1: Vector2 = pos_titik_list[urutan_titik_aktif[i]]
		var p2: Vector2 = pos_titik_list[urutan_titik_aktif[i + 1]]

		var warna_aura: Color = Color(0.18, 0.95, 0.68, 0.28 * denyut) if sudah_menang else Color(0.12, 0.85, 0.95, 0.26 * denyut)
		var warna_utama: Color = Color(0.28, 1.0, 0.74, 0.95) if sudah_menang else Color(0.18, 0.90, 1.0, 0.95)
		var warna_inti: Color = Color(0.92, 1.0, 0.96, denyut)

		overlay_draw.draw_line(p1, p2, warna_aura, 20.0)
		overlay_draw.draw_line(p1, p2, warna_utama, 8.5)
		overlay_draw.draw_line(p1, p2, warna_inti, 3.2)

		var p_spark: Vector2 = p1.lerp(p2, fase_percikan)
		overlay_draw.draw_circle(p_spark, 4.2, Color(1.0, 1.0, 1.0, 0.9))

	# 4. Gambar Gelombang Kejut (Ripple) saat Simpul Tersambung
	for g in efek_gelombang:
		var t_val: float = g["t"]
		var pos_g: Vector2 = g["pos"]
		var col: Color = g["warna"]
		var rad: float = lerpf(14.0, 52.0, t_val)
		col.a = (1.0 - t_val) * 0.85
		overlay_draw.draw_arc(pos_g, rad, 0.0, TAU, 32, col, 3.0 * (1.0 - t_val) + 1.0)

	# 5. Gambar 5 Medalion Kristal Rune di Setiap Titik Simpul
	for i in range(total_titik):
		var pos: Vector2 = pos_titik_list[i]
		var pernah_dikunjungi: bool = i in urutan_titik_aktif
		var adalah_ujung_aktif: bool = (index_titik_terakhir == i and sedang_menarik)
		var adalah_target_valid: bool = (sedang_menarik and is_edge_valid_next(index_titik_terakhir, i))

		if adalah_target_valid:
			var rad_target: float = 22.0 + 3.5 * sin(waktu_animasi * 7.0)
			overlay_draw.draw_arc(pos, rad_target, 0.0, TAU, 32, Color(1.0, 0.88, 0.35, 0.9), 2.5)

		overlay_draw.draw_circle(pos + Vector2(0, 2), 16.5, Color(0.02, 0.04, 0.03, 0.75))
		overlay_draw.draw_circle(pos, 15.5, Color(0.08, 0.14, 0.12, 0.96))

		var warna_bingkai: Color = Color(0.32, 0.96, 0.76) if pernah_dikunjungi else Color(0.42, 0.62, 0.54)
		if adalah_ujung_aktif:
			warna_bingkai = Color(1.0, 0.92, 0.45)
		overlay_draw.draw_arc(pos, 15.5, 0.0, TAU, 28, warna_bingkai, 2.2)

		var arah_putar: float = 1.4 if (i % 2 == 0) else -1.4
		var sudut_mulai: float = waktu_animasi * arah_putar + float(i)
		overlay_draw.draw_arc(pos, 19.5, sudut_mulai, sudut_mulai + PI * 0.65, 16, warna_bingkai * Color(1, 1, 1, 0.45), 1.5)
		overlay_draw.draw_arc(pos, 19.5, sudut_mulai + PI, sudut_mulai + PI * 1.65, 16, warna_bingkai * Color(1, 1, 1, 0.45), 1.5)

		var r_permata: float = 9.5 if (pernah_dikunjungi or adalah_ujung_aktif) else 7.2
		var titik_permata := PackedVector2Array([
			pos + Vector2(0, -r_permata),
			pos + Vector2(r_permata, 0),
			pos + Vector2(0, r_permata),
			pos + Vector2(-r_permata, 0)
		])
		var warna_permata: Color = Color(0.28, 1.0, 0.76) if pernah_dikunjungi else Color(0.24, 0.68, 0.64)
		if adalah_ujung_aktif:
			warna_permata = Color(0.55, 1.0, 0.92)
		overlay_draw.draw_polygon(titik_permata, PackedColorArray([warna_permata]))

		overlay_draw.draw_circle(pos, 3.0 if pernah_dikunjungi else 2.0, Color(0.95, 1.0, 0.98, 0.95))

	# 6. Gambar Kunang-Kunang Rimba Melayang di Sekitar Prasasti
	for k in kunang_kunang:
		var pos_k: Vector2 = k["pos"]
		var phase_k: float = k["phase"]
		var radius_k: float = k["radius"]
		var emas_k: bool = k["emas"]

		var p_lokal: Vector2 = overlay_draw.to_local(pos_k)
		var kedip: float = 0.35 + 0.45 * sin(waktu_animasi * 3.2 + phase_k)
		var col_k: Color = Color(0.92, 1.0, 0.45, kedip) if emas_k else Color(0.35, 1.0, 0.75, kedip)
		overlay_draw.draw_circle(p_lokal, radius_k * 2.2, col_k * Color(1, 1, 1, 0.25))
		overlay_draw.draw_circle(p_lokal, radius_k, col_k)
