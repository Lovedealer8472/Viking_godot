# ═══════════════════════════════════════════════════════════════════════════
# Events — lightweight event system with pool filtering, flag matching,
# and effect resolution. Events can be loaded from a JSON dictionary
# (convert TS events to Godot Resources later).
#
# Ported from src/sim/eventFlags.ts and supporting event logic from
# src/sim/weeklyTurn.ts.
# ═══════════════════════════════════════════════════════════════════════════
class_name SimEvents
extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════
# Event data store — load from JSON or set at runtime.
# Defaults to an empty array; call set_events() or load_from_json().
# ═══════════════════════════════════════════════════════════════════════════

static var _events: Array = []  # Array[Dictionary] — each dict is an event

# Set the full event pool.
static func set_events(events: Array) -> void:
	_events = events

# Get the current event pool.
static func get_events() -> Array:
	return _events

# Find an event by its id string. Returns {} if not found.
static func find_event(id: String) -> Dictionary:
	for e in _events:
		if e.get("id", "") == id:
			return e
	return {}

# Load events from a JSON string.
static func load_from_json(json_string: String) -> void:
	var result = JSON.parse_string(json_string)
	if result is Array:
		_events = result
	elif result is Dictionary and result.has("events"):
		_events = result["events"]
	else:
		push_warning("SimEvents.load_from_json: invalid format, events array expected")


# ═══════════════════════════════════════════════════════════════════════════
# Event filtering — returns the eligible event pool for the current state.
# Matches the logic in weeklyTurn.ts: pickWeeklyEvent().
# ═══════════════════════════════════════════════════════════════════════════

static func event_pool(events: Array, season: int, realism: int, event_flags: Dictionary,
		week_mod: int, recent_ids: Array, excluded_ids: Array = []) -> Array:
	var result: Array = []
	for e in events:
		if e.get("id", "") in excluded_ids:
			continue
		if e.get("id", "") == "shipping_season":
			continue  # shipping is handled separately
		if not (_realism_allowed(e, realism)):
			continue
		if not _season_allowed(e, season):
			continue
		if not _week_in_range(e, week_mod):
			continue
		if not event_flags_match(event_flags, e.get("requires_flags", {})):
			continue
		if event_flags_blocked(event_flags, e.get("blocks_flags", {})):
			continue
		var cooldown: int = e.get("cooldown_weeks", 4)
		if e.get("id", "") in recent_ids.slice(0, cooldown):
			continue
		result.append(e)
	return result


# Filter without shipping exclusion (for fallback pool).
static func event_pool_fallback(events: Array, realism: int) -> Array:
	var result: Array = []
	for e in events:
		if e.get("id", "") == "shipping_season":
			continue
		if _realism_allowed(e, realism):
			result.append(e)
	return result


# ── Individual check helpers ──────────────────────────────────────────────

static func _realism_allowed(event: Dictionary, realism: int) -> bool:
	if not event.has("realism"):
		return true
	var realism_list: Array = event["realism"]
	# realism_list contains ints matching GameTypes.Realism enum
	return realism in realism_list


static func _season_allowed(event: Dictionary, season: int) -> bool:
	if not event.has("seasons"):
		return true
	var season_list: Array = event["seasons"]
	return season in season_list


static func _week_in_range(event: Dictionary, week_mod: int) -> bool:
	if event.has("min_week") and week_mod < event["min_week"]:
		return false
	if event.has("max_week") and week_mod > event["max_week"]:
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════
# Event flag matching
# ═══════════════════════════════════════════════════════════════════════════

# Returns true if all required flags match the current flags.
static func event_flags_match(current_flags: Dictionary, requires: Dictionary) -> bool:
	if requires.is_empty():
		return true
	for key in requires:
		var required_val = requires[key]
		if current_flags.get(key) != required_val:
			return false
	return true


# Returns true if any blocking flag is set (event should be excluded).
static func event_flags_blocked(current_flags: Dictionary, blocks: Dictionary) -> bool:
	if blocks.is_empty():
		return false
	for key in blocks:
		var blocked_val = blocks[key]
		if current_flags.get(key) == blocked_val:
			return true
	return false


# Apply flag set/clear operations. Returns a new flags Dictionary.
static func apply_event_flags(current_flags: Dictionary, set_flags: Dictionary, clear_flags: Array) -> Dictionary:
	var result: Dictionary = current_flags.duplicate()
	for key in set_flags:
		result[key] = set_flags[key]
	for key in clear_flags:
		result.erase(key)
	return result


# ═══════════════════════════════════════════════════════════════════════════
# Lore requirements check (ported from lore.ts meetsLore)
# ═══════════════════════════════════════════════════════════════════════════

# Check if state meets lore requirements (Dictionary of LoreBranch int -> level).
static func meets_lore(state: GameState, requires: Dictionary) -> bool:
	if requires.is_empty():
		return true
	for branch in requires:
		var needed: int = requires[branch]
		if state.get_lore(branch) < needed:
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════
# Weighted random event selection (ported from weeklyTurn.ts pickWeeklyEvent)
# ═══════════════════════════════════════════════════════════════════════════

static func weighted_pick(pool: Array, difficulty_bias: Dictionary = {}, base_flags: Dictionary = {}) -> Dictionary:
	if pool.is_empty():
		return {}
	var weighted: Array = []
	for event in pool:
		var w: float = event.get("weight", 1.0)
		# Flag-gated events get 2.5x weight boost
		var flags: Dictionary = event.get("requires_flags", {})
		if not flags.is_empty():
			w *= 2.5
		# Difficulty bias
		# difficulty_bias: {difficulty_int: float_multiplier}
		# We expect difficulty_bias to have the current difficulty as the key
		# Actually the TS version has event.difficultyBias?.[state.setup.difficulty] ?? 1
		# In the Godot version, difficulty_bias is keyed by difficulty int
		w *= difficulty_bias.get("all", 1.0)
		weighted.append({"event": event, "weight": w})

	var total_weight: float = 0.0
	for entry in weighted:
		total_weight += entry["weight"]

	if total_weight <= 0.0:
		return pool[pool.size() - 1] if not pool.is_empty() else {}

	# This function doesn't take an RNG parameter — it's meant for the caller
	# who has the RNG. Instead, weighted_pick returns the list for external roll.
	# We store the weighted list as metadata for the caller.
	push_warning("SimEvents.weighted_pick: use weighted_pick_roll() instead")
	return {}


# Better: weighted array + roll function
static func weighted_pick_roll(pool: Array, rng: Callable, difficulty_bias: int = -1) -> Dictionary:
	if pool.is_empty():
		return {}

	var weighted: Array = []
	for event in pool:
		var w: float = event.get("weight", 1.0)
		var flags: Dictionary = event.get("requires_flags", {})
		if not flags.is_empty():
			w *= 2.5
		# Difficulty bias from event definition
		var bias_dict: Dictionary = event.get("difficulty_bias", {})
		if difficulty_bias >= 0 and bias_dict.has(difficulty_bias):
			w *= float(bias_dict[difficulty_bias])
		weighted.append({"event": event, "weight": w})

	var total_weight: float = 0.0
	for entry in weighted:
		total_weight += entry["weight"]

	if total_weight <= 0.0:
		return pool[pool.size() - 1] if not pool.is_empty() else {}

	var roll: float = rng.call() * total_weight
	for entry in weighted:
		roll -= entry["weight"]
		if roll <= 0.0:
			return entry["event"]

	return pool[pool.size() - 1]


# ═══════════════════════════════════════════════════════════════════════════
# Effect resolution — apply an event choice's effects to GameState.
# Matches applyEventChoice() in weeklyTurn.ts.
# ═══════════════════════════════════════════════════════════════════════════

# Apply resource delta fields directly to GameState.
static func apply_resource_delta(state: GameState, delta: Dictionary) -> void:
	if delta.has("food"):       state.food       = max(0.0, state.food + float(delta["food"]))
	if delta.has("hay"):        state.hay        = max(0.0, state.hay + float(delta["hay"]))
	if delta.has("fuel"):       state.fuel       = max(0.0, state.fuel + float(delta["fuel"]))
	if delta.has("materials"):  state.materials  = max(0.0, state.materials + float(delta["materials"]))
	if delta.has("morale"):     state.morale     = clampf(state.morale + float(delta["morale"]), 0.0, 100.0)
	if delta.has("knowledge"):  state.knowledge  = max(0.0, state.knowledge + float(delta["knowledge"]))
	if delta.has("wealth"):     state.wealth     = max(0.0, state.wealth + float(delta["wealth"]))
	if delta.has("tools"):      state.tools      = clampf(state.tools + float(delta["tools"]), 0.0, 100.0)
	if delta.has("shelter"):    state.shelter    = clampf(state.shelter + float(delta["shelter"]), 0.0, 4.0)


# Apply a choice's effects to the state. Handles all effect types:
# resources, lore, standing, milestones, discoveries, herd, characters,
# supernatural mutations, and event flags.
static func resolve_choice_effects(state: GameState, choice: Dictionary, event_id: String = "") -> void:
	var effects: Dictionary = choice.get("effects", {})

	# Resource effects
	apply_resource_delta(state, effects)

	# Standing
	if effects.has("standing"):
		state.standing = max(0, state.standing + int(effects["standing"]))

	# Lore
	if effects.has("lore_branch") and effects.has("lore_amount"):
		var branch: int = effects["lore_branch"]
		var amount: int = effects["lore_amount"]
		state.add_lore(branch, amount)

	# Milestone
	if effects.has("milestone"):
		state.milestones[str(effects["milestone"])] = true

	# Discover region
	if effects.has("discover_region"):
		var region: int = effects["discover_region"]
		if not (region in state.discovered_regions):
			state.discovered_regions.append(region)

	# Herd delta
	if effects.has("herd_delta"):
		var herd_d: Dictionary = effects["herd_delta"]
		for animal in herd_d:
			var new_val: int = _get_herd_count(state, animal) + int(herd_d[animal])
			_set_herd_count(state, animal, max(0, new_val))

	# Character injury
	if effects.has("injury_character_id"):
		var target_id: String = effects["injury_character_id"]
		var found := false
		for c in state.characters:
			if c.id == target_id and c.alive and not c.is_child:
				c.injured = true
				found = true
				break
		if not found:
			# Fallback: injure first able-bodied adult
			for c in state.characters:
				if c.alive and not c.injured and not c.is_child:
					c.injured = true
					break

	# Supernatural: vættir shift
	if effects.has("vaettir_shift"):
		var vs: Dictionary = effects["vaettir_shift"]
		var region: int = vs.get("region", -1)  # -1 means home -> coast
		var mood: int = vs.get("mood", GameTypes.VaettirMood.UNSEEN)
		# Update supernatural state
		var sup: Dictionary = state.supernatural_state
		var moods: Dictionary = sup.get("vaettir_moods", {})
		var eff_region: int = GameTypes.RegionId.COAST if region == -1 else region
		moods[eff_region] = mood
		sup["vaettir_moods"] = moods

	# Supernatural: haunting shift
	if effects.has("haunting_shift"):
		var delta: int = effects["haunting_shift"]
		var sup: Dictionary = state.supernatural_state
		var stage: int = sup.get("haunting_stage", 0)
		sup["haunting_stage"] = clamp(stage + delta, 0, 5)

	# Supernatural: burial debt shift
	if effects.has("burial_debt_shift"):
		var delta: int = effects["burial_debt_shift"]
		var sup: Dictionary = state.supernatural_state
		var debt: int = clamp(sup.get("burial_debt", 0) + delta, 0, 10)
		sup["burial_debt"] = debt

	# Supernatural: draugar set
	if effects.has("draugar_set"):
		state.supernatural_state["draugar_active"] = bool(effects["draugar_set"])

	# Supernatural: curse gain
	if effects.has("curse_gain"):
		var c_id: String = str(effects["curse_gain"])
		var curses: Array = state.supernatural_state.get("curse_objects", [])
		if not (c_id in curses):
			curses.append(c_id)
			state.supernatural_state["curse_objects"] = curses

	# Supernatural: curse remove
	if effects.has("curse_remove"):
		var c_id: String = str(effects["curse_remove"])
		var curses: Array = state.supernatural_state.get("curse_objects", [])
		state.supernatural_state["curse_objects"] = curses.filter(func(x): return x != c_id)

	# Supernatural: permanent scar
	if effects.has("permanent_scar"):
		var scar: String = str(effects["permanent_scar"])
		var scars: Array = state.supernatural_state.get("permanent_scars", [])
		if not (scar in scars):
			scars.append(scar)
			state.supernatural_state["permanent_scars"] = scars

	# Supernatural: taboo violate
	if effects.has("taboo_violate"):
		var taboo: String = str(effects["taboo_violate"])
		var violations: Array = state.supernatural_state.get("taboo_violations", [])
		if not (taboo in violations):
			violations.append(taboo)
			state.supernatural_state["taboo_violations"] = violations

	# Supernatural: taboo repair
	if effects.has("taboo_repair"):
		var repair: String = str(effects["taboo_repair"])
		var violations: Array = state.supernatural_state.get("taboo_violations", [])
		state.supernatural_state["taboo_violations"] = violations.filter(func(x): return x != repair)

	# Supernatural: barrow discover
	if effects.has("barrow_discover"):
		var barrow: Dictionary = effects["barrow_discover"]
		var barrows: Array = state.supernatural_state.get("barrows", [])
		var found := false
		for b in barrows:
			if b.get("id", "") == barrow.get("id", ""):
				found = true
				break
		if not found:
			barrows.append(barrow)
			state.supernatural_state["barrows"] = barrows

	# Event flags
	if effects.has("event_flag_set") or effects.has("event_flag_clear"):
		state.event_flags = apply_event_flags(
			state.event_flags,
			effects.get("event_flag_set", {}),
			effects.get("event_flag_clear", [])
		)

	# Saga entry
	if effects.has("saga_entry"):
		state.saga_log.append(str(effects["saga_entry"]))


# ── Herd helpers ─────────────────────────────────────────────────────────

static func _get_herd_count(state: GameState, animal: int) -> int:
	match animal:
		GameTypes.AnimalType.CATTLE:   return state.cattle
		GameTypes.AnimalType.SHEEP:    return state.sheep
		GameTypes.AnimalType.GOATS:    return state.goats
		GameTypes.AnimalType.HORSES:   return state.horses
		GameTypes.AnimalType.PIGS:     return state.pigs
		GameTypes.AnimalType.CHICKENS: return state.chickens
	return 0


static func _set_herd_count(state: GameState, animal: int, value: int) -> void:
	match animal:
		GameTypes.AnimalType.CATTLE:   state.cattle = value
		GameTypes.AnimalType.SHEEP:    state.sheep = value
		GameTypes.AnimalType.GOATS:    state.goats = value
		GameTypes.AnimalType.HORSES:   state.horses = value
		GameTypes.AnimalType.PIGS:     state.pigs = value
		GameTypes.AnimalType.CHICKENS: state.chickens = value
