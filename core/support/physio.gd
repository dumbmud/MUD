# res://core/support/physio.gd
extends RefCounted
class_name Physio
##
## Pure speed and stamina math.
## Units: meters (1 tile = 1.0 m; diagonal = √2), seconds.
## No references to world/UI/scheduler.

const GAIT_SNEAK := 0
const GAIT_WALK  := 1
const GAIT_JOG   := 2
const GAIT_SPRINT:= 3

static func gait_base_speed(gait: int) -> float:
	match gait:
		GAIT_SNEAK:  return 1.0
		GAIT_WALK:   return 2.0
		GAIT_JOG:    return 3.5
		GAIT_SPRINT: return 5.0
		_:           return 2.0

static func locomotor_multiplier(actor: Actor) -> float:
	# Average locomotor effector across zones. Size_scale slows linearly.
	var sum := 0.0
	var n := 0
	for z in actor.zone_effectors.keys():
		var eff: Dictionary = actor.zone_effectors[z]
		if eff.has(&"locomotor"):
			sum += float(eff[&"locomotor"])
			n += 1
	var eff_avg := (sum / n) if n > 0 else 1.0
	var size_slow : float = 1.0 / max(0.1, float(actor.size_scale))
	return clamp(eff_avg * size_slow, 0.1, 10.0)

static func step_distance_m(dir: Vector2i) -> float:
	var d := dir
	if d.x != 0: d.x = sign(d.x)
	if d.y != 0: d.y = sign(d.y)
	return 1.41421356237 if (abs(d.x) + abs(d.y) == 2) else 1.0

static func step_seconds(actor: Actor, dir: Vector2i) -> float:
	# Default gait = WALK until Actor.gait lands in a later commit.
	var meters := step_distance_m(dir)
	var speed : float = max(0.01, gait_base_speed(GAIT_WALK) * locomotor_multiplier(actor))
	return meters / speed

# Placeholders for later commits (no state writes yet)
const STAMINA_DRAIN_PER_SEC := 1.0
const STAMINA_REGEN_PER_SEC := 0.5

static func stamina_delta_on_move(_actor: Actor, seconds: float) -> float:
	return -STAMINA_DRAIN_PER_SEC * max(0.0, seconds)

static func stamina_delta_on_wait(_actor: Actor, seconds: float) -> float:
	return  STAMINA_REGEN_PER_SEC * max(0.0, seconds)
