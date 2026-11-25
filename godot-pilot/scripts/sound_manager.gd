extends Node
## Global 5-Bus SoundManager & Acoustic Director:
## - Buses: Master | Music | Ambience (LPF) | SFX_Exterior (LPF) | SFX_Interior (Cedar Reverb) | UI
## - Entering Ark cabins or Patriarch tents smoothly muffles exterior storm/wind (`20000 Hz -> 780 Hz`)
##   while routing interior footsteps, wood creaks, oil-lamp crackle & livestock breathing through `SFX_Interior` Reverb!

var muted: bool = false
var interior_acoustics: bool = false
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _ambience_lpf: AudioEffectLowPassFilter
var _exterior_lpf: AudioEffectLowPassFilter
var _interior_reverb: AudioEffectReverb
var _cache: Dictionary = {}


func _ensure_bus(bus_name: String, send_to: String = "Master") -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, send_to)
	return idx


func _ready() -> void:
	_ensure_bus("Music")
	var amb_idx: int = _ensure_bus("Ambience")
	if AudioServer.get_bus_effect_count(amb_idx) == 0:
		_ambience_lpf = AudioEffectLowPassFilter.new()
		_ambience_lpf.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(amb_idx, _ambience_lpf)
	else:
		_ambience_lpf = AudioServer.get_bus_effect(amb_idx, 0) as AudioEffectLowPassFilter

	var ext_idx: int = _ensure_bus("SFX_Exterior")
	if AudioServer.get_bus_effect_count(ext_idx) == 0:
		_exterior_lpf = AudioEffectLowPassFilter.new()
		_exterior_lpf.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(ext_idx, _exterior_lpf)
	else:
		_exterior_lpf = AudioServer.get_bus_effect(ext_idx, 0) as AudioEffectLowPassFilter

	var int_idx: int = _ensure_bus("SFX_Interior")
	if AudioServer.get_bus_effect_count(int_idx) == 0:
		_interior_reverb = AudioEffectReverb.new()
		_interior_reverb.room_size = 0.62
		_interior_reverb.damping = 0.72
		_interior_reverb.wet = 0.28
		_interior_reverb.dry = 0.88
		AudioServer.add_bus_effect(int_idx, _interior_reverb)
	else:
		_interior_reverb = AudioServer.get_bus_effect(int_idx, 0) as AudioEffectReverb

	_ensure_bus("UI")

	for i in range(6):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "SFX_Exterior"
		add_child(p)
		_sfx_players.append(p)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UISFXPlayer"
	_ui_player.bus = "UI"
	add_child(_ui_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = "Ambience"
	add_child(_ambience_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	add_child(_music_player)


func set_interior_acoustics(inside: bool) -> void:
	interior_acoustics = inside
	var target_hz: float = 780.0 if inside else 20000.0
	if _ambience_lpf != null and is_inside_tree():
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(_ambience_lpf, "cutoff_hz", target_hz, 0.38)
		if _exterior_lpf != null:
			tw.tween_property(_exterior_lpf, "cutoff_hz", target_hz, 0.38)
	else:
		if _ambience_lpf != null:
			_ambience_lpf.cutoff_hz = target_hz
		if _exterior_lpf != null:
			_exterior_lpf.cutoff_hz = target_hz


func set_bus_volume_db(bus_name: String, db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, clampf(db, -40.0, 6.0))
		AudioServer.set_bus_mute(idx, db <= -39.5)


func get_bus_volume_db(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0


func load_stream(wav_name: String, looped: bool = false) -> AudioStream:
	if _cache.has(wav_name):
		return _cache[wav_name]
	var path: String = wav_name if wav_name.begins_with("res://") else ("res://assets/audio/" + wav_name)
	var stream: AudioStream = load(path) as AudioStream
	if stream != null:
		if looped and stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_cache[wav_name] = stream
	return stream


func make_spatial_loop_3d(wav_name: String, pos: Vector3, max_dist: float = 22.0, vol_db: float = -8.0, interior: bool = true) -> AudioStreamPlayer3D:
	var sp: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	sp.stream = load_stream(wav_name, true)
	sp.position = pos
	sp.unit_size = 5.5
	sp.max_distance = max_dist
	sp.volume_db = vol_db
	sp.bus = "SFX_Interior" if interior else "SFX_Exterior"
	sp.autoplay = true
	return sp


func play_sfx(wav_name: String, volume_db: float = -4.0, pitch_jitter: float = 0.06) -> void:
	if muted:
		return
	var stream: AudioStream = load_stream(wav_name, false)
	if stream == null:
		return
	if "ui_" in wav_name or "assign" in wav_name:
		_ui_player.stream = stream
		_ui_player.volume_db = volume_db
		_ui_player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
		_ui_player.play()
		return
	var target_bus: String = "SFX_Interior" if interior_acoustics else "SFX_Exterior"
	for p in _sfx_players:
		if not p.playing:
			p.bus = target_bus
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
			p.play()
			return
	_sfx_players[0].bus = target_bus
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = volume_db
	_sfx_players[0].play()


func play_ambience(wav_name: String, volume_db: float = -10.0) -> void:
	if muted:
		return
	var stream: AudioStream = load_stream(wav_name, true)
	if stream == null:
		return
	if _ambience_player.stream == stream and _ambience_player.playing:
		return
	_ambience_player.stream = stream
	_ambience_player.volume_db = volume_db
	_ambience_player.play()


func stop_ambience() -> void:
	if _ambience_player != null:
		_ambience_player.stop()


func play_music(wav_name: String = "bgm_levant_lyre_loop.wav", volume_db: float = -11.0) -> void:
	if muted or _music_player == null:
		return
	var stream: AudioStream = load_stream(wav_name, true)
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return muted
