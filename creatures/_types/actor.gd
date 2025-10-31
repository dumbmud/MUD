class_name Actor
extends RefCounted
##
## Actor — BodyGraph era. No zone_* fields. No organs_*.
## Stamina is a pool dict.

var species_id: StringName = &""
var tags: Array[StringName] = []           # species tags copied from BodyDB
var death_policy: Dictionary = {}          # species death policy
var survival_defaults: Dictionary = {}     # species survival overrides
var survival: Dictionary = {}              # runtime survival buffers (Survival.init_for fills)
var statuses: Dictionary = {}              # active status flags {id: bool}

# Identity / position
var actor_id: int
var grid_pos: Vector2i
var facing: Vector2i = Vector2i(0, 1)
var relation_to_player: int = 0

# Body / physiology
var controller_ref: StringName = &"controller0"
var reserve_mass: float = 0.0
var mass_scalar: float = 1.0

var body: Dictionary = { "nodes": {}, "links": [] }    # baked BodyGraph dicts
var capacities: Dictionary = {                         # Phase 3 fills real values
	"neuro":0.0,"circ":0.0,"resp":0.0,"load":0.0,"manip":0.0,"sense":{},"thermo":{},"mobility":{}
}

# Stamina / gait
var stamina: Dictionary = {"value": 100.0, "max": 100.0}
var gait: int = 1  # 0..3

# Instance knobs / death policy
var size_scale: float = 1.0
var mass_kg: float = 0.0

# Display
var glyph: String = ""
var fg_color: Color = Color.WHITE
var is_player: bool = false

# Time budget
var phase: int = 0

func _init(_actor_id: int, _grid_pos: Vector2i, _is_player: bool) -> void:
	actor_id = _actor_id
	grid_pos = _grid_pos
	is_player = _is_player
	relation_to_player = 1 if _is_player else -1

func set_facing(dir: Vector2i) -> void:
	var d := dir
	if d.x != 0: d.x = sign(d.x)
	if d.y != 0: d.y = sign(d.y)
	if d != Vector2i.ZERO:
		facing = d

func face_toward(target: Vector2i) -> void:
	set_facing(target - grid_pos)
