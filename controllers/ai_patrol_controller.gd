# res://controllers/ai_patrol_controller.gd
extends CommandSource
class_name AIPatrolController
##
## Minimal patrol AI:
## - Try to move in a fixed direction.
## - If blocked, flip direction and yield the rest of this tick (Wait(1)).
## - No mode checks; scheduler is pure and mode-agnostic.

var _dir: Vector2i = Vector2i(1, 0)

func set_initial_dir(d: Vector2i) -> void:
	_dir = Vector2i(clamp(d.x, -1, 1), clamp(d.y, -1, 1))

func dequeue(a: Actor, sim: SimManager) -> Variant:
	var cmd := {"verb": &"Move", "args": {"dir": _dir}}
	var v := VerbRegistry.get_verb(&"Move")
	if v != null and v.can_start(a, cmd["args"], sim):
		return cmd
	# Blocked: flip and yield this tick to avoid thrashing in rounds.
	_dir = -_dir
	return {"verb": &"Wait", "args": {"ticks": 0}}
