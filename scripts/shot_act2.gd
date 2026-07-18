# Quick screenshot of Act 2 sailing screen.
extends Node

func _ready() -> void:
	var state: GameState = NewSaga.create(GameTypes.Difficulty.NORMAL, GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND])
	state.act = GameTypes.ActId.SAILING

	var scene: Control = load("res://scenes/act2/sailing.tscn").instantiate()
	scene.game_state = state
	add_child(scene)

	for i in 8:
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	img.save_png("user://act2_sailing.png")
	print("saved act2_sailing.png")
	get_tree().quit()
