# res://creatures/_types/body_part.gd
extends Resource
class_name BodyPart
##
## BodyPart v2.1 (species-agnostic)
## One resource type used for both targetable ZONES and INTERNAL organs.
## Clean schema. No arteries. No legacy fields.

# ── Identity / hierarchy (optional) ──────────────────────────────────────────

@export var name: StringName                      # Unique id within a BodyPlan
@export var parent: StringName = &""              # Optional logical parent for tools/visualization

# ── Role selector ────────────────────────────────────────────────────────────
# slot decides which field set is relevant.
# - "zone": targetable body region shown in VATS-style UI.
# - "internal": non-targetable organ hosted inside a zone; only hittable if the zone is pierced.

@export var slot: StringName = &"zone"            # &"zone" | &"internal"

# ── ZONE FIELDS (when slot == "zone") ────────────────────────────────────────
# Coarse targeting groups match UI buckets. Side is L/R/C.
# Coverage/Volume are normalized per species to sum 100%.

@export var group: StringName = &""               # e.g., &"head",&"torso",&"arm",&"leg",&"wing",&"tail",&"stinger",&"special"
@export var side: StringName = &"C"               # &"L" | &"R" | &"C" (center/none)

@export_range(0, 100) var coverage_pct: int = 0   # Contribution to hit weighting within the species (sum 100)
@export_range(0, 100) var volume_pct: int = 0     # Relative physical volume within the species (sum 100)

# Optional human-readable override for UI labels. If empty, label is "left/right <group>".
@export var label_hint: String = ""

# Surface layers from outer→inner. Each element is a Dictionary with keys:
# {
#   "kind": StringName,           # e.g., &"skin",&"fat",&"muscle",&"bone",&"chitin",&"scale",&"shell"
#   "thickness_pct": int,         # 0..100 percent of this zone's radial thickness
#   "rigid": bool,                # true for bone/ribcage/shell-like protection
#   "resist": {                   # minimal resistance set for future damage math
#     "pierce": float,            # baseline >0
#     "cut": float,
#     "blunt": float
#   }
# }
@export var layers: Array = []                    # Array[Dictionary] per the shape above

# Effectors enable verbs. Keys are tightly controlled engine tags.
# Recognized now: &"locomotor", &"manipulator", &"ingestor"
# Values are float scores (0..1) indicating relative capacity at this zone.
@export var effectors: Dictionary = {}            # Dictionary[StringName, float]

# Sensors enable perception systems. Keys are controlled engine tags.
# Recognized now: &"sight", &"hearing", &"scent"
# Each maps to a Dictionary of parameters:
# { "range": float, "fov_deg": float, "acuity": float, "night": float, "tags": Array[StringName] }
@export var sensors: Dictionary = {}              # Dictionary[StringName, Dictionary]

# ── ORGAN FIELDS (when slot == "internal") ───────────────────────────────────
# Functional internals hosted inside a zone. Not directly targetable.

@export var kind: StringName = &""                # &"vital_core"|&"pump"|&"gas_exchange"|&"digestive"|&"filter"|&"storage"|&"support"
@export var host_zone_id: StringName = &""        # Name of the zone BodyPart this organ lives in
@export var vital: bool = false                   # Many allowed; death rules live in species death_policy

# Channel wiring for survival systems. Passed through as-is.
# Example (human lungs):
#   { "oxygen": { "produce": 10.0, "capacity": 100.0 } }
# Example (human heart):
#   { "oxygen": { "gate": 1.0 } }
# Example (human brain):
#   { "oxygen": { "consume": 5.0 }, "sleep": { "consume": 1.0 } }
# Example (human blood pool):
#   { "fluid":  { "capacity": 100.0 } }
@export var channels: Dictionary = {}             # Dictionary[StringName, Dictionary]

# ── Helpers ──────────────────────────────────────────────────────────────────

func is_zone() -> bool:
	return slot == &"zone"

func is_internal() -> bool:
	return slot == &"internal"
