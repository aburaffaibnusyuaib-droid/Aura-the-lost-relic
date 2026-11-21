extends Control

signal puzzle_selesai

# Pengaturan ukuran bingkai dan area papan pipa 5x5 di tengah layar
@export var ukuran_bingkai: float = 560.0
@export_range(0.18, 0.28, 0.002) var margin_bingkai_rasio: float = 0.228
@export var hapus_bg_hitam_bingkai: bool = true

const GRID_SIZE: int = 5

# Bitmask arah sambungan pipa: 1 = Atas, 2 = Kanan, 4 = Bawah, 8 = Kiri
const ARAH_ATAS: int = 1
const ARAH_KANAN: int = 2
const ARAH_BAWAH: int = 4
const ARAH_KIRI: int = 8

# Baris tengah (index 2) sejajar langsung dengan kristal cyan di sisi kiri & kanan bingkai
const BARIS_KONEKSI: int = 2

# Palet warna batu es gelap, logam rune, dan aliran mana cyan Level 2
const COL_DASAR_DALAM := Color("#0b0f1d")
const COL_PIPA_OUTLINE := Color("#060811")
const COL_PIPA_LOGAM := Color("#364363")
const COL_PIPA_HIGHLIGHT := Color("#637ab0")
const COL_PIPA_RONGGA := Color("#161d2e")
const COL_MANA_LUAR := Color("#179be6")
const COL_MANA_DALAM := Color("#6ef7ff")
const COL_MANA_INTI := Color("#ffffff")
const COL_EMAS := Color("#ffd954")

var grid: Array = []
var teraliri: Array = []
var sudut_visual: Array = []
var denyut_klik: Array = []
var jumlah_putaran: int = 0
var sudah_menang: bool = false
var waktu: float = 0.0
var progres_menang: float = 0.0
var waktu_getar: float = 0.0

# Kursor & interaksi mouse/keyboard
var kursor_grid: Vector2i = Vector2i(0, 2)
var pakai_kursor_keyboard: bool = false
var hover_sel: Vector2i = Vector2i(-1, -1)
var area_tombol_acak: Rect2 = Rect2()
var hover_tombol_acak: bool = false

# Sistem partikel atmosfer (salju, kristal melayang di samping layar, dan percikan klik)
var partikel_salju: Array[Dictionary] = []
var kristal_samping: Array[Dictionary] = []
var percikan_klik: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if hapus_bg_hitam_bingkai:
		bersihkan_background_hitam_bingkai()
	inisialisasi_atmosfer()
	buat_papan_baru()
	mainkan_animasi_buka()


# Animasi popup muncul mulus saat puzzle dibuka
func mainkan_animasi_buka() -> void:
	modulate.a = 0.0
	var frame := ambil_node_bingkai()
	if frame:
		frame.pivot_offset = frame.size * 0.5
		frame.scale = Vector2(0.88, 0.88)
		frame.modulate.a = 0.0
		var tw_frame := create_tween().set_parallel(true)
		tw_frame.tween_property(frame, "scale", Vector2.ONE, 0.32)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_frame.tween_property(frame, "modulate:a", 1.0, 0.24)

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Menghapus piksel hitam polos di luar bingkai batu agar menyatu dengan latar game
func bersihkan_background_hitam_bingkai() -> void:
	var frame := ambil_node_bingkai()
	if not frame or not frame.texture:
		return

	var img: Image = frame.texture.get_image()
	if not img:
		return

	img.convert(Image.FORMAT_RGBA8)
	var lebar: int = img.get_width()
	var tinggi: int = img.get_height()

	for y in range(tinggi):
		for x in range(lebar):
			var c: Color = img.get_pixel(x, y)
			var kecerahan: float = maxf(c.r, maxf(c.g, c.b))
			if kecerahan < 0.045:
				c.a = 0.0
				img.set_pixel(x, y, c)
			elif kecerahan < 0.085:
				c.a = clampf((kecerahan - 0.045) / 0.04, 0.0, 1.0)
				img.set_pixel(x, y, c)

	frame.texture = ImageTexture.create_from_image(img)


func ambil_node_bingkai() -> TextureRect:
	if get_parent():
		return get_parent().get_node_or_null("FrameBatu") as TextureRect
	return null


# Membuat partikel salju dan kristal es melayang untuk mengisi sisi kiri & kanan layar
func inisialisasi_atmosfer() -> void:
	partikel_salju.clear()
	krital_samping_init()
	var layar := Vector2(1200.0, 750.0)
	for i in range(55):
		partikel_salju.append({
			"pos": Vector2(randf_range(0.0, layar.x), randf_range(0.0, layar.y)),
			"vel": Vector2(randf_range(-18.0, 18.0), randf_range(22.0, 58.0)),
			"size": randf_range(1.5, 4.0),
			"alpha": randf_range(0.25, 0.75),
			"fase": randf_range(0.0, TAU)
		})


func krital_samping_init() -> void:
	kristal_samping.clear()
	var daftar_pos: Array[Vector2] = [
		Vector2(135.0, 210.0), Vector2(195.0, 385.0), Vector2(125.0, 545.0),
		Vector2(1065.0, 210.0), Vector2(1005.0, 385.0), Vector2(1075.0, 545.0)
	]
	for i in range(daftar_pos.size()):
		kristal_samping.append({
			"asal": daftar_pos[i],
			"ukuran": 16.0 if (i % 3 == 1) else 11.0,
			"fase": float(i) * 1.15,
			"ungu": (i >= 3)
		})


func _process(delta: float) -> void:
	if not visible:
		return

	waktu += delta
	var layar := get_viewport_rect().size

	# Update rotasi & pantulan klik tiap pipa
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if absf(sudut_visual[y][x]) > 0.004:
				sudut_visual[y][x] = lerpf(sudut_visual[y][x], 0.0, clampf(delta * 22.0, 0.0, 1.0))
				if absf(sudut_visual[y][x]) <= 0.004:
					sudut_visual[y][x] = 0.0
			if denyut_klik[y][x] > 0.0:
				denyut_klik[y][x] = maxf(denyut_klik[y][x] - delta * 3.5, 0.0)

	# Update partikel salju di seluruh layar
	for p in partikel_salju:
		p["pos"] += p["vel"] * delta
		p["pos"].x += sin(waktu * 1.8 + p["fase"]) * 12.0 * delta
		if p["pos"].y > layar.y + 10.0:
			p["pos"].y = -10.0
			p["pos"].x = randf_range(0.0, layar.x)

	# Update percikan energi saat pipa diputar atau diacak
	for i in range(percikan_klik.size() - 1, -1, -1):
		var sp: Dictionary = percikan_klik[i]
		sp["pos"] += sp["vel"] * delta
		sp["vel"] *= 0.92
		sp["umur"] -= delta * 2.4
		if sp["umur"] <= 0.0:
			percikan_klik.remove_at(i)

	# Efek getar ringan saat segel terbuka
	if waktu_getar > 0.0:
		waktu_getar -= delta
		var frame := ambil_node_bingkai()
		if frame:
			var pusat_layar := (layar - frame.size) * 0.5
			if waktu_getar > 0.0:
				frame.position = pusat_layar + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
			else:
				frame.position = pusat_layar

	if sudah_menang:
		progres_menang = minf(progres_menang + delta * 1.5, 1.0)

	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible or sudah_menang:
		return

	var rect_grid := hitung_rect_grid()
	var ukuran_sel: float = rect_grid.size.x / float(GRID_SIZE)

	if event is InputEventMouseMotion:
		pakai_kursor_keyboard = false
		var pos: Vector2 = event.position
		hover_tombol_acak = area_tombol_acak.has_point(pos)

		if rect_grid.has_point(pos):
			var gx: int = clampi(floori((pos.x - rect_grid.position.x) / ukuran_sel), 0, GRID_SIZE - 1)
			var gy: int = clampi(floori((pos.y - rect_grid.position.y) / ukuran_sel), 0, GRID_SIZE - 1)
			hover_sel = Vector2i(gx, gy)
		else:
			hover_sel = Vector2i(-1, -1)

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var klik: Vector2 = event.position

		# Tombol ACAK
		if area_tombol_acak.has_point(klik):
			buat_papan_baru()
			tambah_percikan(area_tombol_acak.get_center(), COL_MANA_DALAM, 16)
			accept_event()
			return

		# Klik pada kotak pipa 5x5
		if rect_grid.has_point(klik):
			var gx: int = clampi(floori((klik.x - rect_grid.position.x) / ukuran_sel), 0, GRID_SIZE - 1)
			var gy: int = clampi(floori((klik.y - rect_grid.position.y) / ukuran_sel), 0, GRID_SIZE - 1)
			kursor_grid = Vector2i(gx, gy)
			putar_pipa(gx, gy)
			accept_event()


# Mendukung kontrol penuh Keyboard (WASD/Panah + Spasi/Enter + R untuk Acak)
func _unhandled_input(event: InputEvent) -> void:
	if not visible or sudah_menang:
		return

	if event.is_action_pressed("jalan_kiri") or event.is_action_pressed("ui_left"):
		pakai_kursor_keyboard = true
		kursor_grid.x = posmod(kursor_grid.x - 1, GRID_SIZE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jalan_kanan") or event.is_action_pressed("ui_right"):
		pakai_kursor_keyboard = true
		kursor_grid.x = posmod(kursor_grid.x + 1, GRID_SIZE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("leader_up") or event.is_action_pressed("ui_up"):
		pakai_kursor_keyboard = true
		kursor_grid.y = posmod(kursor_grid.y - 1, GRID_SIZE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("leader_down") or event.is_action_pressed("ui_down"):
		pakai_kursor_keyboard = true
		kursor_grid.y = posmod(kursor_grid.y + 1, GRID_SIZE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		putar_pipa(kursor_grid.x, kursor_grid.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		buat_papan_baru()
		if area_tombol_acak.size != Vector2.ZERO:
			tambah_percikan(area_tombol_acak.get_center(), COL_MANA_DALAM, 16)
		get_viewport().set_input_as_handled()


# Menghitung kotak papan 5x5 tepat di cekungan tengah FrameBatu
func hitung_rect_grid() -> Rect2:
	var layar: Vector2 = get_viewport_rect().size
	var sisi: float = ukuran_bingkai
	var frame := ambil_node_bingkai()
	if frame and frame.size.x > 50.0:
		sisi = minf(frame.size.x, frame.size.y)

	var pos_bingkai: Vector2 = (layar - Vector2(sisi, sisi)) * 0.5
	var margin: float = sisi * margin_bingkai_rasio
	var lebar_dalam: float = sisi - (margin * 2.0)
	return Rect2(pos_bingkai + Vector2(margin, margin), Vector2(lebar_dalam, lebar_dalam))


# Membangun jaringan pipa 5x5 yang dijamin 100% bisa diselesaikan
func buat_papan_baru() -> void:
	grid.clear()
	teraliri.clear()
	sudut_visual.clear()
	denyut_klik.clear()

	for y in range(GRID_SIZE):
		var b_grid: Array[int] = []
		var b_alir: Array[bool] = []
		var b_sudut: Array[float] = []
		var b_denyut: Array[float] = []
		for x in range(GRID_SIZE):
			b_grid.append(0)
			b_alir.append(false)
			b_sudut.append(0.0)
			b_denyut.append(0.0)
		grid.append(b_grid)
		teraliri.append(b_alir)
		sudut_visual.append(b_sudut)
		denyut_klik.append(b_denyut)

	var dikunjungi: Array = []
	for y in range(GRID_SIZE):
		var b_vis: Array[bool] = []
		for x in range(GRID_SIZE):
			b_vis.append(false)
		dikunjungi.append(b_vis)

	var tumpukan: Array[Vector2i] = [Vector2i(0, BARIS_KONEKSI)]
	dikunjungi[BARIS_KONEKSI][0] = true

	while tumpukan.size() > 0:
		var aktif: Vector2i = tumpukan.back()
		var tetangga: Array = []

		if aktif.y > 0 and not dikunjungi[aktif.y - 1][aktif.x]:
			tetangga.append([Vector2i(aktif.x, aktif.y - 1), ARAH_ATAS, ARAH_BAWAH])
		if aktif.x < GRID_SIZE - 1 and not dikunjungi[aktif.y][aktif.x + 1]:
			tetangga.append([Vector2i(aktif.x + 1, aktif.y), ARAH_KANAN, ARAH_KIRI])
		if aktif.y < GRID_SIZE - 1 and not dikunjungi[aktif.y + 1][aktif.x]:
			tetangga.append([Vector2i(aktif.x, aktif.y + 1), ARAH_BAWAH, ARAH_ATAS])
		if aktif.x > 0 and not dikunjungi[aktif.y][aktif.x - 1]:
			tetangga.append([Vector2i(aktif.x - 1, aktif.y), ARAH_KIRI, ARAH_KANAN])

		if tetangga.size() > 0:
			var pilih: Array = tetangga[randi() % tetangga.size()]
			var tujuan: Vector2i = pilih[0]
			grid[aktif.y][aktif.x] |= int(pilih[1])
			grid[tujuan.y][tujuan.x] |= int(pilih[2])
			dikunjungi[tujuan.y][tujuan.x] = true
			tumpukan.append(tujuan)
		else:
			tumpukan.pop_back()

	# Sambungkan mulut masuk (Kiri Tengah) dan keluar (Kanan Tengah)
	grid[BARIS_KONEKSI][0] |= ARAH_KIRI
	grid[BARIS_KONEKSI][GRID_SIZE - 1] |= ARAH_KANAN

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var putar: int = (randi() % 3) + 1
			for _i in range(putar):
				grid[y][x] = putar_mask_kanan(grid[y][x])

	jumlah_putaran = 0
	sudah_menang = false
	progres_menang = 0.0
	hitung_aliran_mana()

	if teraliri[BARIS_KONEKSI][GRID_SIZE - 1] and (grid[BARIS_KONEKSI][GRID_SIZE - 1] & ARAH_KANAN) != 0:
		grid[BARIS_KONEKSI][0] = putar_mask_kanan(grid[BARIS_KONEKSI][0])
		hitung_aliran_mana()


func putar_pipa(x: int, y: int) -> void:
	if sudah_menang:
		return

	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_puzzle_click"):
		am.play_puzzle_click()

	grid[y][x] = putar_mask_kanan(grid[y][x])
	sudut_visual[y][x] -= PI * 0.5
	denyut_klik[y][x] = 1.0
	jumlah_putaran += 1
	hitung_aliran_mana()

	var rect_grid := hitung_rect_grid()
	var sel_size: float = rect_grid.size.x / float(GRID_SIZE)
	var pusat_sel := rect_grid.position + (Vector2(float(x), float(y)) + Vector2(0.5, 0.5)) * sel_size
	var warna_percik := COL_MANA_DALAM if teraliri[y][x] else Color("#8ba4d6")
	tambah_percikan(pusat_sel, warna_percik, 10)

	# Cek kemenangan: otomatis pudar, kirim sinyal ke portal, dan hapus popup dari layar
	if teraliri[BARIS_KONEKSI][GRID_SIZE - 1] and (grid[BARIS_KONEKSI][GRID_SIZE - 1] & ARAH_KANAN) != 0:
		sudah_menang = true
		if am and am.has_method("play_puzzle_win"):
			am.play_puzzle_win()
		waktu_getar = 0.35
		tambah_percikan(rect_grid.get_center(), COL_EMAS, 36)
		await get_tree().create_timer(0.85, true).timeout
		if not is_inside_tree():
			return

		# Animasi pudar keluar untuk seluruh elemen popup (bingkai, overlay, dan papan)
		var parent_layer := get_parent()
		var tw_tutup := create_tween().set_parallel(true)
		tw_tutup.tween_property(self, "modulate:a", 0.0, 0.25)
		if parent_layer:
			for anak in parent_layer.get_children():
				if anak is CanvasItem and anak != self:
					tw_tutup.tween_property(anak, "modulate:a", 0.0, 0.25)
		await tw_tutup.finished

		puzzle_selesai.emit()
		await get_tree().process_frame
		if parent_layer is CanvasLayer and is_instance_valid(parent_layer):
			parent_layer.queue_free()
		elif is_inside_tree():
			queue_free()


func tambah_percikan(pusat: Vector2, warna: Color, jumlah: int) -> void:
	for _i in range(jumlah):
		var sudut: float = randf_range(0.0, TAU)
		var laju: float = randf_range(45.0, 155.0)
		percikan_klik.append({
			"pos": pusat,
			"vel": Vector2(cos(sudut), sin(sudut)) * laju,
			"warna": warna,
			"umur": randf_range(0.45, 0.95),
			"ukuran": randf_range(2.0, 4.5)
		})


func putar_mask_kanan(mask: int) -> int:
	var res: int = 0
	if mask & ARAH_ATAS:
		res |= ARAH_KANAN
	if mask & ARAH_KANAN:
		res |= ARAH_BAWAH
	if mask & ARAH_BAWAH:
		res |= ARAH_KIRI
	if mask & ARAH_KIRI:
		res |= ARAH_ATAS
	return res


func hitung_aliran_mana() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			teraliri[y][x] = false

	if (grid[BARIS_KONEKSI][0] & ARAH_KIRI) == 0:
		return

	var antrean: Array[Vector2i] = [Vector2i(0, BARIS_KONEKSI)]
	teraliri[BARIS_KONEKSI][0] = true

	while antrean.size() > 0:
		var c: Vector2i = antrean.pop_front()
		var m: int = grid[c.y][c.x]

		if (m & ARAH_ATAS) != 0 and c.y > 0 and not teraliri[c.y - 1][c.x]:
			if (grid[c.y - 1][c.x] & ARAH_BAWAH) != 0:
				teraliri[c.y - 1][c.x] = true
				antrean.append(Vector2i(c.x, c.y - 1))
		if (m & ARAH_KANAN) != 0 and c.x < GRID_SIZE - 1 and not teraliri[c.y][c.x + 1]:
			if (grid[c.y][c.x + 1] & ARAH_KIRI) != 0:
				teraliri[c.y][c.x + 1] = true
				antrean.append(Vector2i(c.x + 1, c.y))
		if (m & ARAH_BAWAH) != 0 and c.y < GRID_SIZE - 1 and not teraliri[c.y + 1][c.x]:
			if (grid[c.y + 1][c.x] & ARAH_ATAS) != 0:
				teraliri[c.y + 1][c.x] = true
				antrean.append(Vector2i(c.x, c.y + 1))
		if (m & ARAH_KIRI) != 0 and c.x > 0 and not teraliri[c.y][c.x - 1]:
			if (grid[c.y][c.x - 1] & ARAH_KANAN) != 0:
				teraliri[c.y][c.x - 1] = true
				antrean.append(Vector2i(c.x - 1, c.y))


func _draw() -> void:
	var layar: Vector2 = get_viewport_rect().size
	var rect_grid := hitung_rect_grid()
	var sel_size: float = rect_grid.size.x / float(GRID_SIZE)
	var pusat_layar: Vector2 = layar * 0.5
	var font: Font = ThemeDB.fallback_font

	# 1. Atmosfer samping layar (lingkaran rune berputar & kristal melayang di kiri-kanan)
	gambar_atmosfer_samping(pusat_layar, layar)

	# 2. Latar cekungan batu gelap di dalam bingkai es
	draw_rect(rect_grid.grow(4.0), COL_DASAR_DALAM, true)
	draw_rect(rect_grid.grow(4.0), Color(0.32, 0.44, 0.65, 0.85), false, 2.0)

	# 3. Pipa penghubung langsung ke Kristal Cyan Kiri & Kristal Cyan Kanan bingkai
	var y_tengah: float = rect_grid.position.y + (float(BARIS_KONEKSI) + 0.5) * sel_size
	gambar_pipa_penghubung_kristal(Vector2(rect_grid.position.x - 32.0, y_tengah), Vector2(rect_grid.position.x + 2.0, y_tengah), true)
	gambar_pipa_penghubung_kristal(Vector2(rect_grid.end.x - 2.0, y_tengah), Vector2(rect_grid.end.x + 32.0, y_tengah), sudah_menang)

	# 4. Gambar petak grid & modul pipa logam-batu 5x5 beserta aliran mana hidup
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var pos_sel := rect_grid.position + Vector2(float(x), float(y)) * sel_size
			var rect_sel := Rect2(pos_sel + Vector2(1.5, 1.5), Vector2(sel_size - 3.0, sel_size - 3.0))
			var is_hover := (hover_sel == Vector2i(x, y) and not sudah_menang)
			var is_kursor := (pakai_kursor_keyboard and kursor_grid == Vector2i(x, y) and not sudah_menang)

			var warna_petak := Color(0.10, 0.14, 0.22, 0.94)
			if is_hover or is_kursor:
				warna_petak = Color(0.17, 0.23, 0.36, 0.98)
			draw_rect(rect_sel, warna_petak, true)

			var warna_tepi := Color(0.45, 0.85, 1.0, 0.85) if (is_hover or is_kursor) else Color(0.20, 0.27, 0.40, 0.65)
			draw_rect(rect_sel, warna_tepi, false, 1.5 if (is_hover or is_kursor) else 1.0)

			var pusat := pos_sel + Vector2(sel_size * 0.5, sel_size * 0.5)
			var skala_klik: float = 1.0 + (denyut_klik[y][x] * 0.10)
			draw_set_transform(pusat, sudut_visual[y][x], Vector2(skala_klik, skala_klik))
			gambar_kepingan_pipa(sel_size, grid[y][x], teraliri[y][x])
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 5. Efek gelombang cahaya emas saat seluruh pipa tersambung ke kristal kanan
	if sudah_menang:
		var radius_win: float = progres_menang * 420.0
		var alpha_win: float = clampf(1.0 - progres_menang, 0.0, 0.85)
		draw_arc(pusat_layar, radius_win, 0.0, TAU, 64, Color(0.45, 0.95, 1.0, alpha_win), 5.0)
		draw_arc(pusat_layar, radius_win * 0.72, 0.0, TAU, 48, Color(1.0, 0.88, 0.45, alpha_win), 3.0)

	# 6. Percikan energi klik
	for sp in percikan_klik:
		var c: Color = sp["warna"]
		c.a = clampf(sp["umur"], 0.0, 1.0)
		draw_circle(sp["pos"], sp["ukuran"], c)

	# 7. Bar Kontrol Batu di Bawah Bingkai (Hanya Counter Putaran + Tombol ACAK)
	var sisi_bingkai: float = ukuran_bingkai
	var kiri_bingkai: float = (layar.x - sisi_bingkai) * 0.5
	var bawah_bingkai: float = ((layar.y - sisi_bingkai) * 0.5) + sisi_bingkai + 12.0

	var rect_bar := Rect2(kiri_bingkai + 36.0, bawah_bingkai, sisi_bingkai - 72.0, 42.0)
	draw_rect(rect_bar, Color(0.06, 0.09, 0.16, 0.94), true)
	draw_rect(rect_bar, COL_EMAS if sudah_menang else Color(0.32, 0.48, 0.72, 0.85), false, 1.5)
	draw_rect(rect_bar.grow(-3.0), Color(0.20, 0.30, 0.48, 0.35), false, 1.0)

	# Ornamen kristal kecil di kiri teks status
	var pos_kristal_bar := Vector2(rect_bar.position.x + 18.0, rect_bar.get_center().y)
	var bentuk_kristal := PackedVector2Array([
		pos_kristal_bar + Vector2(0.0, -7.0),
		pos_kristal_bar + Vector2(5.0, 0.0),
		pos_kristal_bar + Vector2(0.0, 7.0),
		pos_kristal_bar + Vector2(-5.0, 0.0)
	])
	draw_colored_polygon(bentuk_kristal, COL_EMAS if sudah_menang else COL_MANA_DALAM)

	var teks_status: String = "SEGEL KRISTAL TERBUKA!" if sudah_menang else "PUTARAN: %d" % jumlah_putaran
	var warna_teks: Color = COL_EMAS if sudah_menang else Color(0.88, 0.95, 1.0)
	draw_string(font, Vector2(rect_bar.position.x + 32.0, rect_bar.position.y + 26.0), teks_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, warna_teks)

	# Satu tombol ACAK bergaya lempeng batu rune di sisi kanan bar
	area_tombol_acak = Rect2(rect_bar.end.x - 118.0, rect_bar.position.y + 5.0, 110.0, 32.0)
	gambar_tombol_acak(area_tombol_acak, hover_tombol_acak, font)


# Menggambar efek atmosfer di sisi kiri dan kanan layar agar tidak kosong
func gambar_atmosfer_samping(pusat_layar: Vector2, layar: Vector2) -> void:
	var r_luar: float = 345.0
	var r_dalam: float = 315.0
	draw_arc(pusat_layar, r_luar, waktu * 0.25, waktu * 0.25 + TAU, 72, Color(0.25, 0.72, 1.0, 0.14), 2.0)
	draw_arc(pusat_layar, r_dalam, -waktu * 0.40, -waktu * 0.40 + TAU, 64, Color(0.75, 0.35, 1.0, 0.12), 1.5)

	var x_kiri: float = (layar.x - ukuran_bingkai) * 0.25
	var x_kanan: float = layar.x - x_kiri
	for x_pilar in [x_kiri, x_kanan]:
		if x_pilar > 40.0 and absf(x_pilar - pusat_layar.x) > (ukuran_bingkai * 0.5 + 30.0):
			draw_line(Vector2(x_pilar, 110.0), Vector2(x_pilar, layar.y - 110.0), Color(0.25, 0.65, 1.0, 0.10), 1.5)

	for kr in kristal_samping:
		var pos_kr: Vector2 = kr["asal"] + Vector2(0.0, sin(waktu * 2.2 + kr["fase"]) * 10.0)
		if absf(pos_kr.x - pusat_layar.x) > (ukuran_bingkai * 0.5 + 24.0):
			var u: float = kr["ukuran"]
			var warna_kr := Color(0.72, 0.32, 1.0, 0.35) if kr["ungu"] else Color(0.20, 0.85, 1.0, 0.35)
			var titik_kristal := PackedVector2Array([
				pos_kr + Vector2(0.0, -u),
				pos_kr + Vector2(u * 0.62, 0.0),
				pos_kr + Vector2(0.0, u),
				pos_kr + Vector2(-u * 0.62, 0.0)
			])
			draw_colored_polygon(titik_kristal, warna_kr)
			draw_polyline(titik_kristal + PackedVector2Array([titik_kristal[0]]), Color(0.85, 0.96, 1.0, 0.45), 1.2)

	for p in partikel_salju:
		draw_circle(p["pos"], p["size"], Color(0.78, 0.93, 1.0, p["alpha"]))


func gambar_pipa_penghubung_kristal(dari: Vector2, ke: Vector2, aktif: bool) -> void:
	draw_line(dari, ke, COL_PIPA_OUTLINE, 18.0)
	draw_line(dari, ke, COL_PIPA_LOGAM, 13.0)
	draw_line(dari, ke, COL_MANA_LUAR if aktif else COL_PIPA_RONGGA, 7.0)
	if aktif:
		draw_line(dari, ke, COL_MANA_DALAM, 3.0)


func gambar_kepingan_pipa(sisi: float, mask: int, aktif: bool) -> void:
	var half: float = sisi * 0.5
	var w_outline: float = sisi * 0.34
	var w_logam: float = sisi * 0.25
	var w_sorot: float = sisi * 0.19
	var w_mana: float = sisi * 0.12

	var arah_vektor: Array = [
		[ARAH_ATAS, Vector2(0.0, -half)],
		[ARAH_KANAN, Vector2(half, 0.0)],
		[ARAH_BAWAH, Vector2(0.0, half)],
		[ARAH_KIRI, Vector2(-half, 0.0)]
	]

	for item in arah_vektor:
		if (mask & int(item[0])) != 0:
			var ujung: Vector2 = item[1]
			draw_line(Vector2.ZERO, ujung, COL_PIPA_OUTLINE, w_outline)
			draw_line(Vector2.ZERO, ujung, COL_PIPA_LOGAM, w_logam)
			draw_line(Vector2.ZERO, ujung, COL_PIPA_HIGHLIGHT, w_sorot)

	var panjang_flensa: float = sisi * 0.40
	var tebal_flensa: float = 5.0
	if mask & ARAH_ATAS:
		draw_rect(Rect2(-panjang_flensa * 0.5, -half, panjang_flensa, tebal_flensa), COL_PIPA_OUTLINE, true)
		draw_rect(Rect2(-panjang_flensa * 0.5 + 1.0, -half + 1.0, panjang_flensa - 2.0, tebal_flensa - 2.0), COL_PIPA_HIGHLIGHT, true)
	if mask & ARAH_BAWAH:
		draw_rect(Rect2(-panjang_flensa * 0.5, half - tebal_flensa, panjang_flensa, tebal_flensa), COL_PIPA_OUTLINE, true)
		draw_rect(Rect2(-panjang_flensa * 0.5 + 1.0, half - tebal_flensa + 1.0, panjang_flensa - 2.0, tebal_flensa - 2.0), COL_PIPA_HIGHLIGHT, true)
	if mask & ARAH_KIRI:
		draw_rect(Rect2(-half, -panjang_flensa * 0.5, tebal_flensa, panjang_flensa), COL_PIPA_OUTLINE, true)
		draw_rect(Rect2(-half + 1.0, -panjang_flensa * 0.5 + 1.0, tebal_flensa - 2.0, panjang_flensa - 2.0), COL_PIPA_HIGHLIGHT, true)
	if mask & ARAH_KANAN:
		draw_rect(Rect2(half - tebal_flensa, -panjang_flensa * 0.5, tebal_flensa, panjang_flensa), COL_PIPA_OUTLINE, true)
		draw_rect(Rect2(half - tebal_flensa + 1.0, -panjang_flensa * 0.5 + 1.0, tebal_flensa - 2.0, panjang_flensa - 2.0), COL_PIPA_HIGHLIGHT, true)

	var fase_alir: float = fmod(waktu * 1.8, 1.0)
	for item in arah_vektor:
		if (mask & int(item[0])) != 0:
			var ujung: Vector2 = item[1]
			draw_line(Vector2.ZERO, ujung, COL_MANA_LUAR if aktif else COL_PIPA_RONGGA, w_mana)
			if aktif:
				draw_line(Vector2.ZERO, ujung, COL_MANA_DALAM, w_mana * 0.55)
				draw_line(Vector2.ZERO, ujung, COL_MANA_INTI, w_mana * 0.25)
				var titik_alir: Vector2 = Vector2.ZERO.lerp(ujung, fase_alir)
				draw_circle(titik_alir, w_mana * 0.42, Color.WHITE)

	draw_circle(Vector2.ZERO, w_outline * 0.56, COL_PIPA_OUTLINE)
	draw_circle(Vector2.ZERO, w_logam * 0.55, COL_PIPA_LOGAM)
	draw_circle(Vector2.ZERO, w_mana * 0.62, COL_MANA_LUAR if aktif else COL_PIPA_RONGGA)
	if aktif:
		draw_circle(Vector2.ZERO, w_mana * 0.30, COL_MANA_INTI)


# Menggambar tombol tunggal ACAK [R] dengan bevel batu es dan bingkai dalam
func gambar_tombol_acak(rect: Rect2, hover: bool, font: Font) -> void:
	var isi := Color("#233452") if hover else Color("#141e30")
	var tepi := Color("#6ef7ff") if hover else Color("#43628a")

	draw_rect(rect, isi, true)
	draw_rect(rect, tepi, false, 2.0)
	draw_rect(rect.grow(-3.0), Color(0.45, 0.85, 1.0, 0.35 if hover else 0.15), false, 1.0)

	var label: String = "ACAK [R]"
	var lebar_t: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(rect.get_center().x - lebar_t * 0.5, rect.position.y + 21.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE if hover else Color("#d6ecff"))
