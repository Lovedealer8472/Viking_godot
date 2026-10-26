# ═══════════════════════════════════════════════════════════════════════════
# MainMenu — title screen + new-saga setup. Mirrors the browser version's
# NewSagaSetup.tsx: pick Difficulty (4), World/Realism (3), and up to 3
# High-Seat Pillars, then Set Sail. A Quick Start button skips straight to a
# Normal saga. Emits start_saga(difficulty, realism, pillars); main.gd routes
# that into NewSaga.create() + Act 1. This is the FIRST screen the game shows.
# ═══════════════════════════════════════════════════════════════════════════
class_name MainMenu
extends Control

signal start_saga(difficulty: int, realism: int, pillars: Array)  # pillars: Array[int] (RegionId)

const GOLD := Color(0.839, 0.663, 0.184)
const GOLD_BRIGHT := Color(0.95, 0.75, 0.30)
const WARM := Color(0.910, 0.863, 0.757)
const MUTED := Color(0.663, 0.592, 0.471)
const DIM := Color(0.416, 0.369, 0.282)

const MAX_PILLARS := 3
const CARD_SIZE := Vector2(440, 60)

@onready var _title_label: Label = $TitleLabel
@onready var _subtitle_label: Label = $SubtitleLabel
@onready var _panel_bg: PanelContainer = $CenterContainer/PanelBg
@onready var _difficulty_column: VBoxContainer = $CenterContainer/PanelBg/InnerVBox/ColumnsRow/DifficultyColumn
@onready var _world_column: VBoxContainer = $CenterContainer/PanelBg/InnerVBox/ColumnsRow/WorldColumn
@onready var _pillars_column: VBoxContainer = $CenterContainer/PanelBg/InnerVBox/ColumnsRow/PillarsColumn
@onready var _quick_start_btn: Button = $CenterContainer/PanelBg/InnerVBox/ActionsRow/QuickStartButton
@onready var _set_sail_btn: Button = $CenterContainer/PanelBg/InnerVBox/ActionsRow/SetSailButton

var _difficulty: int = GameTypes.Difficulty.NORMAL
var _realism: int = GameTypes.Realism.NORMAL
var _pillars: Array = [GameTypes.RegionId.VALLEY]  # Array[int] (RegionId), mirrors browser default

var _difficulty_cards: Array = []  # Array[Button]
var _world_cards: Array = []  # Array[Button]
var _pillar_cards: Array = []  # Array[Button]

# ── Static option tables (enum used as VALUE, not Dictionary key) ─────────

static func _difficulty_options() -> Array:  # Array[Dictionary]
	return [
		{"id": GameTypes.Difficulty.EASY, "name": "Easy", "desc": "Fair winds and a short crossing."},
		{"id": GameTypes.Difficulty.NORMAL, "name": "Normal", "desc": "The intended saga balance."},
		{"id": GameTypes.Difficulty.BRUTAL, "name": "Brutal", "desc": "Lean stores, hungry seas."},
		{"id": GameTypes.Difficulty.VIKING, "name": "Viking", "desc": "The sea does not bargain."},
	]

static func _realism_options() -> Array:  # Array[Dictionary]
	return [
		{"id": GameTypes.Realism.NORMAL, "name": "Historical", "desc": "Storms, hunger, and human foes."},
		{"id": GameTypes.Realism.FANTASY, "name": "Saga-Born", "desc": "Sea-wights, omens, and the restless deep."},
		{"id": GameTypes.Realism.HORROR, "name": "Draugr-Touched", "desc": "The dead walk. The sea hungers. The dark is alive."},
	]

static func _pillar_options() -> Array:  # Array[Dictionary]
	return [
		{"id": GameTypes.RegionId.VALLEY, "name": "Inland Valleys", "desc": "Good grazing, sheltered slopes, fresh water."},
		{"id": GameTypes.RegionId.COAST, "name": "The Coast", "desc": "Fish, driftwood, and the sea-road."},
		{"id": GameTypes.RegionId.HEADLAND, "name": "Sacred Headlands", "desc": "The old powers are strongest here."},
		{"id": GameTypes.RegionId.LEE_SLOPE, "name": "Lee Slopes", "desc": "Sheltered from the worst winds. Good fuel."},
	]

# ── Setup ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_apply_backdrop()
	_style_title()
	_style_panel()
	_style_action_button(_set_sail_btn)
	_style_action_button(_quick_start_btn)

	_build_difficulty_cards()
	_build_world_cards()
	_build_pillar_cards()

	_quick_start_btn.pressed.connect(_on_quick_start)
	_set_sail_btn.pressed.connect(_on_set_sail)
	_update_set_sail_state()

	if _difficulty_cards.size() > 0:
		(_difficulty_cards[0] as Button).grab_focus()

## Dimmed full-screen art behind the content, matching the ActBase pattern
## used by every act. Falls back to the flat dark ColorRect if the art
## is missing.
func _apply_backdrop() -> void:
	var path := "res://assets/art/scenes/fjord.png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)

	var dark := get_node_or_null("DarkBackground")
	if dark:
		dark.visible = false

	var bg := TextureRect.new()
	bg.name = "Backdrop"
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.modulate = Color(0.52, 0.50, 0.45)
	add_child(bg)
	move_child(bg, 0)

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.04, 0.035, 0.025, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	move_child(scrim, 1)

func _style_title() -> void:
	var f = load("res://assets/fonts/Cinzel.ttf")
	if f:
		_title_label.add_theme_font_override("font", f)
	_title_label.add_theme_font_size_override("font_size", 52)
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_constant_override("outline_size", 6)
	_title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.02, 0.9))

	_subtitle_label.add_theme_font_size_override("font_size", 17)
	_subtitle_label.add_theme_color_override("font_color", MUTED)

## Warm parchment PanelContainer with gold border — exact spec from the acts.
func _style_panel() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.11, 0.07, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.55, 0.42, 0.08, 0.4)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	_panel_bg.add_theme_stylebox_override("panel", panel_style)

func _style_action_button(btn: Button) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.20, 0.15, 0.08, 0.8)
	base.set_border_width_all(2)
	base.border_color = GOLD
	base.set_corner_radius_all(6)
	base.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", base)

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

# ── Card + heading builders ────────────────────────────────────────────────

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", GOLD)
	return l

func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", MUTED)
	return l

func _unselected_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.09, 0.06, 0.6)
	s.set_border_width_all(1)
	s.border_width_left = 4
	s.border_color = Color(0.55, 0.42, 0.08, 0.5)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6)
	s.content_margin_left = 12
	return s

func _hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.13, 0.08, 0.75)
	s.set_border_width_all(1)
	s.border_width_left = 4
	s.border_color = GOLD
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6)
	s.content_margin_left = 12
	return s

func _selected_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.18, 0.06, 0.65)
	s.set_border_width_all(1)
	s.border_width_left = 4
	s.border_color = GOLD_BRIGHT
	s.set_corner_radius_all(4)
	s.set_content_margin_all(6)
	s.content_margin_left = 12
	return s

func _card(name_text: String, desc: String) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [name_text, desc]
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", WARM)
	b.add_theme_stylebox_override("normal", _unselected_style())
	b.add_theme_stylebox_override("hover", _hover_style())
	return b

## Applies gold "chosen" tint/border, or reverts to the default parchment
## look, to a single card without touching its siblings.
func _paint_card(b: Button, base_text: String, is_selected: bool) -> void:
	if is_selected:
		b.text = "✦  " + base_text
		b.add_theme_stylebox_override("normal", _selected_style())
		b.add_theme_stylebox_override("hover", _selected_style())
		b.add_theme_color_override("font_color", GOLD)
	else:
		b.text = base_text
		b.add_theme_stylebox_override("normal", _unselected_style())
		b.add_theme_stylebox_override("hover", _hover_style())
		b.add_theme_color_override("font_color", WARM)

func _build_difficulty_cards() -> void:
	_difficulty_column.add_child(_heading("Difficulty"))
	var opts := _difficulty_options()
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var id: int = opt["id"]
		var card := _card(opt["name"], opt["desc"])
		card.pressed.connect(func(): _on_difficulty_picked(id))
		_difficulty_column.add_child(card)
		_difficulty_cards.append(card)
	_refresh_difficulty_visuals()

func _build_world_cards() -> void:
	_world_column.add_child(_heading("World"))
	var opts := _realism_options()
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var id: int = opt["id"]
		var card := _card(opt["name"], opt["desc"])
		card.pressed.connect(func(): _on_realism_picked(id))
		_world_column.add_child(card)
		_world_cards.append(card)
	_refresh_world_visuals()

func _build_pillar_cards() -> void:
	_pillars_column.add_child(_heading("High-Seat Pillars"))
	_pillars_column.add_child(_hint("Choose up to 3 regions — seeds your landing options."))
	var opts := _pillar_options()
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var id: int = opt["id"]
		var card := _card(opt["name"], opt["desc"])
		card.pressed.connect(func(): _on_pillar_toggled(id))
		_pillars_column.add_child(card)
		_pillar_cards.append(card)
	_refresh_pillar_visuals()

# ── Selection handlers ─────────────────────────────────────────────────────

func _on_difficulty_picked(id: int) -> void:
	_difficulty = id
	_refresh_difficulty_visuals()

func _on_realism_picked(id: int) -> void:
	_realism = id
	_refresh_world_visuals()

func _on_pillar_toggled(id: int) -> void:
	if _pillars.has(id):
		_pillars.erase(id)
	elif _pillars.size() < MAX_PILLARS:
		_pillars.append(id)
	# else: already at the cap and this pillar isn't chosen — ignore the
	# click (mirrors the browser's `.slice(0, 3)` behavior).
	_refresh_pillar_visuals()
	_update_set_sail_state()

func _refresh_difficulty_visuals() -> void:
	var opts := _difficulty_options()
	for i in _difficulty_cards.size():
		var b: Button = _difficulty_cards[i]
		var opt: Dictionary = opts[i]
		var base_text: String = "%s\n%s" % [opt["name"], opt["desc"]]
		_paint_card(b, base_text, opt["id"] == _difficulty)

func _refresh_world_visuals() -> void:
	var opts := _realism_options()
	for i in _world_cards.size():
		var b: Button = _world_cards[i]
		var opt: Dictionary = opts[i]
		var base_text: String = "%s\n%s" % [opt["name"], opt["desc"]]
		_paint_card(b, base_text, opt["id"] == _realism)

func _refresh_pillar_visuals() -> void:
	var opts := _pillar_options()
	for i in _pillar_cards.size():
		var b: Button = _pillar_cards[i]
		var opt: Dictionary = opts[i]
		var base_text: String = "%s\n%s" % [opt["name"], opt["desc"]]
		_paint_card(b, base_text, _pillars.has(opt["id"]))

func _update_set_sail_state() -> void:
	_set_sail_btn.disabled = _pillars.size() == 0

# ── Actions ────────────────────────────────────────────────────────────────

func _on_set_sail() -> void:
	start_saga.emit(_difficulty, _realism, _pillars.duplicate())

func _on_quick_start() -> void:
	start_saga.emit(
		GameTypes.Difficulty.NORMAL,
		GameTypes.Realism.NORMAL,
		[GameTypes.RegionId.COAST, GameTypes.RegionId.VALLEY, GameTypes.RegionId.HEADLAND]
	)
