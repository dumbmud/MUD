# res://core/support/survival.gd
class_name Survival
extends RefCounted
## Survival system (status-only).
## - Species-agnostic. Activation via actor tags and death_policy baked by BodyDB.
## - No numeric couplings. Only toggles Status IDs while updating simple buffers.

const StatusAPI = preload("res://core/support/status.gd")

const SEC_PER_H := 3600.0

# Food
const HUNGRY_H := 6.0
const STARVING_H := 0.0
const FAT_KCAL_PER_KG := 7700.0
const BASAL_KCAL_PER_H := 100.0
const MASS_EXP := 0.75

# Water
const THIRSTY_H := 8.0
const DEHYDRATED_H := 0.0

# Sleep (only if sleep_required tag)
const SLEEPY_AWAKE_H := 16.0
const EXHAUSTED_AWAKE_H := 24.0

# Gas
const LO2_FRAC := 0.18
const HYPOXIC_FRAC := 0.12
const LO2_ACCUM_S := 10.0
const HYPOXIC_ACCUM_S := 60.0
const GAS_BUFFER_S := 60.0

# Temperature
const COLD_DELTA1 := 1.5
const COLD_DELTA2 := 3.0
const HEAT_DELTA1 := 0.5
const HEAT_DELTA2 := 2.0
const TEMP_ACCUM_S := 600.0
const CORE_DRIFT_C_PER_S := 0.003

# Helpers ---------------------------------------------------------------------

static func _mass_scale(actor) -> float:
	var m : float = max(1.0, float(actor.mass_kg))
	return pow(m / 70.0, MASS_EXP)

static func _activity_factor(_actor) -> float:
	return 1.0

static func _ensure_runtime_fields(a) -> void:
	if a == null or typeof(a.survival) != TYPE_DICTIONARY:
		return
	var s: Dictionary = a.survival as Dictionary
	# gas
	if s.has("gas") and typeof(s["gas"]) == TYPE_DICTIONARY:
		var g: Dictionary = s["gas"]
		if !g.has("accum_low_s"): g["accum_low_s"] = 0.0
		if !g.has("accum_hyp_s"): g["accum_hyp_s"] = 0.0
		if !g.has("buffer_s"):    g["buffer_s"]    = GAS_BUFFER_S
		s["gas"] = g
	# temp
	if s.has("temp") and typeof(s["temp"]) == TYPE_DICTIONARY:
		var t: Dictionary = s["temp"]
		if !t.has("accum_cold_s"): t["accum_cold_s"] = 0.0
		if !t.has("accum_heat_s"): t["accum_heat_s"] = 0.0
		s["temp"] = t
	a.survival = s

# Public API ------------------------------------------------------------------

static func init_for(a) -> void:
	var s: Dictionary = {}
	# Always tracked
	s["satiety_h"]   = 24.0
	s["hydration_h"] = 24.0
	# Sleep opt-in by tag
	s["awake_h"] = 0.0 if _has_tag(a, &"sleep_required") else null
	# Gas by tag or death_policy
	var gas_name: StringName = _required_gas_name_from_actor(a)
	if String(gas_name) != "":
		s["gas"] = {"name": gas_name, "buffer_s": GAS_BUFFER_S}
	else:
		s["gas"] = null
	# Temperature
	s["temp"] = {"core_C": 37.0, "min_C": 35.0, "max_C": 39.0}
	# Fat reserve
	s["fat_kg"] = 12.0
	# Diet stubs
	s["diet_eff"] = {"plant": 0.5, "meat": 0.5}
	s["diet_req"] = {"plant_min": 0.0, "meat_min": 0.0}
	s["ema"] = {"plant_7d": 0.0, "meat_7d": 0.0, "plant_30d": 0.0, "meat_30d": 0.0}
	# Solid waste opt-in
	s["stool_units"] = 0.0 if _has_tag(a, &"solid_excretion") else null

	# Actor overrides
	var sv: Dictionary = {}
	if a != null and typeof(a.survival_defaults) == TYPE_DICTIONARY:
		sv = a.survival_defaults as Dictionary
	# Gas override
	if sv.has("requires_gas"):
		var gvar = sv["requires_gas"]
		var gsn: StringName = (gvar as StringName) if typeof(gvar) == TYPE_STRING_NAME else StringName(str(gvar))
		s["gas"] = {"name": gsn, "buffer_s": GAS_BUFFER_S}
	# Temperature band override
	if sv.has("temp_band") and typeof(sv["temp_band"]) == TYPE_DICTIONARY:
		var tb: Dictionary = sv["temp_band"]
		var t: Dictionary = s["temp"]
		if tb.has("min_C"): t["min_C"] = float(tb["min_C"])
		if tb.has("max_C"): t["max_C"] = float(tb["max_C"])
		s["temp"] = t
	# Start fat
	if sv.has("start_fat_kg"):
		s["fat_kg"] = max(0.0, float(sv["start_fat_kg"]))
	# Diet efficiency
	if sv.has("diet_eff") and typeof(sv["diet_eff"]) == TYPE_DICTIONARY:
		var de: Dictionary = sv["diet_eff"]
		var eff: Dictionary = s["diet_eff"]
		if de.has("plant"): eff["plant"] = clampf(float(de["plant"]), 0.0, 1.0)
		if de.has("meat"):  eff["meat"]  = clampf(float(de["meat"]),  0.0, 1.0)
		s["diet_eff"] = eff
	# Diet required mix
	if sv.has("diet_req") and typeof(sv["diet_req"]) == TYPE_DICTIONARY:
		var dr: Dictionary = sv["diet_req"]
		var rq: Dictionary = s["diet_req"]
		if dr.has("plant_min"): rq["plant_min"] = clampf(float(dr["plant_min"]), 0.0, 1.0)
		if dr.has("meat_min"):  rq["meat_min"]  = clampf(float(dr["meat_min"]),  0.0, 1.0)
		s["diet_req"] = rq
	# Optional starting buffers
	if sv.has("start_satiety_h"):   s["satiety_h"]   = max(0.0, float(sv["start_satiety_h"]))
	if sv.has("start_hydration_h"): s["hydration_h"] = max(0.0, float(sv["start_hydration_h"]))

	a.survival = s
	if typeof(a.statuses) != TYPE_DICTIONARY:
		a.statuses = {}
	_ensure_runtime_fields(a)

static func tick(a, dt_s: float, env: Dictionary, _tick_i: int) -> void:
	if a == null or typeof(a.survival) != TYPE_DICTIONARY:
		return
	var s: Dictionary = a.survival as Dictionary
	_ensure_runtime_fields(a)
	var A: float = _activity_factor(a)
	var mass_mult: float = _mass_scale(a)

	# 1) Food
	var sat: float = float(s.get("satiety_h", 0.0))
	var kcal_per_h: float = BASAL_KCAL_PER_H / mass_mult
	var satiety_h_drain: float = (kcal_per_h / BASAL_KCAL_PER_H) * (dt_s / SEC_PER_H) * A
	sat = max(0.0, sat - satiety_h_drain)
	s["satiety_h"] = sat
	var hungry: bool = sat < HUNGRY_H and sat > STARVING_H
	var starving: bool = sat <= STARVING_H
	StatusAPI.apply(a, &"-h", hungry)
	StatusAPI.apply(a, &"-H", starving)
	if starving:
		var fat: float = float(s.get("fat_kg", 0.0))
		if fat > 0.0:
			var deficit_kcal: float = BASAL_KCAL_PER_H * (dt_s / SEC_PER_H)
			var dkg: float = deficit_kcal / FAT_KCAL_PER_KG
			fat = max(0.0, fat - dkg)
			s["fat_kg"] = fat

	# 2) Water
	var hyd: float = float(s.get("hydration_h", 0.0))
	var hyd_h_drain: float = (dt_s / SEC_PER_H) * A
	hyd = max(0.0, hyd - hyd_h_drain)
	s["hydration_h"] = hyd
	var thirsty: bool = hyd < THIRSTY_H and hyd > DEHYDRATED_H
	var dehydr: bool = hyd <= DEHYDRATED_H
	StatusAPI.apply(a, &"-t", thirsty)
	StatusAPI.apply(a, &"-T", dehydr)

	# 3) Sleep (opt-in)
	if s.has("awake_h") and s["awake_h"] != null:
		var awake: float = float(s["awake_h"]) + (dt_s / SEC_PER_H)
		s["awake_h"] = awake
		var sleepy: bool = awake >= SLEEPY_AWAKE_H and awake < EXHAUSTED_AWAKE_H
		var exhausted: bool = awake >= EXHAUSTED_AWAKE_H
		StatusAPI.apply(a, &"-s", sleepy)
		StatusAPI.apply(a, &"-S", exhausted)

	# 4) Gas (opt-in)
	if s.has("gas") and typeof(s["gas"]) == TYPE_DICTIONARY:
		var g: Dictionary = s["gas"]
		var name: StringName = g.get("name", StringName())
		var frac: float = 0.0
		if env.has("gas") and typeof(env["gas"]) == TYPE_DICTIONARY:
			var gdict: Dictionary = env["gas"]
			frac = float(gdict.get(name, 0.0))
		var low_now: bool = frac > 0.0 and frac < LO2_FRAC
		var hyp_now: bool = frac > 0.0 and frac < HYPOXIC_FRAC
		var acc_low: float = float(g.get("accum_low_s", 0.0))
		var acc_hyp: float = float(g.get("accum_hyp_s", 0.0))
		acc_low = acc_low + dt_s if low_now else 0.0
		acc_hyp = acc_hyp + dt_s if hyp_now else 0.0
		g["accum_low_s"] = acc_low
		g["accum_hyp_s"] = acc_hyp
		var low_status: bool = low_now and acc_low >= LO2_ACCUM_S
		var hyp_status: bool = hyp_now and acc_hyp >= HYPOXIC_ACCUM_S
		StatusAPI.apply(a, &"-o", low_status and !hyp_status)
		StatusAPI.apply(a, &"-O", hyp_status)
		s["gas"] = g

	# 5) Temperature (universal)
	if s.has("temp") and typeof(s["temp"]) == TYPE_DICTIONARY:
		var t: Dictionary = s["temp"]
		var core: float = float(t.get("core_C", 37.0))
		var min_C: float = float(t.get("min_C", 35.0))
		var max_C: float = float(t.get("max_C", 39.0))
		var amb: float = float(env.get("temp_C", 21.0))
		var target: float = amb + 1.0 * A
		var max_step: float = CORE_DRIFT_C_PER_S * dt_s
		var want: float = target - core
		var delta: float = clampf(want, -max_step, max_step)
		core += delta
		t["core_C"] = core

		var cold_delta: float = (min_C - core)
		var heat_delta: float = (core - max_C)
		var acc_cold: float = float(t.get("accum_cold_s", 0.0))
		var acc_heat: float = float(t.get("accum_heat_s", 0.0))
		acc_cold = acc_cold + dt_s if cold_delta >= COLD_DELTA1 else 0.0
		acc_heat = acc_heat + dt_s if heat_delta >= HEAT_DELTA1 else 0.0
		t["accum_cold_s"] = acc_cold
		t["accum_heat_s"] = acc_heat

		var chilled: bool = (cold_delta >= COLD_DELTA1) and (acc_cold >= TEMP_ACCUM_S) and (cold_delta < COLD_DELTA2)
		var hypo: bool = (cold_delta >= COLD_DELTA2) and (acc_cold >= TEMP_ACCUM_S)
		var overheated: bool = (heat_delta >= HEAT_DELTA1) and (acc_heat >= TEMP_ACCUM_S) and (heat_delta < HEAT_DELTA2)
		var heatstroke: bool = (heat_delta >= HEAT_DELTA2) and (acc_heat >= TEMP_ACCUM_S)
		StatusAPI.apply(a, &"-c", chilled and !hypo)
		StatusAPI.apply(a, &"-C", hypo)
		StatusAPI.apply(a, &"-w", overheated and !heatstroke)
		StatusAPI.apply(a, &"-W", heatstroke)

		s["temp"] = t

	a.survival = s

# Stubs for future phases -----------------------------------------------------

static func ingest(_a, _plant_kcal: float, _meat_kcal: float, _water_L: float) -> void:
	pass

static func void_solid(_a) -> void:
	pass

# Tag/policy helpers ----------------------------------------------------------

static func _has_tag(a, tag: StringName) -> bool:
	if a == null: return false
	if typeof(a.tags) == TYPE_ARRAY:
		return (tag in a.tags)
	return false

static func _required_gas_name_from_actor(a) -> StringName:
	if a == null: return &""
	if typeof(a.tags) == TYPE_ARRAY:
		for t in a.tags:
			if typeof(t) == TYPE_STRING_NAME:
				var s := String(t)
				if s.begins_with("requires_gas:"):
					return StringName(s.get_slice(":", 1))
	if typeof(a.death_policy) == TYPE_DICTIONARY:
		var found := _dfs_channel_name(a.death_policy)
		if found != &"": return found
	return &""

static func _dfs_channel_name(x) -> StringName:
	var T := typeof(x)
	if T == TYPE_DICTIONARY:
		if x.has("channel_depleted"):
			var cd = x["channel_depleted"]
			if typeof(cd) == TYPE_DICTIONARY and cd.has("name"):
				return StringName(cd["name"])
		for k in x.keys():
			var r := _dfs_channel_name(x[k])
			if r != &"": return r
	elif T == TYPE_ARRAY:
		for v in x:
			var r := _dfs_channel_name(v)
			if r != &"": return r
	return &""
