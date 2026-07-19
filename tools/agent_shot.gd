# Agent screenshot harness — instances each act scene with a fresh game state,
# waits for layout/textures, and saves a PNG to res://shots/. Run windowed
# (headless uses a dummy renderer and captures blank frames).
extends Node

func _ready() -> void:
	await _capture_all()
	get_tree().quit()

func _capture_all() -> void:
	DirAccess.make_dir_absolute("res://shots")
	var acts := [
		["res://scenes/act1/preparation.tscn", GameTypes.ActId.PREPARATION, "act1_preparation"],
		["res://scenes/act2/sailing.tscn", GameTypes.ActId.SAILING, "act2_sailing"],
		["res://scenes/act3/landfall.tscn", GameTypes.ActId.LANDFALL, "act3_landfall"],
		["res://scenes/act4/settlement.tscn", GameTypes.ActId.SETTLEMENT, "act4_settlement"],
	]
	for a in acts:
		var scene_path: String = a[0]
		var act_id = a[1]
		var out_name: String = a[2]
		if not ResourceLoader.exists(scene_path):
			print("MISSING ", scene_path)
			continue
		var state: GameState = NewSaga.create(
			GameTypes.Difficulty.NORMAL, GameTypes.Realism.NORMAL,
			[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND]
		)
		state.act = act_id
		var scene: Node = load(scene_path).instantiate()
		scene.set("game_state", state)
		add_child(scene)
		for i in 30:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		var err := img.save_png("res://shots/%s.png" % out_name)
		print("saved ", out_name, " ", img.get_width(), "x", img.get_height(), " err=", err)
		scene.queue_free()
		await get_tree().process_frame
