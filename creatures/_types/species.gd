extends Resource
class_name Species

@export var id: StringName
@export var display_name: String
@export var glyph: String = "@"
@export var fg: Color = Color.WHITE
@export var plan: BodyPlan
@export var tags: Array[StringName] = []
@export var base_stats := { "tu_per_tick": 20 }  # free-form numbers
