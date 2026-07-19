# ═══════════════════════════════════════════════════════════════════════════
# Act 3 — Landfall. The knarr reaches Iceland's shores.
# Steps: Sight Land → Scout → Name Settlement → Begin Settlement
# ═══════════════════════════════════════════════════════════════════════════
class_name Act3Landfall
extends ActBase

func _backdrop_texture() -> String:
	return "res://assets/art/scenes/landfall.png"

const GOLD := Color(0.839, 0.663, 0.184)
const GOLD_BRIGHT := Color(0.95, 0.75, 0.30)
const WARM := Color(0.910, 0.863, 0.757)
const MUTED := Color(0.663, 0.592, 0.471)
const DIM := Color(0.416, 0.369, 0.282)
const RED := Color(0.749, 0.251, 0.145)
const GREEN := Color(0.451, 0.714, 0.275)

enum Step { SIGHT_LAND, SCOUT, NAME_PLACE, READY }

var _step := Step.SIGHT_LAND
var _settlement_name: String = ""
var _chosen_site: String = ""

@onready var _title: Label = $TitleLabel
@onready var _content: VBoxContainer = $CenterContainer/PanelBg/InnerMargin/InnerVBox/ContentVBox
@onready var _btn: Button = $CenterContainer/PanelBg/InnerMargin/InnerVBox/ActionButton
@onready var _name_input: LineEdit = $CenterContainer/PanelBg/InnerMargin/InnerVBox/NameInput

# Possible landing sites based on pillar choices from Act 1
const SITES := {
	"Inland Valleys": "Sheltered valleys with fresh water and good grazing — the pillars drifted into a green fold between two mountains.",
	"The Coast": "A wide bay open to the sea-road — driftwood heaped on the shore, seabirds wheeling overhead.",
	"Sacred Headlands": "Dark cliffs rise above the shore. The old powers stir here. The pillars came to rest at the foot of an ancient stone.",
}

var _site_names := ["Inland Valleys", "The Coast", "Sacred Headlands"]


# ── Setup ─────────────────────────────────────────────────────────────────

func _setup_scene() -> void:
	print("=== Act 3 — Landfall starting ===")

	_btn.pressed.connect(_on_action)
	_name_input.visible = false
	_name_input.text_changed.connect(_on_name_changed)

	# Warm parchment journal panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.11, 0.07, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.55, 0.42, 0.08, 0.4)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	$CenterContainer/PanelBg.add_theme_stylebox_override("panel", panel_style)

	# Gold-bordered action button
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

	_btn.add_theme_color_override("font_color", WARM)
	_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	_btn.add_theme_color_override("font_disabled_color", MUTED)

	# Style name input
	var edit_style := StyleBoxFlat.new()
	edit_style.bg_color = Color(0.08, 0.06, 0.04, 0.4)
	edit_style.set_border_width_all(1)
	edit_style.border_color = Color(0.55, 0.42, 0.08, 0.25)
	edit_style.set_corner_radius_all(3)
	edit_style.set_content_margin_all(4)
	_name_input.add_theme_stylebox_override("normal", edit_style)
	_name_input.add_theme_color_override("font_color", WARM)
	_name_input.add_theme_color_override("caret_color", GOLD)

	# Determine site based on region or default to coast
	if game_state.site_id == "estuary_meadow":
		_chosen_site = "The Coast"
	elif game_state.site_id == "inland_valleys":
		_chosen_site = "Inland Valleys"
	elif game_state.site_id == "sacred_headlands":
		_chosen_site = "Sacred Headlands"
	else:
		_chosen_site = "The Coast"

	_show_sight_land()


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

func _spacer(h := 12) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.custom_minimum_size = Vector2(800, 1)
	d.color = Color(0.55, 0.42, 0.08, 0.25)
	return d

func _portrait_for(char: CharacterData) -> TextureRect:
	var p := TextureRect.new()
	p.custom_minimum_size = Vector2(36, 36)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://assets/art/characters/%s.png" % char.id
	if ResourceLoader.exists(path):
		p.texture = load(path)
	return p


# ── Steps ─────────────────────────────────────────────────────────────────

func _show_sight_land() -> void:
	_step = Step.SIGHT_LAND
	_title.text = "Act III — Landfall"
	_clear()
	_name_input.visible = false

	var pop := game_state.living_population()
	var survivors := []
	for c in game_state.characters:
		if c.alive:
			survivors.append(c)

	_content.add_child(_spacer(16))
	_content.add_child(_label(
		"After weeks at sea — through storms and stillness,\nthrough hunger and hope — a dark line appears on the horizon.\n\nIt grows. Becomes cliffs. Becomes land.\n\nIceland.",
		16, WARM))
	_content.add_child(_spacer(12))
	_content.add_child(_divider())
	_content.add_child(_spacer(12))

	var status := "The knarr holds. %d souls still draw breath." % pop
	if game_state.ship_integrity < 30:
		status += "\nThe hull groans — she barely held together."
	if game_state.ship_supplies < 20:
		status += "\nThe last of the provisions are gone. You arrive hungry."

	_content.add_child(_label(status, 13, MUTED))
	_content.add_child(_spacer(16))

	# Crew portrait row
	var crew_hbox := HBoxContainer.new()
	crew_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	crew_hbox.add_theme_constant_override("separation", 8)
	for c in survivors:
		crew_hbox.add_child(_portrait_for(c))
	_content.add_child(crew_hbox)
	_content.add_child(_spacer(4))
	var crew_names: Array = []
	for c in survivors:
		crew_names.append(c.char_name)
	_content.add_child(_label(", ".join(crew_names), 12, GOLD))

	_content.add_child(_spacer(16))
	_btn.text = "Scout the Landing Site"


func _show_scout() -> void:
	_step = Step.SCOUT
	_title.text = "The Landing Site"
	_clear()
	_name_input.visible = false

	var site_desc: String = SITES.get(_chosen_site, SITES["The Coast"])

	_content.add_child(_spacer(12))
	_content.add_child(_label(_chosen_site, 20, GOLD))
	_content.add_child(_spacer(8))
	_content.add_child(_label(site_desc, 14, WARM))
	_content.add_child(_spacer(12))

	# Show discovered regions
	_content.add_child(_divider())
	_content.add_child(_spacer(8))
	_content.add_child(_label("What your scouts found:", 14, GOLD))
	_content.add_child(_spacer(4))

	var region_names := {
		GameTypes.RegionId.COAST: "Coastal waters — fish and driftwood",
		GameTypes.RegionId.VALLEY: "Sheltered valley — good grazing",
		GameTypes.RegionId.HEADLAND: "High headland — a vantage point",
	}
	for rid in game_state.discovered_regions:
		var name: String = region_names.get(rid, "Unknown region")
		_content.add_child(_label("  • %s" % name, 12, MUTED))

	_content.add_child(_spacer(16))
	_btn.text = "Name This Place"


func _show_name_place() -> void:
	_step = Step.NAME_PLACE
	_title.text = "Name Your Settlement"
	_clear()
	_name_input.visible = true
	_name_input.text = ""
	_name_input.placeholder_text = "Enter a name for your settlement..."
	_name_input.grab_focus()

	_content.add_child(_spacer(20))
	_content.add_child(_label(
		"What will this place be called?\n\nA name is power. A name is memory.\nLet the sagas remember it.",
		15, WARM))
	_content.add_child(_spacer(16))
	_content.add_child(_label("", 8))  # spacer for the name input below

	_btn.text = "Name It"
	_btn.disabled = true


func _on_name_changed(new_text: String) -> void:
	_settlement_name = new_text.strip_edges()
	_btn.disabled = _settlement_name.length() < 2


func _show_ready() -> void:
	_step = Step.READY
	_title.text = "A New Land"
	_clear()
	_name_input.visible = false

	var pop := game_state.living_population()

	_content.add_child(_spacer(16))
	_content.add_child(_label(
		"%s stands at the edge of a new world.\n\n%d souls. A knarr beached on a black-sand shore.\nThe saga of this land begins now." % [_settlement_name, pop],
		16, WARM))

	_content.add_child(_spacer(16))
	_content.add_child(_divider())
	_content.add_child(_spacer(16))

	# Summary stats
	var make_stat := func(lbl: String, val: String):
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = lbl
		lab.add_theme_font_size_override("font_size", 14)
		lab.add_theme_color_override("font_color", MUTED)
		lab.custom_minimum_size = Vector2(300, 0)
		row.add_child(lab)
		var v := Label.new()
		v.text = val
		v.add_theme_font_size_override("font_size", 14)
		v.add_theme_color_override("font_color", WARM)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size = Vector2(300, 0)
		row.add_child(v)
		_content.add_child(row)

	make_stat.call("Settlement", _settlement_name)
	make_stat.call("Landing site", _chosen_site)
	make_stat.call("Survivors", "%d souls" % pop)
	make_stat.call("Ship condition", "%.0f%%" % game_state.ship_integrity)

	_content.add_child(_spacer(20))

	_btn.text = "Begin the Settlement"
	_btn.disabled = false

	# Pulsing button
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(_btn, "modulate", Color(1.15, 1.15, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_btn, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)


func _begin_settlement() -> void:
	print("=== Landfall complete — transitioning to Act 4 ===")
	game_state.act = GameTypes.ActId.SETTLEMENT

	# Initial settlement resources from the ship
	game_state.food = maxf(20.0, game_state.ship_supplies * 0.4)
	game_state.materials = maxf(10.0, game_state.ship_integrity * 0.15)
	game_state.morale = clampf(game_state.ship_morale * 0.8, 30.0, 90.0)
	game_state.fuel = 15.0
	game_state.tools = maxf(10.0, game_state.tools)

	# Starting herd from the ship
	game_state.cattle = 1
	game_state.sheep = 4
	game_state.goats = 2
	game_state.horses = 1

	game_state.saga_log.append("%s sails into the fjord. The settlement of %s begins." % [
		game_state.characters[0].char_name if game_state.characters.size() > 0 else "The leader",
		_settlement_name
	])

	print("  Food: %.1f  Materials: %.1f  Morale: %.1f" % [game_state.food, game_state.materials, game_state.morale])
	print("  Settlement name: ", _settlement_name)
	print("  Saga log entries: ", game_state.saga_log.size())
	print("=== Act 3 complete ===")

	complete_act(game_state)


# ── Action dispatcher ─────────────────────────────────────────────────────

func _on_action() -> void:
	print("[ACTION] Landfall step: ", Step.keys()[_step])
	match _step:
		Step.SIGHT_LAND:
			_show_scout()
		Step.SCOUT:
			_show_name_place()
		Step.NAME_PLACE:
			if _settlement_name.length() >= 2:
				_show_ready()
		Step.READY:
			_begin_settlement()
