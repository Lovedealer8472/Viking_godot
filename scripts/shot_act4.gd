# Quick screenshot of Act 4 settlement screen.
# Run: godot --headless --path . -- script res://scripts/shot_act4.gd
extends Node

func _ready() -> void:
	var state: GameState = NewSaga.create(GameTypes.Difficulty.NORMAL, GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND])
	state.act = GameTypes.ActId.SETTLEMENT

	var scene: Control = load("res://scenes/act4/settlement.tscn").instantiate()
	scene.game_state = state
	add_child(scene)

	for i in 8:
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	img.save_png("user://act4_settlement.png")
	print("saved act4_settlement.png")
	get_tree().quit()
