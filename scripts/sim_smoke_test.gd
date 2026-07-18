# Sim smoke test — drives real weekly turns through the ported GDScript sim.
# Run: godot --path . res://scripts/sim_smoke_test.tscn
extends Node

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		print("  FAIL  ", msg)

func _run_weeks(state: GameState, n: int, label: String) -> GameState:
	for i in n:
		for c in state.characters:
			if c.alive:
				state.assignments[c.id] = GameTypes.WeeklyTask.FORAGE
		var result: Dictionary = SimWeeklyTurn.resolve_assignments(state)
		state = result["state"]
		if state.pending_event_id != "":
			var ev: Dictionary = SimEvents.find_event(state.pending_event_id)
			if not ev.is_empty() and ev.get("choices", []).size() > 0:
				state = SimWeeklyTurn.apply_event_choice(state, ev["id"], ev["choices"][0]["id"])
			else:
				state = SimWeeklyTurn.skip_event(state)
		state = SimWeeklyTurn.run_week_after_event(state)
		var alive := 0
		for c in state.characters:
			if c.alive: alive += 1
		print("  [%s] wk %d | food %.0f hay %.0f fuel %.0f morale %.0f | alive %d | event: %s" % [
			label, state.week, state.food, state.hay, state.fuel, state.morale, alive,
			state.pending_event_id if state.pending_event_id != "" else "-"])
	return state

func _ready() -> void:
	print("=== SIM SMOKE TEST ===")
	var state: GameState = NewSaga.create(GameTypes.Difficulty.NORMAL, GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND])
	_check(state != null, "saga created")
	_check(state.characters.size() == 7, "7 founding characters (got %d)" % state.characters.size())
	_check(state.week == 1, "starts at week 1")
	_check(state.food > 0.0, "food initialized (%.0f)" % state.food)

	print("-- 10 normal weeks (weather roll, food cost ceili path) --")
	var food_before := state.food
	state = _run_weeks(state, 10, "spring")
	_check(state.week == 11, "week advanced to 11 (got %d)" % state.week)
	_check(state.food != food_before, "food changed over 10 weeks (%.0f -> %.0f)" % [food_before, state.food])
	_check(state.season >= 0, "season valid")
	_check(state.morale <= 100.0, "morale capped at 100 (got %.0f)" % state.morale)
	_check(state.fuel >= 0.0, "fuel never negative (got %.0f)" % state.fuel)

	print("-- winter jump: week 48, herd mortality + winter fodder (herd.gd rate path) --")
	state.week = 47  # run_week_after_event increments to 48 on first iteration
	var sheep_before := state.sheep
	state = _run_weeks(state, 4, "winter")
	_check(state.week == 51, "reached week 51 (got %d)" % state.week)
	print("  sheep: %d -> %d over winter" % [sheep_before, state.sheep])

	print("-- direct herd_delta effects path (events.gd duplicate-var fix) --")
	SimEvents._set_herd_count(state, GameTypes.AnimalType.SHEEP, 5)
	var sheep0: int = SimEvents._get_herd_count(state, GameTypes.AnimalType.SHEEP)
	SimEvents.resolve_choice_effects(state, {"effects": {"herd_delta": {GameTypes.AnimalType.SHEEP: -2}}}, "smoke-test")
	var sheep1: int = SimEvents._get_herd_count(state, GameTypes.AnimalType.SHEEP)
	_check(sheep1 == sheep0 - 2, "herd_delta -2 sheep applied (%d -> %d)" % [sheep0, sheep1])
	SimEvents.resolve_choice_effects(state, {"effects": {"herd_delta": {GameTypes.AnimalType.SHEEP: -999}}}, "smoke-test")
	_check(SimEvents._get_herd_count(state, GameTypes.AnimalType.SHEEP) == 0, "herd_delta clamps at 0")

	print("-- RUIN region enum (types.gd fix) --")
	_check(GameTypes.RegionId.RUIN == 5, "RegionId.RUIN exists at TS-matching index 5")
	_check(GameTypes.RegionId.LEE_SLOPE == 8, "LEE_SLOPE shifted correctly to 8")

	print("=== %s (%d failures) ===" % ["ALL PASS" if failures == 0 else "FAILURES", failures])
	get_tree().quit(1 if failures > 0 else 0)
