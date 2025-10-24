# res://creatures/_types/actor.gd
class_name Actor
extends RefCounted
##
## Core runtime actor data. Verbs mutate this; SimManager only schedules.
## Phase model:
##   - phase_per_tick is uniform for all species (100).
##   - speed_mult scales verb *costs* (default 1.0), not regen.

# Identity / pos
var actor_id: int
var grid_pos: Vector2i

# Facing (8-way). Default faces “down” (0,1).
var facing: Vector2i = Vector2i(0, 1)

# Relation to player: -1 hostile, 0 neutral, 1 ally.
var relation_to_player: int = 0

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
var phase_per_tick: int = 100
var phase: int = 0
var speed_mult: float = 1.0

func _init(_actor_id: int, _grid_pos: Vector2i, _is_player: bool) -> void:
	actor_id = _actor_id
	grid_pos = _grid_pos
	is_player = _is_player
	relation_to_player = 1 if _is_player else -1

# ── Facing helpers ───────────────────────────────────────────────────────────

func set_facing(dir: Vector2i) -> void:
	var d := dir
	if d.x != 0: d.x = sign(d.x)
	if d.y != 0: d.y = sign(d.y)
	if d != Vector2i.ZERO:
		facing = d

func face_toward(target: Vector2i) -> void:
	set_facing(target - grid_pos)
