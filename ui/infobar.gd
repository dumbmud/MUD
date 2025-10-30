class_name InfoBar
extends Node2D

const CELL_H := 26               # row height in px
const CHAR_W := 12               # column width in px for UI monospace
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

	# 2) Stamina bar + speed
	var mode := InputManager.get_desired_gait()    # 0..3 Blue/Green/Orange/Red
	var a := _sim.get_actor(_tracked_id) if _sim else null
	if a != null:
		# stamina bar using 🭵…🭰 with partials
		var bar := _stamina_bar(a, 10)
		_push_text(cells, bar, Color(1,1,1))
		# colored speed label after the bar
		var speed_cells := _speed_label(a, mode)
		for cell in speed_cells:
			cells.append(cell)
	else:
		_push_text(cells, "🭵          🭰¼@0.00m/s ", Color(0.6,0.6,0.6))


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

func _mode_color(mode:int) -> Color:
	# Blue, Green, Orange, Red
	match mode:
		0: return Color(0.33, 0.67, 1.0)
		1: return Color(0.33, 1.0, 0.33)
		2: return Color(1.0, 0.66, 0.25)
		3: return Color(1.0, 0.33, 0.33)
		_: return Color(1,1,1)

func _mode_glyph(mode:int) -> String:
	match mode:
		0: return "¼"
		1: return "½"
		2: return "¾"
		3: return "¹"
		_: return "¼"

func _speed_mps(actor: Actor, mode:int) -> float:
	# Cardinal step duration → m/s
	var sec := Physio.step_seconds(actor, Vector2i(1,0), mode)
	return 0.0 if sec <= 0.0 else (1.0 / sec)

func _speed_label(actor: Actor, mode:int) -> Array:
	var mps := _speed_mps(actor, mode)
	var s := "%s@%.2fm/s" % [_mode_glyph(mode), mps]
	var c := _mode_color(mode)
	var out: Array = []
	for i in s.length():
		out.append({"ch": s[i], "fg": c, "bg": Color(0,0,0)})
	return out

# Partial block for last cell: 0..1 → glyph
func _partial_block(frac: float) -> String:
	var f : float = clamp(frac, 0.0, 1.0)
	if f < 0.125: return " "
	elif f < 0.25: return "▏"   # 1/8
	elif f < 0.375: return "▎"  # 2/8
	elif f < 0.5: return "▍"    # 3/8
	elif f < 0.625: return "▌"  # 4/8
	elif f < 0.75: return "▋"   # 5/8
	elif f < 0.875: return "▊"  # 6/8
	else: return "▉"            # 7/8

func _stamina_bar(actor: Actor, slots:int=10) -> String:
	# Format: 🭵 + slots of fill + 🭰 ; last slot can be partial; empties are spaces.
	var st: Dictionary = actor.stamina
	var v := float(st.get("value", 0.0))
	var mx : float = max(1.0, float(st.get("max", 100.0)))
	var p : float = clamp(v / mx, 0.0, 1.0)
	var filled := int(floor(p * slots))
	var frac := p * slots - float(filled)

	var s := "🭵"
	# full blocks
	for i in range(filled):
		s += "█"
	# partial slot
	var used := filled
	if used < slots:
		var part := _partial_block(frac)
		if part != " ":
			s += part
			used += 1
	# empties
	for i in range(slots - used):
		s += " "
	# cap
	s += "🭰"
	return s
