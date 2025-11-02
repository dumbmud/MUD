# res://core/equipment/equipment_api.gd
class_name EquipmentAPI
extends Node
##
## No-UI equipment engine: body-bound layers + drape rack.

# ---------------- Actor bootstrap ----------------

static func prepare_actor(actor) -> void:
	# Ensure per-node and drape structures exist and reflect current body.
	if actor == null or not "body" in actor:
		return
	if not ("equipment_nodes" in actor):
		actor.equipment_nodes = {}       # node_id -> {"soft_used":int,"has_rigid":bool,"soft_cap":int,"rigid_cap":int,"layers":Array}
	if not ("equipment_drape" in actor):
		actor.equipment_drape = []       # Array of {"item_id":StringName,"cost":int,"kind":String}
	if not ("equipment_drape_cap" in actor):
		actor.equipment_drape_cap = 5
	if not ("equipment_drape_used" in actor):
		actor.equipment_drape_used = 0

	var nodes_dict: Dictionary = actor.body.get("nodes", {}) as Dictionary
	for nid in nodes_dict.keys():
		if not actor.equipment_nodes.has(nid):
			var node: Dictionary = nodes_dict[nid] as Dictionary
			var props: Dictionary = node.get("props", {}) as Dictionary
			var soft_cap: int = int(props.get("soft_cap", 5))
			var rigid_cap: int = int(props.get("rigid_cap", 1))
			actor.equipment_nodes[nid] = {
				"soft_used": 0,
				"has_rigid": false,
				"soft_cap": soft_cap,
				"rigid_cap": rigid_cap,
				"layers": []  # Array of {"item_id":StringName,"soft_units":int,"is_rigid":bool,"order":int}
			}

# ---------------- Selector resolution ----------------

static func _resolve_selector(actor, sel: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var nodes: Dictionary = actor.body.get("nodes", {}) as Dictionary
	if sel.begins_with("id:"):
		var nid := StringName(sel.substr(3))
		if nodes.has(nid): out.append(nid)
	elif sel.begins_with("glob:"):
		var pat := sel.substr(5)
		for k in nodes.keys():
			var s := String(k)
			if _glob_match(s, pat):
				out.append(StringName(k))
	elif sel.begins_with("tag:"):
		var tag := sel.substr(4)
		for k in nodes.keys():
			var node: Dictionary = nodes[k] as Dictionary
			var tags: Array = node.get("tags", []) as Array
			for t in tags:
				if String(t) == tag:
					out.append(StringName(k))
					break
	return out

static func _glob_match(s: String, pat: String) -> bool:
	# very small glob: * matches any; no char classes
	if pat == "*": return true
	var parts := pat.split("*")
	if parts.size() == 1:
		return s == pat
	# prefix/suffix/infix check
	var i := 0
	var pos := 0
	for p in parts:
		if p == "": continue
		var idx := s.find(p, pos)
		if idx == -1: return false
		pos = idx + p.length()
	return true

static func _resolve_coverage(actor, selectors: Array[String]) -> Array[StringName]:
	var acc: Array[StringName] = []
	for sel in selectors:
		var ids := _resolve_selector(actor, sel)
		for nid in ids:
			if not acc.has(nid):
				acc.append(nid)
	return acc

static func _count_selector(actor, sel: String) -> int:
	return _resolve_selector(actor, sel).size()

# ---------------- Validation ----------------

static func validate_fit(actor, item: EquipmentItem) -> String:
	if item.is_drape:
		return ""  # no shape checks for drape
	# exact counts per selector
	for k in item.fit_shape.keys():
		var want := int(item.fit_shape[k])
		var have := _count_selector(actor, String(k))
		if have != want:
			return "fit_shape failed for %s: want %d, have %d" % [String(k), want, have]
	return ""

static func _validate_caps(actor, item: EquipmentItem, covered: Array[StringName]) -> String:
	if item.is_drape:
		var new_used : int = actor.equipment_drape_used + max(0, item.drape_cost)
		if new_used > int(actor.equipment_drape_cap):
			return "drape cap exceeded"
		return ""
	for nid in covered:
		var st: Dictionary = actor.equipment_nodes.get(nid, {}) as Dictionary
		if st.is_empty():
			return "unknown node %s" % [String(nid)]
		var soft_used := int(st.get("soft_used", 0))
		var soft_cap  := int(st.get("soft_cap", 5))
		var rigid_cap := int(st.get("rigid_cap", 1))
		var has_rigid := bool(st.get("has_rigid", false))
		if item.soft_units > 0 and (soft_used + item.soft_units) > soft_cap:
			return "soft cap exceeded on %s" % [String(nid)]
		if item.is_rigid and (has_rigid or rigid_cap <= 0):
			return "rigid already present on %s" % [String(nid)]
	return ""

# ---------------- Equip / Unequip ----------------

static func equip(actor, item: EquipmentItem) -> Dictionary:
	# Returns {ok:bool, reason:String}
	prepare_actor(actor)
	var reason := validate_fit(actor, item)
	if reason != "":
		return {"ok": false, "reason": reason}

	if item.is_drape:
		reason = _validate_caps(actor, item, [])
		if reason != "": return {"ok": false, "reason": reason}
		var entry := {
			"item_id": item.id,
			"cost": max(0, item.drape_cost),
			"kind": item.drape_kind
		}
		actor.equipment_drape.append(entry)
		actor.equipment_drape_used = int(actor.equipment_drape_used) + int(entry["cost"])
		actor.mass_kg = float(actor.mass_kg) + float(item.mass_kg)
		return {"ok": true, "reason": ""}

	# body-bound
	var covered := _resolve_coverage(actor, item.coverage)
	reason = _validate_caps(actor, item, covered)
	if reason != "": return {"ok": false, "reason": reason}

	for nid in covered:
		var st: Dictionary = actor.equipment_nodes[nid] as Dictionary
		var layers: Array = st.get("layers", []) as Array
		var entry := {
			"item_id": item.id,
			"soft_units": item.soft_units,
			"is_rigid": item.is_rigid,
			"order": layers.size()
		}
		layers.append(entry)
		st["layers"] = layers
		st["soft_used"] = int(st["soft_used"]) + int(item.soft_units)
		if item.is_rigid:
			st["has_rigid"] = true
		actor.equipment_nodes[nid] = st
	actor.mass_kg = float(actor.mass_kg) + float(item.mass_kg)
	return {"ok": true, "reason": ""}

static func unequip(actor, item_id: StringName) -> void:
	# remove from drape
	var new_drape: Array = []
	for e in actor.equipment_drape:
		var de: Dictionary = e
		if de.get("item_id", StringName()) == item_id:
			actor.equipment_drape_used = int(actor.equipment_drape_used) - int(de.get("cost", 0))
		else:
			new_drape.append(de)
	actor.equipment_drape = new_drape

	# remove from nodes
	for nid in actor.equipment_nodes.keys():
		var st: Dictionary = actor.equipment_nodes[nid]
		var layers: Array = st.get("layers", []) as Array
		var keep: Array = []
		var removed_rigid := false
		var freed_soft := 0
		for le in layers:
			var d: Dictionary = le
			if d.get("item_id", StringName()) == item_id:
				freed_soft += int(d.get("soft_units", 0))
				if bool(d.get("is_rigid", false)):
					removed_rigid = true
			else:
				keep.append(d)
		st["layers"] = keep
		st["soft_used"] = max(0, int(st.get("soft_used", 0)) - freed_soft)
		if removed_rigid:
			# recompute has_rigid from keep
			var any_rigid := false
			for le2 in keep:
				if bool((le2 as Dictionary).get("is_rigid", false)):
					any_rigid = true; break
			st["has_rigid"] = any_rigid
		actor.equipment_nodes[nid] = st

# Optional: reorder within a node (inner→outer)
static func reorder(actor, node_id: StringName, old_idx: int, new_idx: int) -> bool:
	if not actor.equipment_nodes.has(node_id): return false
	var st: Dictionary = actor.equipment_nodes[node_id]
	var layers: Array = st.get("layers", []) as Array
	if old_idx < 0 or old_idx >= layers.size(): return false
	if new_idx < 0 or new_idx >= layers.size(): return false
	var entry : Dictionary = layers.pop_at(old_idx)
	layers.insert(new_idx, entry)
	# refresh order indices
	for i in range(layers.size()):
		(layers[i] as Dictionary)["order"] = i
	st["layers"] = layers
	actor.equipment_nodes[node_id] = st
	return true
