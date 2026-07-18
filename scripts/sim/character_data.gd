# ═══════════════════════════════════════════════════════════════════════════
# CharacterData — Godot Resource for a single character.
# ═══════════════════════════════════════════════════════════════════════════
class_name CharacterData
extends Resource

@export var id: String = ""
@export var char_name: String = ""
@export var char_class: int = GameTypes.CharacterClass.WORKER
@export var age: int = 25
@export var strength: int = 2
@export var resilience: int = 2
@export var willpower: int = 2
@export var intelligence: int = 2
@export var traits: Array = []  # Array[String]
@export var hidden_traits: Array = []  # Array[String]
@export var alive: bool = true
@export var injured: bool = false
@export var is_child: bool = false
@export var loyalty: int = 80
@export var portrait_path: String = ""

func class_label() -> String:
	return GameTypes.class_name_str(char_class)
