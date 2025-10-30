# file: res://ui/panels/log_panel2.gd  (NEW)
class_name LogPanel
extends UIPanel
##
## Message log panel on top of UIPanel.
## - Width-aware wrapping with multi-column glyphs.
## - No duplicate frame/scroll/resize logic.
## - Auto-scroll sticks to bottom when _scroll==0.

const MAX_MESSAGES := 400

var _bus: Node = null
var _lines: Array[String] = []           # newest last
var _wrapped: Array[String] = []         # visual lines after wrap
var _wrap_counts: Array[int] = []        # wrapped-line count per original
var _wrap_width: int = -1                # cols available (excludes borders/scrollbar)

func _ready() -> void:
	title = "📝 Event Log"
	enable_scrollbar = true
	super._ready()

func title_span_for(glyph: String) -> int:
	# Opt-in example: make the notebook emoji double-wide.
	return 2 if glyph == "📝" else 1

# ── public API ────────────────────────────────────────────────────────────────
func bind(bus: Node) -> void:
	_bus = bus
	if _bus:
		_bus.message.connect(_on_msg)

# ── UIPanel content hooks ────────────────────────────────────────────────────
func content_total_rows() -> int:
	var w0 : int = max(0, cols - 2)
	if enable_scrollbar and _wrapped.size() > 0:
		var content_rows := rows - 4
		if _wrapped.size() > content_rows:  # scrollbar present → one less column
			w0 = max(0, w0 - 1)
	_ensure_wrapped(w0)
	return _wrapped.size()

func content_cell_at(col: int, src_row: int, max_cols: int) -> Variant:
	_ensure_wrapped(max_cols)
	if src_row < 0 or src_row >= _wrapped.size():
		return {"ch":" ", "fg":Color(1,1,1), "bg":Color(0,0,0)}
	var s: String = _wrapped[src_row]
	return _cell_for_line_col(s, col, max_cols)

# ── bus handler ──────────────────────────────────────────────────────────────
func _on_msg(text: String, _kind: StringName, _tick: int, _actor_id: int) -> void:
	_lines.append(text)
	if _lines.size() > MAX_MESSAGES:
		_lines = _lines.slice(_lines.size() - MAX_MESSAGES, _lines.size())
	_wrap_width = -1  # force rebuild next paint
	_clamp_scroll_after_change()
	cons.redraw(Vector2i.ZERO)

# ── wrapping / layout helpers (width-aware) ──────────────────────────────────
func _ensure_wrapped(width_cols: int) -> void:
	if width_cols <= 0:
		_wrapped.clear()
		_wrap_counts.clear()
		_wrap_width = width_cols
		return
	if _wrap_width == width_cols:
		return
	_wrapped.clear()
	_wrap_counts.clear()
	for s in _lines:
		var parts := _wrap_text_width(s, width_cols)
		_wrap_counts.append(parts.size())
		for p in parts:
			_wrapped.append(p)
	_wrap_width = width_cols
	_clamp_scroll_after_change()

func _clamp_scroll_after_change() -> void:
	# Keep user position if scrolled up. Stick to bottom when _scroll==0.
	var content_rows := rows - 4
	if content_rows <= 0:
		_scroll = 0
		return
	var total := _wrapped.size()
	var max_scroll : int = max(0, total - content_rows)
	_scroll = clamp(_scroll, 0, max_scroll)

func _wrap_text_width(s: String, max_cols: int) -> Array[String]:
	var out: Array[String] = []
	if max_cols <= 0:
		out.append("")
		return out

	var i := 0
	var n := s.length()
	while i < n:
		# newline hard break
		if s[i] == "\n":
			out.append("")
			i += 1
			continue

		var line := ""
		var line_cols := 0
		var last_space_i := -1
		var last_space_cols := -1

		while i < n:
			var ch := s[i]
			if ch == "\n":
				break
			# if adding this glyph would exceed width, break
			if line_cols + 1 > max_cols:
				break
			line += ch
			line_cols += 1
			if ch == " ":
				last_space_i = i
				last_space_cols = line_cols
			i += 1

		# hard newline
		if i < n and s[i] == "\n":
			out.append(line)
			i += 1
			continue

		# soft wrap at last space if it helps
		if line_cols == max_cols or last_space_i == -1:
			out.append(line)
		else:
			out.append(line.substr(0, last_space_cols))
			i = last_space_i + 1

		# empty line guard
		if line == "" and (i >= n or s[i] == "\n"):
			out.append("")
			i += (1 if i < n and s[i] == "\n" else 0)

	if out.is_empty():
		out.append("")
	return out

func _cell_for_line_col(s: String, col: int, _max_cols: int) -> Dictionary:
	if col < 0 or col >= s.length():
		return {"ch":" ", "fg": Color(1,1,1), "bg": Color(0,0,0)}
	return {"ch": s[col], "fg": Color(1,1,1), "bg": Color(0,0,0)}

func _span(glyph: String) -> int:
	if glyph == "":
		return 1
	if cons == null or cons.font == null:
		return 1
	var cw : int = max(1, cons.cell_w_px)
	var w_px := cons.font.get_string_size(glyph, cons.font_size).x
	return max(1, int(ceil(float(w_px) / float(cw))))
