# ═══════════════════════════════════════════════════════════════════════════
# UI end-to-end playthrough — drives the REAL act scenes through the REAL
# main.gd routing (Act 1 → 2 → 3 → 4), catching UI-layer crashes: bad node
# paths, event popups, the Act 3 name field, the Act 4 weekly loop.
#
# Generic driver: each tick it either fills the name field, clicks one choice
# card / event choice, or presses the primary ActionButton. Works headless
# (crash-hunt) and windowed (screenshots auto-skip when no viewport texture).
# ═══════════════════════════════════════════════════════════════════════════
extends Node

const ACT_TICKS := 6            # frames between driver actions (let UI settle)
const MAX_ACT4_WEEKS := 20      # prove the settlement loop, don't run all 52
const MAX_FRAMES := 3000        # hard safety cap
const STUCK_LIMIT := 12         # ticks with no actionable control → bail

var _state: GameState
var _current: ActBase
var _menu: Node                 # the main menu, while it's up
var _frame := 0
var _tick_cooldown := 0
var _interacted := false        # clicked a choice on the current screen?
var _stuck := 0
var _act4_weeks := 0
var _shots := 0
var _menu_ticks := 0
var _sailing_assigned := false
var _loading := false
var _acts_entered: Array = []

# Sailing tasks the harness assigns so Act 2 progresses under the new depth rules.
const SAIL_PLAN: Array = [
	GameTypes.SailingTask.NAVIGATE, GameTypes.SailingTask.STEER,
	GameTypes.SailingTask.LOOK_OUT, GameTypes.SailingTask.FISH_AT_SEA,
	GameTypes.SailingTask.REPAIR_SHIP, GameTypes.SailingTask.BAIL,
]


func _ready() -> void:
	print("╔══════════════════════════════════════════════════════════╗")
	print("║  UI PLAYTHROUGH — Menu → Act 1 → 2 → 3 → 4 (real scenes)  ║")
	print("╚══════════════════════════════════════════════════════════╝")
	# Boot the REAL first screen: the main menu.
	_menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	if _menu.has_signal("start_saga"):
		_menu.start_saga.connect(_on_saga_start)
	add_child(_menu)
	print("\n>>> ENTER: Main Menu")


func _on_saga_start(difficulty: int, realism: int, pillars: Array) -> void:
	print("<<< MENU start_saga: difficulty=%d realism=%d pillars=%s" % [difficulty, realism, str(pillars)])
	_state = NewSaga.create(difficulty, realism, pillars)
	_state.act = GameTypes.ActId.PREPARATION
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
	_loading = true
	call_deferred("_load_act")


func _scene_path(act: int) -> String:
	match act:
		GameTypes.ActId.PREPARATION: return "res://scenes/act1/preparation.tscn"
		GameTypes.ActId.SAILING:     return "res://scenes/act2/sailing.tscn"
		GameTypes.ActId.LANDFALL:    return "res://scenes/act3/landfall.tscn"
		GameTypes.ActId.SETTLEMENT:  return "res://scenes/act4/settlement.tscn"
	return ""


func _load_act() -> void:
	var path := _scene_path(_state.act)
	if not ResourceLoader.exists(path):
		print("  ✗ MISSING SCENE for act %s: %s" % [GameTypes.act_label(_state.act), path])
		_finish("missing scene")
		return
	_current = load(path).instantiate()
	_current.game_state = _state
	_current.act_completed.connect(_on_act_completed)
	add_child(_current)
	_acts_entered.append(GameTypes.act_label(_state.act))
	print("\n>>> ENTER: Act %s" % GameTypes.act_label(_state.act))
	_interacted = false
	_stuck = 0
	_loading = false


func _on_act_completed(next_state: GameState) -> void:
	print("<<< COMPLETE: Act %s → Act %s" % [GameTypes.act_label(_state.act), GameTypes.act_label(next_state.act)])
	_state = next_state
	_loading = true
	if is_instance_valid(_current):
		_current.act_completed.disconnect(_on_act_completed)
		_current.queue_free()
	_current = null
	if _state.game_over:
		_finish("game over during transition")
		return
	call_deferred("_load_act")


func _process(_delta: float) -> void:
	_frame += 1
	if _frame > MAX_FRAMES:
		_finish("frame cap reached")
		return

	# Rate-limit all driving so the UI settles between actions.
	_tick_cooldown -= 1
	if _tick_cooldown > 0:
		return
	_tick_cooldown = ACT_TICKS

	# Menu phase (runs BEFORE the act guard, since _current is null here).
	if is_instance_valid(_menu):
		_menu_ticks += 1
		_screenshot_named("menu")
		# Let the menu render a few frames before launching, so the screenshot
		# captures the laid-out menu (not the frame-1 black pre-render).
		if _menu_ticks < 3:
			return
		var setsail := _menu.find_child("SetSailButton", true, false)
		if setsail and setsail is Button and not setsail.disabled:
			print("  · menu: Set Sail")
			setsail.pressed.emit()
		return

	# Act phase.
	if _loading or _current == null or not is_instance_valid(_current):
		return
	_screenshot()
	_drive()


func _drive() -> void:
	# End if the settlement loop is proven or the saga ended.
	if _state.game_over:
		_finish("game over")
		return
	if _state.act == GameTypes.ActId.SETTLEMENT and _act4_weeks >= MAX_ACT4_WEEKS:
		_finish("settlement loop proven (%d weeks, no crash)" % _act4_weeks)
		return

	var action_btn := _find_action_button()

	# ── Act 3 name field: fill it so the button enables ──
	var name_input := _current.find_child("NameInput", true, false)
	if name_input and name_input is LineEdit and name_input.visible \
			and action_btn and action_btn.disabled:
		name_input.text = "Vinland"
		name_input.text_changed.emit("Vinland")
		print("  · typed settlement name")
		return

	# ── Click one choice card / event choice before pressing the action ──
	if not _interacted:
		var choice := _find_choice_button(action_btn)
		if choice:
			_interacted = true
			_stuck = 0
			print("  · choice: \"%s\"" % _short(choice.text))
			choice.pressed.emit()
			return

	# ── Press the primary action button (advances to the next screen) ──
	if action_btn and action_btn.visible and not action_btn.disabled:
		# Act 2 now requires real assignments — populate them before resolving.
		if _state.act == GameTypes.ActId.SAILING and _short(action_btn.text).begins_with("Resolve Day"):
			_assign_sailing()
		if _state.act == GameTypes.ActId.SETTLEMENT and _short(action_btn.text).begins_with("Resolve"):
			_act4_weeks += 1
			print("  · [week %d] %s (course/hull check)" % [_act4_weeks, _short(action_btn.text)])
		else:
			print("  · action: \"%s\"" % _short(action_btn.text))
		_interacted = false
		_stuck = 0
		action_btn.pressed.emit()
		return

	# ── Nothing actionable ──
	_stuck += 1
	if _stuck >= STUCK_LIMIT:
		var title := _current.find_child("TitleLabel", true, false)
		var title_txt: String = title.text if (title and title is Label) else "?"
		_finish("STUCK in Act %s (screen: \"%s\") — no actionable control" % [
			GameTypes.act_label(_state.act), title_txt])


func _find_action_button() -> Button:
	var n := _current.find_child("ActionButton", true, false)
	return n if (n and n is Button) else null


func _find_choice_button(action_btn: Button) -> Button:
	# First visible, enabled plain Button that isn't the action / buildings /
	# a dropdown (OptionButton subclasses Button).
	for b in _all_buttons(_current):
		if b == action_btn:
			continue
		if b is OptionButton:
			continue
		if b.name == "BuildingsButton":
			continue
		if b.visible and not b.disabled and b.text.strip_edges() != "":
			return b
	return null


func _all_buttons(node: Node) -> Array:
	var out: Array = []
	if node is Button:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_buttons(c))
	return out


func _assign_sailing() -> void:
	# Assign the crew exactly ONCE. If day-to-day persistence works, they keep
	# their posts and still reach landfall; if assignments were cleared each day
	# they'd go idle and founder. This is the persistence regression test.
	if _sailing_assigned:
		return
	_sailing_assigned = true
	var a: Dictionary = {}
	var i := 0
	for c in _state.characters:
		if not c.alive or c.is_child or c.injured:
			continue
		a[c.id] = SAIL_PLAN[i % SAIL_PLAN.size()]
		i += 1
	if is_instance_valid(_current):
		_current.set("_assignments", a)
	print("  · assigned sailing crew ONCE (testing persistence)")


func _screenshot() -> void:
	_screenshot_named(GameTypes.act_label(_state.act).to_lower())


func _screenshot_named(label: String) -> void:
	# No framebuffer under the headless dummy renderer — skip cleanly.
	if DisplayServer.get_name() == "headless":
		return
	var vp := get_viewport()
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	_shots += 1
	img.save_png("user://play_%02d_%s.png" % [_shots, label])


func _short(s: String) -> String:
	var t := s.replace("\n", " | ").strip_edges()
	return t.substr(0, 46)


func _finish(reason: String) -> void:
	print("\n╔══════════════════════════════════════════════════════════╗")
	print("║  PLAYTHROUGH ENDED: %s" % reason)
	print("╚══════════════════════════════════════════════════════════╝")
	print("  Acts entered: ", ", ".join(_acts_entered))
	print("  Frames: %d   Screenshots: %d   Act4 weeks: %d" % [_frame, _shots, _act4_weeks])
	get_tree().quit()
