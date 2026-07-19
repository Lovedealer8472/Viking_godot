# End-to-end flow driver: simulate the button presses / card clicks a player makes,
# to verify Act 1 plays through to Set Sail (patrons + pillars/landing choice) and an
# Act 2 event resolves — the paths the playtest found broken.
extends Node

func _ready() -> void:
	DirAccess.make_dir_absolute("res://shots")
	await _test_act1()
	await _test_act2()
	print(">>> FLOW TESTS DONE")
	get_tree().quit()

func _fr(n := 5) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(nm: String) -> void:
	await _fr(20)
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % nm)
	print("  saved ", nm)

func _mk(act: int) -> GameState:
	var s: GameState = NewSaga.create(
		GameTypes.Difficulty.NORMAL, GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND])
	s.act = act
	return s

func _click_first_card(content: Node) -> bool:
	for c in content.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).pressed.emit()
			return true
	return false

func _press(scene) -> void:
	var b: Button = scene._btn
	if b and b.visible and not b.disabled:
		b.pressed.emit()

func _test_act1() -> void:
	print(">>> ACT 1 FLOW")
	var s := _mk(GameTypes.ActId.PREPARATION)
	var scene: Control = load("res://scenes/act1/preparation.tscn").instantiate()
	scene.set("game_state", s)
	add_child(scene)
	await _fr(8)
	print("  step(setup)=", scene._step)
	_press(scene); await _fr()                       # INTRO -> CREW
	_press(scene); await _fr()                       # CREW -> PATRONS
	print("  PATRONS cards=", scene._content.get_child_count())
	_click_first_card(scene._content); await _fr()   # accept a patron
	_press(scene); await _fr()                       # PATRONS -> PILLARS
	print("  PILLARS cards=", scene._content.get_child_count())
	await _shot("dbg_act1_pillars2")
	_click_first_card(scene._content); await _fr()   # choose a pillar (landing)
	_press(scene); await _fr()                       # PILLARS -> READY
	await _shot("dbg_act1_ready")
	_press(scene); await _fr(8)                      # READY -> set sail
	print("  RESULT act=", s.act, " want=", GameTypes.ActId.SAILING, " site_id=", s.site_id)
	scene.queue_free(); await _fr()

func _test_act2() -> void:
	print(">>> ACT 2 FLOW")
	var s := _mk(GameTypes.ActId.SAILING)
	var scene: Control = load("res://scenes/act2/sailing.tscn").instantiate()
	scene.set("game_state", s)
	add_child(scene)
	await _fr(8)
	_press(scene); await _fr()                       # INTRO -> ASSIGN
	scene._show_event(Act2Sailing.SAILING_EVENTS[0]); await _fr(6)
	print("  EVENT cards=", scene._content.get_child_count())
	await _shot("dbg_act2_event_big")
	var day_before = scene._day
	var ok := _click_first_card(scene._content); await _fr(6)
	print("  choice clicked=", ok, " step=", scene._step, " day=", scene._day, " (was ", day_before, ")")
	scene.queue_free(); await _fr()
