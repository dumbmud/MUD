# res://autoloads/species_db.gd
extends Node
##
## Autoload. Single source of truth for species data and accessors.
## Compiles Species resources into baked dictionaries so sim code never touches raw assets.
## Phase regen is uniform and NOT controlled here.

const SPECIES_DIR := "res://creatures/species"  # content root

# Compiled caches
var by_id: Dictionary = {}   # Dictionary[StringName, Dictionary]
var by_tag: Dictionary = {}  # Dictionary[StringName, Array[StringName]]

func _ready() -> void:
	_build_index(SPECIES_DIR)

# ── Public API ────────────────────────────────────────────────────────────────

func get_id(id_in: Variant) -> Dictionary:
	var key: StringName
	if id_in is StringName:
		key = id_in
	elif id_in is String:
		key = StringName(id_in)
	else:
		key = StringName(str(id_in))
	return by_id.get(key, {})

func ids_with_tag(tag: StringName) -> Array:
	return by_tag.get(tag, [])

func apply_to(species_id: Variant, actor: Actor) -> void:
	var s := get_id(species_id)
	var used_fallback := false

	if s.is_empty():
		var human := get_id(&"human")
		if human.is_empty():
			push_warning("Species not found and no fallback: %s" % species_id)
			actor.glyph = "?"
			actor.fg_color = Color(1, 0, 1)
			# Do not touch phase regen here; Actor defaults are authoritative.
			actor.speed_mult = 1.0
			return
		s = human
		used_fallback = true

	# Visuals
	actor.glyph    = "?" if used_fallback else s["glyph"]
	actor.fg_color = Color(1, 0, 1) if used_fallback else s["fg"]

	# Time/speed: regen is uniform and owned by Actor. Only baseline multiplier here.
	actor.speed_mult = 1.0

	# Anatomy (pass-through compiled zones and plan)
	actor.plan      = s["plan"]
	actor.plan_map  = s["plan_map"]
	actor.zone_labels     = s["zone_labels"]
	actor.zone_coverage   = s["zone_coverage_pct"]
	actor.zone_volume     = s["zone_volume_pct"]
	actor.zone_organs     = s["zone_organs"]
	actor.zone_has_artery = s["zone_has_artery"]
	actor.zone_eff_kind   = s["zone_eff_kind"]
	actor.zone_eff_score  = s["zone_eff_score"]
	actor.zone_sensors    = s["zone_sensors"]
	actor.zone_effectors  = s["zone_effectors"]

# ── Build / index ────────────────────────────────────────────────────────────

func _build_index(root: String) -> void:
	by_id.clear()
	by_tag.clear()
	_scan_dir(root)

	# Sanity checks per compiled species
	for sid in by_id.keys():
		var s: Dictionary = by_id[sid]

		# 100% sums
		var cov: Dictionary = s["zone_coverage_pct"]
		var vol: Dictionary = s["zone_volume_pct"]
		var cov_sum := 0; for v in cov.values(): cov_sum += int(v)
		var vol_sum := 0; for v in vol.values(): vol_sum += int(v)
		assert(cov_sum == 100, "Coverage must sum 100 for %s" % sid)
		assert(vol_sum == 100, "Volume must sum 100 for %s" % sid)

		# head/torso present
		var has_head := false; var has_torso := false
		for zid in s["zones"].keys():
			var z: Dictionary = s["zones"][zid]
			if z["kind"] == &"core" and z["class"] == &"head":  has_head = true
			if z["kind"] == &"core" and z["class"] == &"torso": has_torso = true
		assert(has_head and has_torso, "Missing head/torso zones for %s" % sid)

		# human sanity
		if sid == &"human":
			assert(s["zone_effectors"].has(&"arm.L") and s["zone_effectors"].has(&"arm.R"), "Human needs graspers")
			var v := 0.0
			for z in s["zone_sensors"].values():
				v = max(v, float(z.get(&"vision", 0.0)))
			assert(v > 0.0, "Human needs vision")

func _scan_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null: return
	d.list_dir_begin()
	while true:
		var dname := d.get_next()
		if dname == "": break
		if dname.begins_with("_"): continue
		var full := path.path_join(dname)
		if d.current_is_dir():
			_scan_dir(full)
		elif full.get_extension() in ["tres","res"]:
			var res := load(full)
			if res is Species:
				var compiled := _compile_species(res)
				by_id[compiled["id"]] = compiled
				for t: StringName in compiled["tags"]:
					if not by_tag.has(t): by_tag[t] = []
					(by_tag[t] as Array).append(compiled["id"])
	d.list_dir_end()

# ── Compile Species resource → baked dict ────────────────────────────────────

func _compile_species(sres: Species) -> Dictionary:
	var tags := _dedupe(sres.tags.duplicate())

	var plan_map := sres.plan.to_map() if sres.plan != null else {}
	var zones := _compile_zones(sres.plan) if sres.plan != null else {}

	var zone_cov_raw := {}; var zone_vol_raw := {}
	for id in zones.keys():
		zone_cov_raw[id] = zones[id]["cov"]
		zone_vol_raw[id] = zones[id]["vol"]
	var zone_cov_pct := _normalize_weights(zone_cov_raw)
	var zone_vol_pct := _normalize_weights(zone_vol_raw)

	var zone_organs := {}; var zone_has_artery := {}; var zone_labels := {}
	var zone_effectors := {}; var zone_eff_kind := {}; var zone_eff_score := {}

	for id in zones.keys():
		var z: Dictionary = zones[id]
		zone_organs[id] = _organs_for(z["kind"], z["class"], id)
		zone_has_artery[id] = bool(z["artery"]) or (zone_organs[id].find(&"artery") != -1)
		zone_labels[id] = z["label"]

		# Copy effectors map as-is (kind → score)
		zone_effectors[id] = z["effectors"]

		# Primary effector choice: prefer grasper, else highest score deterministically.
		var eff: Dictionary = z["effectors"]
		var pk: StringName = &""
		var ps := -1.0
		for k in eff.keys():
			var sc := float(eff[k])
			if sc > ps:
				pk = k
				ps = sc
		if eff.has(&"grasper"):
			pk = &"grasper"
			ps = float(eff[&"grasper"])
		zone_eff_kind[id] = pk
		zone_eff_score[id] = max(ps, 0.0)

	# Sensors: per zone per kind = max(part scores)
	var zone_sensors := {}
	if sres.plan != null:
		for p: BodyPart in sres.plan.parts:
			var id: StringName = p.name if (p.slot == &"core" and p.group_id == &"") else p.group_id
			if id == &"" or p.sensor_kind == &"": continue
			if not zone_sensors.has(id): zone_sensors[id] = {}
			var prev := float(zone_sensors[id].get(p.sensor_kind, 0.0))
			if p.sensor_score > prev:
				zone_sensors[id][p.sensor_kind] = p.sensor_score

	return {
		"id": sres.id, "name": sres.display_name, "glyph": sres.glyph, "fg": sres.fg,
		"plan": sres.plan, "plan_map": plan_map, "tags": tags, "meta": sres.meta,

		"zones": zones, "zone_labels": zone_labels,
		"zone_coverage_raw": zone_cov_raw, "zone_volume_raw": zone_vol_raw,
		"zone_coverage_pct": zone_cov_pct, "zone_volume_pct": zone_vol_pct,
		"zone_organs": zone_organs, "zone_has_artery": zone_has_artery,

		# effectors
		"zone_effectors": zone_effectors,
		"zone_eff_kind": zone_eff_kind,
		"zone_eff_score": zone_eff_score,

		# sensors
		"zone_sensors": zone_sensors,
	}

# ── Helpers ──────────────────────────────────────────────────────────────────

static func _dedupe(arr: Array) -> Array:
	var seen := {}
	var out: Array = []
	for v in arr:
		if not seen.has(v):
			seen[v] = true
			out.append(v)
	return out

static func _label_from_token(token: String) -> String:
	var TOK := {"L":"left","R":"right","FL":"front left","FR":"front right","RL":"rear left","RR":"rear right"}
	return TOK.get(token, token)

static func _zone_label(kind: StringName, cls: StringName, token: String, hint: String) -> String:
	if hint != "": return hint
	if kind == &"core": return String(cls)
	var base := _label_from_token(token)
	return "%s %s" % [base, String(cls)] if cls != &"" else (base if base != "" else String(cls))

static func _compute_terminal(plan: BodyPlan) -> Dictionary:
	var has_child: Dictionary = {}
	for p in plan.parts:
		has_child[p.parent] = true
	var term: Dictionary = {}
	for p in plan.parts:
		term[p.name] = not has_child.has(p.name)
	return term

static func _compile_zones(plan: BodyPlan) -> Dictionary:
	var term: Dictionary = _compute_terminal(plan)
	var zones := {} # id -> dict of props
	for p in plan.parts:
		var id: StringName = p.name if (p.slot == &"core" and p.group_id == &"") else p.group_id
		if id == &"": continue
		if not zones.has(id):
			var cls := p.core_role if (p.slot == &"core") else p.limb_class
			var id_str := String(id)
			var token := id_str.get_slice(".", 1) if (p.slot == &"limb" and id_str.find(".") != -1) else ""
			zones[id] = {
				"kind": p.slot, "class": cls, "token": token, "label": _zone_label(p.slot, cls, token, p.label_hint),
				"cov": 0, "vol": 0, "artery": false,
				"effectors": {}
			}
		var z: Dictionary = zones[id]
		z["cov"] = int(z["cov"]) + p.coverage
		z["vol"] = int(z["vol"]) + p.volume
		z["artery"] = bool(z["artery"]) or p.has_artery
		# Prefer terminal part when tieing by a hair to break symmetry.
		if p.effector_kind != &"":
			var eff: Dictionary = z["effectors"]
			var prev := float(eff.get(p.effector_kind, 0.0))
			var cand := p.effector_score + (0.001 if term[p.name] else 0.0)
			if cand > prev:
				eff[p.effector_kind] = p.effector_score
	return zones

static func _normalize_weights(m: Dictionary) -> Dictionary:
	var tot := 0
	for v in m.values(): tot += int(v)
	if tot <= 0: return m.duplicate()
	var out := {}; var acc := 0
	for k in m.keys():
		var pct := int(round(100.0 * float(int(m[k])) / float(tot)))
		out[k] = pct; acc += pct
	if acc != 100:
		var keys: Array = m.keys()
		var kmax: Variant = keys[0]
		for k in keys:
			if int(m[k]) > int(m[kmax]): kmax = k
		out[kmax] = int(out[kmax]) + (100 - acc)
	return out

static func _organs_for(kind: StringName, cls: StringName, _id: StringName) -> Array[StringName]:
	if kind == &"core" and cls == &"head":  return [&"brain",&"eyes",&"jaw",&"skull",&"throat"]
	if kind == &"core" and cls == &"torso": return [&"heart",&"lungs",&"guts",&"spine",&"ribs",&"aorta"]
	if kind == &"limb" and cls == &"arm":   return [&"long_bone",&"fore_bone",&"hand",&"artery"]
	if kind == &"limb" and cls == &"leg":   return [&"femur",&"shin",&"foot",&"artery"]
	return [&"segment",&"artery"] if kind == &"limb" else []
