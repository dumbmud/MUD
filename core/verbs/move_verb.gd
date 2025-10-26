# res://core/verbs/move_verb.gd
extends Verb
class_name MoveVerb
##
## Move one tile if passable and unoccupied.
## Corner rule: diagonal allowed unless both adjacent orthogonals are blocked.
## Uses Physio for distance→seconds and stamina math.
##   - 1 phase = 1 ms; phase cost = round(Physio.step_seconds * 1000).
##   - stamina deltas computed via Physio but not yet applied.

static func _move_blocked(sim: SimManager, from: Vector2i, dir: Vector2i, target: Vector2i) -> bool:
	var world := sim.world
	if world == null: return true
	if !world.is_passable(target): return true
	# Diagonal squeeze check: forbid only when both orthogonals are impassable.
	if abs(dir.x) + abs(dir.y) == 2:
		var side_a := Vector2i(from.x + dir.x, from.y)
		var side_b := Vector2i(from.x, from.y + dir.y)
		if !world.is_passable(side_a) and !world.is_passable(side_b):
			return true
	return false

func can_start(a: Actor, args: Dictionary, sim: SimManager) -> bool:
	var d: Vector2i = args.get("dir", Vector2i.ZERO)
	if d == Vector2i.ZERO: return false
	if d.x != 0: d.x = sign(d.x)
	if d.y != 0: d.y = sign(d.y)
	var t := a.grid_pos + d
	if _move_blocked(sim, a.grid_pos, d, t): return false
	if GridOccupancy.has_pos(t): return false
	return true

func phase_cost(a: Actor, args: Dictionary, _sim: SimManager) -> int:
	var d: Vector2i = args.get("dir", Vector2i.ZERO)
	var seconds := Physio.step_seconds(a, d)
	return max(1, int(round(seconds * 1000.0)))

func apply(a: Actor, args: Dictionary, sim: SimManager) -> bool:
	var d: Vector2i = args.get("dir", Vector2i.ZERO)
	if d.x != 0: d.x = sign(d.x)
	if d.y != 0: d.y = sign(d.y)
	var t := a.grid_pos + d
	if _move_blocked(sim, a.grid_pos, d, t): return false
	if GridOccupancy.has_pos(t): return false
	a.set_facing(d)
	if !GridOccupancy.move(a.actor_id, t): return false
	a.grid_pos = t
	# Stamina accounting placeholder (value not applied yet).
	# Leave stamina accounting for a later commit (no state writes now)
	# var _unused := Physio.stamina_delta_on_move(a, Physio.step_seconds(a, d))
	return true
