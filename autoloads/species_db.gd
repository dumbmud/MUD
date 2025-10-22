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
	# sanity check
	for sid in by_id.keys():
		var s = by_id[sid]
		var cov : Dictionary = s["zone_coverage_pct"]; var vol : Dictionary = s["zone_volume_pct"]
		var cov_sum := 0; for v in cov.values(): cov_sum += int(v)
		var vol_sum := 0; for v in vol.values(): vol_sum += int(v)
		assert(cov_sum == 100, "Coverage must sum 100 for %s" % sid)
		assert(vol_sum == 100, "Volume must sum 100 for %s" % sid)

		# head/torso present
		var has_head := false; var has_torso := false
		for zid in s["zones"].keys():
			var z: Dictionary = s["zones"][zid]
			if z["kind"] == &"core" and z["class"] == &"head": has_head = true
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
	var plan_map := s.plan.to_map() if s.plan != null else {}

	var zones := _compile_zones(s.plan) if s.plan != null else {}

	var zone_cov_raw := {}; var zone_vol_raw := {}
	for id in zones.keys():
		zone_cov_raw[id] = zones[id]["cov"]
		zone_vol_raw[id] = zones[id]["vol"]
	var zone_cov_pct := _normalize_weights(zone_cov_raw)
	var zone_vol_pct := _normalize_weights(zone_vol_raw)

	var zone_organs := {}; var zone_has_artery := {}; var zone_labels := {}
	var zone_effectors := {}; var zone_eff_kind := {}; var zone_eff_score := {}
	for id in zones.keys():
		var z:Dictionary = zones[id]
		zone_organs[id] = _organs_for(z["kind"], z["class"], id)
		zone_has_artery[id] = bool(z["artery"]) or (zone_organs[id].find(&"artery") != -1)
		zone_labels[id] = z["label"]

		# multi-effectors
		zone_effectors[id] = z["effectors"]        # {kind->score}
		# compatibility primary: prefer grasper, else max score
		var pk := &""; var ps := -1.0
		for k in (z["effectors"] as Dictionary).keys():
			var sc := float(z["effectors"][k])
			if k == &"grasper":
				if sc > ps: pk = k; ps = sc
			elif pk != &"grasper" and sc > ps:
				pk = k; ps = sc
		zone_eff_kind[id] = pk
		zone_eff_score[id] = max(ps, 0.0)

	# sensors: max per zone per kind
	var zone_sensors := {}
	if s.plan != null:
		for p:BodyPart in s.plan.parts:
			var id := p.name if (p.slot==&"core" and p.group_id==&"") else p.group_id
			if id == &"" or p.sensor_kind == &"": continue
			if not zone_sensors.has(id): zone_sensors[id] = {}
			var prev := float(zone_sensors[id].get(p.sensor_kind, 0.0))
			if p.sensor_score > prev: zone_sensors[id][p.sensor_kind] = p.sensor_score

	return {
		"id": s.id, "name": s.display_name, "glyph": s.glyph, "fg": s.fg,
		"plan": s.plan, "plan_map": plan_map, "tags": tags, "stats": stats,

		"zones": zones, "zone_labels": zone_labels,
		"zone_coverage_raw": zone_cov_raw, "zone_volume_raw": zone_vol_raw,
		"zone_coverage_pct": zone_cov_pct, "zone_volume_pct": zone_vol_pct,
		"zone_organs": zone_organs, "zone_has_artery": zone_has_artery,

		# effectors
		"zone_effectors": zone_effectors,     # id->{kind->score}
		"zone_eff_kind": zone_eff_kind,       # legacy primary
		"zone_eff_score": zone_eff_score,

		# sensors
		"zone_sensors": zone_sensors,
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
	actor.zone_labels      = s["zone_labels"]
	actor.zone_coverage    = s["zone_coverage_pct"]   # for hit weights
	actor.zone_volume      = s["zone_volume_pct"]     # for scaling
	actor.zone_organs      = s["zone_organs"]
	actor.zone_has_artery  = s["zone_has_artery"]
	actor.zone_eff_kind    = s["zone_eff_kind"]
	actor.zone_eff_score   = s["zone_eff_score"]
	actor.zone_sensors     = s["zone_sensors"]
	actor.zone_effectors   = s["zone_effectors"]


# -------- zone compiler --------
static func _label_from_token(token:String) -> String:
	var TOK := {"L":"left","R":"right","FL":"front left","FR":"front right","RL":"rear left","RR":"rear right"}
	return TOK.get(token, token)

static func _zone_label(kind:StringName, cls:StringName, token:String, hint:String) -> String:
	if hint != "": return hint
	if kind == &"core": return String(cls)  # "head","torso"
	var base := _label_from_token(token)
	return "%s %s" % [base, String(cls)] if cls != &"" else (base if base != "" else String(cls))

# --- add above _compile_zones ---
static func _compute_terminal(plan: BodyPlan) -> Dictionary:
	var has_child: Dictionary = {}
	for p: BodyPart in plan.parts:
		has_child[p.parent] = true
	var term: Dictionary = {}
	for p: BodyPart in plan.parts:
		term[p.name] = not has_child.has(p.name)
	return term

static func _compile_zones(plan: BodyPlan) -> Dictionary:
	var term : Dictionary = _compute_terminal(plan)
	var zones := {} # id -> dict of props
	for p: BodyPart in plan.parts:
		var id := p.name if (p.slot == &"core" and p.group_id == &"") else p.group_id
		if id == &"": continue
		if not zones.has(id):
			var cls := p.core_role if (p.slot == &"core") else p.limb_class
			var token := id.get_slice(".",1) if (p.slot == &"limb" and id.find(".") != -1) else ""
			zones[id] = {
				"kind":p.slot, "class":cls, "token":token, "label":_zone_label(p.slot,cls,token,p.label_hint),
				"cov":0, "vol":0, "artery":false,
				"effectors": {}   # <--- multi-effectors here
			}
		var z:Dictionary = zones[id]
		z["cov"] = int(z["cov"]) + p.coverage
		z["vol"] = int(z["vol"]) + p.volume
		z["artery"] = bool(z["artery"]) or p.has_artery
		# gather effectors (prefer terminal part’s value but always keep max)
		if p.effector_kind != &"":
			var eff: Dictionary = z["effectors"]
			var prev := float(eff.get(p.effector_kind, 0.0))
			var cand := p.effector_score + (0.001 if term[p.name] else 0.0)
			if cand > prev:
				eff[p.effector_kind] = p.effector_score
	return zones

static func _normalize_weights(m:Dictionary) -> Dictionary:
	var tot := 0; for v in m.values(): tot += int(v)
	if tot <= 0: return m.duplicate()
	var out := {}; var acc := 0
	for k in m.keys():
		var pct := int(round(100.0 * float(int(m[k])) / float(tot)))
		out[k] = pct; acc += pct
	if acc != 100:
		var kmax : Array = m.keys()[0]
		for k in m.keys(): if int(m[k]) > int(m[kmax]): kmax = k
		out[kmax] = int(out[kmax]) + (100 - acc)
	return out

static func _organs_for(kind:StringName, cls:StringName, _id:StringName) -> Array[StringName]:
	if kind == &"core" and cls == &"head":  return [&"brain",&"eyes",&"jaw",&"skull",&"throat"]
	if kind == &"core" and cls == &"torso": return [&"heart",&"lungs",&"guts",&"spine",&"ribs",&"aorta"]
	if kind == &"limb" and cls == &"arm":   return [&"long_bone",&"fore_bone",&"hand",&"artery"]
	if kind == &"limb" and cls == &"leg":   return [&"femur",&"shin",&"foot",&"artery"]
	return [&"segment",&"artery"] if kind == &"limb" else []
