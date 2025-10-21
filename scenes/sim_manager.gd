extends Node2D

enum GameMode { TURN_BASED, REAL_TIME }
@export var mode: GameMode = GameMode.TURN_BASED

# ---------- Display / world ----------
const CELL_PX := 64
const GRID_W := 481
const GRID_H := 271

var visible_w := 0
var visible_h := 0

var player_pos := Vector2i.ZERO

var zoom_levels: Array[float] = [0.1, 0.5, 1.0, 2.0, 3.0, 4.0]
var zoom_index := 2

@onready var cam: Camera2D = $Camera
@onready var console: Console = $Console
@onready var ui: UIOverlay = $UI/HUD

# ---------- Timebase ----------
const TICK_SEC := 0.1                # 1 tick = 0.1s real time
var acc := 0.0
var tick_count := 0
var ticks_running := false           # only meaningful in TB; RT always advances

# ---------- TU / Costs (spec names) ----------
const TU_PER_TICK := 10              # present for completeness; not directly used in math
const COST_CARDINAL_TU := 100
const COST_DIAGONAL_TU := 141
@export var SPEED_TU_PER_TICK := 20  # default speed: ~0.5s card, ~0.7s diag (emergent)

# ---------- Actor state (single-actor) ----------
var energy_TU := 0                   # per-actor energy bank
var is_busy := false                 # true only while in an explicit Wait
var ready_tick := 0                  # end tick for Wait

# ---------- One-shot input + pending move ----------
var intent_dir := Vector2i.ZERO        # set on key press, consumed once
var intent_wait := 0                   # 1 or 5, consumed once
var pending_move_dir := Vector2i.ZERO  # non-zero while a move is winding up to completion

# ---------- Lifecycle ----------
func _ready() -> void:
	position = Vector2.ZERO
	cam.position = Vector2.ZERO
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.make_current()
	get_viewport().size_changed.connect(_on_view_changed)
	_apply_zoom()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)
	console.redraw(player_pos, Callable(self, "get_world_glyph"))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("time_mode_toggle"):
		mode = GameMode.REAL_TIME if mode == GameMode.TURN_BASED else GameMode.TURN_BASED
		if mode == GameMode.REAL_TIME:
			ticks_running = true
		else:
			# TB pauses if idle; else keep ticking
			ticks_running = is_busy or _any_input_held() or intent_dir != Vector2i.ZERO or intent_wait > 0

	# Latch exactly one action on press.
	# Allow latching during waits (implicit or explicit).
	# Forbid latching while a move is winding up (pending_move_dir != ZERO).
	if pending_move_dir == Vector2i.ZERO:
		if event.is_action_pressed("move_up"):           intent_dir = Vector2i(0, -1)
		elif event.is_action_pressed("move_down"):       intent_dir = Vector2i(0, 1)
		elif event.is_action_pressed("move_left"):       intent_dir = Vector2i(-1, 0)
		elif event.is_action_pressed("move_right"):      intent_dir = Vector2i(1, 0)
		elif event.is_action_pressed("move_upleft"):     intent_dir = Vector2i(-1, -1)
		elif event.is_action_pressed("move_upright"):    intent_dir = Vector2i(1, -1)
		elif event.is_action_pressed("move_downleft"):   intent_dir = Vector2i(-1, 1)
		elif event.is_action_pressed("move_downright"):  intent_dir = Vector2i(1, 1)
		elif event.is_action_pressed("wait_5"):          intent_wait = 5
		elif event.is_action_pressed("wait_1"):          intent_wait = 1

	# Wake TB immediately on a latched intent.
	if mode == GameMode.TURN_BASED and !ticks_running and (intent_dir != Vector2i.ZERO or intent_wait > 0):
		ticks_running = true

	if event.is_action_pressed("zoom_in"):
		zoom_index = clamp(zoom_index + 1, 0, zoom_levels.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_out"):
		zoom_index = clamp(zoom_index - 1, 0, zoom_levels.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_reset"):
		zoom_index = 2
		_apply_zoom()


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

# ---------- Main loop ----------
func _process(dt: float) -> void:
	if mode == GameMode.REAL_TIME or (mode == GameMode.TURN_BASED and ticks_running):
		acc += dt
		while acc >= TICK_SEC:
			_tick()
			acc -= TICK_SEC

func _tick() -> void:
	tick_count += 1

	# ---------- REFILL first ----------
	# Refill unless this is the final tick of a Wait. Moves-in-progress DO refill.
	if !is_busy:
		energy_TU += SPEED_TU_PER_TICK
	elif pending_move_dir != Vector2i.ZERO:
		energy_TU += SPEED_TU_PER_TICK
	elif tick_count < ready_tick:
		energy_TU += SPEED_TU_PER_TICK
	# else: waiting and this is the final wait tick → skip refill

	# ---------- RESOLVE ----------
	# A) Finish Wait: zero energy, clear busy.
	if is_busy and pending_move_dir == Vector2i.ZERO and tick_count >= ready_tick:
		energy_TU = 0
		is_busy = false

	# B) Finish pending Move: subtract cost now, attempt the move at this tick.
	if is_busy and pending_move_dir != Vector2i.ZERO and tick_count >= ready_tick:
		var cost := _cost_for_dir(pending_move_dir)
		energy_TU = max(0, energy_TU - cost)  # consume cost; never negative
		var target := player_pos + pending_move_dir
		if !_move_blocked(player_pos, pending_move_dir, target):
			player_pos = target
		# clear action
		pending_move_dir = Vector2i.ZERO
		is_busy = false

	var steps_this_tick := 0
	var input_any := false

	# ---------- SCHEDULE ----------
	if !is_busy:
		# Consume one-shot intent first.
		if intent_wait > 0:
			is_busy = true
			ready_tick = tick_count + intent_wait
			intent_wait = 0
			input_any = true

		elif intent_dir != Vector2i.ZERO:
			var cost := _cost_for_dir(intent_dir)
			# If we already have enough, execute exactly ONE step now.
			if energy_TU >= cost:
				var target := player_pos + intent_dir
				var blocked := _move_blocked(player_pos, intent_dir, target)
				energy_TU -= cost
				_claim(target, tick_count, 0)  # stub for future TIOM
				if !blocked:
					player_pos = target
				steps_this_tick = 1
			else:
				# Not enough energy: start a pending move that will complete when energy suffices.
				var need := cost - energy_TU
				var ticks_needed := int(ceil(float(need) / float(SPEED_TU_PER_TICK)))
				pending_move_dir = intent_dir
				is_busy = true
				ready_tick = tick_count + max(1, ticks_needed)
			intent_dir = Vector2i.ZERO
			input_any = true

		else:
			# No one-shot intent; allow HOLD behavior.
			var hold_dir := _held_dir()
			if hold_dir != Vector2i.ZERO:
				var steps_limit := 4
				while steps_this_tick < steps_limit:
					var cost := _cost_for_dir(hold_dir)
					if energy_TU < cost:
						break
					var target := player_pos + hold_dir
					var blocked := _move_blocked(player_pos, hold_dir, target)
					energy_TU -= cost
					_claim(target, tick_count, 0)
					if !blocked:
						player_pos = target
					steps_this_tick += 1
				input_any = true
			else:
				# RT idle → implicit Wait(1)
				if mode == GameMode.REAL_TIME:
					is_busy = true
					ready_tick = tick_count + 1

	# ---------- DRAW / HUD ----------
	console.redraw(player_pos, Callable(self, "get_world_glyph"))
	ui.set_debug(
		tick_count,
		player_pos,
		ready_tick,
		zoom_levels[zoom_index],
		visible_w,
		visible_h,
		"RT" if mode == GameMode.REAL_TIME else "TB",
		energy_TU,
		SPEED_TU_PER_TICK,
		is_busy,
		steps_this_tick
	)

	# ---------- TB pause rule ----------
	if mode == GameMode.TURN_BASED:
		if is_busy or steps_this_tick > 0 or input_any:
			ticks_running = true
		else:
			ticks_running = false
			acc = 0.0

# ---------- Input helpers ----------
func _held_dir() -> Vector2i:
	# Axis-based diagonals first; explicit diagonals as fallback
	var x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	var v := Vector2i(x, y)
	if v == Vector2i.ZERO:
		if Input.is_action_pressed("move_upleft"): v = Vector2i(-1, -1)
		elif Input.is_action_pressed("move_upright"): v = Vector2i(1, -1)
		elif Input.is_action_pressed("move_downleft"): v = Vector2i(-1, 1)
		elif Input.is_action_pressed("move_downright"): v = Vector2i(1, 1)
	# Normalize to {-1,0,1} components; disallow illegal inputs like (2,0)
	if v.x != 0: v.x = sign(v.x)
	if v.y != 0: v.y = sign(v.y)
	return v

func _any_input_held() -> bool:
	return _held_dir() != Vector2i.ZERO \
		or Input.is_action_pressed("wait_1") \
		or Input.is_action_pressed("wait_5")

# ---------- Move rules ----------
func _cost_for_dir(d: Vector2i) -> int:
	return COST_DIAGONAL_TU if (abs(d.x) + abs(d.y) == 2) else COST_CARDINAL_TU

func _move_blocked(from: Vector2i, dir: Vector2i, target: Vector2i) -> bool:
	# Target must be passable at execution tick; if not, the move fails and still pays cost.
	if !_is_passable(target):
		return true
	# No diagonal corner-cutting: if two orthogonal walls touch corners, block the diagonal.
	if abs(dir.x) + abs(dir.y) == 2:
		var side_a := Vector2i(from.x + dir.x, from.y)
		var side_b := Vector2i(from.x, from.y + dir.y)
		if _is_wall(side_a) and _is_wall(side_b):
			return true
	return false

# ---------- Optional future stub ----------
func _claim(tile: Vector2i, commit_tick: int, actor_id: int) -> void:
	# Single-actor no-op; exists to match TIOM API later.
	pass

# ---------- World / passability ----------
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
