# res://world/world_test.gd
class_name WorldTest
extends WorldAPI

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

	# 1) Partitions with door gaps at y=0
	if p.x == -12 and p.y != 0: return true
	if p.x == 12  and p.y != 0: return true

	# Left section: race lane
	if (p.y == -9 or p.y == -7) and _in_x(p.x, -18, -13):
		return true

	# Center: doorway choke at x=-2, gap at y=0
	if p.x == -2 and _in_y(p.y, -10, 10) and p.y != 0:
		return true

	# Right: corner-touch blocker
	if p == Vector2i(15, 6) or p == Vector2i(16, 5):
		return true

	return false

func _is_inside(p: Vector2i) -> bool:
	return p.x > GRID_MIN.x and p.x < GRID_MAX.x and p.y > GRID_MIN.y and p.y < GRID_MAX.y

func is_passable(p: Vector2i) -> bool:
	return _is_inside(p) and !is_wall(p)

func glyph(p: Vector2i) -> String:
	if is_wall(p): return "#"
	if is_passable(p): return "."
	return " "
