# res://autoloads/grid_occupancy.gd
# Add as Autoload: Name "GridOccupancy"
extends Node
##
## Minimal tile occupancy map: id ↔ pos.
## No world rules here. Verbs perform passability/bounds checks.
## Emits signals for observers (e.g., debug, AI, UI).
##

signal claimed(id: int, pos: Vector2i)
signal released(id: int, pos: Vector2i)
signal moved(id: int, from: Vector2i, to: Vector2i)
signal reset()

var _by_pos: Dictionary = {} # Dictionary[Vector2i, int]
var _by_id: Dictionary = {}  # Dictionary[int, Vector2i]

# ── lifecycle ────────────────────────────────────────────────────────────────

func clear() -> void:
	_by_pos.clear()
	_by_id.clear()
	emit_signal("reset")

# ── queries ─────────────────────────────────────────────────────────────────

func has_pos(p: Vector2i) -> bool:
	return _by_pos.has(p)

func has_id(id: int) -> bool:
	return _by_id.has(id)

func id_at(p: Vector2i) -> int:
	# Returns -1 if empty.
	return int(_by_pos.get(p, -1))

func pos_of(id: int) -> Variant:
	# Returns Vector2i when present, null when not.
	return _by_id.get(id, null)

# ── mutation ────────────────────────────────────────────────────────────────

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

func move(id: int, to: Vector2i) -> bool:
	# Moves id to `to` if destination empty or is the same tile.
	# World rules (bounds, passability) are not checked here.
	if !has_id(id): return false
	var from: Vector2i = _by_id[id]
	if to == from: return true
	if has_pos(to): return false
	_by_pos.erase(from)
	_by_pos[to] = id
	_by_id[id] = to
	emit_signal("moved", id, from, to)
	return true

# ── dev guards (optional) ───────────────────────────────────────────────────

func _invariant() -> void:
	# Call manually in debug tools if needed.
	for p in _by_pos.keys():
		var id := int(_by_pos[p])
		assert(_by_id.has(id) and _by_id[id] == p)
	for id in _by_id.keys():
		var p: Vector2i = _by_id[id]
		assert(_by_pos.has(p) and int(_by_pos[p]) == id)
