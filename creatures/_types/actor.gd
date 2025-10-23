# res://creatures/_types/actor.gd
class_name Actor
extends RefCounted

# Identity / pos
var actor_id: int
var grid_pos: Vector2i

# Anatomy
var plan: BodyPlan = null
var plan_map: Dictionary = {}

# Zones (compiled by SpeciesDB)
var zone_labels: Dictionary = {}     # id->string
var zone_coverage: Dictionary = {}   # id->int (sum 100)
var zone_volume: Dictionary = {}     # id->int (sum 100)
var zone_organs: Dictionary = {}     # id->[StringName]
var zone_has_artery: Dictionary = {} # id->bool
var zone_eff_kind: Dictionary = {}   # id->"grasper"/"stepper"/"chewer"
var zone_eff_score: Dictionary = {}  # id->0..1
var zone_sensors: Dictionary = {}    # id->{vision:0..1}
var zone_effectors: Dictionary = {}  # id->{&"grasper":f,&"stepper":f,&"chewer":f}

# Display
var glyph: String = ""
var fg_color: Color = Color.WHITE
var is_player: bool = false

# Time / speed
var phase_per_tick: int = 20
var phase: int = 0

func _init(_actor_id: int, _grid_pos: Vector2i, _is_player: bool) -> void:
	actor_id = _actor_id
	grid_pos = _grid_pos
	is_player = _is_player
