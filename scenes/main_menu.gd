@tool
extends Control

# Menu Utama Game Aura: The Lost Relic
const LEVEL_1_PATH: String = "res://scenes/level1.tscn"

const SETTINGS_POPUP_SCENE: PackedScene = preload("res://scenes/settings_popup.tscn")

@onready var btn_play: TextureButton = find_child("PlayButton", true, false)
@onready var btn_setting: TextureButton = find_child("Setting_Button", true, false)
@onready var btn_quit: TextureButton = find_child("Quit_Button", true, false)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if btn_play and not btn_play.pressed.is_connected(_on_play_button_pressed):
		btn_play.pressed.connect(_on_play_button_pressed)
	if btn_setting and not btn_setting.pressed.is_connected(_on_setting_button_pressed):
		btn_setting.pressed.connect(_on_setting_button_pressed)
	if btn_quit and not btn_quit.pressed.is_connected(_on_quit_button_pressed):
		btn_quit.pressed.connect(_on_quit_button_pressed)


func _on_play_button_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	if ResourceLoader.exists(LEVEL_1_PATH):
		get_tree().change_scene_to_file(LEVEL_1_PATH)
	else:
		var fallback_path := "res://fulllevel/level1.tscn"
		if ResourceLoader.exists(fallback_path):
			get_tree().change_scene_to_file(fallback_path)
		else:
			push_error("Scene level 1 tidak ditemukan! Cek kembali path filenya.")


func _on_setting_button_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	if has_node("SettingsPopup"):
		return
	var popup = SETTINGS_POPUP_SCENE.instantiate()
	add_child(popup)


func _on_quit_button_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_button_click"):
		am.play_button_click()

	get_tree().quit()
