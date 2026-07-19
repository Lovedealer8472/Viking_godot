# ═══════════════════════════════════════════════════════════════════════════
# GameTheme — autoload. Builds a cohesive "Longhouse Hearth" Theme in code and
# applies it to the SceneTree root so every Control inherits saga-grade
# typography, colour, and panel/button styling.
# ═══════════════════════════════════════════════════════════════════════════
extends Node

const BODY_FONT := "res://assets/fonts/EBGaramond.ttf"
const DISPLAY_FONT := "res://assets/fonts/Cinzel.ttf"

const GOLD := Color(0.84, 0.66, 0.18)
const GOLD_BRIGHT := Color(0.97, 0.80, 0.36)
const WARM := Color(0.93, 0.89, 0.80)
const MUTED := Color(0.70, 0.63, 0.50)

func _ready() -> void:
	var theme := Theme.new()

	var body := load(BODY_FONT)
	if body:
		theme.default_font = body
	theme.default_font_size = 19

	theme.set_color("font_color", "Label", WARM)

	# Buttons
	theme.set_stylebox("normal", "Button", _btn(Color(0.17, 0.13, 0.07, 0.88), GOLD.darkened(0.15)))
	theme.set_stylebox("hover", "Button", _btn(Color(0.25, 0.18, 0.09, 0.94), GOLD_BRIGHT))
	theme.set_stylebox("pressed", "Button", _btn(Color(0.12, 0.09, 0.05, 0.96), GOLD))
	theme.set_stylebox("disabled", "Button", _btn(Color(0.12, 0.10, 0.06, 0.55), Color(0.35, 0.30, 0.22)))
	theme.set_color("font_color", "Button", WARM)
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.96, 0.86))
	theme.set_color("font_pressed_color", "Button", GOLD_BRIGHT)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_font_size("font_size", "Button", 18)

	# Panels
	var panel := _panel()
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	# Inputs
	theme.set_stylebox("normal", "LineEdit", _input_box(Color(0.55, 0.42, 0.10, 0.4)))
	theme.set_stylebox("focus", "LineEdit", _input_box(GOLD))
	theme.set_color("font_color", "LineEdit", WARM)
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)

	# Dropdowns
	theme.set_stylebox("normal", "OptionButton", _btn(Color(0.15, 0.11, 0.07, 0.9), GOLD.darkened(0.2)))
	theme.set_stylebox("hover", "OptionButton", _btn(Color(0.21, 0.15, 0.09, 0.95), GOLD))
	theme.set_stylebox("pressed", "OptionButton", _btn(Color(0.12, 0.09, 0.05, 0.95), GOLD))
	theme.set_color("font_color", "OptionButton", WARM)

	# Title type variation — Cinzel display caps in gold.
	var disp := load(DISPLAY_FONT)
	theme.set_type_variation("Title", "Label")
	if disp:
		theme.set_font("font", "Title", disp)
	theme.set_font_size("font_size", "Title", 42)
	theme.set_color("font_color", "Title", GOLD)

	# Heading variation — smaller Cinzel for section headers.
	theme.set_type_variation("Heading", "Label")
	if disp:
		theme.set_font("font", "Heading", disp)
	theme.set_font_size("font_size", "Heading", 22)
	theme.set_color("font_color", "Heading", GOLD)

	# Dark text outlines so type stays legible over busy tapestry backdrops.
	var outline := Color(0.03, 0.025, 0.02, 0.9)
	theme.set_color("font_outline_color", "Label", outline)
	theme.set_constant("outline_size", "Label", 5)
	theme.set_color("font_outline_color", "Button", outline)
	theme.set_constant("outline_size", "Button", 4)
	theme.set_color("font_outline_color", "Title", outline)
	theme.set_constant("outline_size", "Title", 6)
	theme.set_color("font_outline_color", "Heading", outline)
	theme.set_constant("outline_size", "Heading", 5)

	get_tree().root.theme = theme

func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(1)
	s.border_color = border
	s.set_corner_radius_all(5)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 9.0
	s.content_margin_bottom = 9.0
	return s

func _panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.08, 0.05, 0.84)
	s.set_border_width_all(1)
	s.border_color = Color(0.55, 0.42, 0.10, 0.55)
	s.set_corner_radius_all(8)
	s.content_margin_left = 22.0
	s.content_margin_right = 22.0
	s.content_margin_top = 18.0
	s.content_margin_bottom = 18.0
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 14
	return s

func _input_box(border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.05, 0.03, 0.6)
	s.set_border_width_all(1)
	s.border_color = border
	s.set_corner_radius_all(4)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s
