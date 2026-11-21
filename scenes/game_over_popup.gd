@tool
extends CanvasLayer

# Popup Game Over saat HP Rhein habis
# Bergaya lempeng batu kuil kuno dengan aksen crimson (Dark Ancient Relic UI)

@onready var panel_kontainer: PanelContainer = $PanelContainer
@onready var label_judul: Label = $PanelContainer/VBox/JudulLabel
@onready var label_sub: Label = $PanelContainer/VBox/SubLabel
@onready var btn_retry: Button = $PanelContainer/VBox/HBox/BtnRetry
@onready var btn_menu: Button = $PanelContainer/VBox/HBox/BtnMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_terapkan_style_batu_crimson()
	_perbarui_teks_bahasa()

	var gs := get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("bahasa_berubah"):
		gs.bahasa_berubah.connect(func(_lang): _perbarui_teks_bahasa())

	btn_retry.pressed.connect(_on_retry_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)

	# Animasi fade-in halus saat game over muncul
	panel_kontainer.modulate.a = 0.0
	panel_kontainer.scale = Vector2(0.92, 0.92)
	panel_kontainer.pivot_offset = panel_kontainer.size * 0.5

	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel_kontainer, "modulate:a", 1.0, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_kontainer, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _perbarui_teks_bahasa() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if not gs:
		return
	label_judul.text = gs.t("GAMEOVER_TITLE")
	label_sub.text = gs.t("GAMEOVER_SUB")
	btn_retry.text = gs.t("BTN_RETRY")
	btn_menu.text = gs.t("BTN_MAINMENU")


func _on_retry_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	# Buka status pause sebelum reload agar scene baru tidak ikut terhenti
	if get_tree():
		get_tree().paused = false
		if get_tree().current_scene:
			get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	# Buka status pause sebelum kembali ke main menu
	if get_tree():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _terapkan_style_batu_crimson() -> void:
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("#0b0f17")
	panel_sb.border_color = Color("#6b212d")
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(8)
	panel_sb.set_content_margin_all(24)
	panel_kontainer.add_theme_stylebox_override("panel", panel_sb)

	var btn_retry_norm := StyleBoxFlat.new()
	btn_retry_norm.bg_color = Color("#172033")
	btn_retry_norm.border_color = Color("#3b5078")
	btn_retry_norm.set_border_width_all(2)
	btn_retry_norm.set_corner_radius_all(6)
	btn_retry_norm.set_content_margin_all(10)

	var btn_retry_hov := StyleBoxFlat.new()
	btn_retry_hov.bg_color = Color("#22314f")
	btn_retry_hov.border_color = Color("#5ce1e6")
	btn_retry_hov.set_border_width_all(2)
	btn_retry_hov.set_corner_radius_all(6)
	btn_retry_hov.set_content_margin_all(10)

	btn_retry.add_theme_stylebox_override("normal", btn_retry_norm)
	btn_retry.add_theme_stylebox_override("hover", btn_retry_hov)
	btn_retry.add_theme_stylebox_override("pressed", btn_retry_norm)
	btn_retry.add_theme_color_override("font_color", Color("#d5e2f2"))
	btn_retry.add_theme_color_override("font_hover_color", Color("#ffffff"))

	var btn_menu_norm := StyleBoxFlat.new()
	btn_menu_norm.bg_color = Color("#141924")
	btn_menu_norm.border_color = Color("#2d3748")
	btn_menu_norm.set_border_width_all(2)
	btn_menu_norm.set_corner_radius_all(6)
	btn_menu_norm.set_content_margin_all(10)

	var btn_menu_hov := StyleBoxFlat.new()
	btn_menu_hov.bg_color = Color("#1e2738")
	btn_menu_hov.border_color = Color("#ffd954")
	btn_menu_hov.set_border_width_all(2)
	btn_menu_hov.set_corner_radius_all(6)
	btn_menu_hov.set_content_margin_all(10)

	btn_menu.add_theme_stylebox_override("normal", btn_menu_norm)
	btn_menu.add_theme_stylebox_override("hover", btn_menu_hov)
	btn_menu.add_theme_stylebox_override("pressed", btn_menu_norm)
	btn_menu.add_theme_color_override("font_color", Color("#a0aec0"))
	btn_menu.add_theme_color_override("font_hover_color", Color("#ffffff"))
