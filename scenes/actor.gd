class_name Actor
extends RefCounted

var actor_id: int
var grid_pos: Vector2i
var plan: BodyPlan        # optional now, useful later
var plan_map: Dictionary = {}

# in Actor.gd
var zone_labels: Dictionary = {}     # id->string
var zone_coverage: Dictionary = {}   # id->int (sum 100)
var zone_volume: Dictionary = {}     # id->int (sum 100)
var zone_organs: Dictionary = {}     # id->[StringName]
var zone_has_artery: Dictionary = {} # id->bool
var zone_eff_kind: Dictionary = {}   # id->"grasper"/"stepper"/"chewer"
var zone_eff_score: Dictionary = {}  # id->0..1
var zone_sensors: Dictionary = {}    # id->{vision:0..1}
var zone_effectors: Dictionary = {}  # id->{&"grasper":f,&"stepper":f,&"chewer":f}

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
