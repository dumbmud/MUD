# res://core/verbs/move_verb.gd
extends Verb
class_name MoveVerb
##
## Move one tile if passable and unoccupied.
## Corner rule: diagonal allowed unless both adjacent orthogonals are blocked.
## Phase model: base costs for a 100-per-tick budget.
##   - Cardinal: 500 (≈5 ticks)
##   - Diagonal: 707 (≈7.07 ticks)
## Variability comes from actor.speed_mult (≥0). Regen is uniform for all species.

const COST_CARDINAL := 500
const COST_DIAGONAL := 707

static func _cost_for_dir(d: Vector2i) -> int:
	return COST_DIAGONAL if (abs(d.x) + abs(d.y) == 2) else COST_CARDINAL

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
	var base := _cost_for_dir(d)
	var speed_mult : float = max(0.0, float(a.speed_mult))
	return max(1, int(round(base * speed_mult)))

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
	return true
