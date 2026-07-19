# ═══════════════════════════════════════════════════════════════════════════
# Act4Settlement — settlement screen with JOURNAL UI theme.
# Warm parchment panel, gold trim, dark leather background.
# ═══════════════════════════════════════════════════════════════════════════
class_name Act4Settlement
extends ActBase

func _backdrop_texture() -> String:
	return "res://assets/art/scenes/hall.png"

const GOLD := Color(0.839, 0.663, 0.184)
const GOLD_BRIGHT := Color(0.95, 0.75, 0.30)
const WARM := Color(0.910, 0.863, 0.757)
const MUTED := Color(0.663, 0.592, 0.471)
const DIM := Color(0.416, 0.369, 0.282)
const RED := Color(0.9, 0.3, 0.2)
const GREEN := Color(0.3, 0.85, 0.3)
const BLUE := Color(0.3, 0.6, 0.9)

# ── Resource config ───────────────────────────────────────────────────────

const RESOURCE_KEYS: Array = [
	"food", "hay", "fuel", "materials", "morale", "wealth", "tools", "shelter",
]
const RESOURCE_LABELS: Dictionary = {
	"food": "Food", "hay": "Hay", "fuel": "Fuel", "materials": "Materials",
	"morale": "Morale", "wealth": "Wealth", "tools": "Tools", "shelter": "Shelter",
}
const RESOURCE_MAXES: Dictionary = {
	"food": 100.0, "hay": 60.0, "fuel": 80.0, "materials": 50.0,
	"morale": 100.0, "wealth": 30.0, "tools": 50.0, "shelter": 5.0,
}

const WEATHER_LABELS: Array = ["Fair", "Harsh", "Extreme"]
const SEASON_LABELS: Array = ["Spring", "Summer", "Autumn", "Winter"]

# ── Task list (all 17 in display order) ────────────────────────────────────

const TASK_ORDER: Array = [
	GameTypes.WeeklyTask.FORAGE, GameTypes.WeeklyTask.HUNT,
	GameTypes.WeeklyTask.FISH, GameTypes.WeeklyTask.MAKE_HAY,
	GameTypes.WeeklyTask.TEND_HERD, GameTypes.WeeklyTask.GATHER_FUEL,
	GameTypes.WeeklyTask.BUILD, GameTypes.WeeklyTask.CRAFT,
	GameTypes.WeeklyTask.SCOUT, GameTypes.WeeklyTask.SAIL_EXPLORE,
	GameTypes.WeeklyTask.VIKING_ABROAD, GameTypes.WeeklyTask.GUARD,
	GameTypes.WeeklyTask.STORYTELL, GameTypes.WeeklyTask.FEAST,
	GameTypes.WeeklyTask.REST, GameTypes.WeeklyTask.TRAIN,
	GameTypes.WeeklyTask.TEND_LAND,
]

# ── Node references ───────────────────────────────────────────────────────

@onready var _title: Label = $TitleLabel
@onready var _content: VBoxContainer = $CenterContainer/PanelBg/InnerMargin/InnerVBox/ScrollContainer/ContentVBox
@onready var _scroll: ScrollContainer = $CenterContainer/PanelBg/InnerMargin/InnerVBox/ScrollContainer
@onready var _panel: PanelContainer = $CenterContainer/PanelBg
@onready var _btn: Button = $CenterContainer/PanelBg/InnerMargin/InnerVBox/ActionHBox/ActionButton
@onready var _buildings_btn: Button = $CenterContainer/PanelBg/InnerMargin/InnerVBox/ActionHBox/BuildingsButton

# ── Stored UI references for targeted refresh ────────────────────────────

# key -> {bar, value_label}
var _resource_refs: Dictionary = {}
# Array of {hbox, option, char_id}
var _char_rows: Array = []
# Sections as VBoxContainer children of _content
var _section_herd: VBoxContainer = null
var _section_lore: VBoxContainer = null
var _section_supernatural: VBoxContainer = null
var _section_buildings: VBoxContainer = null
var _section_summary: VBoxContainer = null
# Summary log (accumulated text entries)
var _week_log_entries: Array = []
# Whether buildings panel is expanded
var _buildings_visible: bool = false


# ═══════════════════════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════════════════════

func _setup_scene() -> void:
	print("=== Act4Settlement: _setup_scene ===")
	print("  game_state assigned: ", game_state != null)

	if game_state == null:
		push_error("Act4Settlement: game_state is null — cannot render")
		return

	# ── Journal parchment panel ──
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.11, 0.07, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.55, 0.42, 0.08, 0.4)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", panel_style)

	# ── Scroll container styling (parchment interior) ──
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.10, 0.08, 0.05, 0.3)
	scroll_bg.set_border_width_all(1)
	scroll_bg.border_color = Color(0.55, 0.42, 0.08, 0.15)
	scroll_bg.set_corner_radius_all(4)
	scroll_bg.set_content_margin_all(8)
	_scroll.add_theme_stylebox_override("panel", scroll_bg)

	# Scroll bar styling
	_scroll.get_v_scroll_bar().add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	var scroll_grabber := StyleBoxFlat.new()
	scroll_grabber.bg_color = Color(0.55, 0.42, 0.08, 0.3)
	scroll_grabber.set_corner_radius_all(3)
	_scroll.get_v_scroll_bar().add_theme_stylebox_override("grabber", scroll_grabber)
	_scroll.get_v_scroll_bar().custom_minimum_size = Vector2(8, 0)

	# ── Gold-bordered action buttons ──
	_apply_button_style(_btn)
	_apply_button_style(_buildings_btn)
	_buildings_btn.text = "Buildings"

	# ── Connect signals ──
	_btn.text = "Resolve Week"
	_btn.pressed.connect(_on_resolve_week)
	_buildings_btn.pressed.connect(_toggle_buildings)

	# Debug-print initial state
	_debug_state("INITIAL STATE")

	# Build all sections
	_build_resource_section()
	_build_character_section()
	_build_herd_section()
	_build_lore_section()
	_build_supernatural_section()
	_build_summary_section()

	# Perform initial value refresh
	_refresh_resources()
	_refresh_herd()
	_refresh_lore()
	_refresh_supernatural()
	_refresh_title()

	print("=== Act4Settlement setup done ===")


# ═══════════════════════════════════════════════════════════════════════════
# Theme helpers
# ═══════════════════════════════════════════════════════════════════════════

func _apply_button_style(btn: Button) -> void:
	"""Apply journal gold-trim button style."""
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.20, 0.15, 0.08, 0.8)
	normal.set_border_width_all(2)
	normal.border_color = GOLD
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.30, 0.20, 0.10, 0.9)
	hover.set_border_width_all(2)
	hover.border_color = GOLD_BRIGHT
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.15, 0.12, 0.06, 0.6)
	disabled.set_border_width_all(2)
	disabled.border_color = DIM
	disabled.set_corner_radius_all(6)
	disabled.set_content_margin_all(8)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", WARM)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	btn.add_theme_color_override("font_disabled_color", MUTED)


# ═══════════════════════════════════════════════════════════════════════════
# Section builders — called once, create static widget structure
# ═══════════════════════════════════════════════════════════════════════════

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", GOLD)
	l.custom_minimum_size = Vector2(860, 0)
	return l


func _label(text: String, color := WARM, size := 12) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(860, 0)
	return l


func _spacer(h := 6) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _divider() -> ColorRect:
	"""Thin gold line for journal section breaks."""
	var d := ColorRect.new()
	d.custom_minimum_size = Vector2(800, 1)
	d.color = Color(0.55, 0.42, 0.08, 0.25)
	return d


func _journal_card(title: String, desc: String) -> Button:
	"""Styled journal-entry card button with border-left accent."""
	var b := Button.new()
	b.text = "%s\n%s" % [title, desc]
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(860, 72)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", WARM)

	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.12, 0.09, 0.06, 0.6)
	base.set_border_width_all(1)
	base.border_width_left = 4
	base.border_color = Color(0.55, 0.42, 0.08, 0.5)
	base.set_corner_radius_all(4)
	base.set_content_margin_all(10)
	base.content_margin_left = 14
	b.add_theme_stylebox_override("normal", base)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.13, 0.08, 0.75)
	hover.set_border_width_all(1)
	hover.border_width_left = 4
	hover.border_color = GOLD
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(10)
	hover.content_margin_left = 14
	b.add_theme_stylebox_override("hover", hover)

	return b


func _make_gold_card(b: Button) -> void:
	"""Turns a card gold — for selected/accepted items."""
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color(0.25, 0.18, 0.06, 0.65)
	gold.set_border_width_all(1)
	gold.border_width_left = 4
	gold.border_color = GOLD_BRIGHT
	gold.set_corner_radius_all(4)
	gold.set_content_margin_all(10)
	gold.content_margin_left = 14
	b.add_theme_stylebox_override("normal", gold)
	b.add_theme_stylebox_override("disabled", gold)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_disabled_color", GOLD)


# ── 1. Resources ──────────────────────────────────────────────────────────

func _build_resource_section() -> void:
	_content.add_child(_heading("— Resources —"))
	print("Building resource bars section...")

	for key in RESOURCE_KEYS:
		var hbox := HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(860, 22)
		hbox.size_flags_horizontal = SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = RESOURCE_LABELS[key]
		lbl.custom_minimum_size = Vector2(80, 0)
		lbl.add_theme_color_override("font_color", GOLD)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(lbl)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(340, 14)
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.show_percentage = false

		# Style the progress bar with journal theme
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.08, 0.06, 0.04, 0.6)
		bar_bg.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", bar_bg)

		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = GOLD
		bar_fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", bar_fill)

		hbox.add_child(bar)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size = Vector2(56, 0)
		val_lbl.add_theme_color_override("font_color", WARM)
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(val_lbl)

		_resource_refs[key] = {"bar": bar, "value": val_lbl, "hbox": hbox}
		_content.add_child(hbox)

	_content.add_child(_spacer(4))
	print("  Created ", RESOURCE_KEYS.size(), " resource bars")


# ── 2. Character assignments ──────────────────────────────────────────────

func _build_character_section() -> void:
	_content.add_child(_heading("— Character Assignments —"))
	print("Building character assignment rows...")

	var living: Array = []
	for c in game_state.characters:
		if c.alive:
			living.append(c)

	if living.is_empty():
		_content.add_child(_label("No living characters.", RED))
		print("  WARNING: no living characters!")
		_content.add_child(_spacer(4))
		return

	for c in living:
		var hbox := HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(860, 52)
		hbox.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 10)

		# Character portrait
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(40, 40)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var portrait_path := "res://assets/art/characters/%s.png" % c.id
		if ResourceLoader.exists(portrait_path):
			portrait.texture = load(portrait_path)
		hbox.add_child(portrait)

		# Character info label
		var status := ""
		if c.injured:
			status = " [INJURED]"
		var info := Label.new()
		info.text = "%s (%s)%s" % [c.char_name, GameTypes.class_name_str(c.char_class), status]
		info.custom_minimum_size = Vector2(210, 0)
		info.add_theme_color_override("font_color", RED if c.injured else WARM)
		info.add_theme_font_size_override("font_size", 11)
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(info)

		# Task dropdown
		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(220, 24)
		for t in TASK_ORDER:
			option.add_item(GameTypes.task_name(t), t)

		# Style the dropdown with journal theme
		var dd_normal := StyleBoxFlat.new()
		dd_normal.bg_color = Color(0.08, 0.06, 0.04, 0.4)
		dd_normal.set_border_width_all(1)
		dd_normal.border_color = Color(0.55, 0.42, 0.08, 0.25)
		dd_normal.set_corner_radius_all(3)
		dd_normal.set_content_margin_all(2)
		option.add_theme_stylebox_override("normal", dd_normal)
		option.add_theme_stylebox_override("focus", dd_normal)
		option.add_theme_color_override("font_color", WARM)
		option.add_theme_color_override("font_focus_color", WARM)

		# Pre-select current assignment (default FORAGE)
		var current: int = game_state.assignments.get(c.id, GameTypes.WeeklyTask.FORAGE)
		var found_idx := -1
		for i in option.item_count:
			if option.get_item_id(i) == current:
				found_idx = i
				break
		if found_idx >= 0:
			option.select(found_idx)

		option.set_meta("char_id", c.id)
		option.item_selected.connect(_on_task_selected.bind(option))
		hbox.add_child(option)

		_char_rows.append({"hbox": hbox, "option": option, "char_id": c.id})
		_content.add_child(hbox)
		print("  Row: ", c.char_name, " (", c.id, ") task=", GameTypes.task_name(current))

	_content.add_child(_spacer(4))
	print("  Created ", living.size(), " assignment rows")


func _on_task_selected(index: int, option: OptionButton) -> void:
	var char_id: String = option.get_meta("char_id")
	var task_id: int = option.get_item_id(index)
	game_state.assignments[char_id] = task_id
	print("  Assignment: ", char_id, " -> ", GameTypes.task_name(task_id))


# ── 3. Herd ────────────────────────────────────────────────────────────────

func _build_herd_section() -> void:
	_section_herd = VBoxContainer.new()
	_section_herd.custom_minimum_size = Vector2(860, 0)
	_content.add_child(_section_herd)

	# Header
	_section_herd.add_child(_heading("— Herd —"))

	# Placeholder line — refreshed later
	_section_herd.add_child(_label("Cattle: --  Sheep: --  Goats: --  Horses: --  Pigs: --  Chickens: --", MUTED, 11))
	_section_herd.add_child(_spacer(4))
	print("  Herd section built (static placeholder)")


# ── 4. Lore ────────────────────────────────────────────────────────────────

func _build_lore_section() -> void:
	_section_lore = VBoxContainer.new()
	_section_lore.custom_minimum_size = Vector2(860, 0)
	_content.add_child(_section_lore)

	_section_lore.add_child(_heading("— Lore —"))
	_section_lore.add_child(_label("Law: --  Ritual: --  Genealogy: --  Wayfinding: --  Land: --  Rune: --", MUTED, 11))
	_section_lore.add_child(_spacer(4))
	print("  Lore section built (static placeholder)")


# ── 5. Supernatural ────────────────────────────────────────────────────────

func _build_supernatural_section() -> void:
	_section_supernatural = VBoxContainer.new()
	_section_supernatural.custom_minimum_size = Vector2(860, 0)
	_content.add_child(_section_supernatural)

	_section_supernatural.add_child(_heading("— Supernatural —"))
	_section_supernatural.add_child(_label("Vaettir: --  Haunting: --  Debt: --  Draugar: --  Curses: --", MUTED, 11))
	_section_supernatural.add_child(_spacer(4))
	print("  Supernatural section built (static placeholder)")


# ── 6. Summary ─────────────────────────────────────────────────────────────

func _build_summary_section() -> void:
	_section_summary = VBoxContainer.new()
	_section_summary.custom_minimum_size = Vector2(860, 0)
	_content.add_child(_section_summary)

	_section_summary.add_child(_heading("— Week Summary —"))
	if _week_log_entries.is_empty():
		_section_summary.add_child(_label("No weeks resolved yet. Assign tasks and click Resolve Week.", DIM, 11))
	else:
		for entry in _week_log_entries:
			_section_summary.add_child(_label(entry, WARM, 11))
	_section_summary.add_child(_spacer(4))
	print("  Summary section built, ", _week_log_entries.size(), " log entries")


# ═══════════════════════════════════════════════════════════════════════════
# Refresh — update visible values from game_state
# ═══════════════════════════════════════════════════════════════════════════

func _refresh_title() -> void:
	var s: String = SEASON_LABELS[game_state.season] if game_state.season < SEASON_LABELS.size() else "?"
	var w: String = WEATHER_LABELS[game_state.weather] if game_state.weather < WEATHER_LABELS.size() else "?"
	_title.text = "Act IV — Settlement  |  Year %d, Week %d  |  %s  (%s)" % [
		game_state.year, game_state.week, s, w
	]


func _refresh_resources() -> void:
	for key in RESOURCE_KEYS:
		var refs = _resource_refs.get(key)
		if refs == null:
			continue
		var val: float = game_state.get(key)
		var max_val: float = RESOURCE_MAXES.get(key, 100.0)
		refs["bar"].value = min(val, max_val)
		refs["bar"].max_value = max_val
		refs["value"].text = "%.1f" % val

		# Color-code the bar fill
		var ratio := val / max_val if max_val > 0 else 0.0
		if ratio < 0.15:
			var fill_red := StyleBoxFlat.new()
			fill_red.bg_color = RED
			fill_red.set_corner_radius_all(3)
			refs["bar"].add_theme_stylebox_override("fill", fill_red)
		elif ratio < 0.4:
			var fill_amber := StyleBoxFlat.new()
			fill_amber.bg_color = Color(0.9, 0.7, 0.2)
			fill_amber.set_corner_radius_all(3)
			refs["bar"].add_theme_stylebox_override("fill", fill_amber)
		elif ratio > 0.75:
			var fill_green := StyleBoxFlat.new()
			fill_green.bg_color = GREEN
			fill_green.set_corner_radius_all(3)
			refs["bar"].add_theme_stylebox_override("fill", fill_green)
		else:
			var fill_gold := StyleBoxFlat.new()
			fill_gold.bg_color = GOLD
			fill_gold.set_corner_radius_all(3)
			refs["bar"].add_theme_stylebox_override("fill", fill_gold)

	print("  Resources refreshed")


func _refresh_herd() -> void:
	if _section_herd == null:
		return
	var children := _section_herd.get_children()
	if children.size() < 2:
		return
	var val_label := children[1] as Label
	if val_label == null:
		return

	var herd: Dictionary = game_state.get_herd_dict()
	var names := {
		GameTypes.AnimalType.CATTLE: "Cattle",
		GameTypes.AnimalType.SHEEP: "Sheep",
		GameTypes.AnimalType.GOATS: "Goats",
		GameTypes.AnimalType.HORSES: "Horses",
		GameTypes.AnimalType.PIGS: "Pigs",
		GameTypes.AnimalType.CHICKENS: "Chickens",
	}
	var parts: Array = []
	for animal in [GameTypes.AnimalType.CATTLE, GameTypes.AnimalType.SHEEP,
			GameTypes.AnimalType.GOATS, GameTypes.AnimalType.HORSES,
			GameTypes.AnimalType.PIGS, GameTypes.AnimalType.CHICKENS]:
		var count: int = herd.get(animal, 0)
		parts.append("%s: %d" % [names.get(animal, "?"), count])

	val_label.text = "  ".join(parts)
	val_label.add_theme_color_override("font_color", WARM)
	print("  Herd refreshed: ", val_label.text)


func _refresh_lore() -> void:
	if _section_lore == null:
		return
	var children := _section_lore.get_children()
	if children.size() < 2:
		return
	var val_label := children[1] as Label
	if val_label == null:
		return

	var branches := [
		["Law", GameTypes.LoreBranch.LAW],
		["Ritual", GameTypes.LoreBranch.RITUAL],
		["Genealogy", GameTypes.LoreBranch.GENEALOGY],
		["Wayfinding", GameTypes.LoreBranch.WAYFINDING],
		["Land", GameTypes.LoreBranch.LAND],
		["Rune", GameTypes.LoreBranch.RUNE],
	]
	var parts: Array = []
	for pair in branches:
		var val: int = game_state.get_lore(pair[1])
		parts.append("%s: %d" % [pair[0], val])

	val_label.text = "  ".join(parts)
	val_label.add_theme_color_override("font_color", WARM)
	print("  Lore refreshed: ", val_label.text)


func _refresh_supernatural() -> void:
	if _section_supernatural == null:
		return
	var children := _section_supernatural.get_children()
	if children.size() < 2:
		return
	var val_label := children[1] as Label
	if val_label == null:
		return

	var sup: Dictionary = game_state.supernatural_state
	var mood: int = SimSupernatural.get_home_vaettir_mood(sup)
	var mood_label: String = SimSupernatural.VAETTIR_MOOD_LABELS.get(mood, "Unknown")
	var haunt_stage: int = sup.get("haunting_stage", 0)
	var haunt_label: String = SimSupernatural.HAUNTING_LABELS.get(haunt_stage, "None")
	var debt: int = sup.get("burial_debt", 0)
	var draugar: bool = sup.get("draugar_active", false)
	var curse_count: int = sup.get("curse_objects", []).size()

	val_label.text = "Vaettir: %s  |  Haunting: %s  |  Debt: %d  |  Draugar: %s  |  Curses: %d" % [
		mood_label, haunt_label, debt, "ACTIVE" if draugar else "Inactive", curse_count
	]
	val_label.add_theme_color_override("font_color", WARM)

	# Color the text based on danger level
	if mood == GameTypes.VaettirMood.HOSTILE or mood == GameTypes.VaettirMood.OFFENDED:
		val_label.add_theme_color_override("font_color", RED)
	elif haunt_stage >= 3:
		val_label.add_theme_color_override("font_color", RED)
	elif debt >= 5:
		val_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))

	print("  Supernatural refreshed: ", val_label.text)


func _refresh_summary() -> void:
	if _section_summary == null:
		return
	# Remove all children
	for c in _section_summary.get_children():
		c.queue_free()

	_section_summary.add_child(_heading("— Week Summary —"))
	if _week_log_entries.is_empty():
		_section_summary.add_child(_label("No weeks resolved yet. Assign tasks and click Resolve Week.", DIM, 11))
	else:
		for entry in _week_log_entries:
			# Style the journal entry with a left-border accent
			var entry_hbox := HBoxContainer.new()
			entry_hbox.custom_minimum_size = Vector2(860, 0)

			var accent := ColorRect.new()
			accent.custom_minimum_size = Vector2(3, 0)
			accent.size_flags_vertical = SIZE_EXPAND_FILL
			accent.color = Color(0.55, 0.42, 0.08, 0.4)
			entry_hbox.add_child(accent)

			var entry_lbl := _label(entry, WARM, 11)
			entry_lbl.custom_minimum_size = Vector2(840, 0)
			entry_hbox.add_child(entry_lbl)

			_section_summary.add_child(entry_hbox)

	_section_summary.add_child(_spacer(4))
	print("  Summary refreshed, ", _week_log_entries.size(), " entries")


# ═══════════════════════════════════════════════════════════════════════════
# Buildings panel (toggle)
# ═══════════════════════════════════════════════════════════════════════════

func _toggle_buildings() -> void:
	_buildings_visible = not _buildings_visible
	print("=== Toggle Buildings: visible=", _buildings_visible)
	_buildings_btn.text = "Hide Buildings" if _buildings_visible else "Buildings"

	if _buildings_visible:
		_rebuild_buildings_panel()
	else:
		if _section_buildings != null:
			_section_buildings.queue_free()
			_section_buildings = null


func _rebuild_buildings_panel() -> void:
	# Remove old panel if exists
	if _section_buildings != null:
		_section_buildings.queue_free()

	_section_buildings = VBoxContainer.new()
	_section_buildings.custom_minimum_size = Vector2(860, 0)

	_section_buildings.add_child(_heading("— Available Buildings —"))
	print("Rebuilding buildings panel...")

	# Active project
	if not game_state.active_project.is_empty():
		var proj: Dictionary = game_state.active_project
		var b_id: int = proj.get("building_id", -1)
		var b_def: Dictionary = SimBuildings.BUILDING_DEFS.get(b_id, {})
		_section_buildings.add_child(_label("Currently building: %s (progress %d/%d)" % [
			b_def.get("name", "Unknown"),
			proj.get("progress", 0),
			b_def.get("work_required", 999),
		], GOLD, 12))
		_section_buildings.add_child(_spacer(2))

	# List available buildings
	var available: Array = SimBuildings.available_buildings(game_state)
	print("  Available buildings: ", available.size())

	if available.is_empty():
		_section_buildings.add_child(_label("All buildings have been constructed.", DIM, 11))
	else:
		for b in available:
			var err: String = SimBuildings.can_start_building(game_state, b["id"])
			var can_start: bool = err.is_empty()
			var card_color := GOLD if can_start else DIM

			# Use journal-card style for each building
			var b_card := _journal_card(
				b.get("name", "Building"),
				b.get("desc", "")
			)
			b_card.custom_minimum_size = Vector2(860, 56)
			b_card.add_theme_font_size_override("font_size", 13)

			if not can_start:
				b_card.disabled = true
				b_card.add_theme_color_override("font_color", DIM)
				b_card.add_theme_color_override("font_disabled_color", DIM)

			# Cost line (displayed below the card)
			var cost_parts: Array = []
			cost_parts.append("Work: %d" % b.get("work_required", 999))
			var up_mat: int = b.get("upfront_materials", 0)
			var up_tool: int = b.get("upfront_tools", 0)
			if up_mat > 0 or up_tool > 0:
				cost_parts.append("Upfront: %d mat%s, %d tool%s" % [
					up_mat, "s" if up_mat != 1 else "",
					up_tool, "s" if up_tool != 1 else "",
				])
			var wk_mat: int = b.get("weekly_materials", 0)
			var wk_tool: int = b.get("weekly_tools", 0)
			if wk_mat > 0 or wk_tool > 0:
				cost_parts.append("Weekly: %d mat, %d tool" % [wk_mat, wk_tool])

			var cost_line := _label("  ".join(cost_parts), DIM, 10)
			_section_buildings.add_child(b_card)

			# Bonus
			var bonus: String = b.get("bonus", "")
			if not bonus.is_empty():
				_section_buildings.add_child(_label(bonus, GREEN, 10))

			_section_buildings.add_child(cost_line)

			# Requirements / start button
			if can_start:
				var start_btn := Button.new()
				start_btn.text = "Start Project"
				start_btn.custom_minimum_size = Vector2(200, 26)
				_apply_button_style(start_btn)
				start_btn.add_theme_font_size_override("font_size", 13)
				start_btn.pressed.connect(_on_start_building.bind(b["id"]))
				_section_buildings.add_child(start_btn)
			else:
				_section_buildings.add_child(_label("Cannot start: " + err, RED, 10))

			_section_buildings.add_child(_spacer(6))

	# Insert buildings section before summary
	var insert_idx := -1
	for i in _content.get_child_count():
		if _content.get_child(i) == _section_summary:
			insert_idx = i
			break

	if insert_idx >= 0:
		_content.add_child_at(_section_buildings, insert_idx)
	else:
		# Fallback: append at end
		_content.add_child(_section_buildings)

	print("  Buildings panel rebuilt")


func _on_start_building(b_id: int) -> void:
	print("=== Start Building ===")
	print("  Building ID: ", b_id)
	var def: Dictionary = SimBuildings.BUILDING_DEFS.get(b_id, {})
	print("  Name: ", def.get("name", "Unknown"))
	var err: String = SimBuildings.can_start_building(game_state, b_id)
	if not err.is_empty():
		print("  ERROR: ", err)
		return

	SimBuildings.start_building_project(game_state, b_id)
	print("  materials now: %.0f, tools now: %.0f" % [game_state.materials, game_state.tools])
	print("  active_project: ", game_state.active_project)

	_refresh_resources()
	_rebuild_buildings_panel()
	print("=== Start Building done ===")


# ═══════════════════════════════════════════════════════════════════════════
# Resolve Week — the main gameplay action
# ═══════════════════════════════════════════════════════════════════════════

func _on_resolve_week() -> void:
	print("\n" + "=".repeat(60))
	print("=== RESOLVE WEEK — Week %d ===" % game_state.week)
	print("=".repeat(60))

	# 1. Flush assignment changes from dropdowns
	for row in _char_rows:
		var char_id: String = row["char_id"]
		var option: OptionButton = row["option"]
		var task_id: int = option.get_item_id(option.selected)
		game_state.assignments[char_id] = task_id
		print("  Assigned ", char_id, " -> ", GameTypes.task_name(task_id))

	# 2. Debug state before resolve
	print("--- State before resolve ---")
	_debug_state("PRE-RESOLVE")

	# 3. Call the sim engine
	print("--- Calling resolve_assignments ---")
	var result: Dictionary = SimWeeklyTurn.resolve_assignments(game_state)
	print("--- Resolve complete ---")

	# 4. Log results
	var summary_str: String = result.get("task_summary", "minimal gains")
	var injuries: Array = result.get("injuries", [])
	var event_id: String = game_state.pending_event_id

	print("  task_summary: ", summary_str)
	print("  injuries: ", injuries)
	print("  pending_event: ", event_id)

	# Build log entry
	var log_line := "Week %d: %s" % [game_state.week, summary_str]
	if not injuries.is_empty():
		log_line += "  |  Injured: %s" % ", ".join(injuries)
	if not event_id.is_empty():
		var event_name: String = SimEvents.find_event(event_id).get("title", event_id)
		log_line += "  |  Event: %s" % event_name
	_week_log_entries.append(log_line)
	print("  Log entry: ", log_line)

	# 5. Show event popup if there's a pending event
	var has_event := not event_id.is_empty()
	if has_event:
		_show_event_popup(event_id)
		return  # Don't advance week until event is resolved

	# 5. Check for game over / victory (after advance_week)
	SimWeeklyTurn.advance_week(game_state)
	print("--- Advance complete ---")
	
	if game_state.game_over:
		_show_ending()
		return

	# 6. Debug state after
	print("--- State after resolve+advance ---")
	_debug_state("POST-RESOLVE")

	# 7. Refresh UI
	print("--- Refreshing UI ---")
	_refresh_title()
	_refresh_resources()
	_refresh_herd()
	_refresh_lore()
	_refresh_supernatural()
	_refresh_summary()

	# Update task dropdowns for next week (injuries may have changed)
	_refresh_assignment_dropdowns()

	print("=== RESOLVE WEEK done ===")
	print("=".repeat(60) + "\n")


func _refresh_assignment_dropdowns() -> void:
	"""Update character labels to reflect new injury/status changes."""
	for row in _char_rows:
		var char_id: String = row["char_id"]
		var hbox: HBoxContainer = row["hbox"]
		# Portrait is child 0, info label is child 1
		var info_label := hbox.get_child(1) as Label
		if info_label == null:
			continue

		# Find the character
		for c in game_state.characters:
			if c.id == char_id:
				var status := ""
				if c.injured:
					status = " [INJURED]"
				info_label.text = "%s (%s)%s" % [c.char_name, GameTypes.class_name_str(c.char_class), status]
				info_label.add_theme_color_override("font_color", RED if c.injured else WARM)
				break

	print("  Assignment dropdowns refreshed")


# ═══════════════════════════════════════════════════════════════════════════
# Ending screen — shown when game_state.game_over is true
# ═══════════════════════════════════════════════════════════════════════════

func _show_ending() -> void:
	print("=== GAME ENDING: victory=%s ===" % game_state.victory)

	# Hide action buttons
	_btn.visible = false
	_buildings_btn.visible = false

	# Clear content and show ending
	for c in _content.get_children():
		c.queue_free()

	var is_victory: bool = game_state.victory

	_title.text = "The Saga Ends" if is_victory else "The Settlement is Lost"

	_content.add_child(_spacer(30))

	if is_victory:
		_content.add_child(_label("⚔ VICTORY ⚔", GOLD, 32))
		_content.add_child(_spacer(16))
		_content.add_child(_label(
			"After three hard years of wind and winter, of hunger and hope,\nthe settlement endures.\n\nThe saga of your people will be told for generations.\nSkal!",
			WARM, 16))
	else:
		_content.add_child(_label("✝ DEFEAT ✝", RED, 32))
		_content.add_child(_spacer(16))
		_content.add_child(_label(
			"The Icelandic winter claimed the last of them.\nThe settlement — the dream — is gone.\n\nBut the land remembers. The stones remember.\nPerhaps others will come.",
			MUTED, 16))

	_content.add_child(_spacer(24))
	_content.add_child(_divider())
	_content.add_child(_spacer(16))

	# Final stats
	var pop := game_state.living_population()
	var final_year := game_state.year
	var final_week := game_state.week

	var stats := [
		["Years survived", "%d" % final_year],
		["Souls remaining", "%d" % pop],
		["Standing", "%d" % game_state.standing],
		["Lore gathered", "%d" % game_state.lore_total()],
		["Buildings raised", "%d" % game_state.buildings_built.size()],
		["Saga entries", "%d" % game_state.saga_log.size()],
	]

	for pair in stats:
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = pair[0]
		lab.add_theme_font_size_override("font_size", 14)
		lab.add_theme_color_override("font_color", MUTED)
		lab.custom_minimum_size = Vector2(300, 0)
		row.add_child(lab)
		var val := Label.new()
		val.text = pair[1]
		val.add_theme_font_size_override("font_size", 14)
		val.add_theme_color_override("font_color", GOLD)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size = Vector2(300, 0)
		row.add_child(val)
		_content.add_child(row)

	_content.add_child(_spacer(20))

	# Saga log excerpt
	_content.add_child(_label("— Final Saga Entries —", GOLD, 16))
	_content.add_child(_spacer(4))
	var last_entries := game_state.saga_log.slice(max(0, game_state.saga_log.size() - 6))
	for entry in last_entries:
		_content.add_child(_label("  " + entry, MUTED, 12))

	_content.add_child(_spacer(30))
	_content.add_child(_label("Thank you for playing.", DIM, 16))


# ═══════════════════════════════════════════════════════════════════════════
# Event popup — shows artwork, description, and choices
# ═══════════════════════════════════════════════════════════════════════════

func _show_event_popup(event_id: String) -> void:
	print("=== EVENT POPUP: ", event_id, " ===")

	# Hide action buttons during event
	_btn.visible = false
	_buildings_btn.visible = false

	# Clear summary and rebuild with event content
	for c in _section_summary.get_children():
		c.queue_free()

	var event_data: Dictionary = SimEvents.find_event(event_id)
	var title: String = event_data.get("title", event_id)
	var description: String = event_data.get("text", "")

	_section_summary.add_child(_heading("— Event —"))
	_section_summary.add_child(_spacer(8))

	# Event illustration
	var art_path := "res://assets/art/events/%s.png" % event_id
	if ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.texture = load(art_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(640, 350)
		var art_container := CenterContainer.new()
		art_container.custom_minimum_size = Vector2(860, 360)
		art_container.add_child(art)
		_section_summary.add_child(art_container)
		_section_summary.add_child(_spacer(8))

	# Event title
	var title_lbl := _label(title, GOLD, 18)
	_section_summary.add_child(title_lbl)
	_section_summary.add_child(_spacer(4))

	# Event description
	var desc_lbl := _label(description, WARM, 13)
	_section_summary.add_child(desc_lbl)
	_section_summary.add_child(_spacer(12))

	# Divider
	_section_summary.add_child(_divider())
	_section_summary.add_child(_spacer(8))

	# Choice buttons
	var choices: Array = event_data.get("choices", [])
	if choices.is_empty():
		# No choices — auto-resolve
		var dismiss_btn := Button.new()
		dismiss_btn.text = "Continue"
		_apply_button_style(dismiss_btn)
		dismiss_btn.pressed.connect(_on_event_dismissed)
		_section_summary.add_child(dismiss_btn)
	else:
		_section_summary.add_child(_label("What will you do?", GOLD, 14))
		_section_summary.add_child(_spacer(4))
		for i in choices.size():
			var choice: Dictionary = choices[i]
			var choice_text: String = choice.get("text", "Option %d" % (i + 1))
			var choice_btn := Button.new()
			choice_btn.text = choice_text
			choice_btn.custom_minimum_size = Vector2(860, 40)
			_apply_button_style(choice_btn)
			var choice_idx := i
			choice_btn.pressed.connect(func(): _on_event_choice(event_id, choice_idx))
			_section_summary.add_child(choice_btn)
			_section_summary.add_child(_spacer(4))

	_section_summary.add_child(_spacer(4))


func _on_event_choice(event_id: String, choice_idx: int) -> void:
	print("=== EVENT CHOICE: ", event_id, " choice ", choice_idx, " ===")
	var event_data: Dictionary = SimEvents.find_event(event_id)
	var choices: Array = event_data.get("choices", [])
	if choice_idx >= choices.size():
		return

	var choice: Dictionary = choices[choice_idx]

	# Apply effects
	for key in choice.keys():
		if key in ["text", "saga"]:
			continue
		var delta: float = float(choice[key])
		if game_state.get(key) != null:
			game_state.set(key, game_state.get(key) + delta)
			print("  Effect: ", key, " ", "%+.1f" % delta, " → ", game_state.get(key))

	# Log saga entry
	var saga_text: String = choice.get("saga", "")
	if not saga_text.is_empty():
		game_state.saga_log.append(saga_text)
		_week_log_entries.append(saga_text)

	# Clear event
	game_state.pending_event_id = ""

	_on_event_dismissed()


func _on_event_dismissed() -> void:
	print("=== EVENT DISMISSED ===")
	# Advance the week
	SimWeeklyTurn.advance_week(game_state)

	# Restore action buttons
	_btn.visible = true
	_buildings_btn.visible = true

	# Refresh UI
	_refresh_title()
	_refresh_resources()
	_refresh_herd()
	_refresh_lore()
	_refresh_supernatural()
	_refresh_summary()
	_refresh_assignment_dropdowns()

	print("=== Event flow complete ===\n")


# ═══════════════════════════════════════════════════════════════════════════
# Debug helpers
# ═══════════════════════════════════════════════════════════════════════════

func _debug_state(label: String) -> void:
	print("--- ", label, " ---")
	print("  Week %d, Year %d, Season %s, Weather %s" % [
		game_state.week, game_state.year,
		SEASON_LABELS[game_state.season] if game_state.season < SEASON_LABELS.size() else "?",
		WEATHER_LABELS[game_state.weather] if game_state.weather < WEATHER_LABELS.size() else "?",
	])
	print("  Food: %.1f  Hay: %.1f  Fuel: %.1f  Mats: %.1f" % [
		game_state.food, game_state.hay, game_state.fuel, game_state.materials
	])
	print("  Morale: %.1f  Wealth: %.1f  Tools: %.1f  Shelter: %.1f" % [
		game_state.morale, game_state.wealth, game_state.tools, game_state.shelter
	])
	print("  Pop: %d  Standing: %d  Knowledge: %.1f" % [
		game_state.living_population(), game_state.standing, game_state.knowledge
	])
	print("  Herd total: %d" % game_state.herd_total())
	print("  Lore total: %d" % game_state.lore_total())
	print("  Buildings built: ", game_state.buildings_built)
	print("  Active project: ", game_state.active_project)
	print("  Pending event: ", game_state.pending_event_id)
	var sup: Dictionary = game_state.supernatural_state
	print("  Vaettir mood: ", SimSupernatural.get_home_vaettir_mood(sup))
	print("  Haunting stage: ", sup.get("haunting_stage", 0))
	print("  Burial debt: ", sup.get("burial_debt", 0))
	print("  Draugar: ", sup.get("draugar_active", false))
	print("  Curses: ", sup.get("curse_objects", []).size())
