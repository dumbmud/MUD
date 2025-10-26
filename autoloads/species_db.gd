# res://autoloads/species_db.gd
extends Node
##
## SpeciesDB
## Autoload. Single source of truth for body data and accessors.
## Compiles Species resources into baked dictionaries so sim code never touches raw assets.
## No time/speed logic here. No legacy fields. No arteries. No auto-organs.

const SPECIES_DIR := "res://bodies/species"  # content root for Species *.tres

# ── Compiled caches ──────────────────────────────────────────────────────────
var by_id: Dictionary = {}   # Dictionary[StringName, Dictionary]
var by_tag: Dictionary = {}  # Dictionary[StringName, Array[StringName]]

func _ready() -> void:
	_build_index(SPECIES_DIR)

# ── Public API ────────────────────────────────────────────────────────────────

func get_id(id_in: Variant) -> Dictionary:
	# Returns compiled species dict or empty dict.
	var key: StringName
	if id_in is StringName:
		key = id_in
	elif id_in is String:
		key = StringName(id_in)
	else:
		key = StringName(str(id_in))
	return by_id.get(key, {})

func ids_with_tag(tag: StringName) -> Array:
	# Returns Array[StringName] of species ids that include `tag`.
	return by_tag.get(tag, [])

func apply_to(species_id: Variant, actor: Actor) -> void:
	# Copies compiled species data to the Actor instance.
	var s := get_id(species_id)
	var used_fallback := false

	if s.is_empty():
		var human := get_id(&"human")
		if human.is_empty():
			push_warning("Species not found and no fallback: %s" % species_id)
			actor.glyph = "?"
			actor.fg_color = Color(1, 0, 1)  # magenta fallback
			actor.speed_mult = 1.0
			return
		s = human
		used_fallback = true

	# Visuals
	actor.glyph    = "?" if used_fallback else s["glyph"]
	actor.fg_color = Color(1, 0, 1) if used_fallback else s["fg"]

	# Time/speed owned by Actor; baseline multiplier only.
	# actor.speed_mult = 1.0

	# Anatomy (compiled)
	actor.plan             = s["plan"]
	actor.plan_map         = s["plan_map"]
	actor.zone_labels      = s["zone_labels"]
	actor.zone_coverage    = s["zone_coverage_pct"]
	actor.zone_volume      = s["zone_volume_pct"]
	actor.zone_layers      = s["zone_layers"]
	actor.zone_effectors   = s["zone_effectors"]
	actor.zone_sensors     = s["zone_sensors"]
	actor.organs_by_zone   = s["organs_by_zone"]
	actor.organs_all       = s["organs_all"]
	actor.vital_organs     = s["vital_organs"]
	actor.targeting_index  = s["targeting_index"]
	actor.size_scale       = float(s.get("size_scale", 1.0))
	actor.death_policy     = s.get("death_policy", {})

# ── Build / index ────────────────────────────────────────────────────────────

func _build_index(root: String) -> void:
	by_id.clear()
	by_tag.clear()
	_scan_dir(root)

	# Sanity checks per compiled species (no human-centric assumptions)
	for sid: StringName in by_id.keys():
		var s: Dictionary = by_id[sid]

		# Coverage/volume must sum to 100
		var cov: Dictionary = s["zone_coverage_pct"]
		var vol: Dictionary = s["zone_volume_pct"]
		var cov_sum := 0; for v in cov.values(): cov_sum += int(v)
		var vol_sum := 0; for v in vol.values(): vol_sum += int(v)
		assert(cov_sum == 100, "Coverage must sum 100 for %s" % String(sid))
		assert(vol_sum == 100, "Volume must sum 100 for %s" % String(sid))

		# At least one vital organ
		var vitals: Array = s["vital_organs"]
		assert(vitals.size() >= 1, "At least one vital organ required for %s" % String(sid))

func _scan_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if name.begins_with("_"):
			continue
		var full := path.path_join(name)
		if d.current_is_dir():
			_scan_dir(full)
		elif full.get_extension() in ["tres", "res"]:
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

	# Zone aggregates
	var zone_cov_raw := {}        # id -> int
	var zone_vol_raw := {}        # id -> int
	var zone_labels := {}         # id -> String
	var zone_layers := {}         # id -> Array[Dictionary]
	var zone_effectors := {}      # id -> Dictionary
	var zone_sensors := {}        # id -> Dictionary
	var zones_meta := {}          # id -> {group, side}

	# Organs
	var organs_all := {}          # organ_id -> {kind, host_zone, vital, channels}
	var organs_by_zone := {}      # zone_id -> Array[organ_id]
	var vital_organs: Array[StringName] = []

	# Targeting index (grouped lists)
	var targeting_index := {      # label -> Array[zone_id]
		&"head": [], &"torso": [],
		&"left_arm": [], &"right_arm": [],
		&"left_leg": [], &"right_leg": []
	}

	# Pass 1: collect zones and organs
	if sres.plan != null:
		for p: BodyPart in sres.plan.parts:
			var pid: StringName = p.name

			if p.slot == &"zone":
				# Expect: p.group, p.side, p.coverage_pct, p.volume_pct, p.layers, p.effectors, p.sensors, p.label_hint?
				var group: StringName = p.group
				var side: StringName  = p.side
				var cov := int(p.coverage_pct)
				var vol := int(p.volume_pct)

				zone_cov_raw[pid] = cov
				zone_vol_raw[pid] = vol
				zone_layers[pid] = p.layers.duplicate(true)
				zone_effectors[pid] = (p.effectors as Dictionary).duplicate(true)
				zone_sensors[pid] = (p.sensors as Dictionary).duplicate(true)
				zones_meta[pid] = {"group": group, "side": side}

				var lbl := _zone_label(group, side, p.label_hint if "label_hint" in p else "")
				zone_labels[pid] = lbl

				# Targeting buckets
				var tkey := _target_label_for(group, side)
				if tkey != &"":
					if not targeting_index.has(tkey):
						targeting_index[tkey] = []
					(targeting_index[tkey] as Array).append(pid)
				elif group != &"":
					var gkey := group
					if not targeting_index.has(gkey):
						targeting_index[gkey] = []
					(targeting_index[gkey] as Array).append(pid)

			elif p.slot == &"internal":
				# Expect: p.kind, p.vital, p.host_zone_id, p.channels
				var organ := {
					"id": pid,
					"kind": p.kind,
					"host_zone": p.host_zone_id,
					"vital": bool(p.vital),
					"channels": (p.channels as Dictionary).duplicate(true)
				}
				organs_all[pid] = organ
				if not organs_by_zone.has(p.host_zone_id):
					organs_by_zone[p.host_zone_id] = []
				(organs_by_zone[p.host_zone_id] as Array).append(pid)
				if bool(p.vital):
					vital_organs.append(pid)

	# Normalize weights to 100% totals
	var zone_cov_pct := _normalize_weights(zone_cov_raw)
	var zone_vol_pct := _normalize_weights(zone_vol_raw)

	return {
		# Identity / visuals
		"id": sres.id,
		"name": sres.display_name,
		"glyph": sres.glyph,
		"fg": sres.fg,
		"tags": tags,

		# Anatomy resources
		"plan": sres.plan,
		"plan_map": plan_map,

		# Zones
		"zone_coverage_raw": zone_cov_raw,
		"zone_volume_raw": zone_vol_raw,
		"zone_coverage_pct": zone_cov_pct,
		"zone_volume_pct": zone_vol_pct,
		"zone_labels": zone_labels,
		"zone_layers": zone_layers,
		"zone_effectors": zone_effectors,
		"zone_sensors": zone_sensors,
		"zones_meta": zones_meta,

		# Organs
		"organs_all": organs_all,
		"organs_by_zone": organs_by_zone,
		"vital_organs": vital_organs,

		# Targeting
		"targeting_index": targeting_index,

		# Instance knobs
		"size_scale": float(sres.size_scale if "size_scale" in sres else 1.0),
		"death_policy": sres.death_policy if "death_policy" in sres else {}
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

static func _normalize_weights(m: Dictionary) -> Dictionary:
	# Converts raw ints into percentages that sum to 100.
	var tot := 0
	for v in m.values():
		tot += int(v)
	if tot <= 0:
		# Empty species or all-zero zones: return as-is.
		return m.duplicate()
	var out := {}
	var acc := 0
	for k in m.keys():
		var pct := int(round(100.0 * float(int(m[k])) / float(tot)))
		out[k] = pct
		acc += pct
	if acc != 100:
		# Fix rounding drift by adjusting the max-weight key.
		var keys: Array = m.keys()
		var kmax: Variant = keys[0]
		for k in keys:
			if int(m[k]) > int(m[kmax]):
				kmax = k
		out[kmax] = int(out[kmax]) + (100 - acc)
	return out

static func _zone_label(group: StringName, side: StringName, hint: String) -> String:
	# Human-readable label for UI/debug: side + group, with optional hint override.
	if hint != "":
		return hint
	var side_txt := ""
	if side == &"L": side_txt = "left "
	elif side == &"R": side_txt = "right "
	return "%s%s" % [side_txt, String(group)] if String(group) != "" else (hint if hint != "" else "")

static func _target_label_for(group: StringName, side: StringName) -> StringName:
	# Canonical targeting labels for coarse groups.
	if group == &"head":
		return &"head"
	if group == &"torso":
		return &"torso"
	if group == &"arm":
		return &"left_arm" if side == &"L" else (&"right_arm" if side == &"R" else &"arm")
	if group == &"leg":
		return &"left_leg" if side == &"L" else (&"right_leg" if side == &"R" else &"leg")
	# Fallback: for other groups, return "" so caller can bucket by group name if desired.
	return &""
