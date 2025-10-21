extends Node2D

enum GameMode { TURN_BASED, REAL_TIME }
@export var mode: GameMode = GameMode.TURN_BASED

const CELL_PX := 24
const GRID_W := 481
const GRID_H := 271

var visible_w := 0
var visible_h := 0

const TICK_SEC := 0.1
var acc := 0.0
var tick_count := 0

const COST_CARDINAL := 5
const COST_DIAGONAL := 7
var next_free_tick := 0

var player_pos := Vector2i.ZERO
var ticks_running := false

var zoom_levels: Array[float] = [0.1, 0.5, 1.0, 2.0, 3.0, 4.0]
var zoom_index := 2

var queued_dir := Vector2i.ZERO

# NEW: action state
var action_active := false
var action_dir := Vector2i.ZERO
var action_target := Vector2i.ZERO
var action_end_tick := 0

@onready var cam: Camera2D = $Camera
@onready var console: Console = $Console
@onready var ui: UIOverlay = $UI/HUD

func _ready() -> void:
	cam.position = Vector2.ZERO
	get_viewport().size_changed.connect(_on_view_changed)
	_apply_zoom()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)
	console.redraw(player_pos, Callable(self, "get_world_glyph"))
	ui.set_debug(tick_count, player_pos, next_free_tick, zoom_levels[zoom_index], visible_w, visible_h)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):           _queue_dir(Vector2i(0, -1))
	elif event.is_action_pressed("move_down"):       _queue_dir(Vector2i(0, 1))
	elif event.is_action_pressed("move_left"):       _queue_dir(Vector2i(-1, 0))
	elif event.is_action_pressed("move_right"):      _queue_dir(Vector2i(1, 0))
	elif event.is_action_pressed("move_upleft"):     _queue_dir(Vector2i(-1, -1))
	elif event.is_action_pressed("move_upright"):    _queue_dir(Vector2i(1, -1))
	elif event.is_action_pressed("move_downleft"):   _queue_dir(Vector2i(-1, 1))
	elif event.is_action_pressed("move_downright"):  _queue_dir(Vector2i(1, 1))

	if event.is_action_pressed("time_mode_toggle"):
		mode = GameMode.REAL_TIME if mode == GameMode.TURN_BASED else GameMode.TURN_BASED
		if mode == GameMode.REAL_TIME:
			ticks_running = true
		elif !action_active and _held_dir() == Vector2i.ZERO:
			ticks_running = false

	if event.is_action_pressed("zoom_in"):
		zoom_index = clamp(zoom_index + 1, 0, zoom_levels.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_out"):
		zoom_index = clamp(zoom_index - 1, 0, zoom_levels.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_reset"):
		zoom_index = 2
		_apply_zoom()

func _queue_dir(d: Vector2i) -> void:
	queued_dir = d
	_try_start_action(queued_dir)

func _held_dir() -> Vector2i:
	var x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	var v := Vector2i(x, y)
	if v == Vector2i.ZERO:
		if Input.is_action_pressed("move_upleft"): v = Vector2i(-1, -1)
		elif Input.is_action_pressed("move_upright"): v = Vector2i(1, -1)
		elif Input.is_action_pressed("move_downleft"): v = Vector2i(-1, 1)
		elif Input.is_action_pressed("move_downright"): v = Vector2i(1, 1)
	return v

func _on_view_changed() -> void:
	_update_visible()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)

func _update_visible() -> void:
	var vp_px := get_viewport_rect().size
	var z := cam.zoom.x
	visible_w = int(ceil(vp_px.x / (CELL_PX * z))) + 2
	visible_h = int(ceil(vp_px.y / (CELL_PX * z))) + 2
	if (visible_w & 1) == 0: visible_w += 1
	if (visible_h & 1) == 0: visible_h += 1

func _apply_zoom() -> void:
	var z: float = zoom_levels[zoom_index]
	cam.zoom = Vector2(z, z)
	_update_visible()

func _process(dt: float) -> void:
	if mode == GameMode.REAL_TIME or (mode == GameMode.TURN_BASED and ticks_running):
		acc += dt
		while acc >= TICK_SEC:
			_tick()
			acc -= TICK_SEC

func _tick() -> void:
	tick_count += 1

	# 1) Finish action at its end tick
	if action_active and tick_count >= action_end_tick:
		action_active = false
		player_pos = action_target

	# 2) If free, decide next step
	if !action_active and tick_count >= next_free_tick:
		var dir := queued_dir
		if dir == Vector2i.ZERO:
			dir = _held_dir()

		if dir != Vector2i.ZERO:
			_try_start_action(dir)  # starts now, completes in future ticks
		else:
			if mode == GameMode.REAL_TIME:
				next_free_tick = tick_count + 1  # idle exactly one tick
			else:
				ticks_running = false
				acc = 0.0

	# 3) draw
	console.redraw(player_pos, Callable(self, "get_world_glyph"))
	ui.set_debug(tick_count, player_pos, next_free_tick, zoom_levels[zoom_index], visible_w, visible_h)

func _try_start_action(dir: Vector2i) -> void:
	if action_active: return
	if dir == Vector2i.ZERO: return
	var target := player_pos + dir
	if !_is_passable(target): return

	var cost := _cost_for_dir(dir)
	action_active = true
	action_dir = dir
	action_target = target
	action_end_tick = tick_count + cost
	next_free_tick = action_end_tick
	queued_dir = Vector2i.ZERO

	if mode == GameMode.TURN_BASED and !ticks_running:
		ticks_running = true
		acc = 0.0

func _cost_for_dir(d: Vector2i) -> int:
	return COST_DIAGONAL if (abs(d.x) + abs(d.y) == 2) else COST_CARDINAL

# passability/world unchanged
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
