class_name DebugWorld
extends Node

# Map bounds
const GRID_MIN := Vector2i(-20, -20)
const GRID_MAX := Vector2i(20, 20)

# Helpers
func _in_x(x:int, a:int, b:int) -> bool: return x >= a and x <= b
func _in_y(y:int, a:int, b:int) -> bool: return y >= a and y <= b

func is_wall(p: Vector2i) -> bool:
	# 0) Outer border
	if p.x == GRID_MIN.x or p.x == GRID_MAX.x or p.y == GRID_MIN.y or p.y == GRID_MAX.y:
		return true

	# 1) Partitions (left | center | right) with door gaps at y=0
	# Left partition wall at x = -12 (gap at y=0)
	if p.x == -12 and not (p.y == 0 and _in_y(p.y, GRID_MIN.y+1, GRID_MAX.y-1)):
		return true
	# Right partition wall at x = 12 (gap at y=0)
	if p.x == 12 and not (p.y == 0 and _in_y(p.y, GRID_MIN.y+1, GRID_MAX.y-1)):
		return true

	# --- LEFT SECTION: Race lane (narrow corridor) ---
	# Two horizontal wall rails y = -9 and y = -7 across x in [-18, -13]
	if (p.y == -9 or p.y == -7) and _in_x(p.x, -18, -13):
		return true

	# --- CENTER SECTION: Doorway choke ---
	# Vertical wall at x = -2 with a single door gap at y = 0, spanning y in [-10, 10]
	if p.x == -2 and _in_y(p.y, -10, 10) and p.y != 0:
		return true

	# --- RIGHT SECTION: Diagonal-corner blocker test ---
	# Two orthogonal walls that touch only at a corner near (15,6)
	if p == Vector2i(15, 6) or p == Vector2i(16, 5):
		return true

	return false

func is_floor(p: Vector2i) -> bool:
	# Inside bounds and not a wall → floor
	if p.x <= GRID_MIN.x or p.x >= GRID_MAX.x or p.y <= GRID_MIN.y or p.y >= GRID_MAX.y:
		return false
	return !is_wall(p)

func is_passable(p: Vector2i) -> bool:
	return is_floor(p)

func glyph(p: Vector2i) -> String:
	if is_wall(p): return "#"
	if is_floor(p): return "."
	return " "
