# ═══════════════════════════════════════════════════════════════════════════
# ActBase — base class for all act scenes.
# Provides act_completed signal, game_state, and a shared backdrop/scrim so
# every act sits on atmospheric art instead of a flat black void.
# ═══════════════════════════════════════════════════════════════════════════
class_name ActBase
extends Control

signal act_completed(next_state: GameState)

var game_state: GameState

func _ready() -> void:
	var bp := _backdrop_texture()
	if bp != "":
		_apply_backdrop(bp)
	_style_title()
	_setup_scene()

## Gives the act's TitleLabel the Cinzel display face in gold.
func _style_title() -> void:
	var t := get_node_or_null("TitleLabel")
	if t and t is Label:
		var f = load("res://assets/fonts/Cinzel.ttf")
		if f:
			t.add_theme_font_override("font", f)
		t.add_theme_font_size_override("font_size", 40)
		t.add_theme_color_override("font_color", Color(0.90, 0.72, 0.28))
		t.add_theme_constant_override("outline_size", 6)
		t.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.02, 0.9))

## Override in subclasses to return a res:// path to the act's backdrop art.
func _backdrop_texture() -> String:
	return ""

func _setup_scene() -> void:
	# Override in subclasses
	pass

## Places full-screen art behind the content with a dark scrim for legibility.
func _apply_backdrop(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)

	# Hide the flat dark ColorRect the scenes ship with.
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
	bg.modulate = Color(0.52, 0.50, 0.45)  # dim + slightly desaturate for mood
	add_child(bg)
	move_child(bg, 0)

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.04, 0.035, 0.025, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	move_child(scrim, 1)

func complete_act(next_state: GameState) -> void:
	act_completed.emit(next_state)
