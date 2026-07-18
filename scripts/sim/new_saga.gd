# ═══════════════════════════════════════════════════════════════════════════
# New Saga factory — creates a fresh GameState for Act 1.
# Ported from src/sim/newSaga.ts.
# ═══════════════════════════════════════════════════════════════════════════
class_name NewSaga
extends RefCounted

static func create(difficulty: int, realism: int, high_seat_pillars: Array) -> GameState:  # Array[int]
	var state := GameState.new()
	state.act = GameTypes.ActId.PREPARATION
	state.season = GameTypes.Season.SPRING
	state.weather = GameTypes.Weather.FAIR
	state.difficulty = difficulty
	state.realism = realism

	state.food = 20.0; state.hay = 0.0; state.fuel = 5.0
	state.materials = 10.0; state.morale = 65.0; state.knowledge = 5.0
	state.wealth = 2.0; state.tools = 15.0; state.shelter = 0.0

	state.cattle = 0; state.sheep = 0; state.goats = 0
	state.horses = 0; state.pigs = 0; state.chickens = 0

	state.lore_law = 2; state.lore_ritual = 1; state.lore_genealogy = 1
	state.lore_wayfinding = 2; state.lore_land = 0; state.lore_rune = 0

	state.standing = 5
	state.site_id = "estuary_meadow"

	# Founding characters
	state.characters = _founding_characters()

	state.saga_log.append("The saga begins in Norway. A knarr waits in the fjord.")
	return state

static func _founding_characters() -> Array:  # Array[CharacterData]
	var chars: Array = []  # Array[CharacterData]

	var leader := CharacterData.new()
	leader.id = "leader"; leader.char_name = "You"
	leader.char_class = GameTypes.CharacterClass.LEADER; leader.age = 32
	leader.strength = 2; leader.resilience = 3; leader.willpower = 4; leader.intelligence = 4
	leader.traits = ["planner"]; leader.loyalty = 100
	chars.append(leader)

	var bjarne := CharacterData.new()
	bjarne.id = "bjarne"; bjarne.char_name = "Bjarne"
	bjarne.char_class = GameTypes.CharacterClass.FIGHTER; bjarne.age = 28
	bjarne.strength = 4; bjarne.resilience = 3; bjarne.willpower = 3; bjarne.intelligence = 1
	bjarne.traits = ["immovable"]; bjarne.loyalty = 90
	chars.append(bjarne)

	var ragna := CharacterData.new()
	ragna.id = "ragna"; ragna.char_name = "Ragna"
	ragna.char_class = GameTypes.CharacterClass.WORKER; ragna.age = 35
	ragna.strength = 3; ragna.resilience = 4; ragna.willpower = 2; ragna.intelligence = 2
	ragna.traits = ["endurance"]; ragna.loyalty = 92
	chars.append(ragna)

	var einar := CharacterData.new()
	einar.id = "einar"; einar.char_name = "Einar"
	einar.char_class = GameTypes.CharacterClass.SCHOLAR; einar.age = 40
	einar.strength = 1; einar.resilience = 2; einar.willpower = 3; einar.intelligence = 5
	einar.traits = ["eidetic_memory"]; einar.loyalty = 88
	chars.append(einar)

	var brynja := CharacterData.new()
	brynja.id = "brynja"; brynja.char_name = "Brynja"
	brynja.char_class = GameTypes.CharacterClass.CRAFTER; brynja.age = 26
	brynja.strength = 2; brynja.resilience = 3; brynja.willpower = 3; brynja.intelligence = 4
	brynja.traits = ["skilled_hands"]; brynja.loyalty = 90
	chars.append(brynja)

	var leif := CharacterData.new()
	leif.id = "leif"; leif.char_name = "Leif"
	leif.char_class = GameTypes.CharacterClass.SCOUT; leif.age = 24
	leif.strength = 3; leif.resilience = 3; leif.willpower = 3; leif.intelligence = 3
	leif.traits = ["keen_eye"]; leif.hidden_traits = ["curious"]; leif.loyalty = 85
	chars.append(leif)

	var jarl := CharacterData.new()
	jarl.id = "jarl"; jarl.char_name = "Jarl"
	jarl.char_class = GameTypes.CharacterClass.APPRENTICE; jarl.age = 14
	jarl.strength = 1; jarl.resilience = 2; jarl.willpower = 3; jarl.intelligence = 3
	jarl.traits = ["rapid_learner"]; jarl.is_child = true; jarl.loyalty = 95
	chars.append(jarl)

	return chars
