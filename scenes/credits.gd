@tool
extends Control

# Scene rujukan kembali ke menu utama
const MAIN_MENU_PATH: String = "res://scenes/main_menu.tscn"

# Variabel partikel debu kuil kuno & waktu animasi
var partikel_aura: Array[Dictionary] = []
var waktu: float = 0.0
var sedang_pindah: bool = false

@onready var tombol_menu: Button = $VBoxContainer/TombolMenu
@onready var label_lanjut: Label = $VBoxContainer/JudulLanjut
@onready var label_sub: Label = $VBoxContainer/Subjudul
@onready var label_narasi: Label = $VBoxContainer/Narasi


func _get_game_settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	inisialisasi_partikel_kuil()
	siapkan_tata_letak_batu()
	mainkan_intro_credits()

	if tombol_menu:
		tombol_menu.pressed.connect(_on_tombol_menu_pressed)

	var gs := _get_game_settings()
	if gs and gs.has_signal("bahasa_berubah"):
		gs.bahasa_berubah.connect(func(_lang): _perbarui_teks_bahasa())
	_perbarui_teks_bahasa()


func _perbarui_teks_bahasa() -> void:
	var gs := _get_game_settings()
	if not gs:
		return
	if label_lanjut:
		label_lanjut.text = gs.t("CREDITS_TITLE")
	if label_sub:
		label_sub.text = gs.t("CREDITS_SUB")
	if label_narasi:
		label_narasi.text = gs.t("CREDITS_STORY")
	if tombol_menu:
		tombol_menu.text = gs.t("BTN_CREDITS_MENU")


func inisialisasi_partikel_kuil() -> void:
	partikel_aura.clear()
	var ukuran: Vector2 = get_viewport_rect().size
	if ukuran == Vector2.ZERO:
		ukuran = Vector2(1200.0, 750.0)

	for i in range(40):
		partikel_aura.append({
			"pos": Vector2(randf_range(40.0, ukuran.x - 40.0), randf_range(40.0, ukuran.y - 40.0)),
			"vel": Vector2(randf_range(-8.0, 8.0), randf_range(-18.0, -6.0)),
			"radius": randf_range(1.5, 3.8),
			"alpha": randf_range(0.25, 0.65),
			"fase": randf_range(0.0, TAU),
			"emas": randf() < 0.35
		})


func siapkan_tata_letak_batu() -> void:
	# Style batu rune kuno untuk tombol kembali ke menu
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color("#0e1524")
	style_normal.border_color = Color("#2d4263")
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(6)
	style_normal.set_content_margin_all(12)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color("#172238")
	style_hover.border_color = Color("#5ce1e6")
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(6)
	style_hover.set_content_margin_all(12)

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color("#090e17")
	style_pressed.border_color = Color("#ffd954")
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(6)
	style_pressed.set_content_margin_all(12)

	if tombol_menu:
		tombol_menu.add_theme_stylebox_override("normal", style_normal)
		tombol_menu.add_theme_stylebox_override("hover", style_hover)
		tombol_menu.add_theme_stylebox_override("pressed", style_pressed)
		tombol_menu.add_theme_stylebox_override("focus", style_hover)
		tombol_menu.add_theme_color_override("font_color", Color("#d5e2f2"))
		tombol_menu.add_theme_color_override("font_hover_color", Color("#ffffff"))
		tombol_menu.add_theme_color_override("font_pressed_color", Color("#ffd954"))
		tombol_menu.add_theme_font_size_override("font_size", 15)


func mainkan_intro_credits() -> void:
	# Muncul perlahan dari bayangan setelah kilatan putih portal mereda
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	waktu += delta
	var ukuran: Vector2 = get_viewport_rect().size

	# Update gerakan debu mana melayang perlahan
	for p in partikel_aura:
		p["pos"] += p["vel"] * delta
		p["pos"].x += sin(waktu * 1.5 + p["fase"]) * 8.0 * delta
		if p["pos"].y < 10.0:
			p["pos"].y = ukuran.y - 10.0
			p["pos"].x = randf_range(40.0, ukuran.x - 40.0)

	queue_redraw()


func _draw() -> void:
	var ukuran: Vector2 = get_viewport_rect().size
	var pusat: Vector2 = ukuran * 0.5

	# 1. Latar batu kuil gelap pekat
	draw_rect(Rect2(Vector2.ZERO, ukuran), Color("#060910"), true)

	# 2. Ornamen lingkaran rune kuno samar di tengah layar
	var denyut: float = 0.95 + 0.05 * sin(waktu * 1.2)
	draw_arc(pusat, 260.0 * denyut, waktu * 0.15, waktu * 0.15 + TAU, 64, Color(0.18, 0.35, 0.50, 0.12), 2.0)
	draw_arc(pusat, 220.0 * denyut, -waktu * 0.20, -waktu * 0.20 + TAU, 48, Color(0.24, 0.45, 0.65, 0.09), 1.5)

	# 3. Garis pilar relief batu di tepi kiri dan kanan
	draw_line(Vector2(60.0, 40.0), Vector2(60.0, ukuran.y - 40.0), Color(0.20, 0.32, 0.45, 0.18), 2.0)
	draw_line(Vector2(ukuran.x - 60.0, 40.0), Vector2(ukuran.x - 60.0, ukuran.y - 40.0), Color(0.20, 0.32, 0.45, 0.18), 2.0)

	# 4. Gambar debu mana mengapung
	for p in partikel_aura:
		var kedip: float = 0.5 + 0.5 * sin(waktu * 2.5 + p["fase"])
		var col: Color = Color(1.0, 0.85, 0.45, p["alpha"] * kedip) if p["emas"] else Color(0.42, 0.90, 1.0, p["alpha"] * kedip)
		draw_circle(p["pos"], p["radius"], col)


func _on_tombol_menu_pressed() -> void:
	if sedang_pindah:
		return
	sedang_pindah = true
	tombol_menu.disabled = true

	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	# Transisi fade out halus ke menu utama
	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	get_tree().change_scene_to_file(MAIN_MENU_PATH)
