# res://creatures/_types/species.gd
extends Resource
class_name Species

@export var id: StringName
@export var display_name: String
@export var glyph: String = "@"
@export var fg: Color = Color.WHITE
@export var plan: BodyPlan
@export var tags: Array[StringName] = []
# Prefer phase_per_tick; support old tu_per_tick via SpeciesDB.
@export var base_stats := { "phase_per_tick": 20 }
