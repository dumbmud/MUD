# res://ui/panels/survival_panel.gd
class_name SurvivalPanel
extends UIPanel
## Shows the player's survival state (debug). Species-agnostic.
## Open via: WindowManager.toggle(&"survival_panel")
## Optimized: caches lines and only rebuilds on refresh()

var _bus: Node = null
var _lines: Array[String] = []
var _dirty: bool = true

func _ready() -> void:
	title = "💖 Vitals"
	super._ready() # UIPanel sets up Console

func title_span_for(glyph: String) -> int:
	# Render heart as double-width (bitmap font workaround)
	return 2 if glyph == "💖" else 1

func bind(bus: Node) -> void:
	_bus = bus
	_dirty = true
	refresh()

func refresh() -> void:
	# Public entry point called by WindowManager on UI refresh.
	_rebuild_lines()
	if has_node("Console"):
		$Console.redraw(Vector2i.ZERO)

func content_total_rows() -> int:
	# Console will ask these callbacks during redraw
	if _dirty or _lines.is_empty():
		_rebuild_lines()
	return _lines.size()

func content_cell_at(col: int, src_row: int, _max_cols: int) -> Dictionary:
	if _dirty or _lines.is_empty():
		_rebuild_lines()
	if src_row < 0 or src_row >= _lines.size():
		return {"ch":" ", "fg": Color(1,1,1), "bg": Color(0,0,0)}
	var s: String = _lines[src_row]
	if col < 0 or col >= s.length():
		return {"ch":" ", "fg": Color(1,1,1), "bg": Color(0,0,0)}
	return {"ch": s[col], "fg": Color(1,1,1), "bg": Color(0,0,0)}

func _get_sim():
	var wm := get_parent()
	if wm == null:
		return null
	if wm.has_method("get_sim"):
		return wm.call("get_sim")
	# fallback to property access
	return wm.get("_sim") if wm.has_method("get") else null

func _get_tracked_id() -> int:
	var wm := get_parent()
	if wm == null:
		return 0
	if wm.has_method("get_tracked_actor_id"):
		return int(wm.call("get_tracked_actor_id"))
	var v = wm.get("_tracked_id") if wm.has_method("get") else null
	return int(v) if v != null else 0

func _rebuild_lines() -> void:
	var sim = _get_sim()
	var aid: int = _get_tracked_id()

	var out: Array[String] = []
	if sim == null:
		out.append("[no sim]")
		_lines = out
		_dirty = false
		return

	# Allow actor id 0 (valid for first spawned actor)
	var a = sim.get_actor(aid) if sim.has_method("get_actor") else null
	if a == null:
		out.append("[no actor] (id=%d)" % aid)
		_lines = out
		_dirty = false
		return

	out.append("Actor %d" % aid)

	# Statuses
	var buffs := 0
	var debuffs := 0
	var active: Array[String] = []
	if typeof(a.statuses) == TYPE_DICTIONARY:
		for k in a.statuses.keys():
			if a.statuses[k]:
				var ks := String(k)
				active.append(ks)
				if ks.begins_with("+"): buffs += 1
				elif ks.begins_with("-"): debuffs += 1
	out.append("Statuses: +%d / -%d" % [buffs, debuffs])
	if active.size() > 0:
		active.sort()
		out.append("Active: " + ", ".join(active))

	# Survival pools / fields
	if typeof(a.survival) == TYPE_DICTIONARY:
		var s: Dictionary = a.survival
		out.append("Satiety_h:   " + str(s.get("satiety_h", null)))
		out.append("Hydration_h: " + str(s.get("hydration_h", null)))
		if s.get("awake_h", null) != null:
			out.append("Awake_h:     " + str(s.get("awake_h", null)))
		out.append("Fat_kg:      " + str(s.get("fat_kg", null)))
		# Temp
		if typeof(s.get("temp", null)) == TYPE_DICTIONARY:
			var t: Dictionary = s["temp"]
			out.append("Temp: core %.2f°C (%.2f–%.2f) acc_cold %.0fs acc_heat %.0fs"
				% [float(t.get("core_C", 0.0)), float(t.get("min_C", 0.0)), float(t.get("max_C", 0.0)),
				   float(t.get("accum_cold_s", 0.0)), float(t.get("accum_heat_s", 0.0))])
		# Gas
		if typeof(s.get("gas", null)) == TYPE_DICTIONARY:
			var g: Dictionary = s["gas"]
			out.append("Gas: %s low_acc %.0fs hyp_acc %.0fs buffer %.0fs"
				% [String(g.get("name","")), float(g.get("accum_low_s",0.0)), float(g.get("accum_hyp_s",0.0)), float(g.get("buffer_s",0.0))])
		# Diet
		if typeof(s.get("diet_eff", null)) == TYPE_DICTIONARY:
			var de: Dictionary = s["diet_eff"]
			out.append("Diet eff: plant %.2f meat %.2f" % [float(de.get("plant",0.0)), float(de.get("meat",0.0))])
		if typeof(s.get("diet_req", null)) == TYPE_DICTIONARY:
			var dr: Dictionary = s["diet_req"]
			out.append("Diet req: plant_min %.2f meat_min %.2f" % [float(dr.get("plant_min",0.0)), float(dr.get("meat_min",0.0))])
		if typeof(s.get("ema", null)) == TYPE_DICTIONARY:
			var e: Dictionary = s["ema"]
			out.append("EMA: p7 %.1f m7 %.1f p30 %.1f m30 %.1f"
				% [float(e.get("plant_7d",0.0)), float(e.get("meat_7d",0.0)), float(e.get("plant_30d",0.0)), float(e.get("meat_30d",0.0))])
		if s.get("stool_units", null) != null:
			out.append("Stool units: " + str(s.get("stool_units", null)))
	else:
		out.append("No survival data")

	_lines = out
	_dirty = false
