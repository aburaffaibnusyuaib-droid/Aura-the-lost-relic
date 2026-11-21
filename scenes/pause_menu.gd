@tool
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect
@onready var panel_kontainer: PanelContainer = $PanelContainer
@onready var label_judul: Label = $PanelContainer/VBox/JudulLabel
@onready var btn_resume: Button = $PanelContainer/VBox/BtnResume
@onready var btn_restart: Button = $PanelContainer/VBox/BtnRestart
@onready var btn_settings: Button = $PanelContainer/VBox/BtnSettings
@onready var btn_menu: Button = $PanelContainer/VBox/BtnMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_terapkan_style_batu_rune()
	_perbarui_teks_bahasa()

	var gs := get_node_or_null("/root/GameSettings")
	if gs and gs.has_signal("bahasa_berubah"):
		gs.bahasa_berubah.connect(func(_lang): _perbarui_teks_bahasa())

	btn_resume.pressed.connect(_on_resume_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		# Jangan tangani jika SettingsPopup sedang terbuka di atas Pause Menu
		var existing_settings = get_node_or_null("SettingsPopup")
		if existing_settings and existing_settings.visible:
			return

		if visible:
			tutup_pause()
			get_viewport().set_input_as_handled()
		else:
			if boleh_pause():
				buka_pause()
				get_viewport().set_input_as_handled()


func boleh_pause() -> bool:
	if not is_inside_tree():
		return false

	var tree := get_tree()
	var sc: Node = null
	if tree and tree.current_scene:
		sc = tree.current_scene
	elif get_parent():
		sc = get_parent()
	else:
		return false

	# 1. Jangan pause jika GameOverPopup sedang aktif
	if sc.has_node("GameOverPopup"):
		return false

	# 2. Jangan pause jika Popup Puzzle apapun sedang terbuka
	for c in sc.get_children():
		var n := c.name.to_lower()
		if n.contains("puzzle") or c.is_in_group("puzzle_popup"):
			if c.visible:
				return false

	# 3. Jangan pause jika player sedang dalam animasi spawn atau masuk portal
	var player := sc.get_node_or_null("Player")
	if player:
		if player.get("sedang_spawn") or (player.get("bisa_nembak") == false and not player.visible):
			return false

	return true


func buka_pause() -> void:
	visible = true
	if is_inside_tree() and get_tree():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_perbarui_teks_bahasa()

	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	panel_kontainer.modulate.a = 0.0
	panel_kontainer.scale = Vector2(0.95, 0.95)
	panel_kontainer.pivot_offset = panel_kontainer.size * 0.5

	var tw := create_tween()
	if tw:
		tw.set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(panel_kontainer, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel_kontainer, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func tutup_pause() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	visible = false
	if is_inside_tree() and get_tree():
		get_tree().paused = false


func _on_resume_pressed() -> void:
	tutup_pause()


func _on_restart_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	tutup_pause()
	if get_tree() and get_tree().current_scene:
		get_tree().reload_current_scene()


func _on_settings_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	if has_node("SettingsPopup"):
		return
	var set_sc := load("res://scenes/settings_popup.tscn")
	if set_sc:
		var popup = set_sc.instantiate()
		add_child(popup)


func _on_menu_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	tutup_pause()
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _perbarui_teks_bahasa() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if not gs:
		return
	label_judul.text = gs.t("PAUSE_TITLE")
	btn_resume.text = gs.t("BTN_RESUME")
	btn_restart.text = gs.t("BTN_RESTART")
	btn_settings.text = gs.t("BTN_SETTINGS")
	btn_menu.text = gs.t("BTN_MAINMENU")


func _terapkan_style_batu_rune() -> void:
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("#0b0f17")
	panel_sb.border_color = Color("#223843")
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(8)
	panel_sb.set_content_margin_all(20)
	panel_kontainer.add_theme_stylebox_override("panel", panel_sb)

	var tombol_list := [btn_resume, btn_restart, btn_settings, btn_menu]
	for b in tombol_list:
		var norm := StyleBoxFlat.new()
		norm.bg_color = Color("#141d2b")
		norm.border_color = Color("#2e3d52")
		norm.set_border_width_all(2)
		norm.set_corner_radius_all(6)
		norm.set_content_margin_all(8)

		var hov := StyleBoxFlat.new()
		hov.bg_color = Color("#1f2c40")
		hov.border_color = Color("#5ce1e6")
		hov.set_border_width_all(2)
		hov.set_corner_radius_all(6)
		hov.set_content_margin_all(8)

		b.add_theme_stylebox_override("normal", norm)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", norm)
		b.add_theme_color_override("font_color", Color("#d5e2f2"))
		b.add_theme_color_override("font_hover_color", Color("#5ce1e6"))
