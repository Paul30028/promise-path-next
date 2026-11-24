extends Node
## Global SoundManager Autoload (inspired by Sound Manager + gdfxr):
## Cleanly separates Ambience, SFX, and UI playback with cross-scene mute persistence.

var muted: bool = false
var interior_acoustics: bool = false
var _sfx_players: Array[AudioStreamPlayer] = []
var _ambience_player: AudioStreamPlayer
var _ambience_lpf: AudioEffectLowPassFilter
var _cache: Dictionary = {}


func _ready() -> void:
	# Build Ambience bus with LowPassFilter so entering the 102m Ark muffles exterior storm rain & thunder!
	if AudioServer.get_bus_index("Ambience") < 0:
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Ambience")
		AudioServer.set_bus_send(idx, "Master")
		_ambience_lpf = AudioEffectLowPassFilter.new()
		_ambience_lpf.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(idx, _ambience_lpf)
	for i in range(6):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		add_child(p)
		_sfx_players.append(p)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = "Ambience"
	add_child(_ambience_player)


func set_interior_acoustics(inside: bool) -> void:
	interior_acoustics = inside
	if _ambience_lpf != null:
		var tw: Tween = create_tween()
		tw.tween_property(_ambience_lpf, "cutoff_hz", 780.0 if inside else 20000.0, 0.35)


func _load_wav(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path: String = "res://assets/audio/" + name
	var stream: AudioStream = load(path) as AudioStream
	if stream != null:
		_cache[name] = stream
	return stream


func play_sfx(wav_name: String, volume_db: float = -4.0, pitch_jitter: float = 0.06) -> void:
	if muted:
		return
	var stream: AudioStream = _load_wav(wav_name)
	if stream == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
			p.play()
			return
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = volume_db
	_sfx_players[0].play()


func play_ambience(wav_name: String, volume_db: float = -10.0) -> void:
	if muted:
		return
	var stream: AudioStream = _load_wav(wav_name)
	if stream == null:
		return
	if _ambience_player.stream == stream and _ambience_player.playing:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ambience_player.stream = stream
	_ambience_player.volume_db = volume_db
	_ambience_player.play()


func stop_ambience() -> void:
	if _ambience_player != null:
		_ambience_player.stop()


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return muted
