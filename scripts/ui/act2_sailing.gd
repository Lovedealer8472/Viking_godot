# ═══════════════════════════════════════════════════════════════════════════
# Act 2 — Sailing. Day-by-day crew management with random events.
# Journal UI theme matching Act 1.
# Steps: Intro → Assign → Event → Arrival
# ═══════════════════════════════════════════════════════════════════════════
class_name Act2Sailing
extends ActBase

func _backdrop_texture() -> String:
	return "res://assets/art/scenes/ship_deck.png"

const GOLD := Color(0.839, 0.663, 0.184)
const GOLD_BRIGHT := Color(0.95, 0.75, 0.30)
const WARM := Color(0.910, 0.863, 0.757)
const MUTED := Color(0.663, 0.592, 0.471)
const DIM := Color(0.416, 0.369, 0.282)
const RED := Color(0.749, 0.251, 0.145)
const GREEN := Color(0.451, 0.714, 0.275)

enum Step { INTRO, ASSIGN, EVENT, ARRIVAL }

# Task display data
const TASK_INFO := {
	GameTypes.SailingTask.STEER: {"name": "Steer", "desc": "+3-7 course"},
	GameTypes.SailingTask.NAVIGATE: {"name": "Navigate", "desc": "+5-10 course"},
	GameTypes.SailingTask.BAIL: {"name": "Bail", "desc": "+3-6 integrity"},
	GameTypes.SailingTask.REPAIR_SHIP: {"name": "Repair", "desc": "+5-12 integrity"},
	GameTypes.SailingTask.RATION: {"name": "Ration", "desc": "-2 supplies used"},
	GameTypes.SailingTask.FISH_AT_SEA: {"name": "Fish", "desc": "+3-7 supplies"},
	GameTypes.SailingTask.LOOK_OUT: {"name": "Look-out", "desc": "Spot dangers"},
	GameTypes.SailingTask.REST_AT_SEA: {"name": "Rest", "desc": "+5-10 morale"},
}

const TASK_ORDER: Array[int] = [
	GameTypes.SailingTask.STEER,
	GameTypes.SailingTask.NAVIGATE,
	GameTypes.SailingTask.BAIL,
	GameTypes.SailingTask.REPAIR_SHIP,
	GameTypes.SailingTask.RATION,
	GameTypes.SailingTask.FISH_AT_SEA,
	GameTypes.SailingTask.LOOK_OUT,
	GameTypes.SailingTask.REST_AT_SEA,
]

# ═══════════════════════════════════════════════════════════════════════════
# Sailing event definitions
# Each event has a choice array. Each choice has effects that modify
# ship state directly (+/- integrity, supplies, morale, course).
# ═══════════════════════════════════════════════════════════════════════════

const SAILING_EVENTS: Array[Dictionary] = [
	{
		"id": "storm",
		"title": "Storm at Sea",
		"text": "The sky turns to iron. Waves as high as hills crash against the hull. Wind screams through the rigging. The sea tries to swallow you.",
		"choices": [
			{
				"text": "Heave-to and ride it out",
				"integrity": -15.0, "supplies": -5.0, "morale": -5.0, "course": -2.0,
				"saga": "We hove-to and rode out the storm. The sea tested us and we endured."
			},
			{
				"text": "Run before the wind",
				"integrity": -8.0, "morale": -3.0, "course": 5.0,
				"saga": "We ran before the storm, flying across the mountainous waves."
			},
			{
				"text": "Lighten ship — throw cargo overboard",
				"supplies": -12.0, "integrity": -2.0, "morale": -3.0, "course": 2.0,
				"saga": "We threw precious cargo overboard to lighten the ship through the storm."
			},
		]
	},
	{
		"id": "doldrums",
		"title": "The Doldrums",
		"text": "The wind dies. The sails hang limp. The sea is a sheet of glass under a brazen sun. No bird, no cloud, no breath of air.",
		"choices": [
			{
				"text": "Wait for wind — conserve strength",
				"supplies": -8.0, "morale": -3.0,
				"saga": "We sat becalmed, waiting for the wind to return. Time slipped by."
			},
			{
				"text": "Take to the oars",
				"supplies": -3.0, "integrity": -2.0, "course": 3.0, "morale": -2.0,
				"saga": "We manned the oars and rowed through the glassy stillness."
			},
			{
				"text": "Make offerings to Njord for wind",
				"supplies": -5.0, "morale": 3.0, "course": 6.0,
				"saga": "We offered gifts to Njord. The god heard — wind filled the sails."
			},
		]
	},
	{
		"id": "sea_wight_sighting",
		"title": "Sea Wight Sighting",
		"text": "A shape moves in the mist — pale and vast. The crew mutter prayers. A sea-wight. It has not seen us yet.",
		"choices": [
			{
				"text": "Steer clear — say nothing",
				"morale": -5.0,
				"saga": "We gave the sea-wight a wide berth. The crew whispered for days."
			},
			{
				"text": "Face it boldly — all hands to the rail!",
				"morale": 5.0, "integrity": -5.0,
				"saga": "We stood at the rail and faced the sea-wight. It sank beneath the waves."
			},
			{
				"text": "Offer a sacrifice before it notices us",
				"supplies": -8.0, "morale": 3.0,
				"saga": "We made an offering to the sea-wight and it vanished into the mist."
			},
		]
	},
	{
		"id": "iceberg_field",
		"title": "Iceberg Field",
		"text": "Ice glitters on the northern horizon. Great bergs drift like silent ghosts — some tall as hills, others lurking just below the surface.",
		"choices": [
			{
				"text": "Navigate carefully through the channels",
				"course": 2.0, "integrity": -3.0,
				"saga": "We threaded a careful path through the labyrinth of ice."
			},
			{
				"text": "Give them wide passage — go south",
				"course": -5.0, "supplies": -3.0,
				"saga": "We sailed far south to avoid the ice, losing precious days."
			},
			{
				"text": "Send a boat ahead to scout the safest route",
				"integrity": -1.0, "course": 4.0,
				"saga": "We scouted ahead and found a safe passage through the ice field."
			},
		]
	},
]

# ── State ─────────────────────────────────────────────────────────────────

var _step := Step.INTRO
var _day := 0
var _game_over := false
var _assignments: Dictionary = {}  # char_id -> SailingTask int
var _pending_event: Dictionary = {}

@onready var _title: Label = $TitleLabel
@onready var _content: VBoxContainer = $CenterContainer/PanelBg/InnerVBox/ContentVBox
@onready var _btn: Button = $CenterContainer/PanelBg/InnerVBox/ActionButton

# ── Setup ─────────────────────────────────────────────────────────────────

func _setup_scene() -> void:
	# Warm parchment journal panel (identical to Act 1)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.11, 0.07, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.55, 0.42, 0.08, 0.4)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	$CenterContainer/PanelBg.add_theme_stylebox_override("panel", panel_style)

	# Gold-bordered action button with warm parchment text
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.20, 0.15, 0.08, 0.8)
	btn_style.set_border_width_all(2)
	btn_style.border_color = GOLD
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.30, 0.20, 0.10, 0.9)
	btn_hover.set_border_width_all(2)
	btn_hover.border_color = GOLD_BRIGHT
	btn_hover.set_corner_radius_all(6)
	btn_hover.set_content_margin_all(8)
	_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.15, 0.12, 0.06, 0.6)
	btn_disabled.set_border_width_all(2)
	btn_disabled.border_color = DIM
	btn_disabled.set_corner_radius_all(6)
	btn_disabled.set_content_margin_all(8)
	_btn.add_theme_stylebox_override("disabled", btn_disabled)

	_btn.add_theme_color_override("font_color", WARM)
	_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	_btn.add_theme_color_override("font_disabled_color", MUTED)

	_btn.pressed.connect(_on_action)

	# Initialize sailing state on first entry
	if game_state.course <= 0.0:
		game_state.course = 0.0
		game_state.ship_integrity = 100.0
		game_state.ship_supplies = 100.0
		game_state.ship_morale = 80.0
		game_state.storm_count = 0
		game_state.sailing_day = 1

	_day = game_state.sailing_day
	_show_intro()

# ── Content helpers (mirroring Act 1) ─────────────────────────────────────

func _clear() -> void:
	for c in _content.get_children():
		c.queue_free()

func _label(text: String, size := 22, color := WARM) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.custom_minimum_size = Vector2(860, 0)
	return l

func _heading(text: String) -> Label:
	return _label(text, 20, GOLD)

func _journal_card(title: String, desc: String) -> Button:
	"""Styled journal-entry card button with border-left accent."""
	var b := Button.new()
	b.text = "%s\n%s" % [title, desc]
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(860, 72)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", WARM)

	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.12, 0.09, 0.06, 0.5)
	base.set_border_width_all(1)
	base.set_border_width_left(3)
	base.border_color = Color(0.55, 0.42, 0.08, 0.3)
	base.border_color_left = Color(0.55, 0.42, 0.08, 0.6)
	base.set_corner_radius_all(4)
	base.set_content_margin_all(8)
	base.set_content_margin_left(12)
	b.add_theme_stylebox_override("normal", base)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.13, 0.08, 0.6)
	hover.set_border_width_all(1)
	hover.set_border_width_left(3)
	hover.border_color = Color(0.55, 0.42, 0.08, 0.3)
	hover.border_color_left = GOLD
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(8)
	hover.set_content_margin_left(12)
	b.add_theme_stylebox_override("hover", hover)

	return b

func _spacer(h := 12) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _divider() -> ColorRect:
	"""Thin gold line for journal section breaks."""
	var d := ColorRect.new()
	d.custom_minimum_size = Vector2(800, 1)
	d.color = Color(0.55, 0.42, 0.08, 0.25)
	return d

# ── Steps ─────────────────────────────────────────────────────────────────

func _show_intro() -> void:
	_step = Step.INTRO
	_title.text = "Act II — The Crossing"
	_clear()

	var pop := game_state.living_population()

	_content.add_child(_spacer(24))
	_content.add_child(_label(
		"The fjord falls away behind you.\nThe sea-road opens ahead — grey water stretching to the world's edge.\n\n" +
		"%d souls on a knarr, the wind in the sail,\nand nothing but sky and sea between you and a new land." % pop,
		16, WARM))
	_content.add_child(_spacer(16))

	_btn.visible = true
	_btn.text = "Begin the Crossing"

func _show_assign() -> void:
	_step = Step.ASSIGN
	_title.text = "Day %d at Sea" % _day
	_clear()
	_btn.visible = true
	_btn.disabled = false

	# Clamp ship values
	game_state.course = clampf(game_state.course, 0.0, 100.0)
	game_state.ship_integrity = clampf(game_state.ship_integrity, 0.0, 100.0)
	game_state.ship_supplies = maxf(game_state.ship_supplies, 0.0)
	game_state.ship_morale = clampf(game_state.ship_morale, 0.0, 100.0)

	# Dashboard
	_content.add_child(_build_dashboard())
	_content.add_child(_spacer(8))
	_content.add_child(_divider())
	_content.add_child(_spacer(8))

	# Crew task assignment
	_content.add_child(_heading("Crew Assignments"))
	_content.add_child(_spacer(4))
	var crew_table := _build_crew_table()
	if crew_table:
		_content.add_child(crew_table)
	else:
		_content.add_child(_label("No crew available!", 14, RED))

	_btn.text = "Resolve Day"

# ── Dashboard ─────────────────────────────────────────────────────────────

func _build_dashboard() -> Control:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(860, 0)

	container.add_child(_stat_bar("Course Progress", game_state.course, 100.0, GOLD, true))
	container.add_child(_spacer(2))
	container.add_child(_stat_bar("Hull Integrity", game_state.ship_integrity, 100.0, \
		GREEN if game_state.ship_integrity > 50.0 else (WARM if game_state.ship_integrity > 25.0 else RED), false))
	container.add_child(_spacer(2))
	container.add_child(_stat_bar("Supplies", game_state.ship_supplies, 100.0, \
		GREEN if game_state.ship_supplies > 50.0 else (WARM if game_state.ship_supplies > 25.0 else RED), false))
	container.add_child(_spacer(2))
	container.add_child(_stat_bar("Morale", game_state.ship_morale, 100.0, \
		GREEN if game_state.ship_morale > 50.0 else (WARM if game_state.ship_morale > 25.0 else RED), false))

	return container

func _stat_bar(label_text: String, value: float, max_value: float, color: Color, show_pct: bool) -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.custom_minimum_size = Vector2(860, 22)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", GOLD)
	hbox.add_child(lbl)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 16)
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = show_pct
	bar.modulate = color
	hbox.add_child(bar)

	var val_lbl := Label.new()
	val_lbl.text = "%d" % value
	val_lbl.custom_minimum_size = Vector2(40, 0)
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", color)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_lbl)

	return hbox

# ── Crew assignment (OptionButton per crew member) ────────────────────────

func _build_crew_table() -> Control:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(860, 0)
	var has_assignable := false

	for char: CharacterData in game_state.characters:
		if not char.alive or char.is_child:
			continue
		container.add_child(_crew_row(char))
		container.add_child(_spacer(3))
		has_assignable = true

	if not has_assignable:
		return null
	return container

func _crew_row(char: CharacterData) -> Control:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(860, 36)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)

	# Character portrait
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(28, 28)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_path := "res://assets/art/characters/%s.png" % char.id
	if ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	hbox.add_child(portrait)

	# Character name + class label
	var name_lbl := Label.new()
	name_lbl.text = "%s (%s)" % [char.char_name, GameTypes.class_name_str(char.char_class)]
	name_lbl.custom_minimum_size = Vector2(170, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", GOLD if char.char_class == GameTypes.CharacterClass.LEADER else WARM)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if char.injured:
		name_lbl.text += " [injured]"
		name_lbl.add_theme_color_override("font_color", RED)
	hbox.add_child(name_lbl)

	# Injured characters rest automatically
	if char.injured:
		var rest_lbl := Label.new()
		rest_lbl.text = "   [resting]"
		rest_lbl.add_theme_font_size_override("font_size", 11)
		rest_lbl.add_theme_color_override("font_color", DIM)
		rest_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rest_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(rest_lbl)
		return hbox

	# Task dropdown (OptionButton)
	var option_btn := OptionButton.new()
	option_btn.custom_minimum_size = Vector2(0, 28)
	option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_btn.add_theme_font_size_override("font_size", 11)
	option_btn.add_theme_color_override("font_color", WARM)
	option_btn.add_theme_constant_override("arrow_margin", 4)

	# Parchment-styled option button
	var ob_style := StyleBoxFlat.new()
	ob_style.bg_color = Color(0.08, 0.06, 0.04, 0.4)
	ob_style.set_border_width_all(1)
	ob_style.border_color = Color(0.55, 0.42, 0.08, 0.25)
	ob_style.set_corner_radius_all(3)
	ob_style.set_content_margin_all(4)
	option_btn.add_theme_stylebox_override("normal", ob_style)
	option_btn.add_theme_stylebox_override("hover", ob_style)

	# Populate task list
	option_btn.add_item("-- Unassigned --", -1)
	for task_id: int in TASK_ORDER:
		option_btn.add_item(TASK_INFO[task_id]["name"], task_id)

	# Set current assignment
	var char_id := char.id
	var current: int = _assignments.get(char_id, -1)
	if current >= 0:
		for idx in range(option_btn.item_count):
			if option_btn.get_item_id(idx) == current:
				option_btn.select(idx)
				break
	else:
		option_btn.select(0)

	option_btn.item_selected.connect(func(index: int):
		var task_id := option_btn.get_item_id(index)
		if task_id < 0:
			_assignments.erase(char_id)
		else:
			_assignments[char_id] = task_id
	)

	hbox.add_child(option_btn)
	return hbox

# ── Day resolution (simplified, no class bonuses) ─────────────────────────

func _resolve_day() -> void:
	print("\n=== RESOLVING DAY %d ===" % _day)

	# 1. Apply each crew member's task effects
	var assigned_count := 0
	for char: CharacterData in game_state.characters:
		if not char.alive or char.is_child or char.injured:
			continue
		var task: int = _assignments.get(char.id, -1)
		if task < 0:
			continue
		assigned_count += 1
		_apply_task(char, task)

	# 2. Base course advancement (8-15 points)
	var base_course := randf_range(8.0, 15.0)
	game_state.course += base_course

	# 3. Daily supply consumption
	game_state.ship_supplies -= 4.0

	# 4. Morale drift from hardship
	if game_state.ship_supplies < 20.0:
		game_state.ship_morale -= 3.0
	if game_state.ship_integrity < 30.0:
		game_state.ship_morale -= 2.0
	if game_state.ship_morale < 15.0:
		game_state.ship_morale -= 2.0

	# 5. Check for death spiral
	if game_state.ship_integrity <= 0.0:
		_show_foundered()
		return
	if game_state.ship_supplies <= 0.0:
		game_state.ship_morale -= 10.0
		game_state.saga_log.append("Supplies are gone. Hunger gnaws at the crew.")

	# 6. Check for arrival
	game_state.course = minf(game_state.course, 100.0)
	if game_state.course >= 100.0:
		game_state.saga_log.append("After %d days at sea, land is sighted on the horizon!" % _day)
		_show_arrival()
		return

	# 7. Random encounter (50% chance)
	if randf() < 0.50:
		var event_data := _pick_event()
		_show_event(event_data)
		return

	# 8. Advance day and return to assignment
	_advance_day()
	_show_assign()

func _advance_day() -> void:
	_day += 1
	game_state.sailing_day = _day
	_assignments.clear()

func _apply_task(char: CharacterData, task: int) -> void:
	match task:
		GameTypes.SailingTask.STEER:
			var effect := randf_range(3.0, 7.0)
			game_state.course += effect

		GameTypes.SailingTask.NAVIGATE:
			var effect := randf_range(5.0, 10.0)
			game_state.course += effect

		GameTypes.SailingTask.BAIL:
			var effect := randf_range(3.0, 6.0)
			game_state.ship_integrity += effect

		GameTypes.SailingTask.REPAIR_SHIP:
			var effect := randf_range(5.0, 12.0)
			game_state.ship_integrity += effect

		GameTypes.SailingTask.RATION:
			game_state.ship_supplies += 2.0

		GameTypes.SailingTask.FISH_AT_SEA:
			var effect := randf_range(3.0, 7.0)
			game_state.ship_supplies += effect

		GameTypes.SailingTask.LOOK_OUT:
			# Lookout gives a one-time course bonus (spotting favourable currents, winds)
			var effect := randf_range(3.0, 8.0)
			game_state.course += effect

		GameTypes.SailingTask.REST_AT_SEA:
			var effect := randf_range(5.0, 10.0)
			game_state.ship_morale += effect

	# Clamp ship values
	game_state.ship_integrity = clampf(game_state.ship_integrity, 0.0, 100.0)
	game_state.ship_supplies = maxf(game_state.ship_supplies, 0.0)
	game_state.ship_morale = clampf(game_state.ship_morale, 0.0, 100.0)

# ── Events (simplified, uniform random selection) ─────────────────────────

func _pick_event() -> Dictionary:
	return SAILING_EVENTS[randi() % SAILING_EVENTS.size()]

func _show_event(event_data: Dictionary) -> void:
	_step = Step.EVENT
	_title.text = event_data["title"]
	_clear()
	_btn.visible = false

	_pending_event = event_data

	# Event illustration
	var event_id: String = event_data["id"]
	var art_paths := [
		"res://assets/art/events/%s.png" % event_id,
		"res://assets/art/events/%s.png" % event_id.replace("storm", "storm_at_sea"),
	]
	var art_loaded := false
	for path in art_paths:
		if ResourceLoader.exists(path):
			var art := TextureRect.new()
			art.texture = load(path)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.custom_minimum_size = Vector2(350, 175)
			var art_container := CenterContainer.new()
			art_container.custom_minimum_size = Vector2(860, 185)
			art_container.add_child(art)
			_content.add_child(art_container)
			_content.add_child(_spacer(8))
			art_loaded = true
			break

	# Journal entry narrative
	_content.add_child(_spacer(4))
	_content.add_child(_label(event_data["text"], 15, WARM))
	_content.add_child(_spacer(12))
	_content.add_child(_divider())
	_content.add_child(_spacer(8))

	# Choice buttons styled as journal cards
	var choices: Array = event_data["choices"]
	for i in choices.size():
		var choice: Dictionary = choices[i]

		# Build effect description line
		var effects_str := ""
		if choice.has("integrity"):
			effects_str += "Integrity %+.0f  " % float(choice["integrity"])
		if choice.has("supplies"):
			effects_str += "Supplies %+.0f  " % float(choice["supplies"])
		if choice.has("morale"):
			effects_str += "Morale %+.0f  " % float(choice["morale"])
		if choice.has("course"):
			effects_str += "Course %+.0f  " % float(choice["course"])

		var btn := _journal_card(choice["text"], effects_str)
		var idx := i
		btn.pressed.connect(func():
			_resolve_choice(idx)
		)
		_content.add_child(btn)

func _resolve_choice(index: int) -> void:
	var event_data: Dictionary = _pending_event
	var choice: Dictionary = event_data["choices"][index]

	# Apply choice effects directly to ship state
	if choice.has("integrity"):
		game_state.ship_integrity += float(choice["integrity"])
	if choice.has("supplies"):
		game_state.ship_supplies += float(choice["supplies"])
	if choice.has("morale"):
		game_state.ship_morale += float(choice["morale"])
	if choice.has("course"):
		game_state.course += float(choice["course"])
		game_state.course = minf(game_state.course, 100.0)
	if choice.has("saga"):
		game_state.saga_log.append(str(choice["saga"]))

	# Track storms
	if event_data["id"] == "storm":
		game_state.storm_count += 1

	# Clamp values
	game_state.ship_integrity = clampf(game_state.ship_integrity, 0.0, 100.0)
	game_state.ship_supplies = maxf(game_state.ship_supplies, 0.0)
	game_state.ship_morale = clampf(game_state.ship_morale, 0.0, 100.0)

	# Check for game over conditions
	if game_state.ship_integrity <= 0.0:
		game_state.saga_log.append("The ship foundered. The saga ends in the deep.")
		game_state.game_over = true
		complete_act(game_state)
		return

	if game_state.ship_supplies <= 0.0:
		game_state.ship_morale -= 10.0
		game_state.saga_log.append("Supplies are gone. Hunger gnaws at the crew.")

	# Advance to next day and continue
	_advance_day()

	if game_state.course >= 100.0:
		_show_arrival()
	else:
		_show_assign()

# ── Arrival ───────────────────────────────────────────────────────────────

func _show_arrival() -> void:
	_step = Step.ARRIVAL
	_title.text = "Land Ho!"
	_clear()
	_btn.visible = true
	_btn.disabled = false

	var pop := game_state.living_population()

	_content.add_child(_spacer(24))
	_content.add_child(_label(
		"Land ho! Grey cliffs rise from the mist — an unknown coast.\nAfter %d days at sea, you have found what you sought.\n\nThe saga does not end here. It begins anew." % _day,
		17, WARM))
	_content.add_child(_spacer(12))

	# Voyage summary
	var integrity_status := "sturdy" if game_state.ship_integrity > 60.0 else \
		("battered" if game_state.ship_integrity > 30.0 else "breaking apart")
	var morale_status := "high" if game_state.ship_morale > 60.0 else \
		("weary" if game_state.ship_morale > 30.0 else "broken")

	_content.add_child(_label(
		"The knarr is %s. The crew's spirit is %s.\n%d souls make landfall." % [integrity_status, morale_status, pop],
		14, MUTED))
	_content.add_child(_spacer(8))

	var stats_line := "%d days  ·  %d storms weathered  ·  %.0f%% hull" % [_day, game_state.storm_count, game_state.ship_integrity]
	_content.add_child(_label(stats_line, 13, GOLD))

	_btn.text = "Make Landfall — Begin Act III"

func _show_foundered() -> void:
	_title.text = "The Ship Founders"
	_clear()
	_btn.visible = true
	_btn.disabled = true
	_game_over = true

	_content.add_child(_spacer(24))
	_content.add_child(_label(
		"The sea claims the knarr. Planks splinter. Water pours in.\n\nThe saga ends here, in the cold grey deep.",
		17, RED))
	_content.add_child(_spacer(12))
	_content.add_child(_label(
		"%d days at sea. So close, yet so far." % _day,
		14, MUTED))

	game_state.game_over = true
	game_state.saga_log.append("The ship foundered at sea. The saga is over.")

	_btn.text = "The End"
	await get_tree().create_timer(2.0).timeout
	_btn.disabled = false

# ── Main action button handler ────────────────────────────────────────────

func _on_action() -> void:
	if _game_over:
		complete_act(game_state)
		return

	match _step:
		Step.INTRO:
			_day = 1
			game_state.sailing_day = 1
			game_state.saga_log.append("The knarr slips from the fjord. The crossing begins.")
			_show_assign()

		Step.ASSIGN:
			_resolve_day()

		Step.ARRIVAL:
			game_state.act = GameTypes.ActId.LANDFALL
			game_state.saga_log.append("Landfall after %d days at sea. A new saga begins." % _day)
			complete_act(game_state)
