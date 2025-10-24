# res://creatures/_types/species.gd
extends Resource
class_name Species
##
## Species data stub. No control over phase regen here.
## Add fields freely; compiled by SpeciesDB.

@export var id: StringName
@export var display_name: String = ""
@export var glyph: String = "@"
@export var fg: Color = Color.WHITE
@export var plan: BodyPlan
@export var tags: Array[StringName] = []
@export var meta := {"example": 123}
