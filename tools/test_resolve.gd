# Verification: instance Act 4, run one Resolve Week, and screenshot the result
# (event popup or next-week state) to confirm the core loop works and looks right.
extends Node

func _ready() -> void:
	DirAccess.make_dir_absolute("res://shots")
	var state: GameState = NewSaga.create(
		GameTypes.Difficulty.NORMAL, GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND]
	)
	state.act = GameTypes.ActId.SETTLEMENT
	var scene: Control = load("res://scenes/act4/settlement.tscn").instantiate()
	scene.set("game_state", state)
	add_child(scene)
	for i in 24:
		await get_tree().process_frame

	print(">>> triggering Resolve Week")
	if scene.has_method("_on_resolve_week"):
		scene._on_resolve_week()
	for i in 36:
		await get_tree().process_frame

	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://shots/act4_after_resolve.png")
	print(">>> saved act4_after_resolve.png")
	get_tree().quit()
