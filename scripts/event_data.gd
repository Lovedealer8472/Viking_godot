# ═══════════════════════════════════════════════════════════════════════════
# EventData — autoload. Loads the settlement event catalogue into SimEvents at
# startup so Act 4's pick_weekly_event has a populated pool. (SimEvents._events
# is static, so loading once here persists for the whole session.)
#
# The JSON is generated from the browser TS event files by
# X:\viking\convert_events.mjs.
# ═══════════════════════════════════════════════════════════════════════════
extends Node

const EVENTS_PATH := "res://data/settlement_events.json"

func _ready() -> void:
	if not FileAccess.file_exists(EVENTS_PATH):
		push_warning("EventData: %s not found — settlement events will be empty." % EVENTS_PATH)
		return
	var text := FileAccess.get_file_as_string(EVENTS_PATH)
	SimEvents.load_from_json(text)
	print("[EventData] Loaded %d settlement events." % SimEvents.get_events().size())
