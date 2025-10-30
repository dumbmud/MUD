# res://creatures/_types/body_plan.gd
class_name BodyPlan
extends Resource
##
## BodyPlan v2.1
## Container for BodyPart resources (targetable ZONES and INTERNAL organs).
## Pure data. No arteries. Species-agnostic.

@export var parts: Array[BodyPart] = []

# ── Queries ───────────────────────────────────────────────────────────────────

func zones() -> Array[BodyPart]:
	# Returns BodyParts with slot=="zone".
	var out: Array[BodyPart] = []
	for p in parts:
		if p != null and p.slot == &"zone":
			out.append(p)
	return out

func organs() -> Array[BodyPart]:
	# Returns BodyParts with slot=="internal".
	var out: Array[BodyPart] = []
	for p in parts:
		if p != null and p.slot == &"internal":
			out.append(p)
	return out

func get_zone_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in parts:
		if p != null and p.slot == &"zone":
			out.append(p.name)
	return out

func get_internal_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in parts:
		if p != null and p.slot == &"internal":
			out.append(p.name)
	return out

# ── Debug/Introspection map ───────────────────────────────────────────────────
# Used by SpeciesDB to stash a baked, human-readable mirror on Actor.plan_map.
# Keys and shapes match BodyPart v2.1. No behavior inferred from this.

func to_map() -> Dictionary:
	var out: Dictionary = {}
	for p in parts:
		if p == null:
			continue
		if p.slot == &"zone":
			out[p.name] = {
				"parent": p.parent,
				"slot": p.slot,
				"group": p.group,
				"side": p.side,
				"coverage_pct": p.coverage_pct,
				"volume_pct": p.volume_pct,
				"label_hint": p.label_hint,
				"layers": p.layers,           # Array[Dictionary]
				"effectors": p.effectors,     # Dictionary[StringName,float]
				"sensors": p.sensors          # Dictionary[StringName,Dictionary]
			}
		elif p.slot == &"internal":
			out[p.name] = {
				"parent": p.parent,
				"slot": p.slot,
				"kind": p.kind,
				"host_zone_id": p.host_zone_id,
				"vital": p.vital,
				"channels": p.channels        # Dictionary[StringName,Dictionary]
			}
		else:
			# Unknown slot: include only identity for debugging.
			out[p.name] = {
				"parent": p.parent,
				"slot": p.slot
			}
	return out
