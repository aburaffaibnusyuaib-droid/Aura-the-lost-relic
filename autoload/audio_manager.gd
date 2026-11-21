@tool
extends Node

# Autoload AudioManager (Singleton terdaftar di project.godot)
# Menghasilkan efek suara (SFX) dan ambient BGM secara prosedural (AudioStreamWAV)
# 100% mandiri tanpa ketergantungan aset audio eksternal.

const SAMPLE_RATE: int = 22050
const SFX_BUS: String = "SFX"
const BGM_BUS: String = "BGM"

var sfx_streams: Dictionary = {}
var bgm_stream: AudioStreamWAV = null

var sfx_players: Array[AudioStreamPlayer] = []
var next_player_idx: int = 0
var bgm_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Siapkan audio players
	_siapkan_players()

	# Sintesis seluruh audio stream
	_sintesis_semua_audio()

	# Mainkan ambient BGM
	play_bgm()


func _siapkan_players() -> void:
	# Pool player SFX (8 players agar suara tidak saling memotong)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_" + str(i)
		p.bus = SFX_BUS
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_players.append(p)

	# Dedicated player BGM
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = BGM_BUS
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm_player)


func _create_stream(durasi: float, generator: Callable, loop: bool = false) -> AudioStreamWAV:
	var total_samples := int(SAMPLE_RATE * durasi)
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	var dt := 1.0 / float(SAMPLE_RATE)
	for i in range(total_samples):
		var t := float(i) * dt
		var sample: float = generator.call(t, dt, durasi)
		var s16 := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = total_samples

	return stream


func _sintesis_semua_audio() -> void:
	# 1. Jump: Sapuan frekuensi naik 160Hz -> 460Hz
	var p_jump: float = 0.0
	sfx_streams["jump"] = _create_stream(0.16, func(t: float, dt: float, dur: float) -> float:
		var freq: float = lerp(160.0, 460.0, t / dur)
		p_jump += freq * dt * TAU
		var env: float = 1.0 - (t / dur)
		return sin(p_jump) * env * 0.45
	)

	# 2. Shoot: Laser aura tajam dengan sedikit white noise
	var p_shoot: float = 0.0
	sfx_streams["shoot"] = _create_stream(0.14, func(t: float, dt: float, dur: float) -> float:
		var freq: float = lerp(750.0, 220.0, pow(t / dur, 0.6))
		p_shoot += freq * dt * TAU
		var env: float = pow(1.0 - (t / dur), 1.6)
		var noise: float = (randf() * 2.0 - 1.0) * 0.25
		return (sin(p_shoot) * 0.75 + noise) * env * 0.4
	)

	# 3. Hurt: Hantaman rendah terdistorsi dengan noise
	var p_hurt: float = 0.0
	sfx_streams["hurt"] = _create_stream(0.22, func(t: float, dt: float, dur: float) -> float:
		var freq: float = lerp(210.0, 55.0, t / dur)
		p_hurt += freq * dt * TAU
		var env: float = pow(1.0 - (t / dur), 1.8)
		var tone: float = sign(sin(p_hurt)) * 0.45
		var noise: float = (randf() * 2.0 - 1.0) * 0.55
		return (tone + noise) * env * 0.45
	)

	# 4. Stomp: Squash pop saat menginjak musuh dari atas
	var p_stomp: float = 0.0
	sfx_streams["stomp"] = _create_stream(0.14, func(t: float, dt: float, dur: float) -> float:
		var freq: float = lerp(340.0, 90.0, t / dur)
		p_stomp += freq * dt * TAU
		var env: float = 1.0 - (t / dur)
		return sin(p_stomp) * env * 0.5
	)

	# 5. Defeat: Desis asap hilangnya musuh
	sfx_streams["defeat"] = _create_stream(0.24, func(t: float, _dt: float, dur: float) -> float:
		var env: float = pow(1.0 - (t / dur), 2.0)
		return (randf() * 2.0 - 1.0) * env * 0.35
	)

	# 6. Key / Pickup: Dering kristal 2-nada (880Hz -> 1320Hz)
	var p_key: float = 0.0
	sfx_streams["key"] = _create_stream(0.35, func(t: float, dt: float, dur: float) -> float:
		var target_freq: float = 880.0 if t < dur * 0.38 else 1320.0
		p_key += target_freq * dt * TAU
		var env: float = pow(1.0 - (t / dur), 1.3)
		return sin(p_key) * env * 0.4
	)

	# 7. Interact (Tuas / Mekanisme): Dentang mekanis batu
	var p_it: float = 0.0
	sfx_streams["interact"] = _create_stream(0.12, func(t: float, dt: float, dur: float) -> float:
		var freq: float = 240.0
		p_it += freq * dt * TAU
		var env: float = pow(1.0 - (t / dur), 3.0)
		var noise: float = (randf() * 2.0 - 1.0) * 0.35
		return (sin(p_it) * 0.65 + noise) * env * 0.4
	)

	# 8. Puzzle Click: Gesekan batu mini
	sfx_streams["puzzle_click"] = _create_stream(0.06, func(t: float, _dt: float, dur: float) -> float:
		var env: float = pow(1.0 - (t / dur), 3.5)
		return (randf() * 2.0 - 1.0) * env * 0.3
	)

	# 9. Puzzle Win: Akord mistis kuno 4-nada (C5, E5, G5, C6)
	var p_win1: float = 0.0
	var p_win2: float = 0.0
	var p_win3: float = 0.0
	var p_win4: float = 0.0
	sfx_streams["puzzle_win"] = _create_stream(0.9, func(t: float, dt: float, dur: float) -> float:
		p_win1 += 523.25 * dt * TAU
		p_win2 += 659.25 * dt * TAU
		p_win3 += 783.99 * dt * TAU
		p_win4 += 1046.50 * dt * TAU
		var env: float = pow(1.0 - (t / dur), 1.2)
		var a1: float = 1.0 if t >= 0.0 else 0.0
		var a2: float = 1.0 if t >= 0.12 else 0.0
		var a3: float = 1.0 if t >= 0.24 else 0.0
		var a4: float = 1.0 if t >= 0.36 else 0.0
		var sum: float = (sin(p_win1) * a1 + sin(p_win2) * a2 + sin(p_win3) * a3 + sin(p_win4) * a4) * 0.25
		return sum * env * 0.45
	)

	# 10. Portal: Pusaran resonansi mistis
	var p_portal: float = 0.0
	sfx_streams["portal"] = _create_stream(0.75, func(t: float, dt: float, dur: float) -> float:
		var freq: float = 220.0 + sin(t * 12.0) * 60.0
		p_portal += freq * dt * TAU
		var env: float = pow(1.0 - (t / dur), 1.2)
		return (sin(p_portal) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * env * 0.45
	)

	# 11. Button Click: Klik UI singkat dan tajam
	var p_btn: float = 0.0
	sfx_streams["button_click"] = _create_stream(0.04, func(t: float, dt: float, dur: float) -> float:
		p_btn += 880.0 * dt * TAU
		var env: float = 1.0 - (t / dur)
		return sin(p_btn) * env * 0.3
	)

	# 12. BGM Ambient: Drone atmosferik kuil kuno bernada C2 (65.4 Hz) berulang mulus
	bgm_stream = _create_stream(3.5, func(t: float, _dt: float, dur: float) -> float:
		var w1 := sin(t * 65.41 * TAU) * 0.32
		var w2 := sin(t * 98.00 * TAU) * 0.18
		var w3 := sin(t * 130.81 * TAU) * 0.12
		var lfo := 0.85 + 0.15 * sin(t * TAU / dur)
		return (w1 + w2 + w3) * lfo
	, true)


func play_sfx(nama: String) -> void:
	if not sfx_streams.has(nama):
		return
	if sfx_players.is_empty():
		return

	var player := sfx_players[next_player_idx]
	next_player_idx = (next_player_idx + 1) % sfx_players.size()
	player.stream = sfx_streams[nama]
	player.play()


func play_jump() -> void:
	play_sfx("jump")


func play_shoot() -> void:
	play_sfx("shoot")


func play_hurt() -> void:
	play_sfx("hurt")


func play_stomp() -> void:
	play_sfx("stomp")


func play_defeat() -> void:
	play_sfx("defeat")


func play_key() -> void:
	play_sfx("key")


func play_interact() -> void:
	play_sfx("interact")


func play_puzzle_click() -> void:
	play_sfx("puzzle_click")


func play_puzzle_win() -> void:
	play_sfx("puzzle_win")


func play_portal() -> void:
	play_sfx("portal")


func play_button_click() -> void:
	play_sfx("button_click")


func play_bgm() -> void:
	if bgm_player and bgm_stream:
		if not bgm_player.playing:
			bgm_player.stream = bgm_stream
			bgm_player.play()


func stop_bgm() -> void:
	if bgm_player:
		bgm_player.stop()
