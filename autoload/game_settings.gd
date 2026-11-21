@tool
extends Node

# Autoload GameSettings (Singleton terdaftar di project.godot)
# Mengelola Audio (Master, BGM, SFX), Mute, dan Bahasa (ID/EN)

signal bahasa_berubah(bahasa: String)
signal volume_berubah(bus_name: String, volume_linear: float)
signal mute_berubah(is_muted: bool)

const CONFIG_PATH: String = "user://settings.cfg"

static var instance: Node = null

var bahasa_aktif: String = "id"
var volume_master: float = 1.0
var volume_bgm: float = 0.8
var volume_sfx: float = 0.9
var is_muted: bool = false

# Kamus terjemahan terpusat (Indonesian & English)
const KAMUS: Dictionary = {
	"id": {
		"MENU_PLAY": "MULAI PETUALANGAN",
		"MENU_SETTINGS": "PENGATURAN",
		"MENU_QUIT": "KELUAR PERMAINAN",
		"MENU_TITLE": "AURA: THE LOST RELIC",
		
		"SETTINGS_TITLE": "PENGATURAN",
		"LABEL_AUDIO": "PENGATURAN SUARA",
		"LABEL_MASTER": "Volume Utama",
		"LABEL_BGM": "Volume Musik (BGM)",
		"LABEL_SFX": "Volume Efek (SFX)",
		"LABEL_MUTE": "Bisukan Suara (Mute)",
		"LABEL_LANG": "Bahasa / Language",
		"LANG_ID": "Bahasa Indonesia",
		"LANG_EN": "English",
		
		"LABEL_CONTROLS": "PANDUAN KONTROL",
		"CTRL_MOVE": "A / D atau [◄] [►] : Bergerak",
		"CTRL_JUMP": "W / Spasi atau [▲] : Lompat",
		"CTRL_CLIMB": "W / S (Dekat Tangga) : Memanjat",
		"CTRL_ATTACK": "J / F : Tembak Aura",
		"CTRL_INTERACT": "E : Tarik Tuas / Interaksi",
		"CTRL_PAUSE": "ESC : Menu Jeda",
		
		"BTN_BACK": "KEMBALI",
		"BTN_CLOSE": "TUTUP",
		
		"GAMEOVER_TITLE": "PERJALANAN TERHENTI...",
		"GAMEOVER_SUB": "Rhein telah kehabisan energi aura di dalam reruntuhan kuil.",
		"BTN_RETRY": "ULANGI TAHAP",
		"BTN_MAINMENU": "KEMBALI KE MENU",

		"PAUSE_TITLE": "PERMAINAN DIJEDA",
		"BTN_RESUME": "LANJUTKAN",
		"BTN_RESTART": "ULANGI LEVEL",
		"BTN_SETTINGS": "PENGATURAN",
		
		"CREDITS_TITLE": "TO BE CONTINUED...",
		"CREDITS_SUB": "✦  AURA: THE LOST RELIC  ✦",
		"CREDITS_STORY": "Rhein menembus gerbang kuil purba. Namun misteri relik yang hilang masih tersembunyi jauh di kegelapan reruntuhan...",
		"BTN_CREDITS_MENU": "KEMBALI KE MAIN MENU"
	},
	"en": {
		"MENU_PLAY": "START ADVENTURE",
		"MENU_SETTINGS": "SETTINGS",
		"MENU_QUIT": "QUIT GAME",
		"MENU_TITLE": "AURA: THE LOST RELIC",
		
		"SETTINGS_TITLE": "SETTINGS",
		"LABEL_AUDIO": "AUDIO SETTINGS",
		"LABEL_MASTER": "Master Volume",
		"LABEL_BGM": "Music Volume (BGM)",
		"LABEL_SFX": "Effects Volume (SFX)",
		"LABEL_MUTE": "Mute Audio",
		"LABEL_LANG": "Language / Bahasa",
		"LANG_ID": "Bahasa Indonesia",
		"LANG_EN": "English",
		
		"LABEL_CONTROLS": "CONTROLS GUIDE",
		"CTRL_MOVE": "A / D or [◄] [►] : Move",
		"CTRL_JUMP": "W / Space or [▲] : Jump",
		"CTRL_CLIMB": "W / S (Near Ladder) : Climb",
		"CTRL_ATTACK": "J / F : Aura Blast",
		"CTRL_INTERACT": "E : Pull Lever / Interact",
		"CTRL_PAUSE": "ESC : Pause Menu",
		
		"BTN_BACK": "BACK",
		"BTN_CLOSE": "CLOSE",
		
		"GAMEOVER_TITLE": "JOURNEY ENDED...",
		"GAMEOVER_SUB": "Rhein has run out of aura energy within the ancient temple.",
		"BTN_RETRY": "RETRY LEVEL",
		"BTN_MAINMENU": "MAIN MENU",

		"PAUSE_TITLE": "GAME PAUSED",
		"BTN_RESUME": "RESUME",
		"BTN_RESTART": "RESTART LEVEL",
		"BTN_SETTINGS": "SETTINGS",
		
		"CREDITS_TITLE": "TO BE CONTINUED...",
		"CREDITS_SUB": "✦  AURA: THE LOST RELIC  ✦",
		"CREDITS_STORY": "Rhein stepped through the ancient temple gate. Yet the mystery of the lost relic remains buried deep within the dark ruins...",
		"BTN_CREDITS_MENU": "BACK TO MAIN MENU"
	}
}


func _init() -> void:
	instance = self
	_siapkan_audio_bus()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	muat_pengaturan()


# Mengambil teks terjemahan berdasarkan kunci terpusat (mendukung static & instance call)
static func tr_key(key: String) -> String:
	var lang := "id"
	if instance != null:
		lang = instance.bahasa_aktif
	var dict: Dictionary = KAMUS.get(lang, KAMUS["id"])
	return dict.get(key, key)


func t(key: String) -> String:
	return tr_key(key)


# Mengubah bahasa aktif dan memancarkan sinyal ke seluruh UI
func set_bahasa(kode: String) -> void:
	if kode == "id" or kode == "en":
		bahasa_aktif = kode
		simpan_pengaturan()
		bahasa_berubah.emit(bahasa_aktif)


# Memastikan bus BGM dan SFX ada di AudioServer
func _siapkan_audio_bus() -> void:
	if AudioServer.get_bus_index("BGM") == -1:
		AudioServer.add_bus()
		var bgm_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bgm_idx, "BGM")
		AudioServer.set_bus_send(bgm_idx, "Master")
	
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var sfx_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")


# Mengatur volume bus tertentu secara aman (0.0 sampai 1.0)
func set_bus_volume(bus_name: String, nilai_linear: float) -> void:
	nilai_linear = clampf(nilai_linear, 0.0, 1.0)
	
	match bus_name:
		"Master":
			volume_master = nilai_linear
		"BGM":
			volume_bgm = nilai_linear
		"SFX":
			volume_sfx = nilai_linear

	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		var db: float = linear_to_db(nilai_linear) if nilai_linear > 0.001 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)
		if not is_muted:
			AudioServer.set_bus_mute(bus_idx, nilai_linear <= 0.001)

	simpan_pengaturan()
	volume_berubah.emit(bus_name, nilai_linear)


# Mengatur status bisu suara (Mute)
func set_mute(muted: bool) -> void:
	is_muted = muted
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx != -1:
		AudioServer.set_bus_mute(master_idx, is_muted)
	simpan_pengaturan()
	mute_berubah.emit(is_muted)


# Menyimpan konfigurasi ke file settings.cfg
func simpan_pengaturan() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", volume_master)
	cfg.set_value("audio", "bgm", volume_bgm)
	cfg.set_value("audio", "sfx", volume_sfx)
	cfg.set_value("audio", "mute", is_muted)
	cfg.set_value("locale", "bahasa", bahasa_aktif)
	cfg.save(CONFIG_PATH)


# Memuat konfigurasi tersimpan saat game pertama kali dijalankan
func muat_pengaturan() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err == OK:
		volume_master = cfg.get_value("audio", "master", 1.0)
		volume_bgm = cfg.get_value("audio", "bgm", 0.8)
		volume_sfx = cfg.get_value("audio", "sfx", 0.9)
		is_muted = cfg.get_value("audio", "mute", false)
		bahasa_aktif = cfg.get_value("locale", "bahasa", "id")

	set_bus_volume("Master", volume_master)
	set_bus_volume("BGM", volume_bgm)
	set_bus_volume("SFX", volume_sfx)
	set_mute(is_muted)
