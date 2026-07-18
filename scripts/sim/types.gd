# ═══════════════════════════════════════════════════════════════════════════
# Core types and enums for Viking Saga sim engine.
# Ported from src/sim/types.ts in the browser version.
# ═══════════════════════════════════════════════════════════════════════════
class_name GameTypes
extends RefCounted

# ── Enums ────────────────────────────────────────────────────────────────

enum ActId { PREPARATION, SAILING, LANDFALL, SETTLEMENT }

enum CharacterClass { LEADER, FIGHTER, WORKER, SCHOLAR, CRAFTER, SCOUT, APPRENTICE }

enum WeeklyTask {
	FORAGE, HUNT, FISH, MAKE_HAY, TEND_HERD, GATHER_FUEL,
	BUILD, CRAFT, SCOUT, SAIL_EXPLORE, VIKING_ABROAD,
	GUARD, STORYTELL, FEAST, REST, TRAIN, TEND_LAND
}

enum SailingTask {
	STEER, NAVIGATE, BAIL, REPAIR_SHIP, RATION,
	FISH_AT_SEA, LOOK_OUT, REST_AT_SEA
}

enum Season { SPRING, SUMMER, AUTUMN, WINTER }
enum Weather { FAIR, HARSH, EXTREME }
enum Difficulty { EASY, NORMAL, BRUTAL, VIKING }
enum Realism { NORMAL, FANTASY, HORROR }

enum RegionId {
	COAST, VALLEY, BOG, GROVE, RIVER,
	RUIN, DRIFTWOOD_BEACH, HEADLAND, LEE_SLOPE
}

enum AnimalType { CATTLE, SHEEP, GOATS, HORSES, PIGS, CHICKENS }
enum LoreBranch { LAW, RITUAL, GENEALOGY, WAYFINDING, LAND, RUNE }
enum VaettirMood { UNSEEN, CURIOUS, FED, OFFENDED, HOSTILE, BOUND }
enum BuildingId {
	EMERGENCY_SHELTER, BASIC_HALL, LONGHOUSE, GREAT_HALL,
	STOREHOUSE, HAY_BARN, WORKSHOP, DOCK,
	THING_YARD, HOF_CHURCH, BOUNDARY_STONES, WATCH_POST
}

# ── Constants ─────────────────────────────────────────────────────────────

const WEEKS_PER_YEAR := 52
const TASK_COUNT := 17
const ANIMAL_COUNT := 6
const LORE_COUNT := 6

static func default_herd() -> Dictionary:
	return {AnimalType.CATTLE: 1, AnimalType.SHEEP: 4, AnimalType.GOATS: 2, AnimalType.HORSES: 1, AnimalType.PIGS: 1, AnimalType.CHICKENS: 6}

# ── Helpers ───────────────────────────────────────────────────────────────

static func week_to_season(week: int) -> int:
	var w := ((week - 1) % 52) + 1
	if w <= 13: return Season.SPRING
	if w <= 26: return Season.SUMMER
	if w <= 39: return Season.AUTUMN
	return Season.WINTER

static func act_label(act: int) -> String:
	match act:
		ActId.PREPARATION: return "Preparation"
		ActId.SAILING: return "The Crossing"
		ActId.LANDFALL: return "Landfall"
		ActId.SETTLEMENT: return "Settlement"
	return "Unknown"

static func class_name_str(cls: int) -> String:
	return ["Leader", "Fighter", "Worker", "Scholar", "Crafter", "Scout", "Apprentice"][cls]

static func task_name(task: int) -> String:
	return ["Forage", "Hunt", "Fish", "Make Hay", "Tend Herd", "Gather Fuel",
		"Build", "Craft", "Scout", "Sail Explore", "Viking Abroad",
		"Guard", "Storytell", "Feast", "Rest", "Train", "Tend Land"][task]
