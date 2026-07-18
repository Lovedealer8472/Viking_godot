# ═══════════════════════════════════════════════════════════════════════════
# Supernatural ecology of the settlement.
#
# Design principle: the supernatural is a consequence system, not a random-mob
# generator. Beings emerge from broken relationships — with the land, the dead,
# the law, and lore. Players with high Land/Rune lore read the signs; those
# without are ambushed by consequences.
#
# Ported from src/sim/supernatural.ts.
# ═══════════════════════════════════════════════════════════════════════════
class_name SimSupernatural
extends RefCounted

# ── Vættir mood modifier table ───────────────────────────────────────────
# Key: VaettirMood enum int.
# food/hay/fuel: yield multipliers. morale: flat delta. injury_risk: risk delta.
const VAETTIR_MODIFIERS: Dictionary = {
	GameTypes.VaettirMood.UNSEEN:   {"food": 1.00, "hay": 1.00, "fuel": 1.00, "morale": 0,    "injury_risk": 0.0},
	GameTypes.VaettirMood.CURIOUS:  {"food": 1.05, "hay": 1.08, "fuel": 1.02, "morale": 2,    "injury_risk": 0.0},
	GameTypes.VaettirMood.FED:      {"food": 1.15, "hay": 1.18, "fuel": 1.08, "morale": 4,    "injury_risk": -0.02},
	GameTypes.VaettirMood.OFFENDED: {"food": 0.85, "hay": 0.80, "fuel": 0.90, "morale": -5,   "injury_risk": 0.05},
	GameTypes.VaettirMood.HOSTILE:  {"food": 0.70, "hay": 0.65, "fuel": 0.80, "morale": -10,  "injury_risk": 0.12},
	GameTypes.VaettirMood.BOUND:    {"food": 1.20, "hay": 1.25, "fuel": 1.10, "morale": 6,    "injury_risk": -0.03},
}

const VAETTIR_MOOD_LABELS: Dictionary = {
	GameTypes.VaettirMood.UNSEEN:   "Unseen",
	GameTypes.VaettirMood.CURIOUS:  "Curious",
	GameTypes.VaettirMood.FED:      "Fed",
	GameTypes.VaettirMood.OFFENDED: "Offended",
	GameTypes.VaettirMood.HOSTILE:  "Hostile",
	GameTypes.VaettirMood.BOUND:    "Bound by Oath",
}

const VAETTIR_MOOD_DESC: Dictionary = {
	GameTypes.VaettirMood.UNSEEN:   "The land-wights take no notice. Normal conditions.",
	GameTypes.VaettirMood.CURIOUS:  "Something watches with mild interest. Grazing is good; animals are calm.",
	GameTypes.VaettirMood.FED:      "Offerings received. The land gives back — better yields and safer routes.",
	GameTypes.VaettirMood.OFFENDED: "A wrong has been done: overharvest, taboo broken, land insulted. Yields suffer.",
	GameTypes.VaettirMood.HOSTILE:  "The wights are actively against you. Livestock panic, tools vanish, weather worsens.",
	GameTypes.VaettirMood.BOUND:    "A sacred oath binds the wights to your household. Great boon — but break it and face disaster.",
}

# ── Haunting stages ──────────────────────────────────────────────────────

const HAUNTING_LABELS: Dictionary = {
	0: "None",
	1: "Omen",
	2: "Contamination",
	3: "Manifestation",
	4: "Social Collapse",
	5: "Crisis",
}

# Each stage: {morale_hit: int, food_risk: float, labor_penalty: float, desc: String}
const HAUNTING_EFFECTS: Dictionary = {
	0: {"morale_hit": 0,  "food_risk": 0.0,  "labor_penalty": 0.0,  "desc": ""},
	1: {"morale_hit": -2, "food_risk": 0.0,  "labor_penalty": 0.0,  "desc": "Strange dreams and ill-omens unsettle the household."},
	2: {"morale_hit": -4, "food_risk": 0.05, "labor_penalty": 0.0,  "desc": "Illness spreads; food stores feel wrong. The dead's possessions must be burnt."},
	3: {"morale_hit": -6, "food_risk": 0.10, "labor_penalty": 0.10, "desc": "The dead sit by the fire. Animals refuse to enter the byre."},
	4: {"morale_hit": -8, "food_risk": 0.15, "labor_penalty": 0.20, "desc": "Workers refuse night tasks. Guests leave. The hall is half-abandoned."},
	5: {"morale_hit": -12,"food_risk": 0.20, "labor_penalty": 0.35, "desc": "Colony crisis. The settlement may fail if the haunting is not resolved."},
}

# ── Draugr threshold ─────────────────────────────────────────────────────

const DRAUGR_THRESHOLD: int = 6

# ── Curse objects ─────────────────────────────────────────────────────────

const CURSE_OBJECTS: Dictionary = {
	"cursed_driftwood": {
		"id": "cursed_driftwood",
		"name": "The Rune-Carved Timber",
		"desc": "A sea-borne log with runes bloodied in the grooves. It was brought inside before anyone looked closely.",
		"weekly_penalty": {"morale": -3, "injury_risk": 0.06},
		"detect_lore": 3,
		"remove_lore": 4,
	},
	"nid_pole": {
		"id": "nid_pole",
		"name": "Nid-Pole",
		"desc": "A horse-head pole with carved curses. Raises the vaettir against a rival — and risks backlash.",
		"weekly_penalty": {"morale": -1},
		"detect_lore": 0,
		"remove_lore": 5,
	},
	"barrow_silver": {
		"id": "barrow_silver",
		"name": "Barrow Silver",
		"desc": "Taken from the mound without ceremony. The dead man remembers.",
		"weekly_penalty": {"morale": -2, "injury_risk": 0.04},
		"detect_lore": 2,
		"remove_lore": 6,
	},
	"cursed_bedgear": {
		"id": "cursed_bedgear",
		"name": "The Cursed Bed-Gear",
		"desc": "A dead guest's sleeping furs, left in the hall. Sickness follows them.",
		"weekly_penalty": {"morale": -2, "food_risk": 0.07},
		"detect_lore": 2,
		"remove_lore": 3,
	},
}


# ═══════════════════════════════════════════════════════════════════════════
# Default state factory
# ═══════════════════════════════════════════════════════════════════════════

static func empty_supernatural() -> Dictionary:
	return {
		"vaettir_moods": {},    # region_id (int) -> VaettirMood (int)
		"burial_debt": 0,       # 0-10
		"haunting_stage": 0,    # 0-5
		"draugar_active": false,
		"curse_objects": [],    # Array[String] — curse object IDs
		"barrows": [],          # Array[Dictionary] — discovered barrows
		"taboo_violations": [], # Array[String] — taboo labels
		"permanent_scars": [],  # Array[String] — scar labels
	}


# ═══════════════════════════════════════════════════════════════════════════
# Vættir mood queries
# ═══════════════════════════════════════════════════════════════════════════

# The home site vættir mood is keyed by the coast region ID.
static func get_home_vaettir_mood(supernatural: Dictionary) -> int:
	return supernatural.get("vaettir_moods", {}).get(GameTypes.RegionId.COAST, GameTypes.VaettirMood.UNSEEN)


# Dominant mood across all discovered regions (worst mood wins).
static func dominant_vaettir_mood(supernatural: Dictionary, discovered_regions: Array) -> int:
	var priority: Array = [
		GameTypes.VaettirMood.HOSTILE,
		GameTypes.VaettirMood.OFFENDED,
		GameTypes.VaettirMood.BOUND,
		GameTypes.VaettirMood.FED,
		GameTypes.VaettirMood.CURIOUS,
		GameTypes.VaettirMood.UNSEEN,
	]
	var moods: Dictionary = supernatural.get("vaettir_moods", {})
	for mood in priority:
		for region in discovered_regions:
			if moods.get(region, GameTypes.VaettirMood.UNSEEN) == mood:
				return mood
	return GameTypes.VaettirMood.UNSEEN


# Aggregate yield modifier across all active vaettir moods.
# Returns Dictionry with food, hay, fuel (float multipliers), morale_delta (int), injury_risk_delta (float).
static func aggregate_vaettir_yield_mod(supernatural: Dictionary, discovered_regions: Array) -> Dictionary:
	var food_mult := 1.0
	var hay_mult := 1.0
	var fuel_mult := 1.0
	var morale_delta := 0.0
	var injury_risk := 0.0
	var count := 0

	var moods: Dictionary = supernatural.get("vaettir_moods", {})

	for region in discovered_regions:
		var mood: int = moods.get(region, GameTypes.VaettirMood.UNSEEN)
		var mod: Dictionary = VAETTIR_MODIFIERS.get(mood, VAETTIR_MODIFIERS[GameTypes.VaettirMood.UNSEEN])
		food_mult += mod["food"] - 1.0
		hay_mult  += mod["hay"] - 1.0
		fuel_mult += mod["fuel"] - 1.0
		morale_delta  += float(mod["morale"])
		injury_risk   += mod["injury_risk"]
		count += 1

	var n: int = max(1, count)
	return {
		"food": snapped(food_mult / float(n) + (float(count) - 1.0) / float(n), 0.01) if count > 0 else 1.0,
		"hay":  snapped(hay_mult  / float(n) + (float(count) - 1.0) / float(n), 0.01) if count > 0 else 1.0,
		"fuel": snapped(fuel_mult / float(n) + (float(count) - 1.0) / float(n), 0.01) if count > 0 else 1.0,
		"morale_delta": roundi(morale_delta / float(n)),
		"injury_risk_delta": snapped(injury_risk / float(n), 0.001),
	}


# ═══════════════════════════════════════════════════════════════════════════
# Burial debt & draugar
# ═══════════════════════════════════════════════════════════════════════════

# Probability that burial debt triggers a draugr event this week.
static func draugr_risk(debt: int) -> float:
	if debt < DRAUGR_THRESHOLD:
		return 0.0
	return min(0.9, ((float(debt) - float(DRAUGR_THRESHOLD)) / 4.0) * 0.3)


# How much burial debt a character's death accumulates, based on ritual lore.
static func burial_debt_from_death(state: GameState) -> int:
	var ritual_level: int = state.get_lore(GameTypes.LoreBranch.RITUAL)
	if ritual_level >= 8: return 0   # Master knowledge: perfect rites
	if ritual_level >= 5: return 1   # Good knowledge: minor slip
	if ritual_level >= 3: return 2   # Average: rushed burial
	if ritual_level >= 1: return 3   # Poor: wrong handling
	return 5                          # None: "just bury him before the snow"


# ═══════════════════════════════════════════════════════════════════════════
# Haunting
# ═══════════════════════════════════════════════════════════════════════════

# Probability of haunting advancing one stage this week.
static func haunting_advance_risk(stage: int, debt: int) -> float:
	if stage == 0 or stage >= 5:
		return 0.0
	return min(0.7, float(stage) * 0.12 + float(debt) * 0.04)


# ═══════════════════════════════════════════════════════════════════════════
# Lore checks
# ═══════════════════════════════════════════════════════════════════════════

static func can_read_vaettir(state: GameState) -> bool:
	return state.get_lore(GameTypes.LoreBranch.LAND) >= 3

static func can_perform_burial_rites(state: GameState) -> bool:
	return state.get_lore(GameTypes.LoreBranch.RITUAL) >= 3

static func can_perform_door_doom(state: GameState) -> bool:
	return state.get_lore(GameTypes.LoreBranch.LAW) >= 5 and state.get_lore(GameTypes.LoreBranch.RITUAL) >= 3

static func can_detect_curse(state: GameState, detect_threshold: int) -> bool:
	return state.get_lore(GameTypes.LoreBranch.RUNE) >= detect_threshold

static func can_claim_barrow(state: GameState) -> bool:
	return state.get_lore(GameTypes.LoreBranch.GENEALOGY) >= 4


# ═══════════════════════════════════════════════════════════════════════════
# Weekly supernatural tick — called inside resolve_assignments.
# Returns a Dictionary with:
#   morale_delta: int, food_risk: float, labor_penalty: float,
#   injury_risk_bonus: float, new_supernatural: Dictionary
# ═══════════════════════════════════════════════════════════════════════════

static func tick_supernatural(state: GameState, rng: Callable) -> Dictionary:
	var sup: Dictionary = state.supernatural_state.duplicate(true)
	var moods: Dictionary = sup.get("vaettir_moods", {}).duplicate(true)

	var morale_delta := 0.0
	var food_risk := 0.0
	var labor_penalty := 0.0
	var injury_risk_bonus := 0.0

	# Vættir aggregate effect
	var v_mod: Dictionary = aggregate_vaettir_yield_mod(sup, state.discovered_regions)
	morale_delta += float(v_mod["morale_delta"])
	injury_risk_bonus += v_mod["injury_risk_delta"]

	# Haunting effect
	var h_stage: int = sup.get("haunting_stage", 0)
	var h_effect: Dictionary = HAUNTING_EFFECTS.get(h_stage, HAUNTING_EFFECTS[0])
	morale_delta  += float(h_effect["morale_hit"])
	food_risk     += h_effect["food_risk"]
	labor_penalty += h_effect["labor_penalty"]

	# Curse object effects
	var curse_ids: Array = sup.get("curse_objects", [])
	for c_id in curse_ids:
		var def: Dictionary = CURSE_OBJECTS.get(c_id, {})
		if def.is_empty():
			continue
		var penalty: Dictionary = def.get("weekly_penalty", {})
		morale_delta    += float(penalty.get("morale", 0))
		injury_risk_bonus += penalty.get("injury_risk", 0.0)
		food_risk       += penalty.get("food_risk", 0.0)

	# Draugar active: persistent morale drain and injury risk
	if sup.get("draugar_active", false):
		morale_delta    -= 8.0
		injury_risk_bonus += 0.15
		food_risk       += 0.10

	# Clone supernatural for mutation
	var new_supernatural: Dictionary = sup.duplicate(true)
	new_supernatural["vaettir_moods"] = moods

	# Haunting advance?
	if h_stage > 0 and h_stage < 5:
		var advance_risk: float = haunting_advance_risk(h_stage, sup.get("burial_debt", 0))
		if rng.call() < advance_risk:
			new_supernatural["haunting_stage"] = min(5, h_stage + 1)

	# Draugr emergence from burial debt?
	var debt: int = sup.get("burial_debt", 0)
	if not sup.get("draugar_active", false) and debt >= DRAUGR_THRESHOLD:
		if rng.call() < draugr_risk(debt):
			new_supernatural["draugar_active"] = true
			new_supernatural["haunting_stage"] = max(new_supernatural.get("haunting_stage", 0), 2)

	# Natural vættir drift: offended -> hostile, fed -> curious
	for region in state.discovered_regions:
		var region_int: int = region  # Godot int enum
		var mood: int = moods.get(region_int, GameTypes.VaettirMood.UNSEEN)
		if mood == GameTypes.VaettirMood.OFFENDED and rng.call() < 0.08:
			moods[region_int] = GameTypes.VaettirMood.HOSTILE
		if mood == GameTypes.VaettirMood.FED and rng.call() < 0.04:
			moods[region_int] = GameTypes.VaettirMood.CURIOUS

	new_supernatural["vaettir_moods"] = moods

	return {
		"morale_delta": roundi(morale_delta),
		"food_risk": snapped(food_risk, 0.001),
		"labor_penalty": snapped(labor_penalty, 0.001),
		"injury_risk_bonus": snapped(injury_risk_bonus, 0.001),
		"new_supernatural": new_supernatural,
	}


# ═══════════════════════════════════════════════════════════════════════════
# State mutation helpers
# ═══════════════════════════════════════════════════════════════════════════

# Set a vættir's mood in a region. 'home' maps to coast.
static func set_vaettir_mood(supernatural: Dictionary, region: int, mood: int) -> void:
	var effective_region: int = region
	if region == -1:  # -1 sentinel for 'home'
		effective_region = GameTypes.RegionId.COAST
	var moods: Dictionary = supernatural.get("vaettir_moods", {})
	moods[effective_region] = mood
	supernatural["vaettir_moods"] = moods


static func shift_haunting_stage(supernatural: Dictionary, delta: int) -> void:
	var current: int = supernatural.get("haunting_stage", 0)
	supernatural["haunting_stage"] = clamp(current + delta, 0, 5)


static func add_curse_object(supernatural: Dictionary, id: String) -> void:
	var curses: Array = supernatural.get("curse_objects", [])
	if not (id in curses):
		curses.append(id)
		supernatural["curse_objects"] = curses


static func remove_curse_object(supernatural: Dictionary, id: String) -> void:
	var curses: Array = supernatural.get("curse_objects", [])
	supernatural["curse_objects"] = curses.filter(func(c): return c != id)
