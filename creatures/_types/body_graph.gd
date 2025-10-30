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
			"tags": n.tags
		}
	return {"nodes": m, "links": _links_to_arr(links)}

func validate() -> Dictionary:
	var errs: Array[String] = []
	var seen := {}
	for n in nodes:
		if n == null: continue
		if n.id == &"": errs.append("node with empty id")
		elif seen.has(n.id): errs.append("duplicate node id: %s" % String(n.id))
		else: seen[n.id] = true
	for e in links:
		if e == null: continue
		if !seen.has(e.a): errs.append("link a missing: %s" % String(e.a))
		if !seen.has(e.b): errs.append("link b missing: %s" % String(e.b))
	return {"ok": errs.is_empty(), "errors": errs}

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

static func _links_to_arr(arr) -> Array:
	var out: Array = []
	for e in arr:
		if e == null: continue
		out.append({"a": e.a, "b": e.b, "flow": e.flow})
	return out
