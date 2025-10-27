extends Node2D
class_name LogPanel

const ROWS := 8
const CELL_H := 26
const CHAR_W := 13
const COLS := 64
const WIDTH_PX := COLS * CHAR_W
const HEIGHT_PX := ROWS * CELL_H

@onready var cons: Console = $Console

var _bus: Node
var _lines: Array[String] = []   # newest last
var panel_id: StringName = &"log_console"

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
	# draw top border with title
	if y == 0:
		var title := "[ Messages ]  (click to close)"
		return _char_from(title, x)
	# content lines from bottom up
	var vis_idx := ROWS - 2 - y  # y=1 is first content row
	var src_idx := _lines.size() - 1 - vis_idx
	if src_idx >= 0 and src_idx < _lines.size():
		var s := _lines[src_idx]
		return _char_from(s, x)
	return " "

func _char_from(s: String, x: int) -> Dictionary:
	if x >= s.length():
		return {"ch":" ", "fg": Color(1,1,1), "bg": Color(0,0,0)}
	return {"ch": s[x], "fg": Color(1,1,1), "bg": Color(0,0,0)}

func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		# Close only on RELEASE inside panel bounds to avoid re-open race
		if !mb.pressed:
			var p := to_local(mb.position)
			var inside : float = abs(p.x) <= WIDTH_PX * 0.5 and abs(p.y) <= HEIGHT_PX * 0.5
			if inside:
				visible = false

func _center_to_view() -> void:
	var vp := get_viewport_rect().size
	global_position = Vector2(vp.x * 0.5, vp.y * 0.5)
