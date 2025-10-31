class_name Species
extends Resource
##
## Species v3 — BodyGraph-based. No BodyPlan, no zones.
## Pure data.

# Identity / visuals
@export var id: StringName
@export var display_name: String = ""
@export var glyph: String = "@"
@export var fg: Color = Color.WHITE

# Anatomy
@export var graph: BodyGraph            # REQUIRED

# Tags
@export var tags: Array[StringName] = []

# Instance knobs (compile-through only)
@export var size_scale: float = 1.0
@export var death_policy: Dictionary = {}
@export var body_mass_kg: float = 70.0

# Survival knobs (species-local defaults and requirements)
@export var survival: Dictionary = {}
