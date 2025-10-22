class_name Actor
extends RefCounted

var actor_id: int
var grid_pos: Vector2i
var plan: BodyPlan        # optional now, useful later
var plan_map: Dictionary = {}


# Display (set by SpeciesDB)
var glyph: String = ""
var fg_color: Color = Color.WHITE
var is_player: bool = false

# Time / speed (speed set by SpeciesDB)
var tu_per_tick: int = 20
var energy_tu: int = 0

# Action state
var is_waiting: bool = false
var ready_at_tick: int = 0
var pending_dir: Vector2i = Vector2i.ZERO

func _init(_actor_id: int, _grid_pos: Vector2i, _is_player: bool) -> void:
	actor_id = _actor_id
	grid_pos = _grid_pos
	is_player = _is_player
