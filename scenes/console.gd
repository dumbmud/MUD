class_name Console
extends Node2D

@export var font: FontFile
@export var font_size := 64

var cell_px := 64
var view_cols := 0
var view_rows := 0
var grid_cols := 0
var grid_rows := 0

var _view_center := Vector2i.ZERO
var _player := Vector2i.ZERO
var _get_cell: Callable

var _baseline := 0.0
var _view_origin_px := Vector2i.ZERO

func configure(px:int, vw:int, vh:int, gw:int, gh:int) -> void:
	cell_px = px
	view_cols = vw
	view_rows = vh
	grid_cols = gw
	grid_rows = gh
	_view_center = Vector2i(int(view_cols * 0.5), int(view_rows * 0.5))
	_view_origin_px = -Vector2i(int(view_cols * cell_px * 0.5), int(view_rows * cell_px * 0.5))
	_compute_metrics()
	queue_redraw()

func _compute_metrics() -> void:
	if font == null: return
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 1.0
	var h := font.get_height(font_size)
	var asc := font.get_ascent(font_size)
	var vpad: float = (cell_px - h) * 0.5
	_baseline = int(round(vpad + asc))

func redraw(player_world: Vector2i, get_world_callable: Callable) -> void:
	_player = player_world
	_get_cell = get_world_callable
	queue_redraw()

func _draw() -> void:
	if font == null: return

	for sy in range(view_rows):
		var y_px := _view_origin_px.y + sy * cell_px
		for sx in range(view_cols):
			var x_px := _view_origin_px.x + sx * cell_px
			var wx := _player.x + (sx - _view_center.x)
			var wy := _player.y + (sy - _view_center.y)

			var cell: Variant = _get_cell.call(Vector2i(wx, wy))

			var ch: String = ""
			var fg: Color = Color.WHITE
			var bg: Color = Color.BLACK

			match typeof(cell):
				TYPE_STRING:
					ch = cell
				TYPE_DICTIONARY:
					ch = cell.get("ch", cell.get("glyph", ""))
					fg = cell.get("fg", cell.get("color", Color.WHITE))
					bg = cell.get("bg", Color.BLACK)
				TYPE_ARRAY:
					if cell.size() > 0: ch = cell[0]
					if cell.size() > 1: fg = cell[1]
					if cell.size() > 2: bg = cell[2]
				_:
					pass

			# draw background per cell
			draw_rect(Rect2(Vector2(x_px, y_px), Vector2(cell_px, cell_px)), bg, true)

			# draw one foreground glyph if any
			if ch != "" and ch != " ":
				draw_string(
					font,
					Vector2(x_px, y_px + _baseline),
					ch,
					HORIZONTAL_ALIGNMENT_CENTER,
					cell_px,
					font_size,
					fg
				)
