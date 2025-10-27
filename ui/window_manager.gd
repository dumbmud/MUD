extends Control
class_name WindowManager

signal panel_count_changed(count: int)

var _panels: Dictionary = {}   # id -> CanvasItem
var _z_next: int = 1

# Optional references for later
var _sim: SimManager
var _bus: Node
var _tracked_id: int = 0

func bind(sim: SimManager, bus: Node, tracked_actor_id: int) -> void:
	_sim = sim
	_bus = bus
	_tracked_id = tracked_actor_id
	_prewarm_log_panel()

func _prewarm_log_panel() -> void:
	if _panels.has(&"log_console"):
		return
	var s := load("res://ui/panels/LogPanel.tscn")
	if s == null:
		push_warning("LogPanel scene missing")
		return
	var node: CanvasItem = (s as PackedScene).instantiate()
	register_panel(&"log_console", node)
	if node.has_method("bind"):
		node.call("bind", _bus)
	node.visible = false   # keep hidden until first open

func open(id: StringName) -> void:
	if _panels.has(id):
		var p: CanvasItem = _panels[id]
		p.visible = true
		_focus(p)
		return
	# factories
	var node: CanvasItem = null
	if id == &"log_console":
		var s := load("res://ui/panels/LogPanel.tscn")
		node = (s as PackedScene).instantiate()
	elif id == &"actor_sheet":
		push_warning("actor_sheet not implemented yet")
	if node != null:
		register_panel(id, node)
		# bind after add_child so @onready is valid
		if node.has_method("bind"):
			node.call("bind", _bus)
	else:
		push_warning("WindowManager.open: no factory for '%s'" % String(id))

func toggle(id: StringName) -> void:
	if !_panels.has(id):
		open(id)
		return
	var p: CanvasItem = _panels[id]
	p.visible = !p.visible
	if p.visible:
		_focus(p)
	_emit_count()

func register_panel(id: StringName, panel: CanvasItem) -> void:
	_panels[id] = panel
	add_child(panel)
	panel.z_index = _z_next
	_z_next += 1
	panel.visible = true
	_emit_count()

func unregister_panel(id: StringName) -> void:
	if !_panels.has(id): return
	var p: CanvasItem = _panels[id]
	_panels.erase(id)
	if is_instance_valid(p):
		p.queue_free()
	_emit_count()

func _focus(p: CanvasItem) -> void:
	p.z_index = _z_next
	_z_next += 1
	if p is Control:
		(p as Control).grab_focus()

func _emit_count() -> void:
	emit_signal("panel_count_changed", _panels.size())
