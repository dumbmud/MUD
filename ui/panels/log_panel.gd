extends Node2D
class_name LogPanel

const DEFAULT_ROWS := 12        # rows incl. borders
const CELL_H := 26
const CHAR_W := 13
const DEFAULT_COLS := 64        # cols incl. borders
const MIN_ROWS := 5             # 3-row header + 1 content row + bottom border
const MIN_COLS_FLOOR := 18      # fallback floor if title is short
const RESIZE_LEFT := 1
const RESIZE_RIGHT := 2
const RESIZE_TOP := 4
const RESIZE_BOTTOM := 8

@onready var cons: Console = $Console

var _bus: Node
var _lines: Array[String] = []   # newest last
var _wrapped: Array[String] = []              # visual lines after wrapping
var _wrap_counts: Array[int] = []             # wrapped-line count per original line
var _last_msg_first_idx: int = 0              # index in _wrapped
var _auto_anchor_last_head: bool = false      # when true, top aligns to newest msg head
var panel_id: StringName = &"log_console"
var _scroll := 0                 # 0 = newest at bottom
var _cols := DEFAULT_COLS
var _rows := DEFAULT_ROWS
var _close_col := 0             # updated in _reconfigure()
var _dragging := false
var _resizing := false
var _resize_mode: int = 0
var _resize_cols0 := 0
var _resize_rows0 := 0
var _resize_mouse0 := Vector2.ZERO
var _left0: float = 0.0
var _right0: float = 0.0
var _top0: float = 0.0
var _bottom0: float = 0.0
var _scroll_col: int = 0
var _scrollbar_dragging: bool = false
var _scroll_drag_offset: int = 0

func bind(bus: Node) -> void:
	_bus = bus
	if _bus:
		_bus.message.connect(_on_msg)
	_reconfigure()
	cons.set_resolver(Callable(self, "_resolve"))
	_center_to_view()
	get_viewport().size_changed.connect(_center_to_view)

func _on_msg(text: String, _kind: StringName, _tick: int, _actor_id: int) -> void:
	_lines.append(text)
	if _lines.size() > 200:
		_lines = _lines.slice(_lines.size() - 200, _lines.size())
	_auto_anchor_last_head = false
	_rebuild_wrap()
	cons.redraw(Vector2i.ZERO)

func _resolve(p: Vector2i) -> Variant:
	var x := p.x + int(_cols * 0.5)
	var y := p.y + int(_rows * 0.5)
	if x < 0 or x >= _cols or y < 0 or y >= _rows:
		return " "
	# Row 0: top border ╔═…═╗
	if y == 0:
		if x == 0:          return _cell("╔")
		if x == _cols - 1:  return _cell("╗")
		return _cell("═")
	# Row 1: title row  ║ … X ║  (supports wide emoji)
	if y == 1:
		if x == 0 or x == _cols - 1:
			return _cell("║")
		if x == _close_col:
			return {"ch":"╳", "fg": Color(1,0.4,0.4), "bg": Color(0,0,0)}
		return _title_cell_at(x)
	# Row 2: separator  ╠═…═╣
	if y == 2:
		if x == 0:          return _cell("╠")
		if x == _cols - 1:  return _cell("╣")
		return _cell("═")
	# Bottom border
	if y == _rows - 1:
		if x == 0:          return _cell("╚")
		if x == _cols - 1:  return _cell("╝")
		return _cell("═")
	# Content rows (between separator and bottom)
	if x == 0 or x == _cols - 1:
		return _cell("║")
  # Scrollbar column inside content area only
	if _scrollbar_visible() and x == _scroll_col and y >= 3 and y <= _rows - 2:
		var m := _thumb_metrics()
		var track_y0: int = 3
		var thumb_top: int = int(m["top"]) + track_y0
		var thumb_bot: int = thumb_top + int(m["thumb_h"]) - 1
		return {"ch": ("█" if y >= thumb_top and y <= thumb_bot else "│"), "fg": Color(1,1,1), "bg": Color(0,0,0)}
	var content_rows: int = _rows - 4             # rows between sep and bottom
	var vis_row: int = y - 3                      # 0..content_rows-1 from top
	var src_from_bottom: int = content_rows - 1 - vis_row + _scroll
	var src_idx: int = _wrapped.size() - 1 - src_from_bottom
	if src_idx >= 0 and src_idx < _wrapped.size():
		return _char_from(_wrapped[src_idx], x - 1, _visible_width())
	return " "

func _char_from(s: String, col: int, max_cols: int = 9999) -> Dictionary:
	if col >= max_cols:
		return {"ch":" ", "fg": Color(1,1,1), "bg": Color(0,0,0)}
	if col >= s.length():
		return {"ch":" ", "fg": Color(1,1,1), "bg": Color(0,0,0)}
	return {"ch": s[col], "fg": Color(1,1,1), "bg": Color(0,0,0)}

func _input(event: InputEvent) -> void:
	if !visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# 1) Wheel scroll
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var up: bool = (mb.button_index == MOUSE_BUTTON_WHEEL_UP)
			var content_rows: int = _rows - 4
			var max_scroll: int = max(0, _wrapped.size() - content_rows)
			_auto_anchor_last_head = false
			_scroll = clamp(_scroll + (1 if up else -1), 0, max_scroll)
			cons.redraw(Vector2i.ZERO)
			return
		# 2) Non-left buttons ignored
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var lp := to_local(mb.position)
		# Map to cell coords relative to panel center
		var origin_x := -int(_cols * CHAR_W * 0.5)
		var origin_y := -int(_rows * CELL_H * 0.5)
		var sx := int(floor((lp.x - origin_x) / CHAR_W))
		var sy := int(floor((lp.y - origin_y) / CELL_H))
		if mb.pressed:
			# Scrollbar drag start
			if _scrollbar_visible() and sx == _scroll_col and sy >= 3 and sy <= _rows - 2:
				var m := _thumb_metrics()
				var thumb_top_cell: int = 3 + int(m["top"])
				_scrollbar_dragging = true
				_scroll_drag_offset = sy - thumb_top_cell
				_auto_anchor_last_head = false
				_update_scroll_from_thumb(thumb_top_cell)
				cons.redraw(Vector2i.ZERO)
				return
			# Try resize first (edges or corners)
			var hit_mode := _hit_resize_zone(sx, sy)
			if hit_mode != 0:
				_start_resize(hit_mode, mb.position)
				return
			# Start drag on title row (y==1), excluding the close cell and borders
			if sy == 1 and sx != _close_col and sx > 0 and sx < _cols - 1:
				_dragging = true
				# bring to front cheaply
				z_index += 1
		else:
			# Stop drag on release
			_dragging = false
			# Stop resize on release
			if _resizing:
				_resizing = false
				_resize_mode = 0
				return
			# Stop scrollbar drag on release
			if _scrollbar_dragging:
				_scrollbar_dragging = false
				return
			# Close only on RELEASE exactly on the 'X' cell
			if sy == 1 and sx == _close_col:
				visible = false
		return
	if event is InputEventMouseMotion and _dragging:
		# drag using relative motion in viewport space
		var mm := event as InputEventMouseMotion
		global_position += mm.relative
		return
	if event is InputEventMouseMotion and _resizing:
		var mm := event as InputEventMouseMotion
		_apply_resize(mm.position - _resize_mouse0)
		return
	if event is InputEventMouseMotion and _scrollbar_dragging:
		var mm := event as InputEventMouseMotion
		var lp2 := to_local(mm.position)
		var origin_y2 := -int(_rows * CELL_H * 0.5)
		var sy2 := int(floor((lp2.y - origin_y2) / CELL_H))
		_update_scroll_from_thumb(sy2 - _scroll_drag_offset)
		cons.redraw(Vector2i.ZERO)
		return
	if event is InputEventMouseMotion:
		return
	# Simple scroll: mouse wheel up/down moves history
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var mb2 := event as InputEventMouseButton
		var up: bool = (mb2.button_index == MOUSE_BUTTON_WHEEL_UP)
		var content_rows: int = _rows - 4
		var max_scroll: int = max(0, _wrapped.size() - content_rows)
		_auto_anchor_last_head = false
		_scroll = clamp(_scroll + (1 if up else -1), 0, max_scroll)
		cons.redraw(Vector2i.ZERO)
		return
		
func _center_to_view() -> void:
	var vp := get_viewport_rect().size
	global_position = Vector2(vp.x * 0.5, vp.y * 0.5)

func _cell(ch: String) -> Dictionary:
	return {"ch": ch, "fg": Color(1,1,1), "bg": Color(0,0,0)}

# Title painter with wide-emoji support (occupies 2 cols)
func _title_cell_at(x: int) -> Dictionary:
	var title := "📝Event Log "
	var col := 2
	for i in range(title.length()):
		var ch := title[i]
		var span := 2 if ch == "📝" else 1
		if x == col:
			return {"ch": ch, "fg": Color(1,1,1), "bg": Color(0,0,0), "span": span}
		if x > col and x < col + span:
			return _cell(" ")
		col += span
	return _cell(" ")

# ── sizing helpers ───────────────────────────────────────────────────────────
func _title_span_width() -> int:
	var title := " 📝 Event Log "
	var w := 0
	for i in range(title.length()):
		w += 2 if title[i] == "📝" else 1
	return w

func _min_cols() -> int:
	# Structural minimum only:
	# borders(2) + left pad(1) + minimal title (emoji=2 cols) + gap(1) + 'X'(1) + right pad(1)
	var min_title: int = 2
	var need: int = 2 + 1 + min_title + 1 + 1 + 1
	return max(MIN_COLS_FLOOR, need)

func _reconfigure() -> void:
	_cols = max(_cols, _min_cols())
	_rows = max(_rows, MIN_ROWS)
	_close_col = _cols - 3
	_scroll_col = _cols - 2
	cons.configure(CELL_H, _cols, _rows, _cols, _rows, CHAR_W)
	_rebuild_wrap()
	cons.redraw(Vector2i.ZERO)


# ── wrapping helpers ─────────────────────────────────────────────────────────
func _visible_width() -> int:
	var w: int = _cols - 2
	if _scrollbar_visible():
		w -= 1
	return max(0, w)

func _rebuild_wrap() -> void:
	_wrapped.clear()
	_wrap_counts.clear()
	_last_msg_first_idx = 0
	var w: int = _visible_width()
	if w <= 0:
		return
	for s in _lines:
		var parts: Array[String] = _wrap_text(s, w)
		_wrap_counts.append(parts.size())
		for part in parts:
			_wrapped.append(part)
	# compute index of first wrapped line of newest message
	var idx_acc: int = 0
	for i in range(_wrap_counts.size()):
		if i == _wrap_counts.size() - 1:
			_last_msg_first_idx = idx_acc
		idx_acc += _wrap_counts[i]
	# scroll policy
	var content_rows: int = _rows - 4
	var max_scroll: int = max(0, _wrapped.size() - content_rows)
	if _auto_anchor_last_head:
		var target_top: int = _last_msg_first_idx
		var new_scroll: int = _wrapped.size() - content_rows - target_top
		_scroll = clamp(new_scroll, 0, max_scroll)
	else:
		_scroll = clamp(_scroll, 0, max_scroll)

func _wrap_text(s: String, width: int) -> Array[String]:
	var out: Array[String] = []
	var i: int = 0
	var n: int = s.length()
	while i < n:
		# skip leading spaces
		while i < n and s[i] == " ":
			i += 1
		if i >= n:
			break
		var line := ""
		var line_len: int = 0
		var last_space_idx: int = -1
		var last_space_linepos: int = -1
		var j: int = i
		while j < n and line_len < width:
			var ch := s[j]
			if ch == "\n":
				break
			line += ch
			if ch == " ":
				last_space_idx = j
				last_space_linepos = line_len
			line_len += 1
			j += 1
		if j < n and s[j] == "\n":
			out.append(line)
			i = j + 1
			continue
		if line_len == width and last_space_idx != -1:
			out.append(line.substr(0, last_space_linepos))
			i = last_space_idx + 1
		else:
			out.append(line)
			i = j
	if out.is_empty():
		out.append("")
	return out


func _scrollbar_visible() -> bool:
	var content_rows: int = _rows - 4
	return _wrapped.size() > content_rows

func _thumb_metrics() -> Dictionary:
	var content_rows: int = _rows - 4
	var total: int = _wrapped.size()
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
		# invert: 0 scroll → thumb at bottom
		top = int(round(float(max_scroll - _scroll) * float(track_h - thumb_h) / float(max_scroll)))
	return {"track_h": track_h, "thumb_h": thumb_h, "top": top}

func _update_scroll_from_thumb(thumb_top_cell: int) -> void:
	var m := _thumb_metrics()
	var track_h: int = int(m["track_h"])
	var thumb_h: int = int(m["thumb_h"])
	if track_h <= 0 or thumb_h <= 0:
		_scroll = 0
		return
	var max_scroll: int = max(0, _wrapped.size() - track_h)
	if max_scroll <= 0:
		_scroll = 0
		return
	var top_rel: int = clamp(thumb_top_cell - 3, 0, max(0, track_h - thumb_h))
	var new_scroll: int = max_scroll - int(round(float(top_rel) * float(max_scroll) / float(track_h - thumb_h)))
	_scroll = clamp(new_scroll, 0, max_scroll)

# ── resize helpers ───────────────────────────────────────────────────────────
func _hit_resize_zone(sx: int, sy: int) -> int:
	var mode := 0
	if sx == 0: mode |= RESIZE_LEFT
	elif sx == _cols - 1: mode |= RESIZE_RIGHT
	if sy == 0: mode |= RESIZE_TOP
	elif sy == _rows - 1: mode |= RESIZE_BOTTOM
	return mode

func _start_resize(mode: int, mouse_pos: Vector2) -> void:
	_resizing = true
	_resize_mode = mode
	_resize_cols0 = _cols
	_resize_rows0 = _rows
	_resize_mouse0 = mouse_pos
	var w0: float = float(_cols * CHAR_W)
	var h0: float = float(_rows * CELL_H)
	_left0 = global_position.x - w0 * 0.5
	_right0 = global_position.x + w0 * 0.5
	_top0 = global_position.y - h0 * 0.5
	_bottom0 = global_position.y + h0 * 0.5
	_auto_anchor_last_head = true

func _apply_resize(delta: Vector2) -> void:
	var left := _left0
	var right := _right0
	var top := _top0
	var bottom := _bottom0
	if (_resize_mode & RESIZE_LEFT) != 0:
		left = _left0 + delta.x
	if (_resize_mode & RESIZE_RIGHT) != 0:
		right = _right0 + delta.x
	if (_resize_mode & RESIZE_TOP) != 0:
		top = _top0 + delta.y
	if (_resize_mode & RESIZE_BOTTOM) != 0:
		bottom = _bottom0 + delta.y

	var min_w: float = float(_min_cols() * CHAR_W)
	var min_h: float = float(MIN_ROWS * CELL_H)

	# enforce min width
	var w := right - left
	if w < min_w:
		if (_resize_mode & RESIZE_LEFT) != 0 and (_resize_mode & RESIZE_RIGHT) == 0:
			left = right - min_w
		elif (_resize_mode & RESIZE_RIGHT) != 0 and (_resize_mode & RESIZE_LEFT) == 0:
			right = left + min_w
		else:
			# ambiguous; keep center, expand both sides
			var cx := (left + right) * 0.5
			left = cx - min_w * 0.5
			right = cx + min_w * 0.5
		w = right - left

	# enforce min height
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

	# quantize to cell grid
	var cols_q: int = clamp(int(round(w / float(CHAR_W))), _min_cols(), 999)
	var rows_q: int = clamp(int(round(h / float(CELL_H))), MIN_ROWS, 200)

	# center from (left,right,top,bottom)
	var cx_new: float = (left + right) * 0.5
	var cy_new: float = (top + bottom) * 0.5

	# apply
	if cols_q != _cols or rows_q != _rows or cx_new != global_position.x or cy_new != global_position.y:
		_cols = cols_q
		_rows = rows_q
		global_position = Vector2(cx_new, cy_new)
		_reconfigure()

# Expose panel bounds in viewport coordinates for hit testing.
func global_rect() -> Rect2:
	var w := float(_cols * CHAR_W)
	var h := float(_rows * CELL_H)
	var tl := global_position - Vector2(w, h) * 0.5
	return Rect2(tl, Vector2(w, h))
