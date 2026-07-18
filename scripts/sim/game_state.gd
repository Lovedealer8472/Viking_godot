# ═══════════════════════════════════════════════════════════════════════════
# GameState — the single source of truth for the entire sim.
# Godot Resource so it can be saved/loaded and passed via signals.
# ═══════════════════════════════════════════════════════════════════════════
class_name GameState
extends Resource

# ── Calendar ─────────────────────────────────────────────────────────────
@export var act: int = GameTypes.ActId.SETTLEMENT
@export var week: int = 1
@export var year: int = 1
@export var season: int = GameTypes.Season.SPRING
@export var weather: int = GameTypes.Weather.FAIR

# ── Resources ────────────────────────────────────────────────────────────
@export var food: float = 40.0
@export var hay: float = 6.0
@export var fuel: float = 20.0
@export var materials: float = 15.0
@export var morale: float = 70.0
@export var knowledge: float = 5.0
@export var wealth: float = 3.0
@export var tools: float = 30.0
@export var shelter: float = 0.0

# ── Sailing ──────────────────────────────────────────────────────────────
@export var course: float = 0.0
@export var ship_integrity: float = 100.0
@export var ship_supplies: float = 100.0
@export var ship_morale: float = 80.0
@export var storm_count: int = 0
@export var sailing_day: int = 0

# ── Herd ─────────────────────────────────────────────────────────────────
@export var cattle: int = 1
@export var sheep: int = 4
@export var goats: int = 2
@export var horses: int = 1
@export var pigs: int = 1
@export var chickens: int = 6

# ── Lore ─────────────────────────────────────────────────────────────────
@export var lore_law: int = 2
@export var lore_ritual: int = 1
@export var lore_genealogy: int = 1
@export var lore_wayfinding: int = 2
@export var lore_land: int = 0
@export var lore_rune: int = 0

# ── Standing & setup ─────────────────────────────────────────────────────
@export var standing: int = 5
@export var difficulty: int = GameTypes.Difficulty.NORMAL
@export var realism: int = GameTypes.Realism.NORMAL
@export var site_id: String = "estuary_meadow"

# ── Characters ───────────────────────────────────────────────────────────
@export var characters: Array = []  # Array[CharacterData]

# ── Assignments ──────────────────────────────────────────────────────────
# Mapping from character id (String) to WeeklyTask enum int.
@export var assignments: Dictionary = {}

# ── Buildings ────────────────────────────────────────────────────────────
# Array of BuildingId enum ints for completed buildings.
@export var buildings_built: Array = []
# {building_id: int, progress: int, committed_materials: int, committed_tools: int}
# Empty Dictionary means no active project.
@export var active_project: Dictionary = {}

# ── Milestones ───────────────────────────────────────────────────────────
# Dictionary of milestone name (String) -> bool.
@export var milestones: Dictionary = {}

# ── Supernatural ─────────────────────────────────────────────────────────
# Dictionary containing vættir moods, burial debt, haunting, etc.
@export var supernatural_state: Dictionary = {}

# ── Flags ────────────────────────────────────────────────────────────────
@export var game_over: bool = false
@export var victory: bool = false
@export var discovered_regions: Array = [GameTypes.RegionId.COAST]  # Array[int]

# ── Events ───────────────────────────────────────────────────────────────
# ID of the event awaiting player response, or "" if none.
@export var pending_event_id: String = ""
# Most recent event IDs (max 6), for cooldown tracking.
@export var recent_event_ids: Array = []  # Array[String]
# Dynamic flags that gate event eligibility and track game state.
@export var event_flags: Dictionary = {}
# Last year the shipping season event was resolved.
@export var shipping_resolved_year: int = 0

# ── Saga ─────────────────────────────────────────────────────────────────
@export var saga_log: Array = []

# ── Most significant event tracking ─────────────────────────────────────
# The ID and category of the most significant event this saga.
@export var most_significant_event: String = ""
@export var most_significant_event_category: String = ""

# ── Methods ──────────────────────────────────────────────────────────────

func living_population() -> int:
	var count := 0
	for c in characters:
		if c.alive: count += 1
	return count

func herd_total() -> int:
	return cattle + sheep + goats + horses + pigs + chickens

func lore_total() -> int:
	return lore_law + lore_ritual + lore_genealogy + lore_wayfinding + lore_land + lore_rune

func get_herd_dict() -> Dictionary:
	return {
		GameTypes.AnimalType.CATTLE: cattle, GameTypes.AnimalType.SHEEP: sheep,
		GameTypes.AnimalType.GOATS: goats, GameTypes.AnimalType.HORSES: horses,
		GameTypes.AnimalType.PIGS: pigs, GameTypes.AnimalType.CHICKENS: chickens
	}

func set_herd(d: Dictionary) -> void:
	cattle = d.get(GameTypes.AnimalType.CATTLE, cattle)
	sheep = d.get(GameTypes.AnimalType.SHEEP, sheep)
	goats = d.get(GameTypes.AnimalType.GOATS, goats)
	horses = d.get(GameTypes.AnimalType.HORSES, horses)
	pigs = d.get(GameTypes.AnimalType.PIGS, pigs)
	chickens = d.get(GameTypes.AnimalType.CHICKENS, chickens)

func get_lore(branch: int) -> int:
	match branch:
		GameTypes.LoreBranch.LAW: return lore_law
		GameTypes.LoreBranch.RITUAL: return lore_ritual
		GameTypes.LoreBranch.GENEALOGY: return lore_genealogy
		GameTypes.LoreBranch.WAYFINDING: return lore_wayfinding
		GameTypes.LoreBranch.LAND: return lore_land
		GameTypes.LoreBranch.RUNE: return lore_rune
	return 0

func add_lore(branch: int, amount: int) -> void:
	match branch:
		GameTypes.LoreBranch.LAW: lore_law = max(0, lore_law + amount)
		GameTypes.LoreBranch.RITUAL: lore_ritual = max(0, lore_ritual + amount)
		GameTypes.LoreBranch.GENEALOGY: lore_genealogy = max(0, lore_genealogy + amount)
		GameTypes.LoreBranch.WAYFINDING: lore_wayfinding = max(0, lore_wayfinding + amount)
		GameTypes.LoreBranch.LAND: lore_land = max(0, lore_land + amount)
		GameTypes.LoreBranch.RUNE: lore_rune = max(0, lore_rune + amount)
