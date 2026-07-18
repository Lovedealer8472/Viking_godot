# ═══════════════════════════════════════════════════════════════════════════
# Weekly Turn — the core pipeline for resolving a settlement week.
# Ported from src/sim/weeklyTurn.ts.
#
# Main entry: resolve_assignments(state) runs the full weekly tick.
# ═══════════════════════════════════════════════════════════════════════════
class_name SimWeeklyTurn
extends RefCounted

# ── Resource delta keys that get scaled by site terrain factor ───────────

const RESOURCE_DELTA_KEYS: Array = [
	"food", "hay", "fuel", "materials", "morale", "knowledge", "wealth", "tools", "shelter",
]

# ── Skip-event narrative entries ─────────────────────────────────────────

const SKIP_ENTRIES: Array = [
	"The household let it pass without counsel.",
	"The matter was set aside. Some things need no answer.",
	"No one spoke their mind; the week moved on all the same.",
	"The settlement kept its own counsel that week.",
	"They chose not to act, and the moment passed.",
	"The household turned back to its work and said nothing of it.",
]

# ── Site data (minimal — port from src/data/sites.ts) ────────────────────
# Each site has terrain modifiers that scale task material outputs.

const SITE_DATA: Dictionary = {
	"estuary_meadow": {
		"name": "Estuary Meadow",
		"coastal": true,
		"modifiers": {"hay_quality": 1.2, "fishing": 1.1, "grazing": 1.1, "fuel": 1.0, "driftwood": 0.8},
		"pasture_bonus": 10,
	},
	"rocky_coast": {
		"name": "Rocky Coast",
		"coastal": true,
		"modifiers": {"hay_quality": 0.7, "fishing": 1.3, "grazing": 0.6, "fuel": 0.5, "driftwood": 1.4},
		"pasture_bonus": 6,
	},
	"inland_valley": {
		"name": "Inland Valley",
		"coastal": false,
		"modifiers": {"hay_quality": 1.3, "fishing": 0.3, "grazing": 1.3, "fuel": 0.9, "driftwood": 0.2},
		"pasture_bonus": 12,
	},
	"forest_clearing": {
		"name": "Forest Clearing",
		"coastal": false,
		"modifiers": {"hay_quality": 0.9, "fishing": 0.6, "grazing": 0.8, "fuel": 1.5, "driftwood": 0.5},
		"pasture_bonus": 8,
	},
}

static func _site_data(site_id: String) -> Dictionary:
	return SITE_DATA.get(site_id, SITE_DATA["estuary_meadow"])


# ═══════════════════════════════════════════════════════════════════════════
# Seeded RNG — port of seededRandom() from weeklyTurn.ts
# ═══════════════════════════════════════════════════════════════════════════

static func create_rng(state: GameState) -> Callable:
	var seed: int = state.week * 9973 + state.year * 7919 + 17
	return _seeded_random(seed)


static func _seeded_random(seed: int) -> Callable:
	var s: int = seed % 4294967296
	if s <= 0:
		s += 4294967296
	# Use an array wrapper so the lambda can mutate the captured variable
	var state_arr: Array = [s]
	return func() -> float:
		state_arr[0] = (state_arr[0] * 1664525 + 1013904223) % 4294967296
		return float(state_arr[0]) / 4294967296.0


# ═══════════════════════════════════════════════════════════════════════════
# Site terrain factor — scales task material outputs by site quality.
# ═══════════════════════════════════════════════════════════════════════════

static func site_task_factor(site_id: String, task: int) -> float:
	var mods: Dictionary = _site_data(site_id).get("modifiers", {})
	match task:
		GameTypes.WeeklyTask.MAKE_HAY:      return mods.get("hay_quality", 1.0)
		GameTypes.WeeklyTask.FISH:          return mods.get("fishing", 1.0)
		GameTypes.WeeklyTask.FORAGE:        return (mods.get("grazing", 1.0) + mods.get("fishing", 1.0)) / 2.0
		GameTypes.WeeklyTask.HUNT:          return mods.get("grazing", 1.0)
		GameTypes.WeeklyTask.GATHER_FUEL:   return (mods.get("fuel", 1.0) + mods.get("driftwood", 1.0)) / 2.0
		_: return 1.0


# ═══════════════════════════════════════════════════════════════════════════
# Event category classification (for saga verdict narrative)
# ═══════════════════════════════════════════════════════════════════════════

static func categorize_event(event: Dictionary) -> String:
	var tags: Array = event.get("tags", [])
	if "supernatural" in tags or "horror" in tags or "mythic" in tags:
		return "supernatural"
	if "feud" in tags or "dispute" in tags:
		return "feud"
	if "exploration" in tags or "discovery" in tags or "wayfinding" in tags:
		return "discovery"
	if "religion" in tags or "sacrifice" in tags:
		return "sacrifice"
	if "trade" in tags or "resource" in tags:
		return "trade"
	return "survival"


# ═══════════════════════════════════════════════════════════════════════════
# Aggregate all character assignments into resource/lore/standing deltas.
# ═══════════════════════════════════════════════════════════════════════════

static func _aggregate_assignments(state: GameState, rng: Callable, injuries: Array) -> Dictionary:
	var resource_delta: Dictionary = {}
	var standing_delta := 0.0
	var lore_delta: Dictionary = {}

	for c in state.characters:
		if not c.alive:
			continue
		var task: int = state.assignments.get(c.id, GameTypes.WeeklyTask.FORAGE)
		var effect: Dictionary = SimTasks.compute_task_contribution(c, task, state.season, state.weather)
		var factor: float = site_task_factor(state.site_id, task)

		# Apply resource deltas with site factor scaling
		for key in RESOURCE_DELTA_KEYS:
			if effect.has(key):
				var val: float = effect[key]
				var scaled: float = val * factor if val > 0 else val
				resource_delta[key] = resource_delta.get(key, 0.0) + scaled

		# Standing
		if effect.has("standing"):
			standing_delta += effect["standing"]

		# Lore
		if effect.has("lore_branch") and effect.has("lore_amount"):
			var branch: int = effect["lore_branch"]
			var amount: float = effect["lore_amount"]
			lore_delta[branch] = lore_delta.get(branch, 0.0) + amount

		# Injury risk
		if effect.has("injury_risk"):
			var difficulty: Dictionary = SimResources.difficulty_profile(state.difficulty)
			var injury_mult: float = difficulty.get("injury", 1.0)
			if rng.call() < effect["injury_risk"] * injury_mult:
				c.injured = true
				injuries.append(c.char_name)

	# Round resource deltas for tidy ledgers
	for key in RESOURCE_DELTA_KEYS:
		if resource_delta.has(key):
			resource_delta[key] = snapped(resource_delta[key], 0.1)

	return {"resource_delta": resource_delta, "standing_delta": standing_delta, "lore_delta": lore_delta}


# ═══════════════════════════════════════════════════════════════════════════
# Sync derived event flags from supernatural state.
# ═══════════════════════════════════════════════════════════════════════════

static func _sync_derived_event_flags(state: GameState) -> void:
	var sup: Dictionary = state.supernatural_state
	var flags: Dictionary = state.event_flags.duplicate()

	# Burial debt
	if sup.get("burial_debt", 0) >= 5:
		flags["burial_debt_high"] = true
	else:
		flags.erase("burial_debt_high")

	# Vaettir offended/hostile
	var vaettir_offended := false
	var moods: Dictionary = sup.get("vaettir_moods", {})
	for m in moods.values():
		if m == GameTypes.VaettirMood.OFFENDED or m == GameTypes.VaettirMood.HOSTILE:
			vaettir_offended = true
			break
	if vaettir_offended:
		flags["vaettir_offended"] = true
	else:
		flags.erase("vaettir_offended")

	# Shipping contact milestone
	if state.milestones.get("shipping_contact", false):
		flags["shipping_contact"] = true

	# Sync supernatural state into flags
	flags["haunting_stage"] = sup.get("haunting_stage", 0)
	flags["draugar_active"] = sup.get("draugar_active", false)

	state.event_flags = flags


# ═══════════════════════════════════════════════════════════════════════════
# Weekly event selection — weighted random, with tutorial/shipping overrides.
# ═══════════════════════════════════════════════════════════════════════════

static func pick_weekly_event(state: GameState, rng: Callable) -> Dictionary:
	var season: int = GameTypes.week_to_season(state.week)
	var difficulty: Dictionary = SimResources.difficulty_profile(state.difficulty)
	var events: Array = SimEvents.get_events()

	# Tutorial: week 1 of settlement act gets survey_the_land
	if state.week == 1 and state.act == GameTypes.ActId.SETTLEMENT:
		var tutorial: Dictionary = SimEvents.find_event("survey_the_land")
		if not tutorial.is_empty():
			return tutorial

	# Shipping season: weeks 18-30, once per year
	var week_mod: int = state.week % 52
	var in_shipping_window: bool = week_mod >= 18 and week_mod <= 30
	var shipping_resolved_year: int = state.shipping_resolved_year  # flat field
	if in_shipping_window and shipping_resolved_year < state.year:
		var harsh_mult: float = difficulty.get("harsh", 1.0)
		if rng.call() < 0.45 * harsh_mult:
			var ship: Dictionary = SimEvents.find_event("shipping_season")
			if not ship.is_empty():
				return ship

	# Filter eligible events (matching TS logic exactly)
	var recent: Array = state.recent_event_ids  # Array[String]
	var eligible: Array = []
	for e in events:
		var eid: String = e.get("id", "")
		if eid == "shipping_season":
			continue
		if eid in recent:
			continue
		# Realism filter
		var realism_list: Array = e.get("realism", [])
		if not realism_list.is_empty() and not (state.realism in realism_list):
			continue
		# Season filter
		var season_list: Array = e.get("seasons", [])
		if not season_list.is_empty() and not (season in season_list):
			continue
		# Week range
		var wm: int = week_mod if week_mod != 0 else 52
		if e.has("min_week") and wm < e["min_week"]:
			continue
		if e.has("max_week") and wm > e["max_week"]:
			continue
		# Flag requirements
		var req_flags: Dictionary = e.get("requires_flags", {})
		if not SimEvents.event_flags_match(state.event_flags, req_flags):
			continue
		# Flag blocks
		var block_flags: Dictionary = e.get("blocks_flags", {})
		if SimEvents.event_flags_blocked(state.event_flags, block_flags):
			continue
		# Cooldown
		var cooldown: int = e.get("cooldown_weeks", 4)
		if eid in recent.slice(0, cooldown):
			continue
		eligible.append(e)

	# Fallback if eligible pool is empty
	var pool: Array = eligible
	if pool.is_empty():
		pool = []
		for e in events:
			var eid: String = e.get("id", "")
			if eid == "shipping_season":
				continue
			var realism_list: Array = e.get("realism", [])
			if realism_list.is_empty() or (state.realism in realism_list):
				pool.append(e)

	# Weighted selection
	return SimEvents.weighted_pick_roll(pool, rng, state.difficulty)


# ═══════════════════════════════════════════════════════════════════════════
# Resource delta merger — applies a Dictionary of resource changes to state.
# ═══════════════════════════════════════════════════════════════════════════

static func _merge_resource(state: GameState, delta: Dictionary) -> void:
	SimEvents.apply_resource_delta(state, delta)


# ── Herd loss description helper (port of describeLosses from herd.ts) ──

static func _describe_losses(losses: Dictionary) -> String:
	if losses.is_empty():
		return "none"
	var parts: Array = []
	for animal in [GameTypes.AnimalType.CATTLE, GameTypes.AnimalType.SHEEP,
			GameTypes.AnimalType.GOATS, GameTypes.AnimalType.HORSES,
			GameTypes.AnimalType.PIGS, GameTypes.AnimalType.CHICKENS]:
		if losses.has(animal):
			var count: int = losses[animal]
			if count > 0:
				var label: String = _animal_label(animal)
				parts.append("%d %s" % [count, label])
	return ", ".join(parts)


static func _animal_label(animal: int) -> String:
	match animal:
		GameTypes.AnimalType.CATTLE:   return "cattle"
		GameTypes.AnimalType.SHEEP:    return "sheep"
		GameTypes.AnimalType.GOATS:    return "goats"
		GameTypes.AnimalType.HORSES:   return "horses"
		GameTypes.AnimalType.PIGS:     return "pigs"
		GameTypes.AnimalType.CHICKENS: return "chickens"
	return "animals"


# ── Character progression (ported from characterProgression.ts) ─────────

# Maps each task to the primary stat it exercises
const TASK_STAT_MAP := {
	GameTypes.WeeklyTask.FORAGE: "strength",
	GameTypes.WeeklyTask.HUNT: "strength",
	GameTypes.WeeklyTask.FISH: "resilience",
	GameTypes.WeeklyTask.MAKE_HAY: "strength",
	GameTypes.WeeklyTask.TEND_HERD: "resilience",
	GameTypes.WeeklyTask.GATHER_FUEL: "resilience",
	GameTypes.WeeklyTask.BUILD: "strength",
	GameTypes.WeeklyTask.CRAFT: "intelligence",
	GameTypes.WeeklyTask.SCOUT: "intelligence",
	GameTypes.WeeklyTask.SAIL_EXPLORE: "willpower",
	GameTypes.WeeklyTask.VIKING_ABROAD: "willpower",
	GameTypes.WeeklyTask.GUARD: "strength",
	GameTypes.WeeklyTask.STORYTELL: "intelligence",
	GameTypes.WeeklyTask.FEAST: "willpower",
	GameTypes.WeeklyTask.REST: "resilience",
	GameTypes.WeeklyTask.TRAIN: "strength",
	GameTypes.WeeklyTask.TEND_LAND: "intelligence",
}

# How many weeks of a given task before a stat point is earned
const WEEKS_PER_STAT_POINT := 8

# Trait-based growth multipliers — makes traits meaningful for progression
const TRAIT_MULTIPLIERS := {
	"planner": {"intelligence": 1.5},
	"immovable": {"resilience": 1.5},
	"endurance": {"resilience": 1.5},
	"eidetic_memory": {"intelligence": 1.5},
	"skilled_hands": {"intelligence": 1.3, "strength": 1.2},
	"keen_eye": {"intelligence": 1.3},
	"rapid_learner": {"intelligence": 2.0, "strength": 1.3, "resilience": 1.3, "willpower": 1.3},
}

# Injuries from overwork or random chance
static func _track_character_work(state: GameState, injuries: Array) -> void:
	# Track what each character did this week
	for c in state.characters:
		if not c.alive or c.injured:
			continue

		var task: int = state.assignments.get(c.id, -1)
		if task < 0:
			continue

		# Initialize work credits metadata if not present
		if not c.has_meta("work_credits"):
			c.set_meta("work_credits", {})
		var credits: Dictionary = c.get_meta("work_credits")

		var stat: String = TASK_STAT_MAP.get(task, "")
		if stat.is_empty():
			continue

		# Apply trait multiplier
		var multiplier := 1.0
		var trait_array: Array = c.traits
		for t in trait_array:
			var t_mult: Dictionary = TRAIT_MULTIPLIERS.get(str(t), {})
			multiplier = maxf(multiplier, t_mult.get(stat, 1.0))

		# Accumulate credits (1.0 per week, modified by traits)
		credits[stat] = credits.get(stat, 0.0) + multiplier
		c.set_meta("work_credits", credits)

	# Track injuries from overwork (3+ weeks without rest on same task)
	for c in state.characters:
		if not c.alive or c.injured:
			continue
		var task: int = state.assignments.get(c.id, -1)
		if task < 0:
			continue

		# Track consecutive weeks on same task
		var last_task: int = c.get_meta("last_task") if c.has_meta("last_task") else -1
		var streak: int = c.get_meta("task_streak") if c.has_meta("task_streak") else 0

		if task == last_task:
			streak += 1
		else:
			streak = 1

		c.set_meta("last_task", task)
		c.set_meta("task_streak", streak)

		# Overwork: 4+ weeks on same physical task causes injury risk
		if streak >= 4 and task in [GameTypes.WeeklyTask.FORAGE, GameTypes.WeeklyTask.HUNT,
				GameTypes.WeeklyTask.BUILD, GameTypes.WeeklyTask.GUARD,
				GameTypes.WeeklyTask.VIKING_ABROAD, GameTypes.WeeklyTask.SAIL_EXPLORE]:
			if randf() < 0.15:
				c.injured = true
				injuries.append(c.char_name)
				state.saga_log.append("%s collapsed from overwork." % c.char_name)


# Apply stat growth when credits reach threshold
static func _apply_character_growth(state: GameState) -> void:
	for c in state.characters:
		if not c.alive:
			continue

		if not c.has_meta("work_credits"):
			continue

		var credits: Dictionary = c.get_meta("work_credits")
		var new_credits := {}
		var grew := false

		for stat in credits.keys():
			var earned: float = credits[stat]
			var points := int(earned / WEEKS_PER_STAT_POINT)
			var remainder := earned - points * WEEKS_PER_STAT_POINT
			new_credits[stat] = remainder

			if points > 0:
				match stat:
					"strength":
						c.strength = mini(c.strength + points, 6)
					"resilience":
						c.resilience = mini(c.resilience + points, 6)
					"willpower":
						c.willpower = mini(c.willpower + points, 6)
					"intelligence":
						c.intelligence = mini(c.intelligence + points, 6)
				grew = true

		c.set_meta("work_credits", new_credits)

		if grew:
			state.saga_log.append("%s has grown stronger from their labors." % c.char_name)


# ═══════════════════════════════════════════════════════════════════════════
# Main pipeline: resolve_assignments
# Resolves a full week of work, applies upkeep, supernatural, discoveries,
# milestones, and returns the new state plus summary info.
# ═══════════════════════════════════════════════════════════════════════════

static func resolve_assignments(state: GameState) -> Dictionary:
	var rng: Callable = create_rng(state)
	var injuries: Array = []  # Array[String] — character names
	var difficulty: Dictionary = SimResources.difficulty_profile(state.difficulty)

	# ── Aggregate all character assignments ──
	var agg: Dictionary = _aggregate_assignments(state, rng, injuries)
	var resource_delta: Dictionary = agg["resource_delta"]
	var standing_delta: float = agg["standing_delta"]
	var lore_delta: Dictionary = agg["lore_delta"]

	# ── Building bonuses ──
	var bonuses: Dictionary = SimBuildings.building_bonuses(state)

	var food_delta: float = resource_delta.get("food", 0.0)
	var hay_delta: float = resource_delta.get("hay", 0.0)
	var mats_delta: float = resource_delta.get("materials", 0.0)

	if bonuses.get("food_save", 0.0) > 0 and food_delta > 0:
		resource_delta["food"] = food_delta * (1.0 + bonuses["food_save"])
	if bonuses.get("hay_save", 0.0) > 0 and hay_delta > 0:
		resource_delta["hay"] = hay_delta * (1.0 + bonuses["hay_save"])
	if bonuses.get("craft_bonus", 1.0) != 1.0 and mats_delta > 0:
		resource_delta["materials"] = mats_delta * bonuses["craft_bonus"]

	# Apply resource deltas
	_merge_resource(state, resource_delta)

	# ── Herd yield (milk/eggs/meat trickle), scaled by site grazing ──
	var has_tend_herd: bool = GameTypes.WeeklyTask.TEND_HERD in state.assignments.values()
	var grazing: float = _site_data(state.site_id).get("modifiers", {}).get("grazing", 1.0)
	var herd_dict: Dictionary = state.get_herd_dict()
	var yield_food: float = snapped(SimHerd.herd_food_yield(herd_dict, has_tend_herd) * grazing, 0.1)
	_merge_resource(state, {"food": yield_food})

	# ── Population upkeep ──
	var pop: int = state.living_population()
	var upkeep: Dictionary = SimResources.weekly_upkeep(pop, state.season, state.weather, state.shelter, difficulty.get("upkeep", 1.0))
	_merge_resource(state, upkeep)

	# ── Lore + standing ──
	var lore_keys: Array = lore_delta.keys()
	for branch in lore_keys:
		var amount: int = roundi(lore_delta[branch])
		state.add_lore(branch, amount)
	state.standing = max(0, state.standing + roundi(standing_delta))

	# ── Knowledge decay ──
	var has_knowledge_task := false
	for t in state.assignments.values():
		if t == GameTypes.WeeklyTask.STORYTELL or t == GameTypes.WeeklyTask.TRAIN:
			has_knowledge_task = true
			break
	if not has_knowledge_task:
		state.knowledge -= 0.5

	# ── Winter fodder & mortality ──
	var fodder_note := ""
	if state.season == GameTypes.Season.WINTER:
		var result: Dictionary = SimHerd.consume_winter_fodder(herd_dict, state.hay, rng)
		var new_herd: Dictionary = result["herd"]
		state.set_herd(new_herd)
		state.hay -= result.get("consumed", 0.0)
		var total_losses: int = result.get("total", 0)
		if total_losses > 0:
			state.morale -= float(total_losses * 2)
			var losses_desc: Dictionary = result.get("losses", {})
			fodder_note = " Livestock starved: %s." % [_describe_losses(losses_desc)]
	elif state.season == GameTypes.Season.SUMMER:
		var healthy: bool = state.food > float(pop * 2) and state.hay > SimHerd.hay_demand_per_week(herd_dict)
		var pasture_bonus: int = _site_data(state.site_id).get("pasture_bonus", 10)
		var bred: Dictionary = SimHerd.breed_herd(herd_dict, healthy, rng)
		state.set_herd(bred)

	# ── Supernatural tick ──
	var sup_result: Dictionary = SimSupernatural.tick_supernatural(state, rng)
	var sup_morale: int = sup_result.get("morale_delta", 0)
	var sup_food_risk: float = sup_result.get("food_risk", 0.0)
	var sup_injury: float = sup_result.get("injury_risk_bonus", 0.0)
	var new_supernatural: Dictionary = sup_result.get("new_supernatural", {})

	if sup_morale != 0:
		state.morale += float(sup_morale)
	if sup_food_risk > 0 and rng.call() < sup_food_risk:
		var food_loss: float = snapped(state.food * 0.08, 0.1)
		state.food -= food_loss
	if sup_injury > 0:
		var able: Array = []
		for c in state.characters:
			if c.alive and not c.injured and not c.is_child:
				able.append(c)
		if not able.is_empty() and rng.call() < sup_injury:
			var pick: CharacterData = able[rng.call() * able.size()]
			if not (pick.char_name in injuries):
				pick.injured = true
				injuries.append(pick.char_name)

	state.supernatural_state = new_supernatural

	# ── Discoveries ──
	var scout_count := 0
	var sail_count := 0
	var viking_count := 0
	for c in state.characters:
		if not c.alive:
			continue
		var t: int = state.assignments.get(c.id, GameTypes.WeeklyTask.FORAGE)
		match t:
			GameTypes.WeeklyTask.SCOUT: scout_count += 1
			GameTypes.WeeklyTask.SAIL_EXPLORE: sail_count += 1
			GameTypes.WeeklyTask.VIKING_ABROAD: viking_count += 1

	if (scout_count > 0 or sail_count > 0) and rng.call() < 0.18 * float(scout_count) + 0.28 * float(sail_count):
		var pool_r: Array = [
			GameTypes.RegionId.VALLEY, GameTypes.RegionId.BOG,
			GameTypes.RegionId.GROVE, GameTypes.RegionId.RIVER,
			GameTypes.RegionId.RUIN, GameTypes.RegionId.DRIFTWOOD_BEACH,
			GameTypes.RegionId.HEADLAND, GameTypes.RegionId.LEE_SLOPE,
		]
		for r in pool_r:
			if not (r in state.discovered_regions):
				state.discovered_regions.append(r)
				break

	var saga_warning := ""
	if viking_count > 0:
		var site: Dictionary = _site_data(state.site_id)
		var has_dock: bool = GameTypes.BuildingId.DOCK in state.buildings_built
		var can_viking: bool = site.get("coastal", false) and has_dock and state.milestones.get("shipping_contact", false) and state.year >= 2
		if can_viking:
			var gained_wealth: int = roundi(float(viking_count) * (4.0 if rng.call() < 0.55 else 1.0))
			var gained_standing: int = viking_count * 2 if rng.call() < 0.5 else 0
			state.wealth += float(gained_wealth)
			state.standing += gained_standing
		elif not site.get("coastal", false):
			saga_warning = " The inland would-be raiders found no reachable coast — their venture yielded nothing."
		elif not has_dock:
			saga_warning = " Without a dock no longship could be launched for raiding."
		elif not state.milestones.get("shipping_contact", false):
			saga_warning = " Without shipping contacts the abroad raid went nowhere."

	# ── Milestones ──
	if state.shelter >= 3.0 and not state.milestones.get("great_hall_built", false):
		state.milestones["great_hall_built"] = true
	if not state.milestones.get("thing_established", false) and state.standing >= 25 and state.lore_law >= 8:
		state.milestones["thing_established"] = true

	# ── Builder count ──
	var builder_count := 0
	for c in state.characters:
		if c.alive and state.assignments.get(c.id, GameTypes.WeeklyTask.FORAGE) == GameTypes.WeeklyTask.BUILD:
			builder_count += 1

	# ── Character growth tracking (stub) ──
	_track_character_work(state, injuries)
	_apply_character_growth(state)

	# ── Pick next event ──
	var next_event: Dictionary = pick_weekly_event(state, rng)
	state.pending_event_id = next_event.get("id", "")

	# ── Advance construction ──
	SimBuildings.advance_construction(state, builder_count)

	# ── Sync derived event flags ──
	_sync_derived_event_flags(state)

	# ── Saga log ──
	if not injuries.is_empty():
		state.saga_log.append("Labor done. Injured: %s." % [", ".join(injuries)])
	else:
		state.saga_log.append("The household labored through the week.")
	if not fodder_note.is_empty():
		state.saga_log[-1] += fodder_note
	if not saga_warning.is_empty():
		state.saga_log[-1] += saga_warning

	# ── Task summary ──
	var task_parts: Array = []
	if resource_delta.get("food", 0.0) != 0.0 or yield_food != 0.0:
		var total_food: float = snapped(resource_delta.get("food", 0.0) + yield_food, 0.1)
		task_parts.append("food +%.1f" % [total_food])
	if resource_delta.has("hay"):
		task_parts.append("hay +%.1f" % [resource_delta["hay"]])
	if resource_delta.has("fuel"):
		task_parts.append("fuel +%.1f" % [resource_delta["fuel"]])
	if builder_count > 0 and not state.active_project.is_empty():
		var proj: Dictionary = state.active_project
		var b_id: int = proj.get("building_id", -1)
		var b_def: Dictionary = SimBuildings.BUILDING_DEFS.get(b_id, {})
		var progress: int = proj.get("progress", 0)
		var work_req: int = b_def.get("work_required", 999)
		task_parts.append("build %d/%d" % [progress, work_req])

	return {
		"state": state,
		"summary": "Week %d resolved." % [state.week],
		"task_summary": ", ".join(task_parts) if not task_parts.is_empty() else "minimal gains",
		"injuries": injuries,
	}


# ═══════════════════════════════════════════════════════════════════════════
# apply_event_choice — applies an event choice's effects to the state.
# Returns the modified GameState.
# ═══════════════════════════════════════════════════════════════════════════

static func apply_event_choice(state: GameState, event_id: String, choice_id: String) -> GameState:
	var event: Dictionary = SimEvents.find_event(event_id)
	if event.is_empty():
		return state

	var choice: Dictionary = {}
	for c in event.get("choices", []):
		if c.get("id", "") == choice_id:
			choice = c
			break

	if choice.is_empty():
		return state

	var effects: Dictionary = choice.get("effects", {})

	# ── Requirement checks ──
	if choice.has("requires_knowledge") and state.knowledge < float(choice["requires_knowledge"]):
		return state
	if choice.has("requires_lore"):
		if not SimEvents.meets_lore(state, choice["requires_lore"]):
			return state
	if choice.has("requires_standing") and state.standing < int(choice["requires_standing"]):
		return state
	if choice.has("requires_wealth") and state.wealth < float(choice["requires_wealth"]):
		return state

	# ── Apply effects via SimEvents ──
	SimEvents.resolve_choice_effects(state, choice, event_id)

	# ── Shipping season tracking ──
	if event_id == "shipping_season":
		state.shipping_resolved_year = state.year

	# ── Event flags (shipping contact milestone) ──
	if state.milestones.get("shipping_contact", false):
		state.event_flags["shipping_contact"] = true

	_sync_derived_event_flags(state)

	# ── Recent event IDs ──
	var recent: Array = state.recent_event_ids.duplicate()
	recent.push_front(event_id)
	state.recent_event_ids = recent.slice(0, 6)

	# ── Clear pending event ──
	state.pending_event_id = ""

	# ── Saga log for this choice ──
	var saga_entry: String = effects.get("saga_entry", "")
	if saga_entry.is_empty():
		saga_entry = "%s: %s" % [event.get("title", "Event"), choice.get("label", "Chosen")]
	state.saga_log.append(saga_entry)

	# ── Track most significant event ──
	var weight: float = float(event.get("weight", 0))
	var req_flags: Dictionary = event.get("requires_flags", {})
	var tags: Array = event.get("tags", [])
	var is_filler: bool = "filler" in tags

	if (weight >= 6.0 or not req_flags.is_empty()) and not is_filler:
		state.most_significant_event = event_id
		state.most_significant_event_category = categorize_event(event)

	# ── Preview next event's special requirements ──
	var preview: String = _preview_special_requirement(state)
	if not preview.is_empty():
		state.saga_log.append(preview)

	return state


# ═══════════════════════════════════════════════════════════════════════════
# Preview next event's special-option requirements.
# ═══════════════════════════════════════════════════════════════════════════

static func _preview_special_requirement(state: GameState) -> String:
	var next_state := GameState.new()

	# Copy relevant fields
	next_state.week = state.week + 1
	next_state.year = state.year
	next_state.act = state.act
	next_state.difficulty = state.difficulty
	next_state.realism = state.realism
	next_state.event_flags = state.event_flags.duplicate()
	next_state.recent_event_ids = state.recent_event_ids.duplicate()
	next_state.shipping_resolved_year = state.shipping_resolved_year
	next_state.milestones = state.milestones.duplicate()
	next_state.supernatural_state = state.supernatural_state.duplicate(true)
	next_state.site_id = state.site_id
	next_state.pending_event_id = ""

	var rng: Callable = create_rng(next_state)
	var preview_event: Dictionary = pick_weekly_event(next_state, rng)
	if preview_event.is_empty():
		return ""

	var choices: Array = preview_event.get("choices", [])
	var special: Dictionary = {}
	for c in choices:
		if c.has("requires_knowledge") or c.has("requires_lore") or c.has("requires_standing"):
			special = c
			break

	if special.is_empty():
		return ""

	var parts: Array = []
	if special.has("requires_knowledge"):
		parts.append("%d lore" % [special["requires_knowledge"]])
	if special.has("requires_lore"):
		var rl: Dictionary = special["requires_lore"]
		for k in rl:
			parts.append("%d %s" % [rl[k], _lore_name(int(k))])
	if special.has("requires_standing"):
		parts.append("%d standing" % [special["requires_standing"]])

	return "An event approaches: %s — requires %s for the special option" % [preview_event.get("title", "?"), "; ".join(parts)]


static func _lore_name(branch: int) -> String:
	match branch:
		GameTypes.LoreBranch.LAW: return "law"
		GameTypes.LoreBranch.RITUAL: return "ritual"
		GameTypes.LoreBranch.GENEALOGY: return "genealogy"
		GameTypes.LoreBranch.WAYFINDING: return "wayfinding"
		GameTypes.LoreBranch.LAND: return "land"
		GameTypes.LoreBranch.RUNE: return "rune"
	return "unknown"


# ═══════════════════════════════════════════════════════════════════════════
# advance_week — increments week, heals injuries, rolls weather,
# handles starvation/desertion, checks game over.
# ═══════════════════════════════════════════════════════════════════════════

static func advance_week(state: GameState) -> GameState:
	var next_week: int = state.week + 1
	var rng: Callable = _seeded_random(next_week * 9973 + state.year * 7919 + 17)
	var season: int = GameTypes.week_to_season(next_week)
	var weather: int = SimResources.roll_weather(next_week, rng)
	var diff: Dictionary = SimResources.difficulty_profile(state.difficulty)
	weather = SimResources.apply_difficulty_to_weather(weather, diff.get("weather", 0.0))

	# ── Injury recovery ──
	for c in state.characters:
		if c.injured:
			var was_resting: bool = state.assignments.get(c.id, GameTypes.WeeklyTask.FORAGE) == GameTypes.WeeklyTask.REST
			var recover_chance: float = 0.8 if was_resting else 0.6
			if rng.call() < recover_chance:
				c.injured = false

	var flags: Dictionary = state.event_flags.duplicate()

	# ── Starvation: food at 0 kills one character per week ──
	if state.food <= 0.0:
		var non_children: Array = []
		for c in state.characters:
			if c.alive and not c.is_child:
				non_children.append(c)
		if not non_children.is_empty():
			# Kill the character with lowest resilience
			non_children.sort_custom(func(a, b): return a.resilience < b.resilience)
			non_children[0].alive = false

	# ── Desertion: morale at 0 for 4+ consecutive weeks ──
	var desertion_weeks: int = flags.get("desertion_weeks", 0)
	if state.morale <= 0.0:
		desertion_weeks += 1
		flags["desertion_weeks"] = desertion_weeks
		if desertion_weeks >= 4:
			var able: Array = []
			for c in state.characters:
				if c.alive and not c.is_child:
					able.append(c)
			if not able.is_empty():
				able.sort_custom(func(a, b): return a.loyalty < b.loyalty)
				able[0].alive = false
			flags["desertion_weeks"] = 0
	else:
		flags["desertion_weeks"] = 0

	# ── Update state ──
	state.week = next_week
	state.season = season
	state.weather = weather
	state.event_flags = flags
	state.pending_event_id = ""

	# ── Game over check ──
	if state.living_population() <= 0:
		state.game_over = true
		state.victory = false
		state.saga_log.append("The last soul has fallen. The settlement is no more.")
		return state

	# ── Individual death spiral ──
	# Starvation: if food is at zero and has been for 3+ weeks
	if state.food <= 0.0:
		var hunger_weeks: int = flags.get("hunger_weeks", 0) + 1
		flags["hunger_weeks"] = hunger_weeks
		if hunger_weeks >= 3:
			# The weakest character dies
			var living: Array = []
			for c in state.characters:
				if c.alive:
					living.append(c)
			if not living.is_empty():
				living.sort_custom(func(a, b): return a.resilience < b.resilience)
				var victim: CharacterData = living[0]
				victim.alive = false
				state.saga_log.append("%s has starved to death." % victim.char_name)
				flags["hunger_weeks"] = 0
	else:
		flags["hunger_weeks"] = 0

	# Freezing: no fuel in winter kills
	if state.fuel <= 0.0 and state.season == GameTypes.Season.WINTER:
		var freeze_weeks: int = flags.get("freeze_weeks", 0) + 1
		flags["freeze_weeks"] = freeze_weeks
		if freeze_weeks >= 2:
			var living: Array = []
			for c in state.characters:
				if c.alive:
					living.append(c)
			if not living.is_empty():
				living.sort_custom(func(a, b): return a.resilience < b.resilience)
				var victim: CharacterData = living[0]
				victim.alive = false
				state.saga_log.append("%s froze to death in the winter cold." % victim.char_name)
				flags["freeze_weeks"] = 0
	else:
		flags["freeze_weeks"] = 0

	# ── Morale collapse ──
	if state.morale <= 5.0:
		var despair_weeks: int = flags.get("despair_weeks", 0) + 1
		flags["despair_weeks"] = despair_weeks
		if despair_weeks >= 4:
			# Lowest-loyalty character deserts
			var living: Array = []
			for c in state.characters:
				if c.alive and c.id != "leader":
					living.append(c)
			if not living.is_empty():
				living.sort_custom(func(a, b): return a.loyalty < b.loyalty)
				var deserter: CharacterData = living[0]
				deserter.alive = false  # "dead" = gone from settlement
				state.saga_log.append("%s has abandoned the settlement in despair." % deserter.char_name)
				flags["despair_weeks"] = 0
	else:
		flags["despair_weeks"] = 0

	# ── Victory check: survive 3 years ──
	if state.year >= 4 and state.living_population() >= 3 and state.standing >= 3:
		state.game_over = true
		state.victory = true
		state.saga_log.append("After three hard years, the settlement endures. The saga will be told for generations.")

	return state


# ═══════════════════════════════════════════════════════════════════════════
# skip_event — dismiss the pending event without making a choice.
# ═══════════════════════════════════════════════════════════════════════════

static func skip_event(state: GameState) -> GameState:
	var entry: String = SKIP_ENTRIES[state.week % SKIP_ENTRIES.size()]
	var skipped_id: String = state.pending_event_id

	if not skipped_id.is_empty():
		var recent: Array = state.recent_event_ids.duplicate()
		recent.push_front(skipped_id)
		state.recent_event_ids = recent.slice(0, 6)

	state.pending_event_id = ""
	state.saga_log.append(entry)
	return state


# ═══════════════════════════════════════════════════════════════════════════
# run_week_after_event — advance the week after an event is resolved.
# ═══════════════════════════════════════════════════════════════════════════

static func run_week_after_event(state: GameState) -> GameState:
	return advance_week(state)
