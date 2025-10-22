extends Resource
class_name BodyPlan

@export var parts: Array[BodyPart] = []

func to_map() -> Dictionary:
	var out := {}
	for p in parts:
		out[p.name] = {
			"parent": p.parent, "coverage": p.coverage, "volume": p.volume, "vital": p.vital,
			"slot": p.slot, "core_role": p.core_role, "limb_class": p.limb_class, "group_id": p.group_id,
			"has_artery": p.has_artery, "label_hint": p.label_hint,
			"effector_kind": p.effector_kind, "effector_score": p.effector_score,
			"sensor_kind": p.sensor_kind, "sensor_score": p.sensor_score,
		}
	return out
