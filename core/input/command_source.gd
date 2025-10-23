# res://core/input/command_source.gd
extends RefCounted
class_name CommandSource
##
## Abstract command source for an Actor.
## SimManager asks each actor’s source for the next command at boundaries.
## Return a Dictionary { "verb": StringName, "args": Dictionary } or null.
##
## Subclasses may:
##  - buffer “taps” (discrete inputs)
##  - synthesize “holds” (continuous inputs)
##  - implement AI decisions
##
## Contract:
##   dequeue(a, sim) is side-effect free on failure (returning null).
##   It may mutate internal queues when it returns a command.

func dequeue(_a: Actor, _sim: SimManager) -> Variant:
	return null

func push(_cmd: Dictionary) -> void:
	# Optional: sources that accept tap commands override this.
	pass

func set_hold_sampler(_callable: Callable) -> void:
	# Optional: sources that want held commands override this.
	pass
