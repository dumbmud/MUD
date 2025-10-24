# res://core/verbs/wait_verb.gd
extends Verb
class_name WaitVerb
##
## Do nothing and spend phase.
## Semantics:
##   - Wait(0): drain the *current* tick’s remaining phase budget (no carry).
##              Requires a.phase > 0 or it won’t start.
##   - Wait(k>=1): wait exactly k full ticks of game time
##                 (cost = k * a.phase_per_tick). May span ticks.
## No scheduler special-casing.

func can_start(a: Actor, args: Dictionary, _sim: SimManager) -> bool:
	var ticks: int = int(args.get("ticks", 0))
	if ticks <= 0:
		return a.phase > 0        # cannot start if no budget to drain
	return true

func phase_cost(a: Actor, args: Dictionary, _sim: SimManager) -> int:
	var ticks: int = int(args.get("ticks", 0))
	if ticks <= 0:
		return int(a.phase)       # drain remaining budget this tick
	return int(a.phase_per_tick) * max(1, ticks)

func apply(_a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	return true
