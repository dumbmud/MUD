# res://core/verbs/wait_verb.gd
extends Verb
class_name WaitVerb
##
## Spend N ticks worth of phase doing nothing.
## Momentum reset: at commit, phase becomes 0 so the next turn starts fresh.

func can_start(_a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	return true

func phase_cost(a: Actor, args: Dictionary, _sim: SimManager) -> int:
	var ticks: int = int(args.get("ticks", 1))
	return max(1, a.phase_per_tick * ticks)

func apply(a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	a.phase = 0
	return true
