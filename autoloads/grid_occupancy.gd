# res://core/support/grid_occupancy.gd
# Add as Autoload: Name "GridOccupancy"
extends Node

signal claimed(id: int, pos: Vector2i)
signal released(id: int, pos: Vector2i)
signal moved(id: int, from: Vector2i, to: Vector2i)
signal reset()

var _by_pos: Dictionary = {} # Dictionary[Vector2i, int]
var _by_id: Dictionary = {}  # Dictionary[int, Vector2i]

func clear() -> void:
	_by_pos.clear()
	_by_id.clear()
	emit_signal("reset")

# ---- queries ----
func has_pos(p: Vector2i) -> bool:
	return _by_pos.has(p)

func has_id(id: int) -> bool:
	return _by_id.has(id)

func id_at(p: Vector2i) -> int:
	return int(_by_pos.get(p, -1))

func pos_of(id: int) -> Vector2i:
	return _by_id.get(id, null)

# ---- mutation ----
func claim(id: int, p: Vector2i) -> bool:
	if has_id(id): return false
	if has_pos(p): return false
	_by_id[id] = p
	_by_pos[p] = id
	emit_signal("claimed", id, p)
	return true

func release_pos(p: Vector2i) -> bool:
	if !has_pos(p): return false
	var id := int(_by_pos[p])
	_by_pos.erase(p)
	_by_id.erase(id)
	emit_signal("released", id, p)
	return true

func release_id(id: int) -> bool:
	if !has_id(id): return false
	var p: Vector2i = _by_id[id]
	_by_id.erase(id)
	_by_pos.erase(p)
	emit_signal("released", id, p)
	return true

func can_move_to(_id: int, to: Vector2i) -> bool:
	# allow moving into your own current tile, disallow others
	return !has_pos(to)

func move(id: int, to: Vector2i) -> bool:
	if !has_id(id): return false
	var from: Vector2i = _by_id[id]
	if to == from: return true
	if has_pos(to): return false
	_by_pos.erase(from)
	_by_pos[to] = id
	_by_id[id] = to
	emit_signal("moved", id, from, to)
	return true
