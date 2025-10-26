extends Verb
class_name WaitVerb
##
## Do nothing and spend phase.
## Semantics:
##   - Wait(0): if a.phase > 0, drain the current tick’s remaining phase;
##              if a.phase == 0, consume one full tick on the next tick.
##   - Wait(k>=1): wait exactly k full ticks (cost = k * 100).
## No scheduler special-casing. 1 phase = 1 ms. 100 phase per tick.

const PHASE_PER_TICK := 100

func can_start(_a: Actor, args: Dictionary, _sim: SimManager) -> bool:
	# Allow starting regardless of current phase to avoid driver coupling.
	var _ticks: int = int(args.get("ticks", 0))
	return true

func phase_cost(a: Actor, args: Dictionary, _sim: SimManager) -> int:
	var ticks: int = int(args.get("ticks", 0))
	if ticks <= 0:
		# Drain-now if budget remains; otherwise defer by one full tick.
		return int(a.phase) if a.phase > 0 else PHASE_PER_TICK
	return PHASE_PER_TICK * max(1, ticks)

func apply(_a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	return true
