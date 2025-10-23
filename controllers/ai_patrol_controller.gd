# res://controllers/ai_patrol_controller.gd
extends CommandSource
class_name AIPatrolController
##
## Tiny placeholder AI:
## - Attempts to move in a fixed direction.
## - If blocked, flips direction next time.
## - In RT, injects Wait(1) when unable to move.

var _dir := Vector2i(1, 0)

func set_initial_dir(d: Vector2i) -> void:
	_dir = Vector2i(clamp(d.x, -1, 1), clamp(d.y, -1, 1))

func dequeue(a: Actor, sim: SimManager) -> Variant:
	var cmd := {"verb": &"Move", "args": {"dir": _dir}}
	var v := VerbRegistry.get_verb(&"Move")
	if v != null and v.can_start(a, cmd["args"], sim):
		return cmd
	# Flip if blocked; try opposite on next boundary.
	_dir = -_dir
	if sim.mode == SimManager.GameMode.REAL_TIME:
		return {"verb": &"Wait", "args": {"ticks": 1}}
	return null
