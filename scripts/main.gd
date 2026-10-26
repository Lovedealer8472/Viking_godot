# ═══════════════════════════════════════════════════════════════════════════
# Main — top-level scene controller. Reads GameState.act and loads the
# appropriate act scene. Acts as a simple state machine.
# ═══════════════════════════════════════════════════════════════════════════
extends Node

var game_state: GameState

func _ready() -> void:
	_show_main_menu()

## First screen the game shows: title + new-saga setup (difficulty, world,
## high-seat pillars). Nothing is created until the menu emits start_saga.
func _show_main_menu() -> void:
	for child in get_children():
		if child != self:
			child.queue_free()

	var menu_scene: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	if menu_scene.has_signal("start_saga"):
		menu_scene.start_saga.connect(_on_start_saga)
	add_child(menu_scene)

func _on_start_saga(difficulty: int, realism: int, pillars: Array) -> void:
	game_state = NewSaga.create(difficulty, realism, pillars)
	# Start at Act 1 — NewSaga.create sets act to PREPARATION
	game_state.act = GameTypes.ActId.PREPARATION
	_load_act_scene()

func _load_act_scene() -> void:
	# Remove current scene (the menu, or the previous act)
	for child in get_children():
		if child != self:
			child.queue_free()

	var scene_path: String
	match game_state.act:
		GameTypes.ActId.PREPARATION:
			scene_path = "res://scenes/act1/preparation.tscn"
		GameTypes.ActId.SAILING:
			scene_path = "res://scenes/act2/sailing.tscn"
		GameTypes.ActId.LANDFALL:
			scene_path = "res://scenes/act3/landfall.tscn"
		GameTypes.ActId.SETTLEMENT:
			scene_path = "res://scenes/act4/settlement.tscn"

	if ResourceLoader.exists(scene_path):
		var act_scene: Node = load(scene_path).instantiate()
		act_scene.set("game_state", game_state)
		if act_scene.has_signal("act_completed"):
			act_scene.act_completed.connect(_on_act_completed)
		add_child(act_scene)

func _on_act_completed(next_state: GameState) -> void:
	game_state = next_state
	# A game-over (e.g. the ship foundered) must not reload the same act — that
	# would loop forever on a dead state. Return to the main menu instead.
	if game_state.game_over:
		_show_main_menu()
		return
	_load_act_scene()
