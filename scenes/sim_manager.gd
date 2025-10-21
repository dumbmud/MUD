extends Node2D

const CELL_PX: int = 24
const GRID_W: int = 481
const GRID_H: int = 271

var visible_w := 0
var visible_h := 0

const TICK_SEC: float = 0.1
var acc: float = 0.0
var tick_count: int = 0

const COST_CARDINAL: int = 5
const COST_DIAGONAL: int = 7
var next_free_tick: int = 0

var player_pos: Vector2i = Vector2i(0, 0)

var zoom_levels: Array[float] = [0.1, 0.5, 1.0, 2.0, 3.0, 4.0]
var zoom_index: int = 2  # default = 1.0


var queued_dir: Vector2i = Vector2i.ZERO

@onready var cam: Camera2D = $Camera
@onready var console: Console = $Console
@onready var ui: UIOverlay = $UI/HUD

func _ready() -> void:
	cam.position = Vector2.ZERO
	cam.make_current()
	get_viewport().size_changed.connect(_on_view_changed)
	_apply_zoom()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)
	console.redraw(player_pos, Callable(self, "get_world_glyph"))


func _input(event: InputEvent) -> void:
	# Movement uses GUI-defined actions:
	# move_up, move_down, move_left, move_right,
	# move_upleft, move_upright, move_downleft, move_downright
	if event.is_action_pressed("move_up"):           _queue_dir(Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):       _queue_dir(Vector2i(0, 1))
	elif event.is_action_pressed("move_left"):       _queue_dir(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):      _queue_dir(Vector2i(1, 0))
	elif event.is_action_pressed("move_upleft"):     _queue_dir(Vector2i(-1, -1))
	elif event.is_action_pressed("move_upright"):    _queue_dir(Vector2i(1, -1))
	elif event.is_action_pressed("move_downleft"):   _queue_dir(Vector2i(-1, 1))
	elif event.is_action_pressed("move_downright"):  _queue_dir(Vector2i(1, 1))

	# Optional zoom actions if you created them in the GUI:
	if event.is_action_pressed("zoom_in"):
		zoom_index = clamp(zoom_index + 1, 0, zoom_levels.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_out"):
		zoom_index = clamp(zoom_index - 1, 0, zoom_levels.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_reset"):
		zoom_index = 1
		_apply_zoom()

func _on_view_changed() -> void:
	_update_visible()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)


func _update_visible() -> void:
	var vp_px := get_viewport_rect().size
	var z := cam.zoom.x
	visible_w = int(ceil(vp_px.x / (CELL_PX * z))) + 2
	visible_h = int(ceil(vp_px.y / (CELL_PX * z))) + 2
	if (visible_w & 1) == 0: visible_w += 1   # make odd
	if (visible_h & 1) == 0: visible_h += 1

func _queue_dir(d: Vector2i) -> void:
	if queued_dir == Vector2i.ZERO:
		queued_dir = d

func _apply_zoom() -> void:
	var z: float = zoom_levels[zoom_index]
	cam.zoom = Vector2(z, z)
	_update_visible()

func _process(dt: float) -> void:
	acc += dt
	while acc >= TICK_SEC:
		_tick()
		acc -= TICK_SEC

func _tick() -> void:
	tick_count += 1
	_process_actions()
	console.redraw(player_pos, Callable(self, "get_world_glyph"))
	ui.set_debug(tick_count, player_pos, next_free_tick, zoom_levels[zoom_index], visible_w, visible_h)

func _process_actions() -> void:
	if tick_count < next_free_tick:
		return
	if queued_dir == Vector2i.ZERO:
		return
	var diag: bool = (abs(queued_dir.x) + abs(queued_dir.y)) == 2
	var cost: int = COST_DIAGONAL if diag else COST_CARDINAL
	var target: Vector2i = player_pos + queued_dir
	if _is_passable(target):
		player_pos = target
		next_free_tick = tick_count + cost
	queued_dir = Vector2i.ZERO

func _is_in_room(p: Vector2i) -> bool:
	return p.x >= -10 and p.x <= 10 and p.y >= -10 and p.y <= 10

func _is_wall(p: Vector2i) -> bool:
	return _is_in_room(p) and (p.x == -10 or p.x == 10 or p.y == -10 or p.y == 10)

func _is_passable(p: Vector2i) -> bool:
	return _is_in_room(p) and not _is_wall(p)

func get_world_glyph(p: Vector2i) -> String:
	if _is_wall(p): return "#"
	elif _is_in_room(p): return "."
	return " "
