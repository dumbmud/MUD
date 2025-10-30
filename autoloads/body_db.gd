extends Node
##
## BodyDB — compiler for Species (BodyGraph-based).
## Builds baked dicts. No legacy fields.

const SPECIES_DIR := "res://bodies/species"

var by_id: Dictionary = {}      # StringName -> Dictionary
var by_tag: Dictionary = {}     # StringName -> Array[StringName]

func _ready() -> void:
	build_index(SPECIES_DIR)

func build_index(root: String) -> void:
	by_id.clear()
	by_tag.clear()
	_scan_dir(root)

	# sanity
	for sid: StringName in by_id.keys():
		var s: Dictionary = by_id[sid]
		assert(s.has("body") and s["body"].has("nodes"), "Species %s missing body graph" % String(sid))

func _scan_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var name_ := d.get_next()
		if name_ == "":
			break
		if name_.begins_with("_"):
			continue
		var full := path.path_join(name_)
		if d.current_is_dir():
			_scan_dir(full)
		elif full.get_extension() in ["tres", "res"]:
			var res := load(full)
			if res is Species and res.graph != null:
				var compiled := _compile_species(res)
				by_id[compiled["id"]] = compiled
				for t: StringName in compiled["tags"]:
					if not by_tag.has(t): by_tag[t] = []
					(by_tag[t] as Array).append(compiled["id"])
	d.list_dir_end()

func _compile_species(sres: Species) -> Dictionary:
	var g: BodyGraph = sres.graph
	var vcheck: Dictionary = g.validate()
	if !bool(vcheck.get("ok", false)):
		push_warning("BodyGraph validate errors for %s: %s" % [String(sres.id), str(vcheck.get("errors", []))])

	var body_map := g.to_map()
	var size_scale := float(sres.size_scale)
	var mass_kg := float(sres.body_mass_kg) * size_scale

	# Phase 3: derive capacities from the baked body
	var caps := Capacity.recompute_from_body(body_map, size_scale, mass_kg, 0.0)

	return {
		"id": sres.id,
		"name": sres.display_name,
		"glyph": sres.glyph,
		"fg": sres.fg,
		"tags": sres.tags.duplicate(),
		"body": body_map,
		"size_scale": size_scale,
		"body_mass_kg": mass_kg,
		"death_policy": sres.death_policy,
		"capacities": caps
	}


func get_id(id_in: Variant) -> Dictionary:
	var key: StringName
	if id_in is StringName: key = id_in
	elif id_in is String:   key = StringName(id_in)
	else:                   key = StringName(str(id_in))
	return by_id.get(key, {})

func ids_with_tag(tag: StringName) -> Array:
	return by_tag.get(tag, [])

func apply_to(species_id: Variant, actor: Actor) -> void:
	var s := get_id(species_id)
	var used_fallback := false

	if s.is_empty():
		push_warning("Species not found: %s" % String(species_id))
		# minimal fallback avoids crashes during content bring-up
		actor.glyph = "?"
		actor.fg_color = Color(1, 0, 1)
		actor.size_scale = 1.0
		actor.mass_kg = 70.0
		actor.body = {"nodes": [], "links": []}
		actor.capacities = {"neuro":0.0,"circ":0.0,"resp":0.0,"load":0.0,"manip":0.0,"sense":{},"thermo":{},"mobility":{}}
		return

	# visuals
	actor.glyph    = s["glyph"]
	actor.fg_color = s["fg"]

	# physicals
	actor.size_scale = float(s.get("size_scale", 1.0))
	actor.mass_kg    = float(s.get("body_mass_kg", 70.0))

	# identity/policy
	actor.death_policy = s.get("death_policy", {})

	# body graph (baked dicts)
	var body: Dictionary = s["body"]
	actor.body = {"nodes": body.get("nodes", {}), "links": body.get("links", [])}

	# capacities placeholder
	actor.capacities = (s.get("capacities", {}) as Dictionary).duplicate(true)
