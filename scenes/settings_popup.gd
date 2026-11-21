@tool
extends CanvasLayer

# Popup Pengaturan Suara, Bahasa, dan Kontrol Permainan
# Bergaya lempeng batu rune gelap (Dark Ancient Relic UI)

@onready var panel_kontainer: PanelContainer = $PanelContainer
@onready var judul_label: Label = $PanelContainer/VBox/JudulLabel
@onready var section_audio: Label = $PanelContainer/VBox/SectionAudio
@onready var label_master: Label = $PanelContainer/VBox/GridAudio/LabelMaster
@onready var slider_master: HSlider = $PanelContainer/VBox/GridAudio/SliderMaster
@onready var val_master: Label = $PanelContainer/VBox/GridAudio/ValMaster

@onready var label_bgm: Label = $PanelContainer/VBox/GridAudio/LabelBGM
@onready var slider_bgm: HSlider = $PanelContainer/VBox/GridAudio/SliderBGM
@onready var val_bgm: Label = $PanelContainer/VBox/GridAudio/ValBGM

@onready var label_sfx: Label = $PanelContainer/VBox/GridAudio/LabelSFX
@onready var slider_sfx: HSlider = $PanelContainer/VBox/GridAudio/SliderSFX
@onready var val_sfx: Label = $PanelContainer/VBox/GridAudio/ValSFX

@onready var check_mute: CheckBox = $PanelContainer/VBox/CheckMute

@onready var section_bahasa: Label = $PanelContainer/VBox/SectionBahasa
@onready var btn_lang_id: Button = $PanelContainer/VBox/HBoxBahasa/BtnLangID
@onready var btn_lang_en: Button = $PanelContainer/VBox/HBoxBahasa/BtnLangEN

@onready var section_kontrol: Label = $PanelContainer/VBox/SectionKontrol
@onready var label_ctrl_move: Label = $PanelContainer/VBox/VBoxKontrol/LabelMove
@onready var label_ctrl_jump: Label = $PanelContainer/VBox/VBoxKontrol/LabelJump
@onready var label_ctrl_climb: Label = $PanelContainer/VBox/VBoxKontrol/LabelClimb
@onready var label_ctrl_attack: Label = $PanelContainer/VBox/VBoxKontrol/LabelAttack
@onready var label_ctrl_interact: Label = $PanelContainer/VBox/VBoxKontrol/LabelInteract
@onready var label_ctrl_pause: Label = $PanelContainer/VBox/VBoxKontrol/LabelPause

@onready var btn_tutup: Button = $PanelContainer/VBox/BtnTutup


func _get_game_settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_terapkan_style_batu()
	_sinkronkan_nilai()
	_perbarui_teks_bahasa()

	var gs := _get_game_settings()
	if gs and gs.has_signal("bahasa_berubah"):
		gs.bahasa_berubah.connect(_on_bahasa_berubah)

	slider_master.value_changed.connect(_on_master_changed)
	slider_bgm.value_changed.connect(_on_bgm_changed)
	slider_sfx.value_changed.connect(_on_sfx_changed)
	check_mute.toggled.connect(_on_mute_toggled)

	btn_lang_id.pressed.connect(func():
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_button_click"):
			am.play_button_click()
		var s := _get_game_settings()
		if s: s.set_bahasa("id")
	)
	btn_lang_en.pressed.connect(func():
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_button_click"):
			am.play_button_click()
		var s := _get_game_settings()
		if s: s.set_bahasa("en")
	)
	btn_tutup.pressed.connect(func():
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_button_click"):
			am.play_button_click()
		tutup_popup()
	)

	# Animasi muncul halus (fade-in & pop)
	panel_kontainer.modulate.a = 0.0
	panel_kontainer.scale = Vector2(0.95, 0.95)
	panel_kontainer.pivot_offset = panel_kontainer.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel_kontainer, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_kontainer, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		tutup_popup()


func _sinkronkan_nilai() -> void:
	var gs := _get_game_settings()
	if gs:
		slider_master.value = gs.volume_master
		slider_bgm.value = gs.volume_bgm
		slider_sfx.value = gs.volume_sfx
		check_mute.button_pressed = gs.is_muted
		
		val_master.text = "%d%%" % int(gs.volume_master * 100)
		val_bgm.text = "%d%%" % int(gs.volume_bgm * 100)
		val_sfx.text = "%d%%" % int(gs.volume_sfx * 100)
		_sorot_tombol_bahasa(gs.bahasa_aktif)


func _on_master_changed(val: float) -> void:
	val_master.text = "%d%%" % int(val * 100)
	var gs := _get_game_settings()
	if gs:
		gs.set_bus_volume("Master", val)


func _on_bgm_changed(val: float) -> void:
	val_bgm.text = "%d%%" % int(val * 100)
	var gs := _get_game_settings()
	if gs:
		gs.set_bus_volume("BGM", val)


func _on_sfx_changed(val: float) -> void:
	val_sfx.text = "%d%%" % int(val * 100)
	var gs := _get_game_settings()
	if gs:
		gs.set_bus_volume("SFX", val)


func _on_mute_toggled(toggled: bool) -> void:
	var gs := _get_game_settings()
	if gs:
		gs.set_mute(toggled)


func _on_bahasa_berubah(bahasa: String) -> void:
	_sorot_tombol_bahasa(bahasa)
	_perbarui_teks_bahasa()


func _sorot_tombol_bahasa(bahasa: String) -> void:
	btn_lang_id.modulate = Color(1.2, 1.2, 1.0, 1.0) if bahasa == "id" else Color(0.7, 0.7, 0.7, 0.8)
	btn_lang_en.modulate = Color(1.2, 1.2, 1.0, 1.0) if bahasa == "en" else Color(0.7, 0.7, 0.7, 0.8)


func _perbarui_teks_bahasa() -> void:
	var gs := _get_game_settings()
	if not gs:
		return
	judul_label.text = gs.t("SETTINGS_TITLE")
	section_audio.text = "✦ " + gs.t("LABEL_AUDIO") + " ✦"
	label_master.text = gs.t("LABEL_MASTER")
	label_bgm.text = gs.t("LABEL_BGM")
	label_sfx.text = gs.t("LABEL_SFX")
	check_mute.text = gs.t("LABEL_MUTE")
	
	section_bahasa.text = "✦ " + gs.t("LABEL_LANG") + " ✦"
	btn_lang_id.text = gs.t("LANG_ID")
	btn_lang_en.text = gs.t("LANG_EN")
	
	section_kontrol.text = "✦ " + gs.t("LABEL_CONTROLS") + " ✦"
	label_ctrl_move.text = gs.t("CTRL_MOVE")
	label_ctrl_jump.text = gs.t("CTRL_JUMP")
	label_ctrl_climb.text = gs.t("CTRL_CLIMB")
	label_ctrl_attack.text = gs.t("CTRL_ATTACK")
	label_ctrl_interact.text = gs.t("CTRL_INTERACT")
	label_ctrl_pause.text = gs.t("CTRL_PAUSE")
	
	btn_tutup.text = gs.t("BTN_CLOSE")


func tutup_popup() -> void:
	var tw := create_tween()
	tw.tween_property(panel_kontainer, "modulate:a", 0.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()


func _terapkan_style_batu() -> void:
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("#0b121e")
	panel_sb.border_color = Color("#2d4263")
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(8)
	panel_sb.set_content_margin_all(20)
	panel_kontainer.add_theme_stylebox_override("panel", panel_sb)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color("#111a2d")
	btn_normal.border_color = Color("#2d4263")
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(6)
	btn_normal.set_content_margin_all(8)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color("#1b2842")
	btn_hover.border_color = Color("#5ce1e6")
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(6)
	btn_hover.set_content_margin_all(8)

	for b in [btn_lang_id, btn_lang_en, btn_tutup]:
		if b:
			b.add_theme_stylebox_override("normal", btn_normal)
			b.add_theme_stylebox_override("hover", btn_hover)
			b.add_theme_stylebox_override("pressed", btn_normal)
			b.add_theme_color_override("font_color", Color("#d5e2f2"))
			b.add_theme_color_override("font_hover_color", Color("#ffffff"))
