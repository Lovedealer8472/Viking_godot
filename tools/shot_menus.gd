# Debug harness: drive the interactive menus that the playtest flagged as broken
# (Act 1 patrons + pillars, Act 2 sea event) and screenshot them.
extends Node

func _ready() -> void:
	DirAccess.make_dir_absolute("res://shots")
	await _cap_act1()
	await _cap_act2()
	get_tree().quit()

func _mk_state(act: int) -> GameState:
	var s: GameState = NewSaga.create(
		GameTypes.Difficulty.NORMAL, GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND]
	)
	s.act = act
	return s

func _shot(nm: String) -> void:
	for i in 24:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://shots/%s.png" % nm)
	print("saved ", nm)

func _cap_act1() -> void:
	var scene: Control = load("res://scenes/act1/preparation.tscn").instantiate()
	scene.set("game_state", _mk_state(GameTypes.ActId.PREPARATION))
	add_child(scene)
	for i in 10:
		await get_tree().process_frame
	scene._show_patrons()
	await _shot("dbg_act1_patrons")
	scene._show_pillars()
	await _shot("dbg_act1_pillars")
	scene.queue_free()
	await get_tree().process_frame

func _cap_act2() -> void:
	var scene: Control = load("res://scenes/act2/sailing.tscn").instantiate()
	scene.set("game_state", _mk_state(GameTypes.ActId.SAILING))
	add_child(scene)
	for i in 10:
		await get_tree().process_frame
	scene._show_event(Act2Sailing.SAILING_EVENTS[0])
	await _shot("dbg_act2_event")
	scene.queue_free()
	await get_tree().process_frame
