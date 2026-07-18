# ═══════════════════════════════════════════════════════════════════════════
# Main — top-level scene controller. Reads GameState.act and loads the
# appropriate act scene. Acts as a simple state machine.
# ═══════════════════════════════════════════════════════════════════════════
extends Node

var game_state: GameState

func _ready() -> void:
	game_state = NewSaga.create(
		GameTypes.Difficulty.NORMAL,
		GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND]
	)
	# Start at Act 1 — NewSaga.create sets act to PREPARATION
	game_state.act = GameTypes.ActId.PREPARATION
	_load_act_scene()

func _load_act_scene() -> void:
	# Remove current act scene
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
	_load_act_scene()
