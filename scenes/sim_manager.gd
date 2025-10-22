extends Node2D
const COST_CARDINAL_TU := 100
const COST_DIAGONAL_TU := 141
const TU_PER_TICK := 10
const MAX_STEPS_PER_TICK := 4

enum GameMode { TURN_BASED, REAL_TIME }
@export var mode: GameMode = GameMode.TURN_BASED

const CELL_PX := 70
const GRID_W := 481
const GRID_H := 271

var visible_w := 0
var visible_h := 0

var zoom_levels: Array[float] = [0.1, 0.5, 1.0, 2.0, 3.0, 4.0]
var zoom_index := 2

@onready var cam: Camera2D = $Camera
@onready var console: Console = $Console
@onready var ui: UIOverlay = $UI/HUD
@onready var world: DebugWorld = $DebugWorld

const TICK_SEC := 0.1
var tick_accum := 0.0
var tick_count := 0
var ticks_running := false

# --- actors / occupancy ---
var actors: Array[Actor] = []
var next_actor_id := 1
var tile_occupant: Dictionary = {}  # Dictionary<Vector2i,int>
var npc_dir_by_id: Dictionary = {}  # id -> Vector2i

# --- player intent (one-shot) ---
var intent_dir := Vector2i.ZERO
var intent_wait := 0

func _ready() -> void:
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.make_current()
	get_viewport().size_changed.connect(_on_view_changed)
	_apply_zoom()
	console.configure(CELL_PX, visible_w, visible_h, GRID_W, GRID_H)

	# spawn player at origin
	var p := ActorFactory.spawn(0, Vector2i.ZERO, &"human", true)
	actors.append(p)
	tile_occupant[p.grid_pos] = p.actor_id

	# spawn two test NPCs
	_add_npc(&"goblin", Vector2i(-15, -8), Vector2i(1, 0))  # race lane
	_add_npc(&"goblin", Vector2i(-18, 0),  Vector2i(1, 0))  # plus hall
	



	_redraw()


func _add_npc(species_id: StringName, start: Vector2i, dir: Vector2i) -> void:
	var a: Actor = ActorFactory.spawn(next_actor_id, start, species_id, false)
	next_actor_id += 1
	a.pending_dir = Vector2i.ZERO
	a.is_waiting = false
	a.ready_at_tick = 0
	actors.append(a)
	tile_occupant[a.grid_pos] = a.actor_id
	npc_dir_by_id[a.actor_id] = dir


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("time_mode_toggle"):
		mode = GameMode.REAL_TIME if mode == GameMode.TURN_BASED else GameMode.TURN_BASED
		if mode == GameMode.REAL_TIME:
			ticks_running = true
		else:
			ticks_running = _player().is_waiting or _any_input_held() or intent_dir != Vector2i.ZERO or intent_wait > 0

	# Latch one action even if waiting; forbid if winding up a move
	var pl := _player()
	if pl.pending_dir == Vector2i.ZERO:
		if event.is_action_pressed("wait_5"): intent_wait = 5
		elif event.is_action_pressed("wait_1"): intent_wait = 1
		elif event.is_action_pressed("move_up"): intent_dir = Vector2i(0,-1)
		elif event.is_action_pressed("move_down"): intent_dir = Vector2i(0,1)
		elif event.is_action_pressed("move_left"): intent_dir = Vector2i(-1,0)
		elif event.is_action_pressed("move_right"): intent_dir = Vector2i(1,0)
		elif event.is_action_pressed("move_upleft"): intent_dir = Vector2i(-1,-1)
		elif event.is_action_pressed("move_upright"): intent_dir = Vector2i(1,-1)
		elif event.is_action_pressed("move_downleft"): intent_dir = Vector2i(-1,1)
		elif event.is_action_pressed("move_downright"): intent_dir = Vector2i(1,1)

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

func _process(dt: float) -> void:
	if mode == GameMode.REAL_TIME or (mode == GameMode.TURN_BASED and ticks_running):
		tick_accum += dt
		while tick_accum >= TICK_SEC:
			_tick()
			tick_accum -= TICK_SEC

func _tick() -> void:
	tick_count += 1

	# 1) REFILL: skip TU on ALL ticks while explicitly waiting (moves-in-progress DO refill)
	for a in actors:
		if a.is_waiting and a.pending_dir == Vector2i.ZERO:
			continue
		a.energy_tu += a.tu_per_tick

	# 2) SCHEDULE: consume intents and HOLD/AI; RT idle → Wait(1)
	var player_steps_this_tick := 0

	for a in actors:
		if a.is_waiting or a.pending_dir != Vector2i.ZERO:
			continue

		if a.is_player:
			var did_something := false

			# explicit Wait(n): counts THIS tick as the first wait tick
			if intent_wait > 0:
				a.is_waiting = true
				a.ready_at_tick = tick_count + max(1, intent_wait) - 1
				intent_wait = 0
				did_something = true

			# one-shot Move
			elif intent_dir != Vector2i.ZERO:
				var cost := _cost_for_dir(intent_dir)
				if a.energy_tu >= cost:
					var target := a.grid_pos + intent_dir
					if not _move_blocked(a.grid_pos, intent_dir, target) and not tile_occupant.has(target):
						a.energy_tu -= cost
						tile_occupant.erase(a.grid_pos)
						a.grid_pos = target
						tile_occupant[a.grid_pos] = a.actor_id
					else:
						a.energy_tu -= cost
					player_steps_this_tick = 1
				else:
					var need := cost - a.energy_tu
					var ticks_needed := ceili(float(need) / float(a.tu_per_tick))
					a.pending_dir = intent_dir
					a.is_waiting = true
					a.ready_at_tick = tick_count + max(1, ticks_needed)
				intent_dir = Vector2i.ZERO
				did_something = true

			# HOLD behavior
			if not did_something:
				var hold := _held_dir()
				if hold != Vector2i.ZERO:
					var steps := 0
					while steps < MAX_STEPS_PER_TICK:
						var c := _cost_for_dir(hold)
						if a.energy_tu < c: break
						var t := a.grid_pos + hold
						if not _move_blocked(a.grid_pos, hold, t) and not tile_occupant.has(t):
							a.energy_tu -= c
							tile_occupant.erase(a.grid_pos)
							a.grid_pos = t
							tile_occupant[a.grid_pos] = a.actor_id
						else:
							a.energy_tu -= c
						steps += 1
					if steps > 0:
						player_steps_this_tick = steps
				else:
					# RT idle auto-waits one future tick
					if mode == GameMode.REAL_TIME:
						a.is_waiting = true
						a.ready_at_tick = tick_count + 1
			continue

		# NPCs: simple pacer brain with HOLD semantics
		var brain_dir: Vector2i = npc_dir_by_id.get(a.actor_id, Vector2i.ZERO)
		if brain_dir == Vector2i.ZERO:
			a.is_waiting = true
			a.ready_at_tick = tick_count + 1
		else:
			var steps := 0
			while steps < MAX_STEPS_PER_TICK:
				var c := _cost_for_dir(brain_dir)
				if a.energy_tu < c: break
				var t := a.grid_pos + brain_dir
				if _move_blocked(a.grid_pos, brain_dir, t) or tile_occupant.has(t):
					a.is_waiting = true
					a.ready_at_tick = tick_count + 1
					npc_dir_by_id[a.actor_id] = -brain_dir
					break
				a.energy_tu -= c
				tile_occupant.erase(a.grid_pos)
				a.grid_pos = t
				tile_occupant[a.grid_pos] = a.actor_id
				steps += 1

	# 3) RESOLVE: finish waits and pending moves at/after ready_at_tick
	actors.sort_custom(func(x, y): return x.actor_id < y.actor_id)
	for a in actors:
		# explicit Wait ends: zero energy
		if a.is_waiting and a.pending_dir == Vector2i.ZERO and tick_count >= a.ready_at_tick:
			a.energy_tu = 0
			a.is_waiting = false
		# pending move commits
		if a.pending_dir != Vector2i.ZERO and tick_count >= a.ready_at_tick:
			var cost := _cost_for_dir(a.pending_dir)
			a.energy_tu = max(0, a.energy_tu - cost)
			var target := a.grid_pos + a.pending_dir
			if !_move_blocked(a.grid_pos, a.pending_dir, target) and not tile_occupant.has(target):
				tile_occupant.erase(a.grid_pos)
				a.grid_pos = target
				tile_occupant[a.grid_pos] = a.actor_id
			a.pending_dir = Vector2i.ZERO
			a.is_waiting = false

	# 4) DRAW / HUD
	_redraw()
	ui.set_debug(
		tick_count,
		_player().grid_pos,
		_player().ready_at_tick,
		zoom_levels[zoom_index],
		visible_w, visible_h,
		"RT" if mode == GameMode.REAL_TIME else "TB",
		_player().energy_tu,
		_player().tu_per_tick,
		_player().is_waiting,
		player_steps_this_tick
	)

	# 5) TB PAUSE: pause unless waiting, holding, or winding up a move
	if mode == GameMode.TURN_BASED:
		var keep_running := _player().is_waiting \
			or _player().pending_dir != Vector2i.ZERO \
			or _any_input_held()
		if keep_running:
			ticks_running = true
		else:
			ticks_running = false
			tick_accum = 0.0

func _player() -> Actor:
	return actors[0]  # id 0 reserved for player

func _redraw() -> void:
	console.redraw(_player().grid_pos, Callable(self, "resolve_cell"))

# ---- view helpers ----
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

# ---- input helpers ----
func _held_dir() -> Vector2i:
	var x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	var v := Vector2i(x, y)
	if v == Vector2i.ZERO:
		if Input.is_action_pressed("move_upleft"): v = Vector2i(-1, -1)
		elif Input.is_action_pressed("move_upright"): v = Vector2i(1, -1)
		elif Input.is_action_pressed("move_downleft"): v = Vector2i(-1, 1)
		elif Input.is_action_pressed("move_downright"): v = Vector2i(1, 1)
	if v.x != 0: v.x = sign(v.x)
	if v.y != 0: v.y = sign(v.y)
	return v

func _any_input_held() -> bool:
	return _held_dir() != Vector2i.ZERO \
		or Input.is_action_pressed("wait_1") \
		or Input.is_action_pressed("wait_5")

# ---- costs / world / glyph ----
func _cost_for_dir(d: Vector2i) -> int:
	return COST_DIAGONAL_TU if (abs(d.x) + abs(d.y) == 2) else COST_CARDINAL_TU

func _move_blocked(from: Vector2i, dir: Vector2i, target: Vector2i) -> bool:
	if !world.is_passable(target): return true
	if abs(dir.x) + abs(dir.y) == 2:
		var side_a := Vector2i(from.x + dir.x, from.y)
		var side_b := Vector2i(from.x, from.y + dir.y)
		if world.is_wall(side_a) and world.is_wall(side_b):
			return true
	return false

func resolve_cell(p: Vector2i) -> Variant:
	# One glyph per cell. Background chosen elsewhere.444
	var pl: Actor = _player()
	if p == pl.grid_pos:
		return {"ch": pl.glyph, "fg": pl.fg_color}

	for a in actors:
		if a.is_player: continue
		if a.grid_pos == p:
			return {"ch": a.glyph, "fg": a.fg_color}

	return world.glyph(p)
