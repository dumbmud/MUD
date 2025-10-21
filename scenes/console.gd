class_name Console
extends Node2D

@export var font: FontFile
@export var font_size := 24

var CELL := 24
var VISIBLE_W := 0
var VISIBLE_H := 0
var GRID_W := 0
var GRID_H := 0

var _center := Vector2i.ZERO
var _player := Vector2i.ZERO
var _get_world: Callable

var _baseline := 0.0
var _hpad := 0.0
var _screen_origin_px := Vector2i.ZERO

func configure(cell_px:int, vw:int, vh:int, gw:int, gh:int) -> void:
	CELL = cell_px
	VISIBLE_W = vw
	VISIBLE_H = vh
	GRID_W = gw
	GRID_H = gh
	_center = Vector2i(VISIBLE_W / 2, VISIBLE_H / 2)  # floor
	# put top-left of visible window at exactly -half size (½-cell shift included)
	_screen_origin_px = -Vector2i((VISIBLE_W * CELL) / 2, (VISIBLE_H * CELL) / 2)
	_compute_metrics()
	queue_redraw()

func _compute_metrics() -> void:
	if font == null: return
	var h := font.get_height(font_size)
	var asc := font.get_ascent(font_size)
	var vpad : float = max(0.0, (CELL - h) * 0.5)
	_baseline = int(vpad + asc + 0.5)
	var char_w := font.get_string_size("@", font_size).x
	_hpad = int(max(0.0, (CELL - char_w) * 0.5))

func redraw(player_world: Vector2i, get_world_callable: Callable) -> void:
	_player = player_world
	_get_world = get_world_callable
	queue_redraw()

func _draw() -> void:
	# big console centered at origin
	var size_px := Vector2(GRID_W * CELL, GRID_H * CELL)
	draw_rect(Rect2(-size_px * 0.5, size_px), Color.BLACK, true)
	if font == null: return

	for sy in range(VISIBLE_H):
		var y_px := _screen_origin_px.y + sy * CELL
		for sx in range(VISIBLE_W):
			var x_px := _screen_origin_px.x + sx * CELL
			var wx := _player.x + (sx - _center.x)
			var wy := _player.y + (sy - _center.y)
			var ch : String = _get_world.call(Vector2i(wx, wy))
			if ch == "" or ch == " ": continue
			draw_string(font, Vector2(x_px + _hpad, y_px + _baseline), ch)

	# draw '@' in the center cell (whose top-left is now at -CELL/2, -CELL/2)
	var mid_tl := -Vector2i(CELL / 2, CELL / 2)
	draw_string(font, Vector2(mid_tl.x + _hpad, mid_tl.y + _baseline), "@")
