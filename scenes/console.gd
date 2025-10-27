# res://scenes/console.gd
class_name Console
extends Node2D
##
## ASCII console renderer with optional facing overlay.
## Resolver is an explicit dependency set via `set_resolver()`.
## - draw uses `_get_cell(p: Vector2i)` which must return:
##     * String               → glyph only
##     * Dictionary           → { ch|glyph, fg|color, bg?, facing?, rel? }
##     * Array                → [ch, fg?, bg?]
## - If unset, a safe blank resolver is used.

@export var font: FontFile
@export var font_size := 26

var cell_px := 26                    # kept for backward compat
var cell_w_px := 26
var cell_h_px := 26
var view_cols := 0
var view_rows := 0
var grid_cols := 0
var grid_rows := 0

var _view_center := Vector2i.ZERO
var _player := Vector2i.ZERO
var _baseline := 0.0
var _view_origin_px := Vector2i.ZERO

var _get_cell: Callable = Callable(self, "_blank_cell")   # safe default

func configure(px:int, vw:int, vh:int, gw:int, gh:int, char_w_px:int = -1) -> void:
	cell_px = px
	cell_h_px = px
	cell_w_px = (char_w_px if char_w_px > 0 else px)
	view_cols = vw
	view_rows = vh
	grid_cols = gw
	grid_rows = gh
	_view_center = Vector2i(int(view_cols * 0.5), int(view_rows * 0.5))
	_view_origin_px = -Vector2i(int(view_cols * cell_px * 0.5), int(view_rows * cell_px * 0.5))
	_view_origin_px = -Vector2i(int(view_cols * cell_w_px * 0.5), int(view_rows * cell_h_px * 0.5))
	_compute_metrics()
	queue_redraw()

func set_resolver(c: Callable) -> void:
	_get_cell = c if c.is_valid() else Callable(self, "_blank_cell")

func redraw(player_world: Vector2i) -> void:
	_player = player_world
	queue_redraw()

func _compute_metrics() -> void:
	if font == null: return
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 1.0
	var h := font.get_height(font_size)
	var asc := font.get_ascent(font_size)
	var vpad: float = (cell_h_px - h) * 0.5
	_baseline = roundi(vpad + asc)

func _draw() -> void:
	if font == null: return
	if !_get_cell.is_valid(): return

	for sy in range(view_rows):
		var y_px := _view_origin_px.y + sy * cell_h_px
		var span_run := 0
		for sx in range(view_cols):
			var x_px := _view_origin_px.x + sx * cell_w_px
			var wx := _player.x + (sx - _view_center.x)
			var wy := _player.y + (sy - _view_center.y)

			var cell: Variant = _get_cell.call(Vector2i(wx, wy))

			var ch: String = ""
			var fg: Color = Color.WHITE
			var bg: Color = Color.BLACK
			var facing: Vector2i = Vector2i.ZERO
			var rel: int = 0

			if cell is String:
				ch = cell
			elif cell is Dictionary:
				ch = cell.get("ch", cell.get("glyph", ""))
				fg = cell.get("fg", cell.get("color", Color.WHITE))
				bg = cell.get("bg", Color.BLACK)
				facing = cell.get("facing", Vector2i.ZERO)
				rel = int(cell.get("rel", 0))
			elif cell is Array:
				if cell.size() > 0: ch = cell[0]
				if cell.size() > 1: fg = cell[1]
				if cell.size() > 2: bg = cell[2]

			# per-cell span (wide glyphs)
			var span := 1
			if cell is Dictionary:
				span = int(cell.get("span", 1))

			# draw background; if starting a span, paint once across the span
			if span_run <= 0:
				var w : int = max(1, span) * cell_w_px
				draw_rect(Rect2(Vector2(x_px, y_px), Vector2(w, cell_h_px)), bg, true)
			# else: skip BG; it was painted by the span head

			# draw facing overlay if provided
			if facing != Vector2i.ZERO:
				_draw_facing_border(Vector2(x_px, y_px), facing, rel)

			# draw one foreground glyph if any
			if ch != "" and ch != " " and span_run <= 0:
				draw_string(
					font,
					Vector2(x_px, y_px + _baseline),
					ch,
					HORIZONTAL_ALIGNMENT_CENTER,
					max(1, span) * cell_w_px,
					font_size,
					fg
				)
				span_run = max(0, span - 1)
			else:
				span_run = max(0, span_run - 1)

# Facing overlay: thin border segment ──────────────────────────────────────────
# TODO now that console is multi-purpose, this feels weird to have in here.
# it also assumes square tiles

func _rel_color(rel: int) -> Color:
	if rel < 0:   return Color(1, 0, 0)   # hostile: red
	if rel > 0:   return Color(0, 1, 0)   # ally: green
	return Color(0.25, 0.5, 1.0)          # neutral: blue

func _draw_facing_border(origin: Vector2, dir: Vector2i, rel: int) -> void:
	var inset: int = max(1, int(cell_px * 0.06))
	var thick: float = max(1.0, float(cell_px) * 0.045)
	var seg: int = max(4, int(cell_px * 0.45))
	var corner_len: int = max(4, int(cell_px * 0.28))
	var half: float = thick * 0.5

	var x0 := origin.x
	var y0 := origin.y
	var x1 := x0 + cell_px
	var y1 := y0 + cell_px
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5

	var c := _rel_color(rel)

	var d := dir
	if d.x != 0: d.x = sign(d.x)
	if d.y != 0: d.y = sign(d.y)

	if abs(d.x) + abs(d.y) == 1:
		# Cardinal: centered short segment on that side.
		if d.y == -1:
			var sx := cx - seg * 0.5
			var ex := cx + seg * 0.5
			var y := y0 + inset
			draw_line(Vector2(sx, y), Vector2(ex, y), c, thick)
		elif d.y == 1:
			var sx := cx - seg * 0.5
			var ex := cx + seg * 0.5
			var y := y1 - inset
			draw_line(Vector2(sx, y), Vector2(ex, y), c, thick)
		elif d.x == -1:
			var sy := cy - seg * 0.5
			var ey := cy + seg * 0.5
			var x := x0 + inset
			draw_line(Vector2(x, sy), Vector2(x, ey), c, thick)
		else:
			var sy := cy - seg * 0.5
			var ey := cy + seg * 0.5
			var x := x1 - inset
			draw_line(Vector2(x, sy), Vector2(x, ey), c, thick)
	else:
		# Diagonal corners with tiny overlap to remove gaps.
		if d.y == -1 and d.x == 1:
			var y := y0 + inset
			var x := x1 - inset
			draw_line(Vector2(x - corner_len, y), Vector2(x + half, y), c, thick)
			draw_line(Vector2(x, y - half), Vector2(x, y + corner_len), c, thick)
		elif d.y == 1 and d.x == 1:
			var y := y1 - inset
			var x := x1 - inset
			draw_line(Vector2(x - corner_len, y), Vector2(x + half, y), c, thick)
			draw_line(Vector2(x, y + half), Vector2(x, y - corner_len), c, thick)
		elif d.y == 1 and d.x == -1:
			var y := y1 - inset
			var x := x0 + inset
			draw_line(Vector2(x - half, y), Vector2(x + corner_len, y), c, thick)
			draw_line(Vector2(x, y + half), Vector2(x, y - corner_len), c, thick)
		elif d.y == -1 and d.x == -1:
			var y := y0 + inset
			var x := x0 + inset
			draw_line(Vector2(x - half, y), Vector2(x + corner_len, y), c, thick)
			draw_line(Vector2(x, y - half), Vector2(x, y + corner_len), c, thick)

# Safe default resolver ────────────────────────────────────────────────────────

func _blank_cell(_p: Vector2i) -> String:
	return " "
