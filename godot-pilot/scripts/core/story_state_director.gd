class_name StoryStateDirector
extends Node
## Universal Chapter Story & Godot State Charts Director:
## - Dynamically constructs a real `StateChart` (`CompoundState` + `AtomicState` + `Transition` per JSON event)
## - Emits `event_activated(event_id, event_dict, preserve_positions)` so any chapter cartridge (`Ch00..Ch11`)
##   runs on a deterministic, inspectable Hierarchical State Machine!

signal event_activated(event_id: String, event_dict: Dictionary, preserve_positions: bool)

var chapter_data: Dictionary = {}
var event_index: Dictionary = {}
var current_event_id: String = ""
var state_chart: StateChart
var root_compound: CompoundState
var _pending_preserve: bool = false
var _suppress_initial: bool = false
var _last_emitted_id: String = ""


func setup_from_json(json_path: String, initial_override: String = "") -> Dictionary:
	var f: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return {}
	chapter_data = parsed
	event_index.clear()
	for ev in chapter_data.get("events", []):
		if ev is Dictionary:
			event_index[str(ev.get("id", ""))] = ev

	var first_id: String = initial_override if (not initial_override.is_empty() and event_index.has(initial_override)) else str(chapter_data.get("firstEventId", ""))
	if first_id.is_empty() and not event_index.is_empty():
		first_id = str(event_index.keys()[0])

	_build_state_chart(first_id)
	return chapter_data


func _build_state_chart(first_id: String) -> void:
	if state_chart != null and is_instance_valid(state_chart):
		state_chart.queue_free()

	state_chart = StateChart.new()
	state_chart.name = "ChapterStateChart"
	root_compound = CompoundState.new()
	root_compound.name = "ActFlow"

	var atomic_map: Dictionary = {}
	for eid in event_index.keys():
		var st: AtomicState = AtomicState.new()
		st.name = String(eid)
		var captured_id: String = str(eid)
		st.state_entered.connect(func() -> void:
			if _suppress_initial:
				return
			if not current_event_id.is_empty() and captured_id != current_event_id:
				state_chart.send_event(StringName("goto_" + current_event_id))
				return
			if _last_emitted_id == captured_id:
				return
			current_event_id = captured_id
			_last_emitted_id = captured_id
			var keep_pos: bool = _pending_preserve
			_pending_preserve = false
			event_activated.emit(captured_id, event_index.get(captured_id, {}), keep_pos)
		)
		root_compound.add_child(st)
		atomic_map[captured_id] = st

	# Create direct jump transitions on root CompoundState so `transition_to("goto_<id>")` is O(1) from any state!
	for eid in atomic_map.keys():
		var tr_node: Transition = Transition.new()
		tr_node.name = "Goto_" + str(eid)
		tr_node.event = StringName("goto_" + str(eid))
		var target_st: AtomicState = atomic_map[eid]
		root_compound.add_child(tr_node)
		tr_node.to = tr_node.get_path_to(target_st)

	if atomic_map.has(first_id):
		root_compound.initial_state = root_compound.get_path_to(atomic_map[first_id])

	state_chart.add_child(root_compound)
	_suppress_initial = true
	add_child(state_chart)
	_suppress_initial = false


func transition_to(event_id: String, preserve_positions: bool = false) -> void:
	if not event_index.has(event_id):
		return
	_pending_preserve = preserve_positions
	current_event_id = event_id
	_last_emitted_id = ""
	if state_chart != null:
		state_chart.send_event(StringName("goto_" + event_id))
	if _last_emitted_id != event_id:
		_last_emitted_id = event_id
		var kp: bool = _pending_preserve
		_pending_preserve = false
		event_activated.emit(event_id, event_index[event_id], kp)


func current_event() -> Dictionary:
	return event_index.get(current_event_id, {})
