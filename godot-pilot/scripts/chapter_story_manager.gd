extends RefCounted
## Pure JSON-backed chapter state. Returned dictionaries never expose mutable internals.
var _chapter: Dictionary = {}
var _events: Dictionary = {}
var _state: Dictionary = {}

func load_chapter(path: String = "res://data/ch01_bethel.json") -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("events") is Array:
		return false
	var indexed: Dictionary = {}
	for event in parsed.events:
		if not event is Dictionary or indexed.has(event.get("id", "")) or str(event.get("id", "")).is_empty():
			return false
		if not event.get("choices") is Array or event.choices.size() < 2 or event.choices.size() > 3:
			return false
		var choice_ids: Array = []
		for choice in event.choices:
			for key in ["id", "labelZh", "resultZh", "deltaWater", "deltaHarmony", "deltaPressure", "nextEventId"]:
				if not choice.has(key):
					return false
			if choice_ids.has(choice.id):
				return false
			choice_ids.append(choice.id)
		indexed[event.id] = event
	if indexed.is_empty():
		return false
	for event in indexed.values():
		for choice in event.choices:
			if choice.nextEventId != "" and not indexed.has(choice.nextEventId):
				return false
	_chapter = parsed.duplicate(true)
	_events = indexed.duplicate(true)
	_state = {"saveSchemaVersion": 1, "chapterId": parsed.id, "path": path,
		"currentEventId": parsed.events[0].id, "completed": false,
		"water": parsed.initialState.water, "harmony": parsed.initialState.harmony,
		"pressure": parsed.initialState.pressure, "actionReady": false, "history": []}
	return true

func get_current_event() -> Dictionary:
	return _events.get(_state.get("currentEventId", ""), {}).duplicate(true)

func get_presentation() -> Dictionary:
	return {"ui": _chapter.get("ui", {}).duplicate(true), "completion": _chapter.get("completion", {}).duplicate(true)}

func complete_action(action: String) -> bool:
	if is_completed() or action != get_current_event().get("requiredAction", "") or action.is_empty():
		return false
	_state.actionReady = true
	return true

func apply_camp_delta(water: int, harmony: int) -> void:
	if _state.is_empty():
		return
	_state.water = maxi(0, int(_state.water) + water)
	_state.harmony = clampi(int(_state.harmony) + harmony, 0, 100)

func choose(choice_id: String) -> Dictionary:
	if _state.is_empty() or is_completed():
		return {"ok": false, "error": "inactive"}
	var event: Dictionary = get_current_event()
	if event.has("requiredAction") and not _state.actionReady:
		return {"ok": false, "error": "required_action"}
	for choice in event.choices:
		if choice.id != choice_id:
			continue
		_state.water = maxi(0, int(_state.water) + int(choice.deltaWater))
		_state.harmony = clampi(int(_state.harmony) + int(choice.deltaHarmony), 0, 100)
		_state.pressure = clampi(int(_state.pressure) + int(choice.deltaPressure), 0, 100)
		_state.history.append({"eventId": event.id, "choiceId": choice_id, "resultZh": choice.resultZh})
		_state.currentEventId = choice.nextEventId
		_state.completed = str(choice.nextEventId).is_empty()
		_state.actionReady = false
		return {"ok": true, "resultZh": choice.resultZh, "snapshot": get_snapshot()}
	return {"ok": false, "error": "unknown_choice"}

func get_snapshot() -> Dictionary:
	return _state.duplicate(true)

func restore_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.get("chapterId") != _chapter.get("id") or snapshot.get("saveSchemaVersion") != 1:
		return false
	if not snapshot.get("completed", false) and not _events.has(snapshot.get("currentEventId", "")):
		return false
	for key in _state:
		if not snapshot.has(key) or typeof(snapshot[key]) != typeof(_state[key]):
			# JSON numbers deserialize as floats.
			if not snapshot.has(key) or not (snapshot[key] is float and _state[key] is int):
				return false
	_state = snapshot.duplicate(true)
	return true

func is_completed() -> bool:
	return bool(_state.get("completed", false))
