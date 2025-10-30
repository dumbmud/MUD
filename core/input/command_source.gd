# res://core/input/command_source.gd
class_name CommandSource
extends RefCounted
##
## Abstract command source for an Actor.
## Scheduler asks each source for the next command at boundaries.
## Return a Dictionary { "verb": StringName, "args": Dictionary } or null.
##
## Notes:
## - No auto-fallbacks here. Idle is allowed.
## - No per-tick caps; the scheduler may pull multiple commands per tick if phase allows.
## - Sources may buffer taps and/or synthesize holds.

func dequeue(_a: Actor, _sim: SimManager) -> Variant:
	return null

func push(_cmd: Dictionary) -> void:
	# Optional: sources that accept tap commands override this.
	pass

func set_hold_sampler(_callable: Callable) -> void:
	# Optional: sources that want held commands override this.
	pass
