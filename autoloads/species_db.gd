extends Node

const SPECIES_DIR := "res://creatures/species"  # single source of truth

var by_id: Dictionary = {}
var by_tag: Dictionary = {}

func _ready() -> void:
	_build_index(SPECIES_DIR)

func _build_index(root: String) -> void:
	by_id.clear()
	by_tag.clear()
	_scan_dir(root)
	# optional sanity:
	# print("Species loaded:", by_id.keys())

func _scan_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null: return
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "": break
		if name.begins_with("_"): continue
		var full := path.path_join(name)
		if d.current_is_dir():
			_scan_dir(full)
		elif full.get_extension() in ["tres","res"]:
			var s := load(full)
			if s is Species:
				var compiled := _compile_species(s)
				by_id[compiled["id"]] = compiled
				for t in compiled["tags"]:
					if not by_tag.has(t): by_tag[t] = []
					(by_tag[t] as Array).append(compiled["id"])
	d.list_dir_end()

func _compile_species(s: Species) -> Dictionary:
	var tags := _dedupe(s.tags.duplicate())
	var stats := s.base_stats.duplicate()
	return {
		"id": s.id,                    # StringName
		"name": s.display_name,
		"glyph": s.glyph,
		"fg": s.fg,
		"plan": s.plan,
		"plan_map": s.plan.to_map(),
		"tags": tags,
		"stats": stats,
	}

# ---- LOOKUP API ----
func get_id(id: Variant) -> Dictionary:
	var key: StringName
	if id is StringName:
		key = id
	elif id is String:
		key = StringName(id)
	else:
		key = StringName(str(id))
	return by_id.get(key, {})

func ids_with_tag(tag: StringName) -> Array:
	return by_tag.get(tag, [])

func _dedupe(arr: Array) -> Array:
	var seen := {}
	var out: Array = []
	for v in arr:
		if not seen.has(v):
			seen[v] = true
			out.append(v)
	return out

# ---- APPLY TO ACTOR ----
func apply_to(species_id: Variant, actor: Actor) -> void:
	var s := get_id(species_id)
	if s.is_empty():
		push_warning("Species not found: %s" % species_id)
		actor.glyph = "?"
		actor.fg_color = Color(1, 0, 1)
		actor.tu_per_tick = 20
		return
	actor.glyph = s["glyph"]
	actor.fg_color = s["fg"]
	actor.tu_per_tick = int(s["stats"].get("tu_per_tick", actor.tu_per_tick))
	actor.plan = s["plan"]
	actor.plan_map = s["plan_map"]
