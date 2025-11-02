# res://core/equipment/equipment_item.gd
class_name EquipmentItem
extends Resource
##
## Minimal, species-agnostic equipment definition.

@export var id: StringName
@export var name: String = ""
@export var mass_kg: float = 0.0

# Drape lane (actor-level)
@export var is_drape: bool = false
@export var drape_cost: int = 0           # 0 if not drape
@export var drape_kind: String = ""       # "cloak" | "backpack" | "quiver" | "pouch" | 

# Body-bound lane (per-node layers)
@export var soft_units: int = 0           # 0..5 typical
@export var is_rigid: bool = false

# Coverage selectors (only used if !is_drape)
# - "id:<node_id>"
# - "glob:<glob_like_pattern>"      e.g., glob:upper_leg.*
# - "tag:<node_tag>"                e.g., tag:core
@export var coverage: Array[String] = []

# Fit checks: exact counts by selector (prevents pants on horses)
# e.g., { "id:pelvis":1, "glob:upper_leg.*":2, "glob:lower_leg.*":2 }
@export var fit_shape: Dictionary = {}

# Optional protection deltas (applied as integument overlays later)
@export var integument_delta: Dictionary = {}  # {"cut":0.1, "pierce":0.0, }
