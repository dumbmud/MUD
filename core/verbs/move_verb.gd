class_name MoveVerb
extends Verb

static func _move_blocked(sim: SimManager, from: Vector2i, dir: Vector2i, target: Vector2i) -> bool:
	var world := sim.world
	if world == null: return true
	if !world.is_passable(target): return true
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

	var mode := int(args.get("gait", -1))
	if !Physio.can_afford_move(a, d, mode):
		MessageBus.send_once_per_tick(&"tired_move", "Too tired for current mode", &"warn", sim.tick_count, a.actor_id)
		return false
	return true

func phase_cost(a: Actor, args: Dictionary, _sim: SimManager) -> int:
	var d: Vector2i = args.get("dir", Vector2i.ZERO)
	var g_hint := int(args.get("gait", -1))
	var seconds := Physio.step_seconds(a, d, g_hint)
	return max(1, int(round(seconds * 1000.0)))

func apply(a: Actor, args: Dictionary, sim: SimManager) -> bool:
	var d: Vector2i = args.get("dir", Vector2i.ZERO)
	if d.x != 0: d.x = sign(d.x)
	if d.y != 0: d.y = sign(d.y)
	var t := a.grid_pos + d
	if _move_blocked(sim, a.grid_pos, d, t): return false
	if GridOccupancy.has_pos(t): return false

	a.set_facing(d)
	if !GridOccupancy.move(a.actor_id, t):
		return false
	a.grid_pos = t
	
	
	var mode := int(args.get("gait", -1))
	var seconds := Physio.step_seconds(a, d, mode)
	var cost := Physio.move_cost(a, seconds, mode)
	var st: Dictionary = a.stamina
	st["value"] = clampf(float(st.get("value", 0.0)) - cost, 0.0, float(st.get("max", 100.0)))
	a.stamina = st

	
	return true
