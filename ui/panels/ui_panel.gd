# file: res://ui/panels/ui_panel.gd
extends Node2D
class_name UIPanel
##
## Reusable console-driven panel shell.
## Owns: frame, title, close, drag, edge/corner resize, wheel scroll, scrollbar.
## Children override content via two hooks:
##   - content_total_rows() -> int                        # total virtual rows
##   - content_cell_at(col:int, src_row:int, max:int)     # char/dict for a source row
##
## Notes:
## - Uses the existing Console node as a child.
## - Enables Console.auto_span for multi-column glyphs in UI panels.
## - World view Consoles remain with auto_span = false.

# Sizing
const CELL_H := 26
const CHAR_W := 13
const MIN_ROWS := 5
const MIN_COLS_FLOOR := 18

# Resize flags
const RESIZE_LEFT := 1
const RESIZE_RIGHT := 2
const RESIZE_TOP := 4
const RESIZE_BOTTOM := 8

# Exports
@export var title: String = " Panel "
@export var cols: int = 64
@export var rows: int = 12
@export var enable_scrollbar: bool = true
@export var wheel_step: int = 3   # rows per wheel notch

# Nodes
@onready var cons: Console = $Console

# State
var _scroll: int = 0                   # 0 = stick to bottom (newest)
var _dragging := false
var _resizing := false
var _resize_mode := 0
var _resize_cols0 := 0
var _resize_rows0 := 0
var _resize_mouse0 := Vector2.ZERO
var _left0 := 0.0
var _right0 := 0.0
var _top0 := 0.0
var _bottom0 := 0.0

# Derived per-config
var _close_col := 0
var _scroll_col := 0

func _ready() -> void:
	_reconfigure()
	cons.set_resolver(Callable(self, "_resolve"))
	get_viewport().size_changed.connect(_center_to_view)
	_center_to_view()

# public API ───────────────────────────────────────────────────────────────────
func set_title(t: String) -> void:
	title = t
	cons.redraw(Vector2i.ZERO)

func set_size(c: int, r: int) -> void:
	cols = max(c, _min_cols())
	rows = max(r, MIN_ROWS)
	_reconfigure()

func set_min(c_min: int, r_min: int) -> void:
	# Optional future hook; kept for symmetry
	pass

# content hooks for subclasses ─────────────────────────────────────────────────
func content_total_rows() -> int:
	return 0

func content_cell_at(_col: int, _src_row: int, _max_cols: int) -> Variant:
	return {"ch":" ", "fg":Color(1,1,1), "bg":Color(0,0,0)}

# layout helpers ───────────────────────────────────────────────────────────────
func _min_cols() -> int:
	# borders(2) + left pad(1) + measured title + gap(1) + 'X'(1) + right pad(1)
	var title_cols := _title_measured_cols()
	var need : int = 2 + 1 + max(1, title_cols) + 1 + 1 + 1
	return max(MIN_COLS_FLOOR, need)

func _reconfigure() -> void:
	cols = max(cols, _min_cols())
	rows = max(rows, MIN_ROWS)
	_close_col = cols - 3
	_scroll_col = cols - 2
	cons.configure(CELL_H, cols, rows, cols, rows, CHAR_W)
	cons.redraw(Vector2i.ZERO)

func _center_to_view() -> void:
	var vp := get_viewport_rect().size
	global_position = Vector2(vp.x * 0.5, vp.y * 0.5)

func _cell(ch: String) -> Dictionary:
	return {"ch": ch, "fg": Color(1,1,1), "bg": Color(0,0,0)}

# resolver: draws frame + routes content ───────────────────────────────────────
func _resolve(p: Vector2i) -> Variant:
	var x := p.x + int(cols * 0.5)
	var y := p.y + int(rows * 0.5)
	if x < 0 or x >= cols or y < 0 or y >= rows:
		return " "

	# Top border
	if y == 0:
		if x == 0: return _cell("╔")
		if x == cols - 1: return _cell("╗")
		return _cell("═")

	# Title row
	if y == 1:
		if x == 0 or x == cols - 1: return _cell("║")
		if x == _close_col: return {"ch":"╳", "fg": Color(1,0.4,0.4), "bg": Color(0,0,0)}
		# title text with auto-span handled by Console
		return _title_cell_at(x)

	# Separator
	if y == 2:
		if x == 0: return _cell("╠")
		if x == cols - 1: return _cell("╣")
		return _cell("═")

	# Bottom border
	if y == rows - 1:
		if x == 0: return _cell("╚")
		if x == cols - 1: return _cell("╝")
		return _cell("═")

	# Side borders
	if x == 0 or x == cols - 1:
		return _cell("║")

	# Scrollbar track inside content area
	if _scrollbar_visible() and x == _scroll_col and y >= 3 and y <= rows - 2:
		var m := _thumb_metrics()
		var track_y0: int = 3
		var top := int(m["top"]) + track_y0
		var bot := top + int(m["thumb_h"]) - 1
		return {"ch": ("█" if y >= top and y <= bot else "│"), "fg": Color(1,1,1), "bg": Color(0,0,0)}

	# Content region
	var content_rows: int = rows - 4
	var vis_row: int = y - 3
	var w := _visible_width()
	var total := content_total_rows()
	if total <= 0 or w <= 0:
		return " "

	# Map visible row to source row from bottom
	var src_from_bottom := content_rows - 1 - vis_row + _scroll
	var src_idx := total - 1 - src_from_bottom
	if src_idx < 0 or src_idx >= total:
		return " "

	# Left padding inside frame
	var col_in_content := x - 1
	return content_cell_at(col_in_content, src_idx, w)

# title painter with explicit span hook (no measuring) ─────────────────────────
func _title_cell_at(x: int) -> Dictionary:
	# Draw starting at column 2: " " + title + " " with span-aware stepping.
	var s := " " + title + " "
	var head := 2
	for i in range(s.length()):
		var ch := s[i]
		if x == head:
			var sp := title_span_for(ch)
			return {"ch": ch, "fg": Color(1,1,1), "bg": Color(0,0,0), "span": max(1, sp)}
		# advance by declared span
		head += max(1, title_span_for(ch))
	return _cell(" ")

# scrollbar math ───────────────────────────────────────────────────────────────
func _visible_width() -> int:
	var w := cols - 2
	if _scrollbar_visible():
		w -= 1
	return max(0, w)

func _scrollbar_visible() -> bool:
	if !enable_scrollbar:
		return false
	var content_rows: int = rows - 4
	return content_total_rows() > content_rows

func _thumb_metrics() -> Dictionary:
	var content_rows: int = rows - 4
	var total: int = content_total_rows()
	var track_h: int = max(0, content_rows)
	if track_h <= 0:
		return {"track_h": 0, "thumb_h": 0, "top": 0}
	var thumb_h: int
	if total <= 0 or total <= track_h:
		thumb_h = track_h
	else:
		thumb_h = clamp(int(round(float(track_h) * float(track_h) / float(total))), 1, track_h)
	var max_scroll: int = max(0, total - track_h)
	var top: int = 0
	if max_scroll > 0 and track_h - thumb_h > 0:
		top = int(round(float(max_scroll - _scroll) * float(track_h - thumb_h) / float(max_scroll)))
	return {"track_h": track_h, "thumb_h": thumb_h, "top": top}

func _update_scroll_from_thumb(thumb_top_cell: int) -> void:
	var m := _thumb_metrics()
	var track_h: int = int(m["track_h"])
	var thumb_h: int = int(m["thumb_h"])
	if track_h <= 0 or thumb_h <= 0:
		_scroll = 0
		return
	var max_scroll: int = max(0, content_total_rows() - track_h)
	if max_scroll <= 0:
		_scroll = 0
		return
	var top_rel: int = clamp(thumb_top_cell - 3, 0, max(0, track_h - thumb_h))
	var new_scroll: int = max_scroll - int(round(float(top_rel) * float(max_scroll) / float(track_h - thumb_h)))
	_scroll = clamp(new_scroll, 0, max_scroll)

# input: drag, resize, wheel, scrollbar, close ─────────────────────────────────
func _input(event: InputEvent) -> void:
	if !visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# Wheel scroll
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var up := (mb.button_index == MOUSE_BUTTON_WHEEL_UP)
			var content_rows: int = rows - 4
			var max_scroll: int = max(0, content_total_rows() - content_rows)
			var step : int = max(1, wheel_step)
			_scroll = clamp(_scroll + (step if up else -step), 0, max_scroll)
			cons.redraw(Vector2i.ZERO)
			return

		# Non-left buttons
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return

		var lp := to_local(mb.position)
		var origin_x := -int(cols * CHAR_W * 0.5)
		var origin_y := -int(rows * CELL_H * 0.5)
		var sx := int(floor((lp.x - origin_x) / CHAR_W))
		var sy := int(floor((lp.y - origin_y) / CELL_H))

		if mb.pressed:
			# Scrollbar drag start
			if _scrollbar_visible() and sx == _scroll_col and sy >= 3 and sy <= rows - 2:
				var m := _thumb_metrics()
				var thumb_top_cell := 3 + int(m["top"])
				_resizing = false
				_dragging = false
				_resize_mode = 0
				_scroll_dragging = true
				_scroll_drag_offset = sy - thumb_top_cell
				_update_scroll_from_thumb(thumb_top_cell)
				cons.redraw(Vector2i.ZERO)
				return

			# Try resize (edges/corners)
			var hit := _hit_resize_zone(sx, sy)
			if hit != 0:
				_start_resize(hit, mb.position)
				return

			# Start drag on title row
			if sy == 1 and sx != _close_col and sx > 0 and sx < cols - 1:
				_dragging = true
				z_index += 1
		else:
			# Mouse release
			_dragging = false
			if _resizing:
				_resizing = false
				_resize_mode = 0
				return
			if _scroll_dragging:
				_scroll_dragging = false
				return
			# Close on release on the X
			if sy == 1 and sx == _close_col:
				visible = false
		return

	if event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		global_position += mm.relative
		return

	if event is InputEventMouseMotion and _resizing:
		var mm := event as InputEventMouseMotion
		_apply_resize(mm.position - _resize_mouse0)
		return

	if event is InputEventMouseMotion and _scroll_dragging:
		var mm := event as InputEventMouseMotion
		var lp2 := to_local(mm.position)
		var origin_y2 := -int(rows * CELL_H * 0.5)
		var sy2 := int(floor((lp2.y - origin_y2) / CELL_H))
		_update_scroll_from_thumb(sy2 - _scroll_drag_offset)
		cons.redraw(Vector2i.ZERO)
		return

# Scrollbar drag state (locals)
var _scroll_dragging := false
var _scroll_drag_offset := 0

# resize helpers ───────────────────────────────────────────────────────────────
func _hit_resize_zone(sx: int, sy: int) -> int:
	var mode := 0
	if sx == 0: mode |= RESIZE_LEFT
	elif sx == cols - 1: mode |= RESIZE_RIGHT
	if sy == 0: mode |= RESIZE_TOP
	elif sy == rows - 1: mode |= RESIZE_BOTTOM
	return mode

func _start_resize(mode: int, mouse_pos: Vector2) -> void:
	_resizing = true
	_resize_mode = mode
	_resize_cols0 = cols
	_resize_rows0 = rows
	_resize_mouse0 = mouse_pos
	var w0 := float(cols * CHAR_W)
	var h0 := float(rows * CELL_H)
	_left0 = global_position.x - w0 * 0.5
	_right0 = global_position.x + w0 * 0.5
	_top0 = global_position.y - h0 * 0.5
	_bottom0 = global_position.y + h0 * 0.5

func _apply_resize(delta: Vector2) -> void:
	var left := _left0
	var right := _right0
	var top := _top0
	var bottom := _bottom0
	if (_resize_mode & RESIZE_LEFT) != 0: left = _left0 + delta.x
	if (_resize_mode & RESIZE_RIGHT) != 0: right = _right0 + delta.x
	if (_resize_mode & RESIZE_TOP) != 0: top = _top0 + delta.y
	if (_resize_mode & RESIZE_BOTTOM) != 0: bottom = _bottom0 + delta.y

	var min_w := float(_min_cols() * CHAR_W)
	var min_h := float(MIN_ROWS * CELL_H)

	var w := right - left
	if w < min_w:
		if (_resize_mode & RESIZE_LEFT) != 0 and (_resize_mode & RESIZE_RIGHT) == 0:
			left = right - min_w
		elif (_resize_mode & RESIZE_RIGHT) != 0 and (_resize_mode & RESIZE_LEFT) == 0:
			right = left + min_w
		else:
			var cx := (left + right) * 0.5
			left = cx - min_w * 0.5
			right = cx + min_w * 0.5
		w = right - left

	var h := bottom - top
	if h < min_h:
		if (_resize_mode & RESIZE_TOP) != 0 and (_resize_mode & RESIZE_BOTTOM) == 0:
			top = bottom - min_h
		elif (_resize_mode & RESIZE_BOTTOM) != 0 and (_resize_mode & RESIZE_TOP) == 0:
			bottom = top + min_h
		else:
			var cy := (top + bottom) * 0.5
			top = cy - min_h * 0.5
			bottom = cy + min_h * 0.5
		h = bottom - top

	# quantize to grid
	var cols_q : int = clamp(int(round(w / float(CHAR_W))), _min_cols(), 999)
	var rows_q : int = clamp(int(round(h / float(CELL_H))), MIN_ROWS, 200)

	# center from edges
	var cx_new := (left + right) * 0.5
	var cy_new := (top + bottom) * 0.5

	if cols_q != cols or rows_q != rows or cx_new != global_position.x or cy_new != global_position.y:
		cols = cols_q
		rows = rows_q
		global_position = Vector2(cx_new, cy_new)
		_reconfigure()

# Hit rectangle for WindowManager
func global_rect() -> Rect2:
	var w := float(cols * CHAR_W)
	var h := float(rows * CELL_H)
	var tl := global_position - Vector2(w, h) * 0.5
	return Rect2(tl, Vector2(w, h))

# span helpers for title rendering ─────────────────────────────────────────────

func _title_measured_cols() -> int:
	# " " + title + " " measured in columns, span-aware.
	var s := " " + title + " "
	var total := 0
	for i in range(s.length()):
		total += max(1, title_span_for(s[i]))
	return total

# Child panels may override to opt-in double-wide for specific glyphs.
func title_span_for(_glyph: String) -> int:
	return 1
