extends RefCounted
class_name Physio

# Modes
const MODE_BLUE   := Tuning.MODE_BLUE
const MODE_GREEN  := Tuning.MODE_GREEN
const MODE_ORANGE := Tuning.MODE_ORANGE
const MODE_RED    := Tuning.MODE_RED

static func step_distance_m(dir: Vector2i) -> float:
	var d := dir
	if d.x != 0: d.x = sign(d.x)
	if d.y != 0: d.y = sign(d.y)
	return 1.41421356237 if (abs(d.x) + abs(d.y) == 2) else 1.0

static func _mobility_score(actor: Actor) -> float:
	var mob: Dictionary = actor.capacities.get("mobility", {})
	if mob.is_empty(): return 1.0
	var best := 0.0
	for k in mob.keys():
		best = max(best, float((mob[k] as Dictionary).get("score", 0.0)))
	return clamp(best, 0.1, 10.0)

static func _mobility_multiplier(actor: Actor) -> float:
	var s := _mobility_score(actor)
	var baseline := 2.0  # two limbs ≈ 1.0 each
	var r : float = s / max(0.1, baseline)
	return (r if r <= 1.0 else 1.0 + (r - 1.0) * Tuning.MOBILITY_GAIN_ABOVE_1)

static func _mass_speed_factor(mass_kg: float) -> float:
	var m : float = max(1.0, mass_kg)
	return pow(Tuning.REF_MASS_KG / m, Tuning.MASS_SPEED_EXP)

static func locomotor_multiplier(actor: Actor) -> float:
	return clamp(_mobility_multiplier(actor) * _mass_speed_factor(actor.mass_kg), 0.05, 12.0)

static func effective_mode(actor: Actor, mode_hint: int) -> int:
	return (mode_hint if mode_hint >= 0 else clampi(actor.gait, 0, 3))  # reusing actor.gait as "effort mode"

static func step_seconds(actor: Actor, dir: Vector2i, mode_hint: int = -1) -> float:
	var meters := step_distance_m(dir)
	var m := effective_mode(actor, mode_hint)
	var base := Tuning.HUMAN_WALK_MPS * float(Tuning.MODE_SPEED_MULT.get(m, 1.0))
	var speed : float = max(0.05, base * locomotor_multiplier(actor))
	return meters / speed

# Cardio/thermo factors
static func _cardio_factor(actor: Actor) -> float:
	var c : float = max(0.01, float(actor.capacities.get("circ",  1.0)))
	var r : float = max(0.01, float(actor.capacities.get("resp",  1.0)))
	var n : float = max(0.01, float(actor.capacities.get("neuro", 1.0)))
	return pow(c * r * n, 1.0/3.0)

static func _thermo_regen_factor(actor: Actor) -> float:
	var th := actor.capacities.get("thermo", {}) as Dictionary
	return Tuning.thermo_regen_factor(th)

static func locomotor_effort_factor(actor: Actor) -> float:
	var s : float = max(0.1, _mobility_score(actor) / 2.0)
	return clamp(1.0 / s, 0.5, 4.0)

# --- Regen (constant, independent of mode) -----------------------------------
static func stamina_regen_per_sec(actor: Actor) -> float:
	var c : float = max(0.01, float(actor.capacities.get("circ",  1.0)))
	var r : float = max(0.01, float(actor.capacities.get("resp",  1.0)))
	var n : float = max(0.01, float(actor.capacities.get("neuro", 1.0)))
	var cardio := pow(c * r * n, 1.0/3.0)
	var thermo := Tuning.thermo_regen_factor(actor.capacities.get("thermo", {}) as Dictionary)
	return Tuning.BASE_STAMINA_REGEN_PER_SEC * cardio * thermo

static func stamina_regen_over(actor: Actor, seconds: float) -> float:
	return stamina_regen_per_sec(actor) * max(0.0, seconds)

# --- Costs (verbs spend; regen is separate) ----------------------------------
static func move_cost_per_sec(actor: Actor, mode_hint: int) -> float:
	var mode := mode_hint
	var effort := locomotor_effort_factor(actor)     # ↑ when mobility is low/asymmetric
	return Tuning.BASE_STAMINA_DRAIN_PER_SEC * effort * float(Tuning.MODE_DRAIN_MULT.get(mode, 1.0))

static func move_cost(actor: Actor, seconds: float, mode_hint: int) -> float:
	return move_cost_per_sec(actor, mode_hint) * max(0.0, seconds)

static func can_afford_move(actor: Actor, dir: Vector2i, mode_hint: int) -> bool:
	var mode := effective_mode(actor, mode_hint)
	var sec := step_seconds(actor, dir, mode)
	var need := move_cost(actor, sec, mode)
	var have := float(actor.stamina.get("value", 0.0))
	if have < float(Tuning.MODE_MIN_BURST.get(mode, 0.0)):
		return false
	return have >= need

# Generic verbs
static func generic_cost_per_sec(actor: Actor, intensity: float) -> float:
	var c : float = max(0.0, intensity)
	return Tuning.BASE_STAMINA_DRAIN_PER_SEC * c

static func generic_cost(actor: Actor, seconds: float, intensity: float) -> float:
	return generic_cost_per_sec(actor, intensity) * max(0.0, seconds)

static func can_afford_generic(actor: Actor, seconds: float, intensity: float) -> bool:
	var need := generic_cost(actor, seconds, intensity)
	var have := float(actor.stamina.get("value", 0.0))
	return have >= need
