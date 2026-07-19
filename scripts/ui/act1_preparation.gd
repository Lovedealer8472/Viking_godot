# ═══════════════════════════════════════════════════════════════════════════
# Act 1 — Preparation. Clean scene-driven flow:
#   Intro → Crew → Patrons → Pillars → Ready → Set Sail
# ═══════════════════════════════════════════════════════════════════════════
class_name Act1Preparation
extends ActBase

func _backdrop_texture() -> String:
	return "res://assets/art/scenes/fjord.png"

const GOLD := Color(0.839, 0.663, 0.184)
const GOLD_BRIGHT := Color(0.95, 0.75, 0.30)
const WARM := Color(0.910, 0.863, 0.757)
const MUTED := Color(0.663, 0.592, 0.471)
const DIM := Color(0.416, 0.369, 0.282)

enum Step { INTRO, CREW, PATRONS, PILLARS, READY }

var _step := Step.INTRO
var _patron_count := 0
var _chosen_pillar := -1
var _crew_name_edits: Array[LineEdit] = []
var _pillar_btns: Array[Button] = []

@onready var _title: Label = $TitleLabel
@onready var _content: VBoxContainer = $CenterContainer/PanelBg/InnerVBox/ContentVBox
@onready var _btn: Button = $CenterContainer/PanelBg/InnerVBox/ActionButton

# ── Setup ─────────────────────────────────────────────────────────────────

func _setup_scene() -> void:
	print("=== Act 1 — Preparation starting ===")
	_btn.pressed.connect(_on_action)

	if game_state:
		print("Characters in state: ", game_state.characters.size())
	else:
		print("WARNING: game_state is null in _setup_scene")

	# Warm parchment journal panel
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

	_show_intro()

# ── Content helpers ───────────────────────────────────────────────────────

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

func _make_gold_card(b: Button) -> void:
	"""Turns a card gold — accepted patron or selected pillar."""
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color(0.25, 0.18, 0.06, 0.5)
	gold.set_border_width_all(1)
	gold.set_border_width_left(3)
	gold.border_color = GOLD
	gold.border_color_left = GOLD_BRIGHT
	gold.set_corner_radius_all(4)
	gold.set_content_margin_all(8)
	gold.set_content_margin_left(12)
	b.add_theme_stylebox_override("normal", gold)
	b.add_theme_stylebox_override("disabled", gold)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_disabled_color", GOLD)

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
	_title.text = "Act I — Preparation"
	_clear()
	print("[STEP] Intro")

	_content.add_child(_spacer(20))
	_content.add_child(_label(
		("The fjord is grey with morning mist. A knarr rocks at the dock —\n"
		+ "your grandfather's ship, sound but small.\n"
		+ "Before you sail, name those who will sail with you,\n"
		+ "seek patrons, and cast the high-seat pillars."),
		16, WARM))
	_content.add_child(_spacer(16))
	_btn.text = "Name Your Crew"

func _show_crew() -> void:
	_step = Step.CREW
	_title.text = "Name Your Crew"
	_clear()
	_crew_name_edits.clear()
	print("[STEP] Crew — showing %d name inputs" % [game_state.characters.size() - 1])

	_content.add_child(_spacer(8))
	_content.add_child(_label(
		"Six souls stand ready beside you.\nSpeak their names before we sail.",
		15, MUTED))
	_content.add_child(_spacer(8))

	# Index 0 is the leader ("You"); let the player rename the other 6
	for i in range(1, game_state.characters.size()):
		var c := game_state.characters[i] as CharacterData
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.custom_minimum_size = Vector2(0, 32)

		# Gold class label on the left
		var cls_label := Label.new()
		cls_label.text = c.class_label()
		cls_label.custom_minimum_size = Vector2(110, 0)
		cls_label.add_theme_color_override("font_color", GOLD)
		cls_label.add_theme_font_size_override("font_size", 14)
		cls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(cls_label)

		# Parchment-styled name input
		var edit := LineEdit.new()
		edit.text = c.char_name
		edit.custom_minimum_size = Vector2(360, 32)
		edit.placeholder_text = "Enter name..."
		edit.add_theme_font_size_override("font_size", 14)
		edit.add_theme_color_override("font_color", WARM)
		edit.add_theme_color_override("placeholder_color", MUTED)
		edit.add_theme_color_override("caret_color", GOLD)

		var edit_style := StyleBoxFlat.new()
		edit_style.bg_color = Color(0.08, 0.06, 0.04, 0.4)
		edit_style.set_border_width_all(1)
		edit_style.border_color = Color(0.55, 0.42, 0.08, 0.25)
		edit_style.set_corner_radius_all(3)
		edit_style.set_content_margin_all(4)
		edit.add_theme_stylebox_override("normal", edit_style)
		edit.add_theme_stylebox_override("focus", edit_style)

		hbox.add_child(edit)
		_crew_name_edits.append(edit)

		_content.add_child(hbox)

	_content.add_child(_spacer(16))
	_btn.text = "Crew Ready"

func _apply_crew_names() -> void:
	print("[CREW] Applying crew names...")
	var changed := 0
	for i in _crew_name_edits.size():
		var char_idx := i + 1  # skip index 0 (leader)
		var c := game_state.characters[char_idx] as CharacterData
		var new_name := _crew_name_edits[i].text.strip_edges()
		if new_name.length() > 0:
			var old := c.char_name
			if old != new_name:
				changed += 1
			c.char_name = new_name
		print("  [CREW] %s — %s" % [c.char_name, c.class_label()])
	print("  Names updated: %d" % changed)

func _show_patrons() -> void:
	_step = Step.PATRONS
	_title.text = "Who Will Back Your Voyage?"
	_clear()
	_patron_count = 0
	print("[STEP] Patrons — presenting 4 patron candidates")

	_content.add_child(_spacer(8))

	var patrons := [
		["Jarl Eirik", "Offers a larger knarr and two fighters — for yearly tribute."],
		["The Kaupang Merchant", "Cargo hold of trade goods — for first rights to your port."],
		["The Goði", "Sacred timber and a scholar — vow to raise a hof in the new land."],
		["The Landless Warrior", "His axe-arm and two kinsmen — for a farmstead and standing."],
	]
	for i in patrons.size():
		var card := _journal_card(patrons[i][0], patrons[i][1])
		var idx := i
		card.pressed.connect(func():
			_patron_count += 1
			_make_gold_card(card)
			card.text = "✓  " + card.text
			card.disabled = true
			_btn.text = "Continue (%d chosen)" % _patron_count
			print("[PATRON] Accepted: %s (%d total)" % [patrons[idx][0], _patron_count])
		)
		_content.add_child(card)

	_content.add_child(_spacer(8))
	_btn.text = "Sail without promises"

func _show_pillars() -> void:
	_step = Step.PILLARS
	_title.text = "The High-Seat Pillars"
	_clear()
	_chosen_pillar = -1
	_pillar_btns.clear()
	print("[STEP] Pillars — 3 pillar choices")

	_content.add_child(_spacer(8))
	_content.add_child(_label(
		("Cast sacred timber overboard when land is near.\n"
		+ "Where the pillars drift ashore — there you will build your hall."),
		15, MUTED))
	_content.add_child(_spacer(12))

	var pillars := [
		["Inland Valleys", "Good grazing, sheltered slopes, fresh water."],
		["The Coast", "Fish, driftwood, and the sea-road."],
		["Sacred Headlands", "The old powers are strongest here."],
	]
	for i in pillars.size():
		var card := _journal_card(pillars[i][0], pillars[i][1])
		var idx := i
		card.pressed.connect(func():
			_chosen_pillar = idx
			_btn.disabled = false
			for j in _pillar_btns.size():
				var b := _pillar_btns[j]
				var base: String = pillars[j][0] + "\n" + pillars[j][1]
				if j == idx:
					b.text = "✦  " + base
					_make_gold_card(b)
				else:
					if b.text != base:
						b.text = base
					b.add_theme_color_override("font_color", DIM)
			print("[PILLAR] Chosen: %s (idx=%d)" % [pillars[idx][0], idx])
		)
		_content.add_child(card)
		_pillar_btns.append(card)

	_btn.text = "Choose Your Landing"
	_btn.disabled = true

func _show_ready() -> void:
	_step = Step.READY
	_title.text = "Ready to Sail"
	_clear()
	var pop := game_state.living_population() if game_state else 0
	var pillar_names := ["Inland Valleys", "The Coast", "Sacred Headlands"]
	var pillar_name: String = pillar_names[_chosen_pillar] if _chosen_pillar >= 0 else "Not yet chosen"
	print("[STEP] Ready — pop=%d, patrons=%d, pillar=%d" % [pop, _patron_count, _chosen_pillar])

	_content.add_child(_spacer(16))
	_content.add_child(_label(
		("The cargo is stowed. The fjord opens before you —\n"
		+ "grey water under a grey sky, but beyond it:\n"
		+ "a new land. A new saga."),
		17, WARM))

	# Gold divider
	_content.add_child(_spacer(12))
	_content.add_child(_divider())
	_content.add_child(_spacer(12))

	# Stat summary — clean journal format
	var make_stat_row := func(label_text: String, value_text: String):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(640, 0)

		var lab := Label.new()
		lab.text = label_text
		lab.add_theme_font_size_override("font_size", 15)
		lab.add_theme_color_override("font_color", MUTED)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lab.custom_minimum_size = Vector2(320, 0)
		row.add_child(lab)

		var val := Label.new()
		val.text = value_text
		val.add_theme_font_size_override("font_size", 15)
		val.add_theme_color_override("font_color", WARM)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size = Vector2(320, 0)
		row.add_child(val)

		_content.add_child(row)

	make_stat_row.call("Souls aboard", "%d" % pop)
	make_stat_row.call("Patron promises", "%d" % _patron_count)
	make_stat_row.call("Landing choice", pillar_name)

	_content.add_child(_spacer(20))

	_btn.text = "Set Sail — The Crossing Begins"
	_btn.disabled = false

	# Subtle pulse to draw attention
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(_btn, "modulate", Color(1.15, 1.15, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_btn, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)

func _set_sail() -> void:
	print("[STEP] Set Sail — transitioning to Act 2 (Crossing)")
	game_state.act = GameTypes.ActId.SAILING
	game_state.saga_log.append("The knarr slips from the fjord. The crossing begins.")
	print("  game_state.act = ", GameTypes.act_label(GameTypes.ActId.SAILING))
	print("  Characters: %d total, %d living"
		% [game_state.characters.size(), game_state.living_population()])
	print("  Patrons chosen: %d" % _patron_count)
	print("  Pillar chosen: %d" % _chosen_pillar)
	print("  Saga log entries: %d" % game_state.saga_log.size())
	print("=== Act 1 complete ===")
	complete_act(game_state)

# ── Action dispatcher ─────────────────────────────────────────────────────

func _on_action() -> void:
	print("[ACTION] Button pressed at step: ", Step.keys()[_step])
	match _step:
		Step.INTRO:
			print("  -> transitioning to CREW")
			_show_crew()
		Step.CREW:
			print("  -> applying crew names, transitioning to PATRONS")
			_apply_crew_names()
			_show_patrons()
		Step.PATRONS:
			print("  -> transitioning to PILLARS")
			_show_pillars()
		Step.PILLARS:
			print("  -> transitioning to READY")
			_show_ready()
		Step.READY:
			print("  -> setting sail")
			_set_sail()
