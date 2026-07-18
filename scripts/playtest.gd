# Playtest — auto-click through Act 1 steps and log everything
extends Node

var _state: GameState
var _act_scene: Control
var _frame := 0

func _ready() -> void:
	print("═══════════════════════════════════════")
	print("  PLAYTEST — Act 1 automatic walkthrough")
	print("═══════════════════════════════════════")
	_state = NewSaga.create(GameTypes.Difficulty.NORMAL, GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND])

	_act_scene = load("res://scenes/act1/preparation.tscn").instantiate()
	_act_scene.game_state = _state
	add_child(_act_scene)

	# Wait for rendering
	await _wait_frames(5)

func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		6: _click_step("Intro -> Crew")
		20: _click_step("Crew -> Patrons")
		34: _click_step("Patrons -> Pillars")
		48: _click_pillar()
		62: _click_step("Ready -> Set Sail")

func _click_step(desc: String) -> void:
	print("\n── ", desc, " ──")
	var btn := _find_action_button()
	if btn:
		print("  Button: '", btn.text, "'  disabled=", btn.disabled)
		btn.pressed.emit()
		print("  Clicked.")

func _click_pillar() -> void:
	print("\n── Selecting first pillar ──")
	# Find all buttons in the content area
	var content := _act_scene.get_node_or_null("CenterContainer/PanelBg/InnerVBox/ContentVBox")
	if content:
		for child in content.get_children():
			if child is Button and not child.disabled:
				print("  Pillar: '", child.text.replace("\n"," | "), "'")
				child.pressed.emit()
				print("  Selected.")
				return

func _find_action_button() -> Button:
	var all := _find_all_buttons(_act_scene)
	# The action button has text like "Name Your Crew", "Crew Ready", "Continue", etc
	for b in all:
		var t := b.text
		if t.contains("Name") or t.contains("Crew") or t.contains("Continue") or t.contains("without") or t.contains("Choose") or t.contains("Set Sail"):
			return b
	return null

func _find_all_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button: result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_buttons(child))
	return result

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
