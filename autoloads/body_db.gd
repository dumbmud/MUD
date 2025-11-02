extends Node
## BodyDB — compiles Species into baked maps and applies morphs.

const SPECIES_DIR := "res://bodies/species"

var by_id: Dictionary = {}      # StringName -> Dictionary (compiled species)
var by_tag: Dictionary = {}     # StringName -> Array[StringName]

func _ready() -> void:
	build_index(SPECIES_DIR)

func build_index(root: String) -> void:
	by_id.clear()
	by_tag.clear()

	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()

	while true:
		var f: String = dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			continue
		if not f.ends_with(".tres"):
			continue

		var res: Resource = ResourceLoader.load(root + "/" + f)
		if res == null:
			continue
		if not (res is Species):
			continue

		var s: Species = res as Species
		var compiled: Dictionary = _compile_species(s)
		by_id[s.id] = compiled

		var tag_list: Array = compiled.get("tags", []) as Array
		for t in tag_list:
			var key: StringName = StringName(t)
			var arr: Array = by_tag.get(key, []) as Array
			arr.append(s.id)
			by_tag[key] = arr

func get_compiled(species_id: StringName) -> Dictionary:
	return by_id.get(species_id, {}) as Dictionary

# NEW: forced_morphs lets you pick exactly which morph(s) to apply
func apply_to(species_id: StringName, actor, forced_morphs: Array[StringName] = []) -> void:
	var s: Dictionary = get_compiled(species_id)
	if s.is_empty():
		return

	# tags → actor
	var tag_src: Array = s.get("tags", []) as Array
	var out: Array[StringName] = []
	for t in tag_src:
		out.append(StringName(t))
	actor.tags = out

	# identity + display + physicals
	actor.species_id = s.get("id", StringName())
	actor.survival_defaults = s.get("survival", {}) as Dictionary
	actor.death_policy = s.get("death_policy", {}) as Dictionary
	actor.glyph = String(s.get("glyph", "?"))
	actor.fg_color = s.get("fg", Color.WHITE) as Color
	actor.size_scale = float(s.get("size_scale", 1.0))
	actor.mass_kg   = float(s.get("body_mass_kg", 0.0))

	# body graph (baked dict)
	var body: Dictionary = s.get("body", {}) as Dictionary

	# pick morph(s)
	var chosen: Array[StringName] = []
	if forced_morphs.size() > 0:
		for m in forced_morphs:
			chosen.append(m)
	else:
		var mr: Dictionary = s.get("morph_rules", {}) as Dictionary
		var weights: Dictionary = mr.get("weights", {}) as Dictionary
		if not weights.is_empty():
			var ids: Array[StringName] = []
			var cum: Array[int] = []
			var total: int = 0
			for k in weights.keys():
				var w: int = int(weights[k])
				if w <= 0:
					continue
				ids.append(StringName(k))
				total += w
				cum.append(total)
			if total > 0:
				var r: int = int(abs(actor.actor_id)) % total
				for i in range(cum.size()):
					if r < cum[i]:
						chosen.append(ids[i])
						break

	# apply morph(s)
	var final_body: Dictionary = body.duplicate(true) as Dictionary
	final_body["nodes"] = (body.get("nodes", {}) as Dictionary).duplicate(true)
	final_body["links"] = (body.get("links", []) as Array).duplicate(true)

	var all_morphs: Dictionary = s.get("morph_defs", {}) as Dictionary
	for m_id in chosen:
		var defn: Dictionary = all_morphs.get(m_id, {}) as Dictionary
		_apply_morph_ops(final_body, defn)

	# repro_key at graph level
	final_body["repro_key"] = StringName(s.get("repro_key", s.get("id", StringName())))

	actor.body = {
		"nodes": final_body.get("nodes", {}),
		"links": final_body.get("links", [])
	}

# Optional helper to pick by seed instead of actor_id
static func pick_morph(species_id: StringName, seed: int) -> StringName:
	var s := BodyDB.get_compiled(species_id)
	var mr: Dictionary = s.get("morph_rules", {}) as Dictionary
	var weights: Dictionary = mr.get("weights", {}) as Dictionary
	if weights.is_empty():
		return StringName()
	var ids: Array[StringName] = []
	var cum: Array[int] = []
	var total: int = 0
	for k in weights.keys():
		var w: int = int(weights[k])
		if w <= 0: continue
		ids.append(StringName(k))
		total += w
		cum.append(total)
	if total <= 0:
		return StringName()
	var r: int = abs(seed) % total
	for i in range(cum.size()):
		if r < cum[i]:
			return ids[i]
	return ids.back()

func _compile_species(s: Species) -> Dictionary:
	var g: BodyGraph = s.graph
	var out: Dictionary = {
		"id": s.id,
		"display_name": s.display_name,
		"glyph": s.glyph,
		"fg": s.fg,
		"tags": s.tags,                 # species tags → StringName on actor
		"death_policy": s.death_policy, # data-only; future evaluator: controller-socket death
		"survival": s.survival,
		"body": g.to_map() if g != null else {"nodes": {}, "links": []},
		"morph_defs": s.morph_defs,
		"morph_rules": s.morph_rules,
		"repro_key": s.repro_key if s.repro_key != StringName() else s.id
	}
	return out

# Morph ops (foundation only). Reserved names: remove_node, rename_node.
# { ops: [
#   {op:"add_node", id, tags:[], props:{}, channels_present:{}, tissue:{}, integument:{}},
#   {op:"add_link", a, b, flow:{}},
#   {op:"add_tag", id, tag},
#   {op:"set_prop", id, key, value}
# ] }
func _apply_morph_ops(body: Dictionary, morph_def: Dictionary) -> void:
	var ops: Array = morph_def.get("ops", []) as Array
	var nodes: Dictionary = body.get("nodes", {}) as Dictionary
	var links: Array = body.get("links", []) as Array

	for op in ops:
		var kind: String = String(op.get("op", ""))
		if kind == "add_node":
			var nid: StringName = StringName(op.get("id", ""))
			if String(nid) == "":
				continue
			var tissue: Dictionary = op.get("tissue", {"skin_hp":100,"soft_hp":100,"structure_hp":100}) as Dictionary
			var integ: Dictionary = op.get("integument", {"cut":1.0,"pierce":1.0,"blunt":1.0,"thermal":1.0}) as Dictionary
			var ch: Dictionary = op.get("channels_present", {"signal":true,"fluid":true,"gas":false}) as Dictionary
			var tags_arr: Array = op.get("tags", []) as Array   # keep node tags as plain Strings
			var props_dict: Dictionary = op.get("props", {}) as Dictionary
			nodes[nid] = {
				"tissue": tissue,
				"integument": integ,
				"channels_present": ch,
				"sockets": [],
				"ports": [],
				"tags": tags_arr,
				"props": props_dict
			}
		elif kind == "add_link":
			var a_id: StringName = StringName(op.get("a", ""))
			var b_id: StringName = StringName(op.get("b", ""))
			var flow: Dictionary = op.get("flow", {"signal":3,"fluid":3,"gas":0}) as Dictionary
			links.append({"a": a_id, "b": b_id, "flow": flow})
		elif kind == "add_tag":
			var nid2: StringName = StringName(op.get("id", ""))
			if nodes.has(nid2):
				var tarr: Array = (nodes[nid2].get("tags", []) as Array)
				tarr.append(op.get("tag", ""))
				nodes[nid2]["tags"] = tarr
		elif kind == "set_prop":
			var nid3: StringName = StringName(op.get("id", ""))
			if nodes.has(nid3):
				var props: Dictionary = (nodes[nid3].get("props", {}) as Dictionary)
				props[String(op.get("key", "k"))] = op.get("value", null)
				nodes[nid3]["props"] = props

	body["nodes"] = nodes
	body["links"] = links
