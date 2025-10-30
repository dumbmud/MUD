class_name WaitVerb
extends Verb

func can_start(_a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	return true

func phase_cost(a: Actor, args: Dictionary, _sim: SimManager) -> int:
	var ticks: int = int(args.get("ticks", 0))
	if ticks <= 0:
		return int(a.phase) if a.phase > 0 else SimManager.PHASE_PER_TICK
	return SimManager.PHASE_PER_TICK * max(1, ticks)

func apply(a: Actor, args: Dictionary, _sim: SimManager) -> bool:
	return true
