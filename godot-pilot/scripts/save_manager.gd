extends Node
## Atomic Versioned SaveManager (`CampaignSaveV3`):
## - Registers `res://translations/messages.csv` (`zh_CN` + `en_US`) into `TranslationServer` at startup
## - Writes crash-safe `.tmp` -> rename JSON snapshots + `240x135` PNG viewport thumbnails per slot (`user://saves/slot_N.png`)
## - Persists `carryoverLedger`, `covenantStonesLit`, 5-bus audio dB, graphics quality, head-bob & touch-stick settings!

signal locale_changed(locale_code: String)
signal settings_changed

const SAVE_SCHEMA_VERSION: int = 3
const SAVE_DIR: String = "user://saves"
const SETTINGS_PATH: String = "user://settings.cfg"
const I18N_CSV_PATH: String = "res://translations/messages.csv"

var current_locale: String = "zh_CN"
var head_bob_enabled: bool = true
var touch_stick_enabled: bool = false
var graphics_quality: int = 0  # 0=High, 1=Balanced, 2=Mobile
var master_db: float = 0.0
var ambience_db: float = -2.0
var sfx_db: float = 0.0
var pending_load_slot: int = 0

var covenant_stones_lit: Array[int] = []
var carryover_ledger: Dictionary = {
	"noah_harmony_bonus": 0,
	"p01_water_bonus": 0,
	"p01_harmony_bonus": 0,
	"p01_pressure_offset": 0,
}
var _translations_loaded: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	touch_stick_enabled = DisplayServer.is_touchscreen_available()
	ensure_translations_loaded()
	load_settings()
	_apply_audio_settings()


func ensure_translations_loaded() -> void:
	if _translations_loaded:
		return
	if not FileAccess.file_exists(I18N_CSV_PATH):
		return
	var f: FileAccess = FileAccess.open(I18N_CSV_PATH, FileAccess.READ)
	if f == null:
		return
	var header: PackedStringArray = f.get_csv_line()
	if header.size() < 3:
		f.close()
		return
	var tr_zh: Translation = Translation.new()
	tr_zh.locale = "zh_CN"
	var tr_en: Translation = Translation.new()
	tr_en.locale = "en_US"
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 3 and not row[0].strip_edges().is_empty():
			var k: StringName = StringName(row[0].strip_edges())
			tr_zh.add_message(k, row[1])
			tr_en.add_message(k, row[2])
	f.close()
	TranslationServer.add_translation(tr_zh)
	TranslationServer.add_translation(tr_en)
	TranslationServer.set_locale(current_locale)
	_translations_loaded = true


func slot_path(slot_idx: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, clampi(slot_idx, 0, 3)]


func slot_thumb_path(slot_idx: int) -> String:
	return "%s/slot_%d.png" % [SAVE_DIR, clampi(slot_idx, 0, 3)]


func has_save(slot_idx: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot_idx))


func first_existing_slot() -> int:
	for s in [1, 2, 3, 0]:
		if has_save(s):
			return s
	return -1


func light_covenant_stone(stone_id: int) -> void:
	if not covenant_stones_lit.has(stone_id):
		covenant_stones_lit.append(stone_id)
		save_settings()


func record_carryover(key: String, val: Variant) -> void:
	carryover_ledger[key] = val
	save_settings()


func save_slot(slot_idx: int, payload: Dictionary, viewport: Viewport = null) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data: Dictionary = payload.duplicate(true)
	data["saveSchemaVersion"] = SAVE_SCHEMA_VERSION
	data["savedAtIso"] = Time.get_datetime_string_from_system(false, true)
	data["locale"] = current_locale
	data["covenantStonesLit"] = covenant_stones_lit.duplicate()
	data["carryoverLedger"] = carryover_ledger.duplicate(true)

	# Capture 240x135 live screenshot thumbnail when running with a visible renderer!
	var vp: Viewport = viewport if viewport != null else (get_viewport() if is_inside_tree() else null)
	if vp != null and DisplayServer.get_name() != "headless" and vp.get_texture() != null:
		var img: Image = vp.get_texture().get_image()
		if img != null and not img.is_empty():
			img.resize(240, 135, Image.INTERPOLATE_BILINEAR)
			img.save_png(slot_thumb_path(slot_idx))

	var final_path: String = slot_path(slot_idx)
	var tmp_path: String = final_path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open %s for writing" % tmp_path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()
	var err: Error = DirAccess.rename_absolute(tmp_path, final_path)
	if err != OK:
		push_error("SaveManager: atomic rename failed (%d)" % err)
		return false
	return true


func load_slot(slot_idx: int) -> Dictionary:
	var p: String = slot_path(slot_idx)
	if not FileAccess.file_exists(p):
		return {}
	var raw: String = FileAccess.get_file_as_string(p)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return {}
	var d: Dictionary = parsed
	if int(d.get("saveSchemaVersion", 0)) < 1:
		return {}
	if d.get("carryoverLedger") is Dictionary:
		carryover_ledger.merge(d["carryoverLedger"], true)
	if d.get("covenantStonesLit") is Array:
		covenant_stones_lit.clear()
		for st in d["covenantStonesLit"]:
			covenant_stones_lit.append(int(st))
	return d


func load_slot_thumbnail(slot_idx: int) -> Texture2D:
	var tp: String = slot_thumb_path(slot_idx)
	if not FileAccess.file_exists(tp):
		return null
	var img: Image = Image.load_from_file(tp)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func delete_slot(slot_idx: int) -> void:
	var p: String = slot_path(slot_idx)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	var tp: String = slot_thumb_path(slot_idx)
	if FileAccess.file_exists(tp):
		DirAccess.remove_absolute(tp)


func _apply_audio_settings() -> void:
	var sm_node: Node = get_node_or_null("/root/SoundManager") if is_inside_tree() else null
	if sm_node != null and sm_node.has_method("set_bus_volume_db"):
		sm_node.call("set_bus_volume_db", "Master", master_db)
		sm_node.call("set_bus_volume_db", "Ambience", ambience_db)
		sm_node.call("set_bus_volume_db", "SFX_Exterior", sfx_db)
		sm_node.call("set_bus_volume_db", "SFX_Interior", sfx_db)


func apply_graphics_quality_to_env(env: Environment, sun_light: DirectionalLight3D = null) -> void:
	if env == null:
		return
	var is_fp: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
	if graphics_quality == 0 and is_fp:
		env.ssao_enabled = true
		env.sdfgi_enabled = true
		env.volumetric_fog_enabled = true
		if sun_light != null: sun_light.shadow_enabled = true
	elif graphics_quality == 1:
		env.ssao_enabled = is_fp
		env.sdfgi_enabled = false
		env.volumetric_fog_enabled = is_fp
		if sun_light != null: sun_light.shadow_enabled = true
	else:
		env.ssao_enabled = false
		env.sdfgi_enabled = false
		env.volumetric_fog_enabled = false
		if sun_light != null: sun_light.shadow_enabled = false


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", current_locale)
	cfg.set_value("general", "stones", covenant_stones_lit)
	cfg.set_value("general", "carryover", carryover_ledger)
	cfg.set_value("comfort", "head_bob", head_bob_enabled)
	cfg.set_value("comfort", "touch_stick", touch_stick_enabled)
	cfg.set_value("graphics", "quality", graphics_quality)
	cfg.set_value("audio", "master_db", master_db)
	cfg.set_value("audio", "ambience_db", ambience_db)
	cfg.set_value("audio", "sfx_db", sfx_db)
	var sm_node: Node = get_node_or_null("/root/SoundManager") if is_inside_tree() else null
	cfg.set_value("audio", "muted", bool(sm_node.get("muted")) if sm_node != null else false)
	cfg.save(SETTINGS_PATH)
	_apply_audio_settings()
	settings_changed.emit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		current_locale = str(cfg.get_value("general", "locale", "zh_CN"))
		var st_arr: Variant = cfg.get_value("general", "stones", [])
		if st_arr is Array:
			covenant_stones_lit.clear()
			for v in st_arr:
				covenant_stones_lit.append(int(v))
		var co: Variant = cfg.get_value("general", "carryover", {})
		if co is Dictionary:
			carryover_ledger.merge(co, true)
		head_bob_enabled = bool(cfg.get_value("comfort", "head_bob", true))
		touch_stick_enabled = bool(cfg.get_value("comfort", "touch_stick", DisplayServer.is_touchscreen_available()))
		graphics_quality = int(cfg.get_value("graphics", "quality", 0))
		master_db = float(cfg.get_value("audio", "master_db", 0.0))
		ambience_db = float(cfg.get_value("audio", "ambience_db", -2.0))
		sfx_db = float(cfg.get_value("audio", "sfx_db", 0.0))
	TranslationServer.set_locale(current_locale)


func set_locale(code: String) -> void:
	ensure_translations_loaded()
	current_locale = code
	TranslationServer.set_locale(code)
	save_settings()
	locale_changed.emit(code)
