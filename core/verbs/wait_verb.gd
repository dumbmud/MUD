extends Verb
class_name WaitVerb
##
## Do nothing and spend phase.
## Wait(0): drain remaining phase this tick, else one full tick.
## Wait(k>=1): wait exactly k ticks. 1 phase = 1 ms. 100 phase per tick.

func can_start(_a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	return true

func phase_cost(a: Actor, args: Dictionary, _sim: SimManager) -> int:
	var ticks: int = int(args.get("ticks", 0))
	if ticks <= 0:
		return int(a.phase) if a.phase > 0 else SimManager.PHASE_PER_TICK
	return SimManager.PHASE_PER_TICK * max(1, ticks)

func apply(_a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	# No stamina writes in this commit.
	return true
