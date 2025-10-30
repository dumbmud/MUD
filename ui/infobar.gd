class_name InfoBar
extends Node2D

const CELL_H := 26               # row height in px
const CHAR_W := 13               # column width in px for UI monospace
const ROWS := 1

@onready var cons: Console = $Console

var _sim: SimManager
var _bus: Node
var _win: WindowManager
var _tracked_id := 0

# layout
var _cols := 0
var _ranges := {}                # name -> Vector2i(start,end_inclusive)
var _last_msg_text := ""
var _last_msg_kind: StringName = &"info"

func bind(sim: SimManager, bus: Node, win: WindowManager, tracked_actor_id: int) -> void:
	_sim = sim
	_bus = bus
	_win = win
	_tracked_id = tracked_actor_id
	# signals
	get_viewport().size_changed.connect(_on_view_changed)
	if _sim:
		_sim.tick_advanced.connect(_on_update)
		_sim.state_changed.connect(_on_update)
	if _bus:
		_bus.message.connect(func(text, kind, _tick, _aid):
			_last_msg_text = String(text)
			_last_msg_kind = kind
			_redraw()
		)
	InputManager.gait_changed.connect(func(_g): _redraw())
	_on_view_changed()

func _on_view_changed() -> void:
	var vp := get_viewport_rect().size
	# ceil to fill width, then add 2 cells for 1-char buffer per side
	_cols = max(20, int(ceil(vp.x / CHAR_W)) + 2)
	cons.configure(CELL_H, _cols, ROWS, _cols, ROWS, CHAR_W)
	# center horizontally at top
	global_position = Vector2(vp.x * 0.5, CELL_H * 0.5)
	cons.set_resolver(Callable(self, "_resolve_cell"))
	_redraw()

func _on_update(_x := 0) -> void:
	_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if !(event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	if !mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT: return
	var lx := to_local(mb.position).x
	var ly := to_local(mb.position).y
	# mirror Console's origin logic: center-based
	var origin_x := -int(_cols * CHAR_W * 0.5)
	var origin_y := -int(ROWS * CELL_H * 0.5)
	var sx := int(floor((lx - origin_x) / CHAR_W))
	var sy := int(floor((ly - origin_y) / CELL_H))
	if sy != 0 or sx < 0 or sx >= _cols: return

	# hit test by segment
	if _in_range("mode", sx):
		GameLoop.toggle_real_time()
		_redraw()
	elif _in_range("vitals", sx):
		if _win: _win.open(&"actor_sheet")
	elif _in_range("message", sx):
		if _win: _win.toggle(&"log_console")

func _in_range(name: String, x: int) -> bool:
	if !_ranges.has(name): return false
	var r: Vector2i = _ranges[name]
	return x >= r.x and x <= r.y

func _redraw() -> void:
	cons.redraw(Vector2i.ZERO)  # center irrelevant; resolver ignores world

# ── Resolver ─────────────────────────────────────────────────────────────

func _resolve_cell(p: Vector2i) -> Dictionary:
	# Build the whole line once per draw, then return cell by index.
	var line := _compose_line()
	var x := p.x + int(_cols * 0.5)  # convert centered world-x to [0..cols-1]
	if x < 0 or x >= line.size():
		return {"ch": " ", "fg": Color(1,1,1), "bg": Color(0,0,0)}
	return line[x]

func _compose_line() -> Array:
	var cells: Array = []
	_ranges.clear()

	# 1) Mode
	var rt := GameLoop.real_time
	var mode_txt := "Real Time" if rt else "Turn Based"
	var mode_col := Color(0.33, 0.67, 1.0) if rt else Color(1.0, 0.33, 0.33)
	_push_text(cells, " " + mode_txt + " ", mode_col, "mode")

	# spacer
	_push_text(cells, " ", Color(1,1,1))

	# 2) Gait + Stamina
	var gait := InputManager.get_desired_gait()
	var gait_txt := "Gait: "+InputManager.gait_name(gait)+" "
	_push_text(cells, gait_txt, Color(1,1,1))
	_push_stamina_bar(cells)
	var a := _sim.get_actor(_tracked_id) if _sim else null
	if a != null:
		var sec := Physio.step_seconds(a, Vector2i(1,0), gait)
		var mps : float = (1.0 / max(0.001, sec))
		_push_text(cells, "@%.2fm/s " % mps, Color(0.8,0.8,0.8))

	# spacer
	_push_text(cells, "  ", Color(1,1,1))

	# 3) Vitals
	_push_text(cells, "[Vitals] ", Color(1,1,1), "vitals")

	# 4) Right-aligned Tick
	var tick := _sim.tick_count if _sim else 0
	var tick_txt := " Tick %d  " % tick
	var right_len := tick_txt.length()

	# 5) Message fills the gap
	var rem : int = max(0, _cols - right_len - cells.size())
	var msg_txt := _trim_message(_last_msg_text, rem)
	var msg_col := _msg_color(_last_msg_kind)
	var msg_start := cells.size()
	_push_text(cells, msg_txt, msg_col)

	# pad if short
	while cells.size() < _cols - right_len:
		cells.append({"ch":" ", "fg":Color(1,1,1), "bg":Color(0,0,0)})
	# clickable range covers the whole gutter, not just text
	_ranges["message"] = Vector2i(msg_start, (_cols - right_len) - 1)

	# 6) Append right-aligned Tick
	_push_text(cells, tick_txt, Color(1,1,1))

	# trim to exact width
	if cells.size() > _cols:
		cells = cells.slice(0, _cols)
	return cells

func _push_text(cells: Array, s: String, col: Color, tag: String="") -> void:
	var start := cells.size()
	for i in s.length():
		cells.append({"ch": s[i], "fg": col, "bg": Color(0,0,0)})
	if tag != "":
		_ranges[tag] = Vector2i(start, cells.size()-1)

func _push_stamina_bar(cells: Array) -> void:
	var a := _sim.get_actor(_tracked_id) if _sim else null
	if a == null:
		_push_text(cells, "[----/----] ", Color(0.7,0.7,0.7))
		return
	var st: Dictionary = a.stamina if a.stamina is Dictionary else {}
	var mx := float(st.get("max", 100.0))
	var val := float(st.get("value", 0.0))
	if mx <= 0.0:
		_push_text(cells, "[----/----] ", Color(0.7,0.7,0.7))
		return
	var slots := 12
	var pct : float = clamp(val / mx, 0.0, 1.0)
	var filled := int(round(pct * slots))
	var s := "["
	for i in range(slots):
		s += "#" if i < filled else "-"
	s += "] "
	_push_text(cells, s, Color(1,1,1))

func _trim_message(s: String, max_chars: int) -> String:
	if max_chars <= 0: return ""
	if s.length() <= max_chars: return s
	if max_chars <= 1: return "…"
	return s.substr(0, max_chars-1) + "…"

func _msg_color(kind: StringName) -> Color:
	match String(kind):
		"error": return Color(1,0.3,0.3)
		"warn", "warning": return Color(1,0.75,0.3)
		_: return Color(1,1,1)
