# ═══════════════════════════════════════════════════════════════════════════
# Tasks — 17 task definitions, class/weather/season multipliers, and
# contribution calculations. Ported from src/sim/tasks.ts.
# ═══════════════════════════════════════════════════════════════════════════
class_name SimTasks
extends RefCounted

# ── Base effects per task ─────────────────────────────────────────────────
# Each entry maps a WeeklyTask enum int to a Dictionary of base yields.
# Keys: food, hay, fuel, materials, morale, knowledge, wealth, tools, shelter,
#       injury_risk, lore_branch, lore_amount (int)
const BASE_EFFECTS: Dictionary = {
	GameTypes.WeeklyTask.FORAGE:        {"food": 4.0, "morale": 1.0},
	GameTypes.WeeklyTask.HUNT:          {"food": 6.0, "wealth": 1.0, "injury_risk": 0.12},
	GameTypes.WeeklyTask.FISH:          {"food": 7.0, "injury_risk": 0.05},
	GameTypes.WeeklyTask.MAKE_HAY:      {"hay": 6.0},
	GameTypes.WeeklyTask.TEND_HERD:     {"food": 2.0, "hay": -1.0},
	GameTypes.WeeklyTask.GATHER_FUEL:   {"fuel": 5.0, "materials": 2.0},
	GameTypes.WeeklyTask.BUILD:         {"materials": -3.0, "shelter": 0.15, "tools": -1.0},
	GameTypes.WeeklyTask.CRAFT:         {"tools": 3.0, "wealth": 1.0, "materials": -1.0},
	GameTypes.WeeklyTask.SCOUT:         {"knowledge": 2.0, "lore_branch": GameTypes.LoreBranch.WAYFINDING, "lore_amount": 2.0},
	GameTypes.WeeklyTask.SAIL_EXPLORE:  {"knowledge": 3.0, "wealth": 1.0, "lore_branch": GameTypes.LoreBranch.WAYFINDING, "lore_amount": 3.0, "injury_risk": 0.08},
	GameTypes.WeeklyTask.VIKING_ABROAD: {"wealth": 8.0, "standing": 5.0, "morale": 2.0, "lore_branch": GameTypes.LoreBranch.GENEALOGY, "lore_amount": 1.0, "injury_risk": 0.22},
	GameTypes.WeeklyTask.GUARD:         {"morale": 2.0},
	GameTypes.WeeklyTask.STORYTELL:     {"knowledge": 3.0, "morale": 4.0, "lore_branch": GameTypes.LoreBranch.GENEALOGY, "lore_amount": 2.0},
	GameTypes.WeeklyTask.FEAST:         {"food": -10.0, "morale": 8.0, "standing": 4.0, "lore_branch": GameTypes.LoreBranch.LAW, "lore_amount": 1.0},
	GameTypes.WeeklyTask.REST:          {"morale": 3.0},
	GameTypes.WeeklyTask.TRAIN:         {"knowledge": 2.0, "tools": 1.0, "lore_branch": GameTypes.LoreBranch.RITUAL, "lore_amount": 2.0},
	GameTypes.WeeklyTask.TEND_LAND:     {"food": -2.0, "lore_branch": GameTypes.LoreBranch.LAND, "lore_amount": 2.0},
}

# Task categorization for weather effects
const OUTDOOR_TASKS: Array = [
	GameTypes.WeeklyTask.SCOUT,
	GameTypes.WeeklyTask.SAIL_EXPLORE,
	GameTypes.WeeklyTask.VIKING_ABROAD,
	GameTypes.WeeklyTask.HUNT,
	GameTypes.WeeklyTask.FISH,
	GameTypes.WeeklyTask.FORAGE,
	GameTypes.WeeklyTask.GATHER_FUEL,
	GameTypes.WeeklyTask.MAKE_HAY,
]

const INDOOR_TASKS: Array = [
	GameTypes.WeeklyTask.STORYTELL,
	GameTypes.WeeklyTask.CRAFT,
	GameTypes.WeeklyTask.REST,
	GameTypes.WeeklyTask.TRAIN,
	GameTypes.WeeklyTask.FEAST,
]

# ── Class × Task multiplier ───────────────────────────────────────────────\
# Returns a multiplier based on the character's class aptitude for a task.
# 1.0 = average, higher = better, lower = worse.
static func class_multiplier(character: CharacterData, task: int) -> float:
	var cls: int = character.char_class
	var intel: int = character.intelligence
	var resilience: int = character.resilience

	match task:
		GameTypes.WeeklyTask.HUNT, GameTypes.WeeklyTask.GUARD:
			match cls:
				GameTypes.CharacterClass.FIGHTER: return 1.4
				GameTypes.CharacterClass.SCOUT: return 1.1
				_: return 0.8
		GameTypes.WeeklyTask.FISH:
			match cls:
				GameTypes.CharacterClass.SCOUT: return 1.2
				GameTypes.CharacterClass.WORKER: return 1.1
				_: return 0.9
		GameTypes.WeeklyTask.MAKE_HAY, GameTypes.WeeklyTask.TEND_HERD:
			match cls:
				GameTypes.CharacterClass.WORKER: return 1.4
				GameTypes.CharacterClass.APPRENTICE: return 1.1
				_: return 0.9
		GameTypes.WeeklyTask.FORAGE, GameTypes.WeeklyTask.GATHER_FUEL:
			match cls:
				GameTypes.CharacterClass.WORKER: return 1.3
				GameTypes.CharacterClass.SCOUT: return 1.2
				_: return 0.9
		GameTypes.WeeklyTask.BUILD, GameTypes.WeeklyTask.CRAFT:
			match cls:
				GameTypes.CharacterClass.CRAFTER: return 1.5
				GameTypes.CharacterClass.WORKER: return 1.2
				_: return 0.7
		GameTypes.WeeklyTask.SCOUT:
			match cls:
				GameTypes.CharacterClass.SCOUT: return 1.5
				_: return 1.2 if intel >= 4 else 0.8
		GameTypes.WeeklyTask.SAIL_EXPLORE:
			match cls:
				GameTypes.CharacterClass.SCOUT: return 1.45
				GameTypes.CharacterClass.LEADER: return 1.15
				_: return 1.1 if intel >= 4 else 0.75
		GameTypes.WeeklyTask.VIKING_ABROAD:
			match cls:
				GameTypes.CharacterClass.FIGHTER: return 1.45
				GameTypes.CharacterClass.LEADER: return 1.25
				GameTypes.CharacterClass.SCOUT: return 1.1
				_: return 0.65
		GameTypes.WeeklyTask.FEAST:
			match cls:
				GameTypes.CharacterClass.LEADER: return 1.4
				GameTypes.CharacterClass.SCHOLAR: return 1.1
				_: return 1.0
		GameTypes.WeeklyTask.STORYTELL, GameTypes.WeeklyTask.TRAIN, GameTypes.WeeklyTask.TEND_LAND:
			match cls:
				GameTypes.CharacterClass.SCHOLAR: return 1.5
				GameTypes.CharacterClass.APPRENTICE: return 1.3
				GameTypes.CharacterClass.LEADER: return 1.2
				_: return 0.6
		GameTypes.WeeklyTask.REST:
			return 1.1 if resilience >= 4 else 1.0
		_:
			return 1.0


# Public alias for external use.
static func get_task_class_multiplier(character: CharacterData, task: int) -> float:
	return class_multiplier(character, task)


# ── Weather multiplier ────────────────────────────────────────────────────

static func weather_multiplier(task: int, weather: int) -> float:
	if weather == GameTypes.Weather.FAIR:
		return 1.0
	if weather == GameTypes.Weather.EXTREME:
		if task in OUTDOOR_TASKS:
			return 0.3
		if task in INDOOR_TASKS:
			return 1.1
		return 0.5
	# harsh
	if task in OUTDOOR_TASKS:
		return 0.6
	return 0.85


# ── Season multiplier ─────────────────────────────────────────────────────

static func season_multiplier(task: int, season: int) -> float:
	# Hay can only be meaningfully cut spring/summer
	if task == GameTypes.WeeklyTask.MAKE_HAY:
		match season:
			GameTypes.Season.SUMMER: return 1.3
			GameTypes.Season.SPRING: return 1.0
			GameTypes.Season.AUTUMN: return 0.5
			_: return 0.1  # winter: almost nothing to cut

	# Summer boosts
	if season == GameTypes.Season.SUMMER:
		if task in [GameTypes.WeeklyTask.FORAGE, GameTypes.WeeklyTask.HUNT,
					GameTypes.WeeklyTask.FISH, GameTypes.WeeklyTask.CRAFT]:
			return 1.2
		if task in [GameTypes.WeeklyTask.SAIL_EXPLORE, GameTypes.WeeklyTask.VIKING_ABROAD]:
			return 1.2

	# Autumn boosts
	if season == GameTypes.Season.AUTUMN:
		if task in [GameTypes.WeeklyTask.GATHER_FUEL, GameTypes.WeeklyTask.BUILD]:
			return 1.25

	# Winter modifiers
	if season == GameTypes.Season.WINTER:
		if task in [GameTypes.WeeklyTask.STORYTELL, GameTypes.WeeklyTask.CRAFT,
					GameTypes.WeeklyTask.REST, GameTypes.WeeklyTask.FEAST]:
			return 1.15
		if task in [GameTypes.WeeklyTask.SCOUT, GameTypes.WeeklyTask.HUNT, GameTypes.WeeklyTask.FISH]:
			return 0.5
		if task in [GameTypes.WeeklyTask.SAIL_EXPLORE, GameTypes.WeeklyTask.VIKING_ABROAD]:
			return 0.25

	return 1.0


# ── Main contribution calculation ─────────────────────────────────────────
# Returns a TaskEffect Dictionary with the final yields after all multipliers.
static func compute_task_contribution(character: CharacterData, task: int, season: int, weather: int) -> Dictionary:
	if not character.alive or character.injured:
		return {"morale": 5.0} if task == GameTypes.WeeklyTask.REST else {}

	var base: Dictionary = BASE_EFFECTS.get(task, {})
	var mult: float = class_multiplier(character, task) * weather_multiplier(task, weather) * season_multiplier(task, season)

	var effect: Dictionary = {}

	# Numeric resource yields (everything except injury_risk, lore_branch, lore_amount)
	for key in ["food", "hay", "fuel", "materials", "morale", "knowledge", "wealth", "tools", "shelter", "standing"]:
		if base.has(key):
			var val: float = base[key]
			effect[key] = snapped(val * mult, 0.1)

	# Injury risk (not multiplied by class/season, but increased by extreme weather)
	if base.has("injury_risk"):
		var ir: float = base["injury_risk"]
		effect["injury_risk"] = ir * (1.5 if weather == GameTypes.Weather.EXTREME else 1.0)

	# Lore
	if base.has("lore_branch"):
		effect["lore_branch"] = base["lore_branch"]
		var la: float = base.get("lore_amount", 0.0)
		effect["lore_amount"] = snapped(la * mult, 0.1)

	return effect


# ── Aggregate multi-character effects ─────────────────────────────────────

static func aggregate_task_effects(effects: Array) -> Dictionary:
	var total: Dictionary = {}
	for e in effects:
		for key in e:
			var val = e[key]
			if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
				total[key] = total.get(key, 0.0) + val
	return total


# ── Pillar normalization ──────────────────────────────────────────────────
# Used for the High Seat pillar system in saga verdicts.

static func normalize_pillars(state: GameState, extra: Dictionary = {}) -> Dictionary:
	var lore_total: int = extra.get("lore_total", state.lore_total())
	var herd_prestige: int = extra.get("herd_prestige", 0)
	var standing: int = extra.get("standing", state.standing)

	var alpha: float = _clamp_score(
		state.food * 0.8 + state.wealth * 7.0 + state.herd_total() * 1.0 +
		herd_prestige * 1.4 + state.tools * 0.3
	)
	var beta: float = _clamp_score(
		state.fuel * 0.45 + state.hay * 1.5 + state.materials * 0.4 +
		state.shelter * 12.0 + state.morale * 0.3 + state.living_population() * 4.0
	)
	var gamma: float = _clamp_score(
		state.knowledge * 1.0 + lore_total * 1.3 +
		state.discovered_regions.size() * 6.0 + standing * 1.5 +
		(8.0 if state.morale > 50.0 else 0.0)
	)
	return {"alpha": alpha, "beta": beta, "gamma": gamma}


static func balance_modifier(alpha: float, beta: float, gamma: float) -> float:
	var spread: float = max(alpha, beta, gamma) - min(alpha, beta, gamma)
	var mod: float = 1.0 - spread / 100.0
	mod = clamp(mod, 0.5, 1.0)

	# Graduated penalty: each point the lowest pillar falls below 15 costs 2%
	var lowest: float = min(alpha, beta, gamma)
	if lowest < 15.0:
		var deficit: float = 15.0 - lowest
		mod *= max(0.5, 1.0 - deficit * 0.02)

	return snapped(mod, 0.01)


# ── Task assignment validation ────────────────────────────────────────────

static func can_assign_task(task: int, state: GameState) -> bool:
	if task != GameTypes.WeeklyTask.VIKING_ABROAD:
		return true
	# Viking abroad requires coastal site, dock, and shipping contact.
	var coastal: bool = _site_is_coastal(state.site_id)
	return coastal and GameTypes.BuildingId.DOCK in state.buildings_built and state.milestones.get("shipping_contact", false)


# ── Internal helpers ──────────────────────────────────────────────────────

static func _clamp_score(v: float) -> float:
	return clamp(v, 0.0, 100.0)


static func _site_is_coastal(site_id: String) -> bool:
	# Known coastal sites; default most settlement sites to coastal.
	var inland_sites: Array = ["mountain_pass", "inland_valley", "forest_clearing", "highland_plateau"]
	return not (site_id in inland_sites)
