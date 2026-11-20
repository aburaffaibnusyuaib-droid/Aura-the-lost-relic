extends Control

# Path level utama (sesuaikan jika letak foldermu berbeda)
const LEVEL_1_PATH: String = "res://scenes/level1.tscn"

func _ready() -> void:
	# Memastikan input UI siap menerima fokus kursor
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_play_button_pressed() -> void:
	# Cek apakah file level tersedia sebelum pindah scene biar anti-crash
	if ResourceLoader.exists(LEVEL_1_PATH):
		get_tree().change_scene_to_file(LEVEL_1_PATH)
	else:
		# Fallback cek folder alternatif jika kamu simpan di folder fulllevel
		var fallback_path := "res://fulllevel/level1.tscn"
		if ResourceLoader.exists(fallback_path):
			get_tree().change_scene_to_file(fallback_path)
		else:
			push_error("Scene level 1 tidak ditemukan! Cek kembali path filenya.")

func _on_setting_button_pressed() -> void:
	print("Menu Settings diklik!")
	# Nanti logika buka popup settings ditaruh di sini

func _on_quit_button_pressed() -> void:
	# Menutup aplikasi game secara bersih
	get_tree().quit()
