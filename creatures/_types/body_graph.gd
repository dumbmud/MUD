class_name BodyGraph
extends Resource

@export var nodes: Array = []  # BodyNode resources
@export var links: Array = []  # BodyLink resources

func to_map() -> Dictionary:
	var m := {}
	for n in nodes:
		if n == null: continue
		m[n.id] = {
			"tissue": n.tissue,
			"integument": n.integument,
			"channels_present": n.channels_present,
			"sockets": _sockets_to_arr(n.sockets),
			"ports": _ports_to_arr(n.ports),
			"tags": _tags_to_arr(n.tags),
			"props": n.props if "props" in n else {}
		}
	return {
		"nodes": m,
		"links": _links_to_arr(links)
	}

static func _sockets_to_arr(arr) -> Array:
	var out: Array = []
	for s in arr:
		if s == null: continue
		out.append({"kind": s.kind, "params": s.params})
	return out

static func _ports_to_arr(arr) -> Array:
	var out: Array = []
	for p in arr:
		if p == null: continue
		out.append({"role": p.role, "anchor": p.anchor, "max_count": p.max_count})
	return out

static func _tags_to_arr(arr) -> Array:
	var out: Array = []
	for t in arr:
		if t == null: continue
		out.append(t)
	return out

static func _links_to_arr(arr) -> Array:
	var out: Array = []
	for e in arr:
		if e == null: continue
		out.append({"a": e.a, "b": e.b, "flow": e.flow})
	return out
