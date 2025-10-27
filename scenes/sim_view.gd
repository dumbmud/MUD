# res://scenes/sim_view.gd
extends Node2D
class_name SimView
##
## View wiring for the pure scheduler:
## - Subscribes to SimManager signals and redraws the Console.
## - Keeps camera + zoom controls and drives HUD.
## - Builds cell resolver here (UI concern), not in the scheduler.

@export var sim_core: NodePath
@export var tracked_actor_id: int = 0

@onready var sim: SimManager = get_node(sim_core) as SimManager
@onready var cam: Camera2D     = $Camera
@onready var console: Console  = $Console
@onready var hud: UIOverlay    = $UI/HUD
@onready var winmgr: WindowManager = $UI/WindowManager
@onready var infobar: InfoBar = $UI/InfoBar

var zoom_levels: Array[float] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 2.0, 3.0, 4.0, 5.0]
var zoom_index := 10
var visible_w := 0
var visible_h := 0
const CELL_PX := 26
const GRID_W := 481
const GRID_H := 271

func _ready() -> void:
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.make_current()
	get_viewport().size_changed.connect(_on_view_changed)
	_apply_zoom()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)
	console.set_resolver(Callable(self, "resolve_cell"))  # set once
	# Subscribe to sim
	sim.tick_advanced.connect(_on_sim_tick)
	sim.state_changed.connect(_on_sim_state_changed)
	# Initial draw
	_redraw()
	_update_hud()
	# Bind Console-based InfoBar
	if infobar != null:
		infobar.bind(sim, MessageBus, winmgr, tracked_actor_id)
	if winmgr != null:
		winmgr.bind(sim, MessageBus, tracked_actor_id)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		zoom_index = clamp(zoom_index + 1, 0, zoom_levels.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_out"):
		zoom_index = clamp(zoom_index - 1, 0, zoom_levels.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_reset"):
		zoom_index = 2
		_apply_zoom()

# ── signal handlers ──────────────────────────────────────────────────────────

func _on_sim_tick(_t: int) -> void:
	_redraw()
	_update_hud()

func _on_sim_state_changed() -> void:
	_redraw()
	_update_hud()

# ── drawing / HUD ────────────────────────────────────────────────────────────

func _tracked_actor() -> Actor:
	var a: Actor = sim.get_actor(tracked_actor_id) as Actor
	if a != null:
		return a
	if sim.actors.size() > 0:
		return sim.actors[0]
	return null

func _redraw() -> void:
	var a: Actor = _tracked_actor()
	if a == null:
		return
	console.redraw(a.grid_pos)

func resolve_cell(p: Vector2i) -> Variant:
	# Prefer actors via occupancy, else world glyph.
	var id := GridOccupancy.id_at(p)
	if id != -1:
		var a: Actor = sim.get_actor(id) as Actor
		if a != null:
			return {
				"ch": a.glyph,
				"fg": a.fg_color,
				"facing": a.facing,
				"rel": a.relation_to_player
			}
	# World glyph
	if sim.world != null:
		return sim.world.glyph(p)
	return " "

func _update_hud() -> void:
	var a: Actor = _tracked_actor()
	if a == null:
		return
	var mode_label := "RT" if (GameLoop.real_time) else "TB"
	var zoom := zoom_levels[zoom_index]
	hud.set_debug(
		sim.tick_count,
		a.grid_pos,
		zoom,
		visible_w,
		visible_h,
		mode_label,
		a.phase,
		SimManager.PHASE_PER_TICK,
		sim.in_tick,
		sim.actors.size()
	)

# ── view sizing / zoom ───────────────────────────────────────────────────────

func _on_view_changed() -> void:
	_update_visible()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)

func _apply_zoom() -> void:
	var z: float = zoom_levels[zoom_index]
	cam.zoom = Vector2(z, z)
	_update_visible()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)

func _update_visible() -> void:
	var vp := get_viewport_rect().size
	var z := cam.zoom
	var world_w_px := vp.x / z.x
	var world_h_px := vp.y / z.y
	visible_w = int(ceil(world_w_px / CELL_PX))
	visible_h = int(ceil(world_h_px / CELL_PX))
	if (visible_w & 1) == 0: visible_w += 1
	if (visible_h & 1) == 0: visible_h += 1
