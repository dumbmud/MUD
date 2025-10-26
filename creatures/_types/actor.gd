# res://creatures/_types/actor.gd
class_name Actor
extends RefCounted
##
## Actor
## Core runtime actor data for the scheduler and verbs.
## Species data is compiled by SpeciesDB and copied here via SpeciesDB.apply_to().
## No time/speed tweaks. No arteries. No legacy fields.

# ── Identity / position ──────────────────────────────────────────────────────
var actor_id: int
var grid_pos: Vector2i

# Facing (8-way). Default faces “down” (0,1).
var facing: Vector2i = Vector2i(0, 1)

# Relation to player: -1 hostile, 0 neutral, 1 ally.
var relation_to_player: int = 0

# ── Anatomy source assets ────────────────────────────────────────────────────
var plan: BodyPlan = null              # BodyPlan asset reference (zones + internal organs)
var plan_map: Dictionary = {}          # Debug/introspection map from BodyPlan.to_map()

# ── Zones (compiled) ─────────────────────────────────────────────────────────
# Keys are zone ids (StringName).
var zone_labels: Dictionary = {}       # id -> String (UI/debug label)
var zone_coverage: Dictionary = {}     # id -> int (normalized; species sum = 100)
var zone_volume: Dictionary = {}       # id -> int (normalized; species sum = 100)
var zone_layers: Dictionary = {}       # id -> Array[Dictionary] (ordered outer→inner)
var zone_effectors: Dictionary = {}    # id -> Dictionary[StringName,float] (e.g., locomotor/manipulator/ingestor)
var zone_sensors: Dictionary = {}      # id -> Dictionary[StringName,Dictionary] (e.g., sight/hearing/scent params)

# ── Organs (compiled) ────────────────────────────────────────────────────────
# organ dict shape: { id, kind, host_zone, vital:bool, channels:Dictionary }
var organs_by_zone: Dictionary = {}    # zone_id -> Array[organ_id]
var organs_all: Dictionary = {}        # organ_id -> Dictionary
var vital_organs: Array[StringName] = []

# ── Targeting (compiled) ─────────────────────────────────────────────────────
# Canonical coarse labels: head, torso, left_arm, right_arm, left_leg, right_leg, plus species-defined extras.
var targeting_index: Dictionary = {}   # label -> Array[zone_id]

# ── Instance knobs (compile-through) ─────────────────────────────────────────
var size_scale: float = 1.0            # 1.0 = human baseline
var death_policy: Dictionary = {}      # Boolean clauses over organs/channels (data only)

# ── Display ──────────────────────────────────────────────────────────────────
var glyph: String = ""
var fg_color: Color = Color.WHITE
var is_player: bool = false

# ── Time / speed ─────────────────────────────────────────────────────────────
# Per-tick budget is a global constant (100). Actors track only current phase.
var phase: int = 0

# ── Ctor ─────────────────────────────────────────────────────────────────────
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
