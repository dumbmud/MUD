extends Resource
class_name BodyPlan

@export var parts: Array[BodyPart] = []

func to_map() -> Dictionary:
	var out := {}
	for p in parts:
		out[p.name] = {
			"parent": p.parent,
			"coverage": p.coverage,
			"volume": p.volume,
			"vital": p.vital
		}
	return out
