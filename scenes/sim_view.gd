# res://scenes/sim_view.gd
extends Node2D
class_name SimView

@export var sim_core: NodePath
@onready var sim: SimManager = get_node(sim_core) as SimManager
@onready var cam: Camera2D     = $Camera
@onready var console: Console  = $Console
@onready var hud: UIOverlay    = $UI/HUD

var zoom_levels: Array[float] = [0.1, 0.5, 1.0, 2.0, 3.0, 4.0]
var zoom_index := 2
var visible_w := 0
var visible_h := 0
const CELL_PX := 64
const GRID_W := 481
const GRID_H := 271

func _ready() -> void:
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.make_current()
	get_viewport().size_changed.connect(_on_view_changed)
	_apply_zoom()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)
	# Subscribe to core
	sim.redraw.connect(_on_core_redraw)
	sim.hud.connect(_on_core_hud)

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

func _on_core_redraw(player_world: Vector2i, resolver: Callable) -> void:
	console.redraw(player_world, resolver)

func _on_core_hud(
	tick:int,
	pos:Vector2i,
	mode_label:String,
	phase:int,
	phase_per_tick:int,
	is_busy:bool,
	steps:int
) -> void:
	hud.set_debug(
		tick,
		pos,
		0,
		zoom_levels[zoom_index],
		visible_w,
		visible_h,
		mode_label,
		phase,
		phase_per_tick,
		is_busy,
		steps
	)

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
