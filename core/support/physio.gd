# res://core/support/physio.gd
extends RefCounted
class_name Physio
##
## Pure speed and stamina math.
## Units: meters (1 tile = 1.0 m; diagonal = √2), seconds.
## No references to world/UI/scheduler.
## Locomotion is anatomy-derived.
## - Sum of zone_effectors.locomotor vs a biped baseline (2.0).
## - Diminishing returns above baseline.
## - Asymmetry tax for L/R mismatch.
## - Size slows linearly.
## Drain scales with inverse capacity so missing limbs cost more stamina per sec.

const GAIT_SNEAK := 0
const GAIT_WALK  := 1
const GAIT_JOG   := 2
const GAIT_SPRINT:= 3

# ── Locomotion coupling constants ────────────────────────────────────────────
const LOC_BASELINE_SUM := 2.0      # two legs at 1.0 each
const LOC_DIMINISH_GAIN := 0.6     # gain above baseline is softened
const ASYM_K := 0.25               # strength of asymmetry penalty
const ASYM_MIN := 0.70             # floor for asymmetry factor
const EFFORT_MIN_CAP := 0.25       # avoid infinite effort when capacity≈0

static func gait_base_speed(gait: int) -> float:
	match gait:
		GAIT_SNEAK:  return 1.0
		GAIT_WALK:   return 2.0
		GAIT_JOG:    return 3.5
		GAIT_SPRINT: return 5.0
		_:           return 2.0

# ── Capacity helpers ─────────────────────────────────────────────────────────
static func _sum_locomotor_all(actor: Actor) -> float:
	var sum := 0.0
	for z in actor.zone_effectors.keys():
		var eff: Dictionary = actor.zone_effectors[z]
		if eff.has(&"locomotor"):
			sum += float(eff[&"locomotor"])
	return sum

static func _sum_locomotor_ids(actor: Actor, ids: Array) -> float:
	var s := 0.0
	for id in ids:
		var eff: Dictionary = actor.zone_effectors.get(id, {})
		if eff.has(&"locomotor"):
			s += float(eff[&"locomotor"])
	return s

static func _asymmetry_factor(actor: Actor) -> float:
	var left_ids: Array = actor.targeting_index.get(&"left_leg", [])
	var right_ids: Array = actor.targeting_index.get(&"right_leg", [])
	if left_ids.is_empty() and right_ids.is_empty():
		return 1.0
	var l := _sum_locomotor_ids(actor, left_ids)
	var r := _sum_locomotor_ids(actor, right_ids)
	var tot := l + r
	if tot <= 0.0:
		return ASYM_MIN
	var imbalance : float = abs(l - r) / tot
	return clamp(1.0 - ASYM_K * imbalance, ASYM_MIN, 1.0)

# ── Speed multiplier (used by step_seconds) ──────────────────────────────────
static func locomotor_multiplier(actor: Actor) -> float:
	var cap := _sum_locomotor_all(actor)          # total locomotor capacity
	var r := cap / LOC_BASELINE_SUM               # capacity vs biped baseline
	var gain := r if r <= 1.0 else (1.0 + (r - 1.0) * LOC_DIMINISH_GAIN)
	var asym := _asymmetry_factor(actor)
	var size_slow : float = 1.0 / max(0.1, float(actor.size_scale))
	return clamp(gain * asym * size_slow, 0.1, 10.0)

# ── Effort factor (used by stamina drain) ────────────────────────────────────
static func locomotor_effort_factor(actor: Actor) -> float:
	var cap : float = max(EFFORT_MIN_CAP, _sum_locomotor_all(actor))
	var r := cap / LOC_BASELINE_SUM
	var asym := _asymmetry_factor(actor)
	# Less capacity or more asymmetry → more effort per second.
	return clamp(1.0 / max(0.1, r * asym), 0.5, 4.0)

static func step_distance_m(dir: Vector2i) -> float:
	var d := dir
	if d.x != 0: d.x = sign(d.x)
	if d.y != 0: d.y = sign(d.y)
	return 1.41421356237 if (abs(d.x) + abs(d.y) == 2) else 1.0

static func effective_gait(actor: Actor, gait_hint: int) -> int:
	var g := gait_hint if gait_hint >= 0 else clampi(actor.gait, 0, 3)
	if g == GAIT_SPRINT and actor.stamina < actor.sprint_gate:
		g = GAIT_JOG
	return g

static func step_seconds(actor: Actor, dir: Vector2i, gait_hint: int = -1) -> float:
	var meters := step_distance_m(dir)
	var g := effective_gait(actor, gait_hint)
	var speed : float = max(0.01, gait_base_speed(g) * locomotor_multiplier(actor))
	return meters / speed

# ── stamina (time-based) ─────────────────────────────────────────────────────
const STAMINA_DRAIN_PER_SEC := 1.0
const STAMINA_REGEN_PER_SEC := 0.5

static func stamina_delta_on_move(actor: Actor, seconds: float) -> float:
	var effort := locomotor_effort_factor(actor)
	return -STAMINA_DRAIN_PER_SEC * effort * max(0.0, seconds)

static func stamina_delta_on_wait(_actor: Actor, seconds: float) -> float:
	return  STAMINA_REGEN_PER_SEC * max(0.0, seconds)
	
