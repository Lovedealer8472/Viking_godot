# ═══════════════════════════════════════════════════════════════════════════
# Sim stress + balance harness — headless.
#  • "random" strategy: rotates all 17 tasks (crash coverage, worst-case play).
#  • "smart" strategy:  competent survival play (is the game winnable?).
# Runs 60 weeks per combo, drives events like the Act 4 UI, prints outcome.
# Pure logic — no rendering.
# ═══════════════════════════════════════════════════════════════════════════
extends Node

const WEEKS := 60

func _ready() -> void:
	print("╔══════════════════════════════════════════════════════════╗")
	print("║  SIM BALANCE HARNESS — random vs. competent play          ║")
	print("╚══════════════════════════════════════════════════════════╝")

	for strategy in ["random", "smart"]:
		print("\n── %s play ──" % strategy)
		for diff in [GameTypes.Difficulty.EASY, GameTypes.Difficulty.NORMAL, GameTypes.Difficulty.BRUTAL, GameTypes.Difficulty.VIKING]:
			_run_settlement(diff, GameTypes.Realism.NORMAL, strategy)

	# Realism differentiation: identical difficulty/seed/play, 3 realisms.
	# Before the fix these were byte-identical. Now HORROR should show more
	# supernatural pressure (lower morale, injuries, hauntings) than HISTORICAL.
	print("\n── realism differentiation (Normal diff, smart play, 60 wk) ──")
	for realism in [GameTypes.Realism.NORMAL, GameTypes.Realism.FANTASY, GameTypes.Realism.HORROR]:
		_realism_probe(realism)

	# Year-increment check (folded in).
	var s := _fresh_settlement(GameTypes.Difficulty.EASY, GameTypes.Realism.NORMAL)
	for w in range(55):
		_assign(s, "smart")
		SimWeeklyTurn.resolve_assignments(s)
		if not s.pending_event_id.is_empty():
			_apply_event_like_ui(s, s.pending_event_id)
		SimWeeklyTurn.advance_week(s)
		if s.game_over: break
	print("\n  year check → after %d weeks: week=%d year=%d (expect year 2)" % [s.week - 1, s.week, s.year])

	print("\n╔══════════════════════════════════════════════════════════╗")
	print("║  HARNESS COMPLETE — no crashes                            ║")
	print("╚══════════════════════════════════════════════════════════╝")
	get_tree().quit()


func _fresh_settlement(diff: int, realism: int) -> GameState:
	var state := NewSaga.create(diff, realism, [GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND])
	state.act = GameTypes.ActId.SETTLEMENT
	state.food = 45.0; state.hay = 10.0; state.fuel = 20.0
	state.materials = 25.0; state.morale = 65.0; state.tools = 20.0
	state.cattle = 1; state.sheep = 4; state.goats = 2; state.horses = 1
	return state


func _run_settlement(diff: int, realism: int, strategy: String) -> void:
	var state := _fresh_settlement(diff, realism)
	var min_pop := state.living_population()
	var min_food := 999.0

	for w in range(WEEKS):
		_assign(state, strategy)
		SimWeeklyTurn.resolve_assignments(state)
		if not state.pending_event_id.is_empty():
			_apply_event_like_ui(state, state.pending_event_id)
		SimWeeklyTurn.advance_week(state)
		min_pop = mini(min_pop, state.living_population())
		min_food = minf(min_food, state.food)

		if state.game_over:
			print("  %-8s → week %2d %s: %s (pop %d)" % [
				_diff_name(diff), state.week, _season_name(state.season),
				("VICTORY" if state.victory else "defeat"), state.living_population()])
			return

	print("  %-8s → survived %d wk, pop %d (low %d), food low %.0f, herd %d, standing %d, bld %d" % [
		_diff_name(diff), state.week - 1, state.living_population(), min_pop,
		min_food, state.herd_total(), state.standing, state.buildings_built.size()])


# ── Assignment strategies ──────────────────────────────────────────────────

func _assign(state: GameState, strategy: String) -> void:
	if strategy == "random":
		var i := 0
		for c in state.characters:
			if not c.alive: continue
			state.assignments[c.id] = (state.week + i) % GameTypes.TASK_COUNT
			i += 1
	else:
		_smart_assign(state)


func _smart_assign(state: GameState) -> void:
	# Competent survival play at a coastal site (estuary_meadow, fishing 1.1).
	var season: int = state.season
	var idx := 0
	for c in state.characters:
		if not c.alive: continue
		var task: int
		if c.is_child:
			task = GameTypes.WeeklyTask.TRAIN
		elif idx == 0:
			task = GameTypes.WeeklyTask.TEND_HERD          # keep the herd alive
		elif season == GameTypes.Season.WINTER:
			task = GameTypes.WeeklyTask.GATHER_FUEL if idx % 2 == 0 else GameTypes.WeeklyTask.FISH
		elif season == GameTypes.Season.AUTUMN:
			if idx == 1: task = GameTypes.WeeklyTask.MAKE_HAY
			elif idx == 2: task = GameTypes.WeeklyTask.GATHER_FUEL
			else: task = GameTypes.WeeklyTask.FISH
		else: # spring / summer
			if idx == 1: task = GameTypes.WeeklyTask.MAKE_HAY
			elif idx == 2: task = GameTypes.WeeklyTask.GATHER_FUEL
			else: task = GameTypes.WeeklyTask.FISH
		state.assignments[c.id] = task
		idx += 1


func _realism_probe(realism: int) -> void:
	var state := _fresh_settlement(GameTypes.Difficulty.NORMAL, realism)
	# Seed a supernatural provocation (as a death/burial/overharvest would in real
	# play) so the realism-gated tick has something to act on. Historical should
	# suppress it (haunting capped at 1, no draugr); Draugr-Touched should let it
	# escalate. Without a seed the supernatural layer stays dormant for all modes.
	state.supernatural_state = {
		"haunting_stage": 2,
		"burial_debt": 7,
		"vaettir_moods": {GameTypes.RegionId.COAST: GameTypes.VaettirMood.OFFENDED},
	}
	var min_morale := 100.0
	var total_injuries := 0
	for w in range(60):
		_assign(state, "smart")
		var result: Dictionary = SimWeeklyTurn.resolve_assignments(state)
		total_injuries += (result.get("injuries", []) as Array).size()
		if not state.pending_event_id.is_empty():
			_apply_event_like_ui(state, state.pending_event_id)
		SimWeeklyTurn.advance_week(state)
		min_morale = minf(min_morale, state.morale)
		if state.game_over:
			break
	var sup: Dictionary = state.supernatural_state
	print("  %-16s → pop %d, morale low %.0f, injuries %d, haunting %d, vaettir %s" % [
		_realism_name(realism), state.living_population(), min_morale, total_injuries,
		sup.get("haunting_stage", 0), str(SimSupernatural.get_home_vaettir_mood(sup))])


func _apply_event_like_ui(state: GameState, event_id: String) -> void:
	var event_data: Dictionary = SimEvents.find_event(event_id)
	var choices: Array = event_data.get("choices", [])
	if choices.is_empty():
		SimWeeklyTurn.skip_event(state)
		return
	# Apply choice 0 through the real effect resolver (resources + lore + the
	# supernatural layer), exactly as the Act 4 UI now does.
	SimEvents.resolve_choice_effects(state, choices[0], event_id)
	state.pending_event_id = ""


func _diff_name(d: int) -> String:
	return ["Easy", "Normal", "Brutal", "Viking"][d]

func _realism_name(r: int) -> String:
	return ["Historical", "Saga-Born", "Draugr-Touched"][r]

func _season_name(s: int) -> String:
	return ["Spring", "Summer", "Autumn", "Winter"][s]
