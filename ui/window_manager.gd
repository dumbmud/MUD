# res://ui/window_manager.gd
class_name WindowManager
extends Control
## Centralized window/panel manager + UI refresh bus (Control-based).
## - open/toggle/close by id (panels are CanvasItem/UIPanel)
## - coalesced UI refresh for all open panels + registered listeners
## - runs while paused
## - exposes helpers for panels / HUD

signal panel_count_changed(count: int)
signal ui_refresh_requested

var _sim                         # SimManager (kept untyped to avoid load-order issues)
var _bus: Node = null
var _tracked_id: int = 0

var _panels: Dictionary = {}     # id:StringName -> CanvasItem (UIPanel instance)
var _z_next: int = 1

# UI refresh bus
var _ui_dirty: bool = false
var _last_tick_seen: int = -1

# Non-window UI that should refresh in sync (e.g., InfoBar)
var _listeners: Array[Node] = []

func _ready() -> void:
	# keep UI responsive even when sim is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---------- Binding & helpers ----------

func bind(sim, bus: Node, tracked_actor_id: int) -> void:
	_sim = sim
	_bus = bus
	_tracked_id = tracked_actor_id
	_last_tick_seen = _get_tick_count()
	request_ui_refresh()

func get_sim():
	return _sim

func get_tracked_actor_id() -> int:
	return _tracked_id

func set_tracked_actor_id(id: int) -> void:
	_tracked_id = id
	request_ui_refresh()

# Let non-window UI (like InfoBar) join the refresh bus
func register_listener(n: Node) -> void:
	if n == null: return
	if _listeners.has(n): return
	_listeners.append(n)
	if n.has_method("refresh"):
		n.refresh()

func unregister_listener(n: Node) -> void:
	if n == null: return
	_listeners.erase(n)

# ---------- Open / Toggle / Close ----------

func open(id: StringName) -> void:
	# If already open, bring to front
	if _panels.has(id):
		_bring_to_front(_panels[id])
		request_ui_refresh()
		return

	var node: CanvasItem = _instantiate(id)
	if node == null:
		push_warning("WindowManager: unknown window id: %s" % String(id))
		return

	add_child(node)
	_panels[id] = node
	_bring_to_front(node)

	# Conventional panel API: bind(bus) if available
	if node.has_method("bind"):
		node.bind(_bus)

	emit_signal("panel_count_changed", _panels.size())
	request_ui_refresh()

func toggle(id: StringName) -> void:
	if _panels.has(id):
		close(id)
	else:
		open(id)

func close(id: StringName) -> void:
	if !_panels.has(id):
		return
	var node: CanvasItem = _panels[id]
	_panels.erase(id)
	if is_instance_valid(node):
		node.queue_free()
	emit_signal("panel_count_changed", _panels.size())
	request_ui_refresh()

func _bring_to_front(node: CanvasItem) -> void:
	_z_next += 1
	node.z_index = _z_next

# ---------- Factory ----------

func _instantiate(id: StringName) -> CanvasItem:
	if id == &"log_console":
		var s := load("res://ui/panels/LogPanel.tscn")
		return (s as PackedScene).instantiate()
	elif id == &"survival_panel":
		var s2 := load("res://ui/panels/SurvivalPanel.tscn")
		return (s2 as PackedScene).instantiate()
	return null

# ---------- Hit-test for SimView ----------

func point_hits_panel(p: Vector2) -> bool:
	for id in _panels.keys():
		var n : CanvasItem = _panels[id]
		if n == null or !n.visible:
			continue
		if n.has_method("global_rect"):
			var r: Rect2 = (n.call("global_rect") as Rect2)
			if r.has_point(p):
				return true
	return false

# ---------- UI refresh bus ----------

func request_ui_refresh() -> void:
	# Coalesce multiple requests into one deferred flush
	if _ui_dirty:
		return
	_ui_dirty = true
	call_deferred("_flush_ui_refresh")

func _flush_ui_refresh() -> void:
	_ui_dirty = false

	# Refresh windows
	for k in _panels.keys():
		var node: CanvasItem = _panels[k]
		if is_instance_valid(node) and node.has_method("refresh"):
			node.refresh()

	# Refresh registered listeners (e.g., InfoBar)
	for n in _listeners:
		if is_instance_valid(n) and n.has_method("refresh"):
			n.refresh()

	emit_signal("ui_refresh_requested")

func _process(_dt: float) -> void:
	var tc := _get_tick_count()
	if tc != _last_tick_seen:
		_last_tick_seen = tc
		request_ui_refresh()

func _get_tick_count() -> int:
	if _sim == null:
		return _last_tick_seen
	# Prefer property if exposed
	if "tick_count" in _sim:
		return int(_sim.tick_count)
	# Fallback to method if you add one later
	if _sim.has_method("get_tick_count"):
		return int(_sim.call("get_tick_count"))
	return _last_tick_seen
