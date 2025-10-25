# res://creatures/_types/species.gd
extends Resource
class_name Species
##
## Species v2.1
## Minimal species asset for body compilation.
## Pure data. No time/speed. No legacy fields.

# ── Identity / visuals ───────────────────────────────────────────────────────

@export var id: StringName                      # Unique species id (e.g., &"human")
@export var display_name: String = ""           # UI name
@export var glyph: String = "@"                 # Single-character glyph
@export var fg: Color = Color.WHITE             # Glyph color

# ── Anatomy ──────────────────────────────────────────────────────────────────

@export var plan: BodyPlan                      # BodyPlan with ZONES and INTERNAL organs

# ── Tags ─────────────────────────────────────────────────────────────────────

@export var tags: Array[StringName] = []        # e.g., [&"debug"]

# ── Instance knobs (compile-through only) ────────────────────────────────────

@export var size_scale: float = 1.0             # 1.0 = human baseline. All mass/capacity derive.
@export var death_policy: Dictionary = {}       # Boolean clauses over organs/channels. Passed through.

# Example death_policy schema (data-only, not enforced here):
# {
#   "or": [
#     {"organ_destroyed": "brain"},
#     {"channel_depleted": {"name":"oxygen", "ticks":3}}
#   ]
# }
