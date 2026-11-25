extends Node
## Atomic Versioned SaveManager (CampaignSaveV3) — writes to .tmp then atomically renames.
## Works identically on Steam Cloud Auto-Cloud (user://saves/) and Android/Desktop local storage.

signal locale_changed(locale_code: String)

const SAVE_SCHEMA_VERSION: int = 3
const SAVE_DIR: String = "user://saves"
const SETTINGS_PATH: String = "user://settings.cfg"

var current_locale: String = "zh_CN"
var head_bob_enabled: bool = true
var pending_load_slot: int = 0


func first_existing_slot() -> int:
	for s in [1, 2, 3, 0]:
		if has_save(s):
			return s
	return -1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	load_settings()


func slot_path(slot_idx: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, clampi(slot_idx, 0, 3)]


func has_save(slot_idx: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot_idx))


func save_slot(slot_idx: int, payload: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data: Dictionary = payload.duplicate(true)
	data["saveSchemaVersion"] = SAVE_SCHEMA_VERSION
	data["savedAtIso"] = Time.get_datetime_string_from_system(false, true)
	data["locale"] = current_locale

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
	return d


func delete_slot(slot_idx: int) -> void:
	var p: String = slot_path(slot_idx)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", current_locale)
	cfg.set_value("comfort", "head_bob", head_bob_enabled)
	var sm_node: Node = get_node_or_null("/root/SoundManager") if is_inside_tree() else null
	cfg.set_value("audio", "muted", bool(sm_node.get("muted")) if sm_node != null else false)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		current_locale = str(cfg.get_value("general", "locale", "zh_CN"))
		head_bob_enabled = bool(cfg.get_value("comfort", "head_bob", true))


func set_locale(code: String) -> void:
	current_locale = code
	TranslationServer.set_locale(code)
	save_settings()
	locale_changed.emit(code)
