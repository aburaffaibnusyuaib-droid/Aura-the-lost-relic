extends Control

# Sinyal komunikasi ke sistem portal Level 3
signal puzzle_selesai

# Konfigurasi dimensi papan labirin 5x5
const UKURAN_GRID: int = 5
const UKURAN_SEL: float = 72.0

# Peta labirin: 0 = jalur energi terbuka, 1 = batu segel penghalang
const PETA: Array = [
	[0, 0, 1, 0, 0],
	[0, 1, 0, 0, 0],
	[0, 0, 0, 1, 0],
	[0, 0, 1, 0, 0],
	[0, 0, 0, 0, 0]
]

# Koordinat awal dan cincin target masing-masing aura (100% dapat diselesaikan dalam 8 langkah)
const AWAL_MERAH: Vector2i = Vector2i(0, 4)
const AWAL_BIRU: Vector2i = Vector2i(4, 0)
const TARGET_MERAH: Vector2i = Vector2i(4, 1)
const TARGET_BIRU: Vector2i = Vector2i(0, 3)

# Palet warna standar aura Rhein
const WARNA_MERAH := Color(1.0, 0.22, 0.30, 1.0)
const WARNA_BIRU := Color(0.18, 0.72, 1.0, 1.0)
const WARNA_EMAS := Color(1.0, 0.84, 0.32, 1.0)

# Status logika permainan
var pos_merah: Vector2i = AWAL_MERAH
var pos_biru: Vector2i = AWAL_BIRU
var jumlah_langkah: int = 0
var sudah_menang: bool = false

# Status animasi visual, jejak cahaya, dan efek klimaks
var visual_merah: Vector2 = Vector2(AWAL_MERAH)
var visual_biru: Vector2 = Vector2(AWAL_BIRU)
var jejak_merah: Array[Vector2] = []
var jejak_biru: Array[Vector2] = []
var waktu_animasi: float = 0.0
var waktu_getar: float = 0.0
var progress_menang: float = 0.0
var radius_gelombang: float = 0.0
var flash_putih: float = 0.0

# Status interaksi mouse & tombol layar
var posisi_dasar: Vector2 = Vector2.ZERO
var area_tombol: Dictionary = {}
var tombol_hover: String = ""
var sel_hover: Vector2i = Vector2i(-1, -1)
var tween_popup: Tween = null


# Inisialisasi awal node kontrol puzzle
func _ready() -> void:
	posisi_dasar = position
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_papan(false)


# Dipanggil oleh portal saat memunculkan popup puzzle dengan animasi buka yang halus
func buka_papan() -> void:
	reset_papan(false)
	pivot_offset = get_viewport_rect().size * 0.5
	scale = Vector2(0.86, 0.86)
	modulate.a = 0.0

	if tween_popup and tween_popup.is_valid():
		tween_popup.kill()

	tween_popup = create_tween().set_parallel(true)
	tween_popup.tween_property(self, "scale", Vector2.ONE, 0.32)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_popup.tween_property(self, "modulate:a", 1.0, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Update animasi halus untuk rotasi rune, jejak aura, getaran, dan efek menang
func _process(delta: float) -> void:
	if not visible:
		return

	waktu_animasi += delta

	# Interpolasi posisi visual bola agar meluncur mulus antar-kotak
	var kecepatan_luncur_visual: float = clampf(delta * 18.0, 0.0, 1.0)
	visual_merah = visual_merah.lerp(Vector2(pos_merah), kecepatan_luncur_visual)
	visual_biru = visual_biru.lerp(Vector2(pos_biru), kecepatan_luncur_visual)

	# Simpan titik jejak cahaya (aura trail) di belakang kedua bola
	jejak_merah.push_front(visual_merah)
	if jejak_merah.size() > 10:
		jejak_merah.pop_back()

	jejak_biru.push_front(visual_biru)
	if jejak_biru.size() > 10:
		jejak_biru.pop_back()

	# Efek getar papan saat menabrak batu penghalang atau menekan reset
	if waktu_getar > 0.0:
		waktu_getar -= delta
		var intensitas: float = clampf(waktu_getar * 42.0, 2.0, 9.0)
		position = posisi_dasar + Vector2(randf_range(-intensitas, intensitas), randf_range(-intensitas, intensitas))
		if waktu_getar <= 0.0:
			position = posisi_dasar

	# Animasi gelombang kejut dan kilatan cahaya saat kedua aura menyatu
	if sudah_menang:
		progress_menang = minf(progress_menang + delta * 1.8, 1.0)
		radius_gelombang += delta * 620.0
		flash_putih = maxf(flash_putih - delta * 1.6, 0.0)

	queue_redraw()


# Deteksi hover dan klik mouse pada tombol kontrol maupun petak papan
func _gui_input(event: InputEvent) -> void:
	if not visible or sudah_menang:
		return

	if event is InputEventMouseMotion:
		var pos_mouse: Vector2 = event.position
		tombol_hover = ""
		for id_btn in area_tombol.keys():
			var rect_btn: Rect2 = area_tombol[id_btn]
			if rect_btn.has_point(pos_mouse):
				tombol_hover = str(id_btn)
				break

		var mulai: Vector2 = hitung_titik_mulai()
		var gx: int = floori((pos_mouse.x - mulai.x) / UKURAN_SEL)
		var gy: int = floori((pos_mouse.y - mulai.y) / UKURAN_SEL)
		if gx >= 0 and gx < UKURAN_GRID and gy >= 0 and gy < UKURAN_GRID:
			sel_hover = Vector2i(gx, gy)
		else:
			sel_hover = Vector2i(-1, -1)

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var klik: Vector2 = event.position

		# Cek klik pada bar tombol arah atau reset
		for id_btn in area_tombol.keys():
			var rect_btn: Rect2 = area_tombol[id_btn]
			if rect_btn.has_point(klik):
				match str(id_btn):
					"kiri":
						gerakkan_bola(Vector2i.LEFT)
					"kanan":
						gerakkan_bola(Vector2i.RIGHT)
					"atas":
						gerakkan_bola(Vector2i.UP)
					"bawah":
						gerakkan_bola(Vector2i.DOWN)
					"reset":
						reset_papan(true)
				accept_event()
				return

		# Klik petak tepat di sebelah bola Merah atau Biru untuk menggerakkannya
		var mulai: Vector2 = hitung_titik_mulai()
		var sel_klik := Vector2i(
			floori((klik.x - mulai.x) / UKURAN_SEL),
			floori((klik.y - mulai.y) / UKURAN_SEL)
		)

		var selisih_merah: Vector2i = sel_klik - pos_merah
		if absi(selisih_merah.x) + absi(selisih_merah.y) == 1:
			gerakkan_bola(selisih_merah)
			accept_event()
			return

		var selisih_biru: Vector2i = pos_biru - sel_klik
		if absi(selisih_biru.x) + absi(selisih_biru.y) == 1:
			gerakkan_bola(selisih_biru)
			accept_event()


# Kontrol keyboard penuh (WASD / Tombol Panah, R untuk Reset)
func _unhandled_input(event: InputEvent) -> void:
	if not visible or sudah_menang:
		return

	if event.is_action_pressed("jalan_kiri") or event.is_action_pressed("ui_left"):
		gerakkan_bola(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jalan_kanan") or event.is_action_pressed("ui_right"):
		gerakkan_bola(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("leader_up") or event.is_action_pressed("ui_up"):
		gerakkan_bola(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("leader_down") or event.is_action_pressed("ui_down"):
		gerakkan_bola(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		reset_papan(true)
		get_viewport().set_input_as_handled()


# Menggerakkan bola Merah searah input dan bola Biru berlawanan arah (cermin)
func gerakkan_bola(arah: Vector2i) -> void:
	if sudah_menang:
		return

	var calon_merah: Vector2i = pos_merah + arah
	var calon_biru: Vector2i = pos_biru - arah

	var merah_bisa: bool = sel_valid(calon_merah)
	var biru_bisa: bool = sel_valid(calon_biru)

	if not merah_bisa or not biru_bisa:
		picu_getar(0.16)

	if merah_bisa or biru_bisa:
		jumlah_langkah += 1
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_puzzle_click"):
			am.play_puzzle_click()

	if merah_bisa:
		pos_merah = calon_merah
	if biru_bisa:
		pos_biru = calon_biru

	cek_kemenangan()


# Validasi batas papan dan batu penghalang
func sel_valid(koordinat: Vector2i) -> bool:
	if koordinat.x < 0 or koordinat.x >= UKURAN_GRID or koordinat.y < 0 or koordinat.y >= UKURAN_GRID:
		return false
	return PETA[koordinat.y][koordinat.x] == 0


# Mengembalikan posisi kedua bola ke titik awal
func reset_papan(dengan_getar: bool = true) -> void:
	pos_merah = AWAL_MERAH
	pos_biru = AWAL_BIRU
	visual_merah = Vector2(AWAL_MERAH)
	visual_biru = Vector2(AWAL_BIRU)
	jejak_merah.clear()
	jejak_biru.clear()
	jumlah_langkah = 0
	sudah_menang = false
	progress_menang = 0.0
	radius_gelombang = 0.0
	flash_putih = 0.0
	if dengan_getar:
		picu_getar(0.20)
	queue_redraw()


# Memicu efek getaran pada altar puzzle
func picu_getar(durasi: float) -> void:
	waktu_getar = durasi


# Mengecek apakah kedua bola telah masuk ke cincin segel masing-masing secara bersamaan
func cek_kemenangan() -> void:
	if pos_merah == TARGET_MERAH and pos_biru == TARGET_BIRU:
		sudah_menang = true
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_puzzle_win"):
			am.play_puzzle_win()
		flash_putih = 0.65
		picu_getar(0.32)

		await get_tree().create_timer(1.15, true).timeout
		if not is_inside_tree():
			return

		pivot_offset = get_viewport_rect().size * 0.5
		var tween_keluar := create_tween().set_parallel(true)
		tween_keluar.tween_property(self, "scale", Vector2(1.08, 1.08), 0.30)
		tween_keluar.tween_property(self, "modulate:a", 0.0, 0.30)
		await tween_keluar.finished
		puzzle_selesai.emit()


# Menghitung persentase kedekatan kedua bola terhadap targetnya (0% - 100%)
func hitung_resonansi() -> float:
	var jarak_awal: float = float(absi(AWAL_MERAH.x - TARGET_MERAH.x) + absi(AWAL_MERAH.y - TARGET_MERAH.y) + absi(AWAL_BIRU.x - TARGET_BIRU.x) + absi(AWAL_BIRU.y - TARGET_BIRU.y))
	var jarak_sisa: float = float(absi(pos_merah.x - TARGET_MERAH.x) + absi(pos_merah.y - TARGET_MERAH.y) + absi(pos_biru.x - TARGET_BIRU.x) + absi(pos_biru.y - TARGET_BIRU.y))
	if jarak_awal <= 0.0:
		return 1.0
	return clampf(1.0 - (jarak_sisa / jarak_awal), 0.0, 1.0)


# Menghitung koordinat sudut kiri-atas papan grid 5x5 agar selalu presisi di tengah layar
func hitung_titik_mulai() -> Vector2:
	var ukuran_layar: Vector2 = get_viewport_rect().size
	var total_papan: float = float(UKURAN_GRID) * UKURAN_SEL
	return (ukuran_layar - Vector2(total_papan, total_papan)) * 0.5 - Vector2(0.0, 12.0)


# Render seluruh visual altar, cincin rune, bola aura, sinar energi, dan kontrol UI
func _draw() -> void:
	var ukuran_layar: Vector2 = get_viewport_rect().size
	var total_papan: float = float(UKURAN_GRID) * UKURAN_SEL
	var titik_mulai: Vector2 = hitung_titik_mulai()
	var pusat_papan: Vector2 = titik_mulai + Vector2(total_papan * 0.5, total_papan * 0.5)
	var font: Font = ThemeDB.fallback_font

	# 1. Lingkaran sihir raksasa berputar di belakang altar
	var sudut_luar: float = waktu_animasi * 0.35
	var sudut_dalam: float = -waktu_animasi * 0.55
	draw_arc(pusat_papan, total_papan * 0.72, sudut_luar, sudut_luar + TAU, 64, Color(0.35, 0.70, 1.0, 0.14), 2.0)
	draw_arc(pusat_papan, total_papan * 0.66, sudut_dalam, sudut_dalam + TAU, 48, Color(1.0, 0.30, 0.40, 0.12), 1.5)
	for k in range(8):
		var a: float = sudut_luar + (float(k) * TAU / 8.0)
		var p_in: Vector2 = pusat_papan + Vector2(cos(a), sin(a)) * (total_papan * 0.66)
		var p_out: Vector2 = pusat_papan + Vector2(cos(a), sin(a)) * (total_papan * 0.72)
		draw_line(p_in, p_out, Color(0.65, 0.85, 1.0, 0.22), 2.0)

	# 2. Bingkai batu relik utama
	var bingkai_luar := Rect2(titik_mulai - Vector2(28.0, 96.0), Vector2(total_papan + 56.0, total_papan + 178.0))
	draw_rect(Rect2(bingkai_luar.position + Vector2(6.0, 8.0), bingkai_luar.size), Color(0.0, 0.0, 0.0, 0.55), true)
	draw_rect(bingkai_luar, Color(0.07, 0.09, 0.16, 0.97), true)

	var warna_bingkai: Color = WARNA_EMAS if sudah_menang else Color(0.42, 0.76, 1.0, 0.88)
	draw_rect(bingkai_luar, warna_bingkai, false, 3.0)
	draw_rect(Rect2(bingkai_luar.position + Vector2(5.0, 5.0), bingkai_luar.size - Vector2(10.0, 10.0)), Color(0.42, 0.76, 1.0, 0.22), false, 1.0)

	# Sudut ornamen emas pada keempat pojok bingkai
	var ukuran_sudut: float = 14.0
	var pojok_list: Array[Vector2] = [
		bingkai_luar.position,
		bingkai_luar.position + Vector2(bingkai_luar.size.x - ukuran_sudut, 0.0),
		bingkai_luar.position + Vector2(0.0, bingkai_luar.size.y - ukuran_sudut),
		bingkai_luar.position + bingkai_luar.size - Vector2(ukuran_sudut, ukuran_sudut)
	]
	for p_sudut in pojok_list:
		draw_rect(Rect2(p_sudut, Vector2(ukuran_sudut, ukuran_sudut)), warna_bingkai, true)

	# 3. Header judul, status aura, dan bar resonansi
	var teks_judul: String = "SEGEL GERBANG TERBUKA!" if sudah_menang else "SEGEL AURA KEMBAR"
	var warna_judul: Color = WARNA_EMAS if sudah_menang else Color(0.95, 0.98, 1.0, 1.0)
	draw_string(font, titik_mulai + Vector2(-8.0, -68.0), teks_judul, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, warna_judul)
	draw_string(font, titik_mulai + Vector2(total_papan - 88.0, -68.0), "LANGKAH: %d" % jumlah_langkah, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.68, 0.80, 0.95))

	var merah_di_target: bool = (pos_merah == TARGET_MERAH)
	var biru_di_target: bool = (pos_biru == TARGET_BIRU)
	var status_m: String = "MERAH: TERKUNCI" if merah_di_target else "MERAH: SEARAH"
	var status_b: String = "BIRU: TERKUNCI" if biru_di_target else "BIRU: CERMIN"
	draw_string(font, titik_mulai + Vector2(-8.0, -45.0), status_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WARNA_EMAS if merah_di_target else WARNA_MERAH)
	draw_string(font, titik_mulai + Vector2(total_papan - 102.0, -45.0), status_b, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WARNA_EMAS if biru_di_target else WARNA_BIRU)

	# Bar progres resonansi energi di bawah header
	var resonansi: float = 1.0 if sudah_menang else hitung_resonansi()
	var rect_bar_bg := Rect2(titik_mulai + Vector2(-8.0, -32.0), Vector2(total_papan + 16.0, 12.0))
	draw_rect(rect_bar_bg, Color(0.13, 0.16, 0.26, 1.0), true)
	draw_rect(rect_bar_bg, Color(0.35, 0.55, 0.80, 0.5), false, 1.0)
	if resonansi > 0.0:
		var warna_isi: Color = WARNA_EMAS if sudah_menang else WARNA_MERAH.lerp(WARNA_BIRU, 0.5 + 0.5 * sin(waktu_animasi * 4.0))
		draw_rect(Rect2(rect_bar_bg.position + Vector2(2.0, 2.0), Vector2((rect_bar_bg.size.x - 4.0) * resonansi, rect_bar_bg.size.y - 4.0)), warna_isi, true)

	# 4. Gambar papan grid 5x5 dengan detail batu ukir dan jalur lantai
	for y in range(UKURAN_GRID):
		for x in range(UKURAN_GRID):
			var pos_sel: Vector2 = titik_mulai + Vector2(float(x), float(y)) * UKURAN_SEL
			var rect_sel := Rect2(pos_sel + Vector2(3.0, 3.0), Vector2(UKURAN_SEL - 6.0, UKURAN_SEL - 6.0))
			var koordinat_sel := Vector2i(x, y)

			if PETA[y][x] == 1:
				# Batu penghalang berdimensi dengan ukiran silang
				draw_rect(rect_sel, Color(0.22, 0.25, 0.36, 1.0), true)
				draw_rect(Rect2(rect_sel.position, Vector2(rect_sel.size.x, 5.0)), Color(0.38, 0.44, 0.60, 0.85), true)
				draw_rect(rect_sel, Color(0.45, 0.52, 0.68, 0.75), false, 2.0)
				var tengah_batu: Vector2 = rect_sel.get_center()
				draw_line(tengah_batu - Vector2(10.0, 10.0), tengah_batu + Vector2(10.0, 10.0), Color(0.14, 0.16, 0.24, 0.9), 2.5)
				draw_line(tengah_batu + Vector2(-10.0, 10.0), tengah_batu + Vector2(10.0, -10.0), Color(0.14, 0.16, 0.24, 0.9), 2.5)
			else:
				# Petak jalur energi
				var warna_lantai := Color(0.12, 0.15, 0.24, 1.0)
				if sel_hover == koordinat_sel and not sudah_menang:
					warna_lantai = Color(0.18, 0.23, 0.36, 1.0)
				draw_rect(rect_sel, warna_lantai, true)
				draw_rect(rect_sel, Color(0.24, 0.32, 0.48, 0.45), false, 1.0)

				# Penanda titik awal tipis agar pemain tahu asal masing-masing bola
				if koordinat_sel == AWAL_MERAH:
					draw_arc(rect_sel.get_center(), 8.0, 0.0, TAU, 16, Color(1.0, 0.25, 0.30, 0.28), 1.5)
				elif koordinat_sel == AWAL_BIRU:
					draw_arc(rect_sel.get_center(), 8.0, 0.0, TAU, 16, Color(0.20, 0.70, 1.0, 0.28), 1.5)

	# 5. Gambar cincin segel target Merah dan Biru dengan rotasi rune aktif
	var pusat_target_m: Vector2 = titik_mulai + (Vector2(TARGET_MERAH) + Vector2(0.5, 0.5)) * UKURAN_SEL
	var pusat_target_b: Vector2 = titik_mulai + (Vector2(TARGET_BIRU) + Vector2(0.5, 0.5)) * UKURAN_SEL
	var denyut: float = sin(waktu_animasi * 5.0) * 2.5

	gambar_cincin_target(pusat_target_m, WARNA_MERAH, merah_di_target or sudah_menang, denyut, waktu_animasi * 2.2)
	gambar_cincin_target(pusat_target_b, WARNA_BIRU, biru_di_target or sudah_menang, denyut, -waktu_animasi * 2.2)

	# 6. Gambar jejak cahaya (aura trail) dan kedua Bola Aura
	var pusat_m: Vector2 = titik_mulai + (visual_merah + Vector2(0.5, 0.5)) * UKURAN_SEL
	var pusat_b: Vector2 = titik_mulai + (visual_biru + Vector2(0.5, 0.5)) * UKURAN_SEL

	for idx in range(jejak_merah.size()):
		var faktor: float = 1.0 - (float(idx) / float(jejak_merah.size()))
		var pos_j_m: Vector2 = titik_mulai + (jejak_merah[idx] + Vector2(0.5, 0.5)) * UKURAN_SEL
		draw_circle(pos_j_m, 13.0 * faktor, Color(WARNA_MERAH.r, WARNA_MERAH.g, WARNA_MERAH.b, 0.22 * faktor))

	for idx in range(jejak_biru.size()):
		var faktor: float = 1.0 - (float(idx) / float(jejak_biru.size()))
		var pos_j_b: Vector2 = titik_mulai + (jejak_biru[idx] + Vector2(0.5, 0.5)) * UKURAN_SEL
		draw_circle(pos_j_b, 13.0 * faktor, Color(WARNA_BIRU.r, WARNA_BIRU.g, WARNA_BIRU.b, 0.22 * faktor))

	gambar_bola_aura(pusat_m, WARNA_MERAH, sudah_menang)
	gambar_bola_aura(pusat_b, WARNA_BIRU, sudah_menang)

	# 7. Efek klimaks saat menang: sinar energi menyatu ke tengah + gelombang kejut
	if sudah_menang:
		var titik_tengah_sinar: Vector2 = pusat_papan
		var ujung_m: Vector2 = pusat_m.lerp(titik_tengah_sinar, progress_menang)
		var ujung_b: Vector2 = pusat_b.lerp(titik_tengah_sinar, progress_menang)
		draw_line(pusat_m, ujung_m, WARNA_MERAH, 6.0)
		draw_line(pusat_m, ujung_m, Color.WHITE, 2.5)
		draw_line(pusat_b, ujung_b, WARNA_BIRU, 6.0)
		draw_line(pusat_b, ujung_b, Color.WHITE, 2.5)

		if progress_menang > 0.45:
			var skala_inti: float = (progress_menang - 0.45) / 0.55
			draw_circle(titik_tengah_sinar, 34.0 * skala_inti, Color(1.0, 0.95, 0.80, 0.45))
			draw_circle(titik_tengah_sinar, 18.0 * skala_inti, Color.WHITE)

		var alpha_gelombang: float = clampf(1.0 - (radius_gelombang / 520.0), 0.0, 0.85)
		if alpha_gelombang > 0.0:
			draw_arc(pusat_papan, radius_gelombang, 0.0, TAU, 64, Color(1.0, 0.96, 0.85, alpha_gelombang), 5.0)

	# 8. Gambar 5 tombol kontrol interaktif di bagian bawah bingkai (tanpa tombol Tutup)
	area_tombol.clear()
	var daftar_tombol: Array = [
		["kiri", "<"],
		["atas", "^"],
		["bawah", "v"],
		["kanan", ">"],
		["reset", "RESET"]
	]
	var lebar_kecil: float = 46.0
	var lebar_besar: float = 80.0
	var jarak_btn: float = 8.0
	var total_lebar_btn: float = (4.0 * lebar_kecil) + (1.0 * lebar_besar) + (4.0 * jarak_btn)
	var kursor_x: float = titik_mulai.x + (total_papan - total_lebar_btn) * 0.5
	var pos_y_btn: float = titik_mulai.y + total_papan + 18.0

	for item in daftar_tombol:
		var id_btn: String = str(item[0])
		var label_btn: String = str(item[1])
		var lebar_aktif: float = lebar_besar if id_btn == "reset" else lebar_kecil
		var rect_btn := Rect2(kursor_x, pos_y_btn, lebar_aktif, 40.0)
		area_tombol[id_btn] = rect_btn
		kursor_x += lebar_aktif + jarak_btn

		var sedang_hover: bool = (tombol_hover == id_btn)
		var warna_isi_btn := Color(0.16, 0.21, 0.33, 1.0)
		var warna_tepi_btn := Color(0.45, 0.72, 0.96, 0.75)

		if id_btn == "reset":
			warna_isi_btn = Color(0.32, 0.25, 0.14, 1.0) if sedang_hover else Color(0.22, 0.18, 0.11, 1.0)
			warna_tepi_btn = WARNA_EMAS
		elif sedang_hover:
			warna_isi_btn = Color(0.24, 0.34, 0.52, 1.0)
			warna_tepi_btn = Color.WHITE

		draw_rect(rect_btn, warna_isi_btn, true)
		draw_rect(rect_btn, warna_tepi_btn, false, 2.0)

		var ukuran_huruf: int = 12 if id_btn == "reset" else 16
		var offset_teks_x: float = (lebar_aktif - (float(label_btn.length()) * (7.5 if ukuran_huruf == 12 else 9.0))) * 0.5
		draw_string(font, rect_btn.position + Vector2(maxf(offset_teks_x, 6.0), 25.0), label_btn, HORIZONTAL_ALIGNMENT_LEFT, -1, ukuran_huruf, Color.WHITE)

	# 9. Kilatan cahaya putih lembut di layar saat segel terbuka
	if flash_putih > 0.0:
		draw_rect(Rect2(Vector2.ZERO, ukuran_layar), Color(1.0, 1.0, 1.0, flash_putih), true)


# Helper menggambar cincin segel target dengan segmen rune berputar
func gambar_cincin_target(pusat: Vector2, warna: Color, aktif: bool, denyut: float, sudut_putar: float) -> void:
	var warna_cincin: Color = WARNA_EMAS if aktif else warna
	var radius_dasar: float = 22.0 + (denyut * 0.6)
	draw_circle(pusat, radius_dasar + 3.0, Color(warna_cincin.r, warna_cincin.g, warna_cincin.b, 0.18 if aktif else 0.10))
	draw_arc(pusat, radius_dasar, 0.0, TAU, 36, warna_cincin, 3.0 if aktif else 2.2)

	# 4 segmen busur rune berputar di sekeliling lubang segel
	for s in range(4):
		var mulai_busur: float = sudut_putar + (float(s) * PI * 0.5)
		draw_arc(pusat, radius_dasar + 6.0, mulai_busur, mulai_busur + 0.55, 12, Color(warna_cincin.r, warna_cincin.g, warna_cincin.b, 0.85), 2.0)


# Helper menggambar bola aura berlapis cahaya (outer glow, inti warna, dan core putih)
func gambar_bola_aura(pusat: Vector2, warna: Color, menang: bool) -> void:
	if menang:
		draw_circle(pusat, 28.0, Color(1.0, 0.92, 0.65, 0.35))
		draw_circle(pusat, 19.0, Color(1.0, 1.0, 1.0, 0.70))
		draw_circle(pusat, 14.0, Color.WHITE)
	else:
		draw_circle(pusat, 25.0, Color(warna.r, warna.g, warna.b, 0.22))
		draw_circle(pusat, 18.0, Color(warna.r, warna.g, warna.b, 0.45))
		draw_circle(pusat, 14.0, warna)
		draw_circle(pusat - Vector2(4.0, 4.0), 4.5, Color(1.0, 1.0, 1.0, 0.75))
