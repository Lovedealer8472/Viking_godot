# Auto-play Act 1 and save screenshots at each step.
# Run with: godot --headless -- script res://scripts/screenshot_test.gd
extends Node

var _state: GameState
var _act_scene: Control
var _step := 0
var _screenshot_count := 0

func _ready() -> void:
	_state = NewSaga.create(GameTypes.Difficulty.NORMAL, GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND])

	_act_scene = load("res://scenes/act1/preparation.tscn").instantiate()
	_act_scene.game_state = _state
	add_child(_act_scene)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_take_screenshot("01_intro")
	print("Screenshot: 01_intro")

	# Click through steps
	await _click_action()  # INTRO → CREW
	await get_tree().process_frame
	_take_screenshot("02_crew")

	await _click_action()  # CREW → PATRONS
	await get_tree().process_frame
	_take_screenshot("03_patrons")

	await _click_action()  # PATRONS → PILLARS
	await get_tree().process_frame
	_take_screenshot("04_pillars")

	# Select first pillar
	var pillar_btns = _find_buttons(_act_scene)
	if pillar_btns.size() > 0:
		pillar_btns[0].button_down.emit()
		pillar_btns[0].button_up.emit()
		await get_tree().process_frame

	_take_screenshot("05_pillars_selected")

	print("Done! ", _screenshot_count, " screenshots saved to user://")
	get_tree().quit()

func _click_action() -> void:
	var btns = _find_buttons(_act_scene)
	for b in btns:
		if b.text.contains("Ready") or b.text.contains("Continue") or b.text.contains("Name") or b.text.contains("without"):
			b.button_down.emit()
			b.button_up.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			return

func _find_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child in node.get_children():
		result.append_array(_find_buttons(child))
	return result

func _take_screenshot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	_screenshot_count += 1
	img.save_png("user://%s.png" % name)
