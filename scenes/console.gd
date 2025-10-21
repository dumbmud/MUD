class_name Console
extends Node2D

@export var font: FontFile
@export var font_size := 64

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
	_center = Vector2i(int(VISIBLE_W * 0.5), int(VISIBLE_H * 0.5))
	# put top-left of visible window at exactly -half size (½-cell shift included)
	_screen_origin_px = -Vector2i(int(VISIBLE_W * CELL * 0.5), int(VISIBLE_H * CELL * 0.5))
	_compute_metrics()
	queue_redraw()

func _compute_metrics() -> void:
	if font == null: return
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 1.0

	var h := font.get_height(font_size)
	var asc := font.get_ascent(font_size)
	var vpad: float = (CELL - h) * 0.5      # allow negative
	_baseline = int(round(vpad + asc))
	_hpad = 0                                # not used anymore


func redraw(player_world: Vector2i, get_world_callable: Callable) -> void:
	_player = player_world
	_get_world = get_world_callable
	queue_redraw()

func _draw() -> void:
	var size_px := Vector2(GRID_W * CELL, GRID_H * CELL)
	draw_rect(Rect2(-size_px * 0.5, size_px), Color.BLACK, true)
	if font == null: return
	draw_line(Vector2(-10000,0), Vector2(10000,0), Color.RED)
	draw_line(Vector2(0,-10000), Vector2(0,10000), Color.RED)
	for sy in range(VISIBLE_H):
		var y_px := _screen_origin_px.y + sy * CELL
		for sx in range(VISIBLE_W):
			var x_px := _screen_origin_px.x + sx * CELL
			var wx := _player.x + (sx - _center.x)
			var wy := _player.y + (sy - _center.y)
			var ch: String = _get_world.call(Vector2i(wx, wy))
			if ch == "" or ch == " ": continue
			# left edge of cell, baseline y; width=CELL centers the glyph visually
			draw_string(font, Vector2(x_px, y_px + _baseline),
				ch, HORIZONTAL_ALIGNMENT_CENTER, CELL, font_size)

	# center cell
	var mid_tl := -Vector2i(int(CELL * 0.5), int(CELL * 0.5))
	draw_string(font, Vector2(mid_tl.x, mid_tl.y + _baseline),
		"@", HORIZONTAL_ALIGNMENT_CENTER, CELL, font_size)
