# ═══════════════════════════════════════════════════════════════════════════
# ActBase — base class for all act scenes.
# Provides the act_completed signal and game_state reference.
# ═══════════════════════════════════════════════════════════════════════════
class_name ActBase
extends Control

signal act_completed(next_state: GameState)

var game_state: GameState

func _ready() -> void:
	_setup_scene()

func _setup_scene() -> void:
	# Override in subclasses
	pass

func complete_act(next_state: GameState) -> void:
	act_completed.emit(next_state)
