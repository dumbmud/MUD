extends Node2D
class_name LogPanel

const ROWS := 12
const CELL_H := 26
const CHAR_W := 13
const COLS := 64
const WIDTH_PX := COLS * CHAR_W
const HEIGHT_PX := ROWS * CELL_H

@onready var cons: Console = $Console

var _bus: Node
var _lines: Array[String] = []   # newest last
var panel_id: StringName = &"log_console"
var _scroll := 0                 # 0 = newest at bottom
var _close_col := COLS - 3       # column of '×' glyph on top row

func bind(bus: Node) -> void:
	_bus = bus
	if _bus:
		_bus.message.connect(_on_msg)
	cons.configure(CELL_H, COLS, ROWS, COLS, ROWS, CHAR_W)
	cons.set_resolver(Callable(self, "_resolve"))
	_center_to_view()
	get_viewport().size_changed.connect(_center_to_view)

func _on_msg(text: String, _kind: StringName, _tick: int, _actor_id: int) -> void:
	_lines.append(text)
	if _lines.size() > 200:
		_lines = _lines.slice(_lines.size() - 200, _lines.size())
	cons.redraw(Vector2i.ZERO)

func _resolve(p: Vector2i) -> Variant:
	var x := p.x + int(COLS * 0.5)
	var y := p.y + int(ROWS * 0.5)
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return " "
	# Row 0: top border ╔═…═╗
	if y == 0:
		if x == 0:          return _cell("╔")
		if x == COLS - 1:   return _cell("╗")
		return _cell("═")
	# Row 1: title row  ║ … X ║  (supports wide emoji)
	if y == 1:
		if x == 0 or x == COLS - 1:
			return _cell("║")
		if x == _close_col:
			return {"ch":"X", "fg": Color(1,0.4,0.4), "bg": Color(0,0,0)}
		return _title_cell_at(x)
	# Row 2: separator  ╠═…═╣
	if y == 2:
		if x == 0:          return _cell("╠")
		if x == COLS - 1:   return _cell("╣")
		return _cell("═")
	# Bottom border
	if y == ROWS - 1:
		if x == 0:          return _cell("╚")
		if x == COLS - 1:   return _cell("╝")
		return _cell("═")
	# Content rows (between separator and bottom)
	if x == 0 or x == COLS - 1:
		return _cell("║")
	var content_rows := ROWS - 4              # rows between sep and bottom
	var vis_row := y - 3                      # 0..content_rows-1 from top
	var src_from_bottom := content_rows - 1 - vis_row + _scroll
	var src_idx := _lines.size() - 1 - src_from_bottom
	if src_idx >= 0 and src_idx < _lines.size():
		return _char_from(_lines[src_idx], x - 1, COLS - 2)
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
		var origin_x := -int(COLS * CHAR_W * 0.5)
		var origin_y := -int(ROWS * CELL_H * 0.5)
		var sx := int(floor((lp.x - origin_x) / CHAR_W))
		var sy := int(floor((lp.y - origin_y) / CELL_H))
		# Close only on RELEASE exactly on the 'X' cell (title row)
		if !mb.pressed and sy == 1 and sx == _close_col:
			visible = false
	if event is InputEventMouseMotion:
		return
	# Simple scroll: mouse wheel up/down moves history
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var up: bool = (event.button_index == MOUSE_BUTTON_WHEEL_UP)
		var content_rows := ROWS - 3
		var max_scroll: int = max(0, _lines.size() - content_rows)
		_scroll = clamp(_scroll + (1 if up else -1), 0, max_scroll)
		cons.redraw(Vector2i.ZERO)

func _center_to_view() -> void:
	var vp := get_viewport_rect().size
	global_position = Vector2(vp.x * 0.5, vp.y * 0.5)

func _cell(ch: String) -> Dictionary:
	return {"ch": ch, "fg": Color(1,1,1), "bg": Color(0,0,0)}

# Title painter with wide-emoji support (occupies 2 cols)
func _title_cell_at(x: int) -> Dictionary:
	var title := " 📝 Event Log "
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
