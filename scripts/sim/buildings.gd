# ═══════════════════════════════════════════════════════════════════════════
# Buildings — 12 building definitions, validation, and construction system.
# Ported from src/sim/buildings.ts.
# ═══════════════════════════════════════════════════════════════════════════
class_name SimBuildings
extends RefCounted

# ── Category enum ─────────────────────────────────────────────────────────

enum BuildingCategory { HALL, STORAGE, CRAFT, CIVIC, LAND }

const BUILDING_CATEGORY_LABELS: Dictionary = {
	BuildingCategory.HALL:   "Hall & Shelter",
	BuildingCategory.STORAGE: "Storage",
	BuildingCategory.CRAFT:  "Craft & Trade",
	BuildingCategory.CIVIC:  "Civic & Spiritual",
	BuildingCategory.LAND:   "Land & Defence",
}

# ── 12 building definitions ───────────────────────────────────────────────
# Each key: BuildingId enum int.
# Fields:
#   id, name, short, desc, bonus, category (BuildingCategory),
#   workRequired, upfrontMaterials, upfrontTools, weeklyMaterials, weeklyTools,
#   requiresBuilt (Array), requiresLore (Dictionary), requiresStanding (int),
#   requiresMilestone (String), countsAsSlot (bool)

const BUILDING_DEFS: Dictionary = {
	GameTypes.BuildingId.EMERGENCY_SHELTER: {
		"id": GameTypes.BuildingId.EMERGENCY_SHELTER,
		"name": "Emergency Shelter",
		"short": "Shelter",
		"desc": "Quick turf roof and windbreak.",
		"bonus": "+1 shelter — keeps the worst weather out.",
		"category": BuildingCategory.HALL,
		"work_required": 12,
		"upfront_materials": 4, "upfront_tools": 0,
		"weekly_materials": 1, "weekly_tools": 0,
		"counts_as_slot": false,
	},
	GameTypes.BuildingId.BASIC_HALL: {
		"id": GameTypes.BuildingId.BASIC_HALL,
		"name": "Turf House",
		"short": "Turf House",
		"desc": "Stable first home for the household.",
		"bonus": "+1 shelter — families sleep warm and dry.",
		"category": BuildingCategory.HALL,
		"work_required": 24,
		"upfront_materials": 8, "upfront_tools": 2,
		"weekly_materials": 2, "weekly_tools": 0,
		"requires_built": [GameTypes.BuildingId.EMERGENCY_SHELTER],
		"counts_as_slot": false,
	},
	GameTypes.BuildingId.LONGHOUSE: {
		"id": GameTypes.BuildingId.LONGHOUSE,
		"name": "Longhouse",
		"short": "Longhouse",
		"desc": "The heart of a proper Viking settlement.",
		"bonus": "+1 shelter, +6 morale — the household stands proud.",
		"category": BuildingCategory.HALL,
		"work_required": 48,
		"upfront_materials": 14, "upfront_tools": 4,
		"weekly_materials": 3, "weekly_tools": 1,
		"requires_built": [GameTypes.BuildingId.BASIC_HALL],
		"counts_as_slot": true,
	},
	GameTypes.BuildingId.GREAT_HALL: {
		"id": GameTypes.BuildingId.GREAT_HALL,
		"name": "Great Hall",
		"short": "Great Hall",
		"desc": "Saga-worthy seat of authority. A generation of work.",
		"bonus": "+1 shelter, +10 morale, +2 wealth — feasts and authority unlock.",
		"category": BuildingCategory.HALL,
		"work_required": 120,
		"upfront_materials": 24, "upfront_tools": 8,
		"weekly_materials": 4, "weekly_tools": 2,
		"requires_built": [GameTypes.BuildingId.LONGHOUSE],
		"requires_standing": 15,
		"counts_as_slot": true,
	},
	GameTypes.BuildingId.STOREHOUSE: {
		"id": GameTypes.BuildingId.STOREHOUSE,
		"name": "Storehouse",
		"short": "Stores",
		"desc": "Locks away food and fuel against spoilage and theft.",
		"bonus": "8% food and fuel saved from spoilage each week.",
		"category": BuildingCategory.STORAGE,
		"work_required": 28,
		"upfront_materials": 10, "upfront_tools": 2,
		"weekly_materials": 2, "weekly_tools": 0,
		"counts_as_slot": true,
	},
	GameTypes.BuildingId.HAY_BARN: {
		"id": GameTypes.BuildingId.HAY_BARN,
		"name": "Hay Barn",
		"short": "Hay Barn",
		"desc": "Keeps fodder dry through wind and wet.",
		"bonus": "12% hay saved from consumption each winter week.",
		"category": BuildingCategory.STORAGE,
		"work_required": 32,
		"upfront_materials": 12, "upfront_tools": 2,
		"weekly_materials": 2, "weekly_tools": 0,
		"counts_as_slot": true,
	},
	GameTypes.BuildingId.WORKSHOP: {
		"id": GameTypes.BuildingId.WORKSHOP,
		"name": "Smithy & Workshop",
		"short": "Workshop",
		"desc": "Iron work, tool repair, and better building pace.",
		"bonus": "+15% craft/build output, +2 base build work per week.",
		"category": BuildingCategory.CRAFT,
		"work_required": 36,
		"upfront_materials": 14, "upfront_tools": 6,
		"weekly_materials": 2, "weekly_tools": 1,
		"counts_as_slot": true,
	},
	GameTypes.BuildingId.DOCK: {
		"id": GameTypes.BuildingId.DOCK,
		"name": "Boathouse & Dock",
		"short": "Dock",
		"desc": "Harbour for fishing boats and trading vessels.",
		"bonus": "Better fishing yield; sea-road trade events unlocked.",
		"category": BuildingCategory.CRAFT,
		"work_required": 40,
		"upfront_materials": 16, "upfront_tools": 4,
		"weekly_materials": 2, "weekly_tools": 1,
		"requires_milestone": "shipping_contact",
		"counts_as_slot": true,
	},
	GameTypes.BuildingId.THING_YARD: {
		"id": GameTypes.BuildingId.THING_YARD,
		"name": "Thing Yard",
		"short": "Thing",
		"desc": "Open-air assembly ground for law, oaths, and feuds.",
		"bonus": "Feud resolution events; standing and law lore gains.",
		"category": BuildingCategory.CIVIC,
		"work_required": 44,
		"upfront_materials": 12, "upfront_tools": 2,
		"weekly_materials": 2, "weekly_tools": 0,
		"requires_lore": {GameTypes.LoreBranch.LAW: 4},
		"requires_standing": 12,
		"counts_as_slot": true,
	},
	GameTypes.BuildingId.HOF_CHURCH: {
		"id": GameTypes.BuildingId.HOF_CHURCH,
		"name": "Hof / Church",
		"short": "Sacred House",
		"desc": "Shrine or church — ritual authority for the settlement.",
		"bonus": "Burial rites, haunting resolution, and ritual lore events.",
		"category": BuildingCategory.CIVIC,
		"work_required": 44,
		"upfront_materials": 14, "upfront_tools": 2,
		"weekly_materials": 2, "weekly_tools": 0,
		"requires_lore": {GameTypes.LoreBranch.RITUAL: 3},
		"counts_as_slot": true,
	},
	GameTypes.BuildingId.BOUNDARY_STONES: {
		"id": GameTypes.BuildingId.BOUNDARY_STONES,
		"name": "Boundary Stones",
		"short": "Stones",
		"desc": "Sacred markers that name the land and honour its spirits.",
		"bonus": "Land lore gains; vaettir mood easier to repair.",
		"category": BuildingCategory.LAND,
		"work_required": 24,
		"upfront_materials": 6, "upfront_tools": 1,
		"weekly_materials": 1, "weekly_tools": 0,
		"requires_lore": {GameTypes.LoreBranch.LAND: 2},
		"counts_as_slot": true,
	},
	GameTypes.BuildingId.WATCH_POST: {
		"id": GameTypes.BuildingId.WATCH_POST,
		"name": "Watch Post",
		"short": "Watch",
		"desc": "High ground eyes on the approaches — day and night.",
		"bonus": "+20% guard effectiveness; raid and theft events reduced.",
		"category": BuildingCategory.LAND,
		"work_required": 28,
		"upfront_materials": 8, "upfront_tools": 2,
		"weekly_materials": 2, "weekly_tools": 0,
		"counts_as_slot": true,
	},
}

# ── Slot-aware building count ────────────────────────────────────────────

static func built_count(state: GameState) -> int:
	var count := 0
	for b_id in state.buildings_built:
		var def: Dictionary = BUILDING_DEFS.get(b_id, {})
		if def.get("counts_as_slot", false):
			count += 1
	return count


# ── Validation ────────────────────────────────────────────────────────────
# Returns an error string if the building cannot be started, or null if OK.

static func can_start_building(state: GameState, id: int) -> String:
	var def: Dictionary = BUILDING_DEFS.get(id, {})
	if def.is_empty():
		return "Unknown building"

	if id in state.buildings_built:
		return "Already built"

	if not state.active_project.is_empty():
		return "Another project is active"

	# Prerequisite buildings
	var req_built: Array = def.get("requires_built", [])
	for b_id in req_built:
		if not (b_id in state.buildings_built):
			return "Requires earlier structure"

	# Standing requirement
	if def.has("requires_standing") and state.standing < def["requires_standing"]:
		return "Requires %d standing" % [def["requires_standing"]]

	# Milestone requirement
	if def.has("requires_milestone"):
		var ms: String = def["requires_milestone"]
		if not state.milestones.get(ms, false):
			return "Requires a saga milestone first"

	# Lore requirement
	if def.has("requires_lore"):
		var req_lore: Dictionary = def["requires_lore"]
		for branch in req_lore:
			var needed: int = req_lore[branch]
			if state.get_lore(branch) < needed:
				return "Requires %d %s lore" % [needed, _lore_name(branch)]

	# Upfront resource check
	if state.materials < float(def.get("upfront_materials", 0)):
		return "Not enough materials"
	if state.tools < float(def.get("upfront_tools", 0)):
		return "Not enough tools"

	return ""


# ── Start / Cancel project ───────────────────────────────────────────────

static func start_building_project(state: GameState, id: int) -> void:
	var err: String = can_start_building(state, id)
	if not err.is_empty():
		return

	var def: Dictionary = BUILDING_DEFS.get(id, {})
	state.materials -= float(def.get("upfront_materials", 0))
	state.tools -= float(def.get("upfront_tools", 0))

	state.active_project = {
		"building_id": id,
		"progress": 0,
		"committed_materials": def.get("upfront_materials", 0),
		"committed_tools": def.get("upfront_tools", 0),
	}


static func cancel_building_project(state: GameState) -> void:
	state.active_project = {}


# ── Construction progress ────────────────────────────────────────────────

static func _build_work_per_assignee(state: GameState) -> int:
	var base := 6
	if GameTypes.BuildingId.WORKSHOP in state.buildings_built:
		base += 2
	if state.season == GameTypes.Season.SUMMER:
		base += 1
	if state.season == GameTypes.Season.WINTER:
		base -= 2
	if state.weather == GameTypes.Weather.HARSH:
		base -= 1
	if state.weather == GameTypes.Weather.EXTREME:
		base -= 3
	return max(2, base)


static func advance_construction(state: GameState, builder_count: int) -> void:
	var project: Dictionary = state.active_project
	if project.is_empty() or builder_count <= 0:
		return

	var b_id: int = project.get("building_id", -1)
	var def: Dictionary = BUILDING_DEFS.get(b_id, {})
	if def.is_empty():
		return

	var weekly_mat: int = def.get("weekly_materials", 0)
	var weekly_tool: int = def.get("weekly_tools", 0)

	# Check weekly material/tool availability
	if state.materials < float(weekly_mat) or state.tools < float(weekly_tool):
		return  # stalled for lack of materials

	state.materials -= float(weekly_mat)
	state.tools -= float(weekly_tool)

	var progress: int = project.get("progress", 0) + builder_count * _build_work_per_assignee(state)
	var work_required: int = def.get("work_required", 999)

	if progress < work_required:
		state.active_project["progress"] = progress
		return

	# Construction complete
	state.buildings_built.append(b_id)
	state.active_project = {}

	# On-complete effects
	_on_complete(state, b_id, def)


static func _on_complete(state: GameState, b_id: int, def: Dictionary) -> void:
	match b_id:
		GameTypes.BuildingId.EMERGENCY_SHELTER, GameTypes.BuildingId.BASIC_HALL:
			state.shelter += 1.0
		GameTypes.BuildingId.LONGHOUSE:
			state.shelter += 1.0
			state.morale += 6.0
		GameTypes.BuildingId.GREAT_HALL:
			state.shelter += 1.0
			state.morale += 10.0
			state.wealth += 2.0
			state.milestones["great_hall_built"] = true
		GameTypes.BuildingId.THING_YARD:
			state.milestones["thing_established"] = true
		GameTypes.BuildingId.HOF_CHURCH:
			state.milestones["temple_or_church"] = true
		# storehouse, hay_barn, workshop, dock, boundary_stones, watch_post:
		# passive bonuses handled in building_bonuses()


# ── Active building bonuses ──────────────────────────────────────────────

static func building_bonuses(state: GameState) -> Dictionary:
	var built: Array = state.buildings_built
	return {
		"food_save": 0.08 if GameTypes.BuildingId.STOREHOUSE in built else 0.0,
		"hay_save": 0.12 if GameTypes.BuildingId.HAY_BARN in built else 0.0,
		"craft_bonus": 1.15 if GameTypes.BuildingId.WORKSHOP in built else 1.0,
		"guard_bonus": 1.2 if GameTypes.BuildingId.WATCH_POST in built else 1.0,
	}


# ── Available buildings list ─────────────────────────────────────────────

static func available_buildings(state: GameState) -> Array:
	var result: Array = []
	for b_id in BUILDING_DEFS:
		if not (b_id in state.buildings_built):
			result.append(BUILDING_DEFS[b_id])
	return result


# ── Helpers ───────────────────────────────────────────────────────────────

static func _lore_name(branch: int) -> String:
	match branch:
		GameTypes.LoreBranch.LAW: return "law"
		GameTypes.LoreBranch.RITUAL: return "ritual"
		GameTypes.LoreBranch.GENEALOGY: return "genealogy"
		GameTypes.LoreBranch.WAYFINDING: return "wayfinding"
		GameTypes.LoreBranch.LAND: return "land"
		GameTypes.LoreBranch.RUNE: return "rune"
	return "unknown"
