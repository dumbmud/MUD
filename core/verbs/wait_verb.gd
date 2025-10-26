extends Verb
class_name WaitVerb
##
## Do nothing and spend phase.
## Wait(0): drain remaining phase this tick; if none, spend one full tick.
## Wait(k>=1): wait exactly k ticks.
## 1 phase = 1 ms. 100 ms per tick.

func can_start(_a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	return true

func phase_cost(a: Actor, args: Dictionary, _sim: SimManager) -> int:
	var ticks: int = int(args.get("ticks", 0))
	if ticks <= 0:
		return int(a.phase) if a.phase > 0 else SimManager.PHASE_PER_TICK
	return SimManager.PHASE_PER_TICK * max(1, ticks)

func apply(a: Actor, args: Dictionary, _sim: SimManager) -> bool:
	# Regen is proportional to elapsed time.
	var ticks: int = int(args.get("ticks", 0))
	var ms: int
	if ticks <= 0:
		ms = int(a.phase) if a.phase > 0 else SimManager.PHASE_PER_TICK
	else:
		ms = SimManager.PHASE_PER_TICK * max(1, ticks)
	var seconds := float(ms) * 0.001
	var delta := Physio.stamina_delta_on_wait(a, seconds)
	a.stamina = clampf(a.stamina + delta, 0.0, a.stamina_max)
	return true
