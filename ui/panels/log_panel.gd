extends Node2D
class_name LogPanel

const DEFAULT_ROWS := 12        # rows incl. borders
const CELL_H := 26
const CHAR_W := 13
const DEFAULT_COLS := 64        # cols incl. borders
const MIN_ROWS := 5             # 3-row header + 1 content row
const MIN_COLS_FLOOR := 18      # fallback floor if title is short

@onready var cons: Console = $Console

var _bus: Node
var _lines: Array[String] = []   # newest last
var panel_id: StringName = &"log_console"
var _scroll := 0                 # 0 = newest at bottom
var _cols := DEFAULT_COLS
var _rows := DEFAULT_ROWS
var _close_col := 0             # updated in _reconfigure()
var _dragging := false
var _resizing := false
var _resize_cols0 := 0
var _resize_rows0 := 0
var _resize_mouse0 := Vector2.ZERO

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
			return {"ch":"X", "fg": Color(1,0.4,0.4), "bg": Color(0,0,0)}
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
	var content_rows := _rows - 4             # rows between sep and bottom
	var vis_row := y - 3                      # 0..content_rows-1 from top
	var src_from_bottom := content_rows - 1 - vis_row + _scroll
	var src_idx := _lines.size() - 1 - src_from_bottom
	if src_idx >= 0 and src_idx < _lines.size():
		return _char_from(_lines[src_idx], x - 1, _cols - 2)
	return " "

func _char_from(s: String, col: int, max_cols: int = 9999) -> Dictionary:
	if col >= max_cols:
		return {"ch":" ", "fg": Color(1,1,1), "bg": Color(0,0,0)}
	if col >= s.length():
		return {"ch":" ", "fg": Color(1,1,1), "bg": Color(0,0,0)}
	return {"ch": s[col], "fg": Color(1,1,1), "bg": Color(0,0,0)}

func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var lp := to_local(mb.position)
		# Map to cell coords relative to panel center
		var origin_x := -int(_cols * CHAR_W * 0.5)
		var origin_y := -int(_rows * CELL_H * 0.5)
		var sx := int(floor((lp.x - origin_x) / CHAR_W))
		var sy := int(floor((lp.y - origin_y) / CELL_H))
		if mb.pressed:
			# Start drag on title row (y==1), excluding the close cell and borders
			if sy == 1 and sx != _close_col and sx > 0 and sx < _cols - 1:
				_dragging = true
				# bring to front cheaply
				z_index += 1
			# Start resize when pressing bottom-right corner (╝) or its neighbor
			if (sy == _rows - 1 and sx >= _cols - 2) or (sx == _cols - 1 and sy >= _rows - 2):
				_resizing = true
				_resize_cols0 = _cols
				_resize_rows0 = _rows
				_resize_mouse0 = mb.position
		else:
			# Stop drag on release
			_dragging = false
			# Stop resize on release
			if _resizing:
				_resizing = false
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
		var delta: Vector2 = mm.position - _resize_mouse0
		var dcols: int = int(round(delta.x / float(CHAR_W)))
		var drows: int = int(round(delta.y / float(CELL_H)))
		var new_cols: int = clamp(_resize_cols0 + dcols, _min_cols(), 999)
		var new_rows: int = clamp(_resize_rows0 + drows, MIN_ROWS, 200)
		if new_cols != _cols or new_rows != _rows:
			_cols = new_cols
			_rows = new_rows
			_reconfigure()
		return
	if event is InputEventMouseMotion:
		return
	# Simple scroll: mouse wheel up/down moves history
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var mb2 := event as InputEventMouseButton
		var up: bool = (mb2.button_index == MOUSE_BUTTON_WHEEL_UP)
		var content_rows: int = _rows - 4
		var max_scroll: int = max(0, _lines.size() - content_rows)
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
	cons.configure(CELL_H, _cols, _rows, _cols, _rows, CHAR_W)
	cons.redraw(Vector2i.ZERO)
