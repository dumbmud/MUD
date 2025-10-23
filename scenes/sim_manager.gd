# res://scenes/sim_manager.gd
extends Node2D
class_name SimManager

# signals
signal redraw(player_pos: Vector2i, resolver: Callable)
signal hud(tick:int, pos:Vector2i, mode_label:String, phase:int, phase_per_tick:int, is_busy:bool, steps:int)

# ---- Constants ---------------------------------------------------------------
const TICK_SEC := 0.1
const CELL_PX := 70
const GRID_W := 481
const GRID_H := 271

const COST_CARDINAL := 100
const COST_DIAGONAL := 141

enum GameMode { TURN_BASED, REAL_TIME }
@export var mode: GameMode = GameMode.TURN_BASED

# ---- Scene refs --------------------------------------------------------------
@onready var world: DebugWorld = $DebugWorld

# ---- View / zoom -------------------------------------------------------------
var zoom_levels: Array[float] = [0.1, 0.5, 1.0, 2.0, 3.0, 4.0]
var zoom_index := 2
var visible_w := 0
var visible_h := 0

# ---- Time -------------------------------------------------------------------
var tick_accum := 0.0
var tick_count := 0
var ticks_running := false

# ---- Actors / occupancy ------------------------------------------------------
var actors: Array[Actor] = []
var next_actor_id := 1
var tile_occupant: Dictionary = {}        # Dictionary<Vector2i,int>
var npc_dir_by_id: Dictionary = {}        # id -> Vector2i

# ---- Command + Activity model -----------------------------------------------
# Command: Dictionary {verb:StringName, args:Dictionary, resumable:bool=false, resume_key:Variant=null}
# Activity: Dictionary {cmd:Dictionary, remaining:int}
var activity_by_id: Dictionary[int, Variant] = {}              # id -> Activity or null
var resume_table: Dictionary[Variant, Dictionary] = {}         # key -> Activity (verbs opt-in)
var tap_queue: Array[Dictionary] = []                          # player-only queue of Commands

# -----------------------------------------------------------------------------
func _ready() -> void:
	# Player
	var p := ActorFactory.spawn(0, Vector2i.ZERO, &"human", true)
	actors.append(p)
	tile_occupant[p.grid_pos] = p.actor_id
	activity_by_id[p.actor_id] = null

	# NPCs
	_add_npc(&"goblin", Vector2i(-15, -8), Vector2i(1, 0))
	_add_npc(&"goblin", Vector2i(-18, 0),  Vector2i(1, 0))

	_redraw()

func _add_npc(species_id: StringName, start: Vector2i, dir: Vector2i) -> void:
	var a: Actor = ActorFactory.spawn(next_actor_id, start, species_id, false)
	next_actor_id += 1
	actors.append(a)
	tile_occupant[a.grid_pos] = a.actor_id
	npc_dir_by_id[a.actor_id] = dir
	activity_by_id[a.actor_id] = null

# -----------------------------------------------------------------------------
# Input: taps enqueue. Holds sampled only at control boundary.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("time_mode_toggle"):
		mode = GameMode.REAL_TIME if mode == GameMode.TURN_BASED else GameMode.TURN_BASED
		ticks_running = true if mode == GameMode.REAL_TIME else _should_keep_running_TB()

	# Movement taps
	if event.is_action_pressed("move_up"):        tap_queue.append(_cmd_move(Vector2i(0,-1)))
	elif event.is_action_pressed("move_down"):    tap_queue.append(_cmd_move(Vector2i(0,1)))
	elif event.is_action_pressed("move_left"):    tap_queue.append(_cmd_move(Vector2i(-1,0)))
	elif event.is_action_pressed("move_right"):   tap_queue.append(_cmd_move(Vector2i(1,0)))
	elif event.is_action_pressed("move_upleft"):  tap_queue.append(_cmd_move(Vector2i(-1,-1)))
	elif event.is_action_pressed("move_upright"): tap_queue.append(_cmd_move(Vector2i(1,-1)))
	elif event.is_action_pressed("move_downleft"):tap_queue.append(_cmd_move(Vector2i(-1,1)))
	elif event.is_action_pressed("move_downright"):tap_queue.append(_cmd_move(Vector2i(1,1)))

	# Wait taps
	if event.is_action_pressed("wait_1"): tap_queue.append(_cmd_wait(1))
	if event.is_action_pressed("wait_5"): tap_queue.append(_cmd_wait(5))

	# TB autostart only if next tap is valid after draining invalid taps
	if mode == GameMode.TURN_BASED and !_is_busy(_player()):
		_drain_invalid_player_taps()
		if tap_queue.size() > 0 and _can_start(_player(), tap_queue[0]):
			ticks_running = true

# -----------------------------------------------------------------------------
func _process(dt: float) -> void:
	if mode == GameMode.REAL_TIME or (mode == GameMode.TURN_BASED and ticks_running):
		tick_accum += dt
		while tick_accum >= TICK_SEC:
			_tick()
			tick_accum -= TICK_SEC

# -----------------------------------------------------------------------------
func _tick() -> void:
	tick_count += 1

	# Regen phase
	for a in actors:
		a.phase += a.phase_per_tick

	var player_steps_this_tick := 0

	# Player-first
	actors.sort_custom(func(x, y): return x.actor_id < y.actor_id)

	for a in actors:
		var safety := 0
		while true:
			var act: Variant = activity_by_id.get(a.actor_id, null)

			# Boundary: acquire command
			if act == null:
				var cmd_v: Variant = _acquire_command(a)
				if cmd_v == null:
					break
				var cmd_d: Dictionary = cmd_v
				if bool(cmd_d.get("resumable", false)) and resume_table.has(cmd_d.get("resume_key", null)):
					act = resume_table[cmd_d["resume_key"]]
				else:
					act = {"cmd": cmd_d, "remaining": _phase_cost_for(a, cmd_d)}
					if cmd_d["verb"] == &"Wait":
						a.phase = 0
				activity_by_id[a.actor_id] = act

			# Commit if enough phase
			var act_d: Dictionary = act
			var need: int = int(act_d["remaining"])
			if a.phase < need:
				break

			a.phase -= need
			var cmd2: Dictionary = act_d["cmd"]
			var committed: bool = _apply_if_still_valid(a, cmd2)

			# resumable cleanup (stub)
			if bool(cmd2.get("resumable", false)):
				var key: Variant = cmd2.get("resume_key", null)
				resume_table.erase(key)

			activity_by_id[a.actor_id] = null

			if a.is_player and cmd2["verb"] == &"Move" and committed:
				player_steps_this_tick += 1

			safety += 1
			if safety > 64:
				break

	# Redraw + HUD
	_redraw()
	emit_signal(
		"hud",
		tick_count,
		_player().grid_pos,
		("RT" if mode == GameMode.REAL_TIME else "TB"),
		_player().phase,
		_player().phase_per_tick,
		_is_busy(_player()),
		player_steps_this_tick
	)


	# TB pause rule
	if mode == GameMode.TURN_BASED:
		ticks_running = _should_keep_running_TB()
		if !ticks_running:
			tick_accum = 0.0

# -----------------------------------------------------------------------------
# Drain invalid taps so TB does not advance when pressing into a wall
func _drain_invalid_player_taps() -> void:
	var pl := _player()
	while tap_queue.size() > 0:
		var cmd: Dictionary = tap_queue[0]
		if _can_start(pl, cmd):
			return
		tap_queue.pop_front()
		_emit_msg("blocked: %s" % [str(cmd)])

# -----------------------------------------------------------------------------
# Command acquisition (boundary). Taps beat holds. Gate with can_start.
func _acquire_command(a: Actor) -> Variant:
	if a.is_player:
		# taps
		while tap_queue.size() > 0:
			var cmd_d: Dictionary = tap_queue.pop_front()
			if _can_start(a, cmd_d): return cmd_d
			_emit_msg("blocked: %s" % [str(cmd_d)])

		# holds
		for cmd in _held_actions_now():
			var hc: Dictionary = cmd
			if _can_start(a, hc): return hc
			_emit_msg("blocked: %s" % [str(hc)])

		# RT auto-wait, TB pause
		return _cmd_wait(1) if mode == GameMode.REAL_TIME else null
	else:
		var dir: Vector2i = npc_dir_by_id.get(a.actor_id, Vector2i.ZERO)
		if dir != Vector2i.ZERO:
			var mv: Dictionary = _cmd_move(dir)
			if _can_start(a, mv): return mv
			npc_dir_by_id[a.actor_id] = -dir
		return _cmd_wait(1) if mode == GameMode.REAL_TIME else null

# -----------------------------------------------------------------------------
# Planning checks (no time)
func _can_start(a: Actor, cmd: Dictionary) -> bool:
	var verb: StringName = cmd.get("verb", &"")
	if verb == &"Move":
		var d: Vector2i = cmd["args"].get("dir", Vector2i.ZERO)
		if d == Vector2i.ZERO: return false
		var t := a.grid_pos + d
		if _move_blocked(a.grid_pos, d, t): return false
		if tile_occupant.has(t): return false
		return true
	elif verb == &"Wait":
		return true
	return false

func _apply_if_still_valid(a: Actor, cmd: Dictionary) -> bool:
	var verb: StringName = cmd.get("verb", &"")
	if verb == &"Move":
		var d: Vector2i = cmd["args"]["dir"]
		var t := a.grid_pos + d
		if _move_blocked(a.grid_pos, d, t): return false
		if tile_occupant.has(t): return false
		tile_occupant.erase(a.grid_pos)
		a.grid_pos = t
		tile_occupant[a.grid_pos] = a.actor_id
		return true
	elif verb == &"Wait":
		return true
	return false

func _phase_cost_for(a: Actor, cmd: Dictionary) -> int:
	var verb: StringName = cmd.get("verb", &"")
	if verb == &"Move":
		var d: Vector2i = cmd["args"]["dir"]
		return COST_DIAGONAL if (abs(d.x) + abs(d.y) == 2) else COST_CARDINAL
	elif verb == &"Wait":
		var ticks: int = int(cmd["args"].get("ticks", 1))
		return a.phase_per_tick * ticks
	return a.phase_per_tick

# -----------------------------------------------------------------------------
# Input helpers
func _held_actions_now() -> Array[Dictionary]:
	var cmds: Array[Dictionary] = []
	var x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	var v := Vector2i(x, y)
	if v == Vector2i.ZERO:
		if Input.is_action_pressed("move_upleft"):  v = Vector2i(-1, -1)
		elif Input.is_action_pressed("move_upright"): v = Vector2i(1, -1)
		elif Input.is_action_pressed("move_downleft"): v = Vector2i(-1, 1)
		elif Input.is_action_pressed("move_downright"): v = Vector2i(1, 1)
	if v.x != 0: v.x = sign(v.x)
	if v.y != 0: v.y = sign(v.y)
	if v != Vector2i.ZERO:
		cmds.append(_cmd_move(v))
	if Input.is_action_pressed("wait_1"): cmds.append(_cmd_wait(1))
	if Input.is_action_pressed("wait_5"): cmds.append(_cmd_wait(5))
	return cmds

func _cmd_move(dir: Vector2i) -> Dictionary:
	return {"verb": &"Move", "args": {"dir": dir}, "resumable": false}

func _cmd_wait(n: int) -> Dictionary:
	return {"verb": &"Wait", "args": {"ticks": n}, "resumable": false}

# -----------------------------------------------------------------------------
# World / geometry
func _move_blocked(from: Vector2i, dir: Vector2i, target: Vector2i) -> bool:
	if !world.is_passable(target): return true
	if abs(dir.x) + abs(dir.y) == 2:
		var side_a := Vector2i(from.x + dir.x, from.y)
		var side_b := Vector2i(from.x, from.y + dir.y)
		if world.is_wall(side_a) and world.is_wall(side_b):
			return true
	return false

# -----------------------------------------------------------------------------
# View / HUD
func _player() -> Actor:
	return actors[0]

func _redraw() -> void:
	emit_signal("redraw", _player().grid_pos, Callable(self, "resolve_cell"))

func resolve_cell(p: Vector2i) -> Variant:
	var pl: Actor = _player()
	if p == pl.grid_pos:
		return {"ch": pl.glyph, "fg": pl.fg_color}
	for a in actors:
		if a.is_player: continue
		if a.grid_pos == p:
			return {"ch": a.glyph, "fg": a.fg_color}
	return world.glyph(p)

# -----------------------------------------------------------------------------
# TB pause rule
func _should_keep_running_TB() -> bool:
	var pl := _player()
	if _is_busy(pl): return true
	_drain_invalid_player_taps()
	# valid tap?
	if tap_queue.size() > 0 and _can_start(pl, tap_queue[0]): return true
	# valid hold?
	for cmd in _held_actions_now():
		if _can_start(pl, cmd): return true
	return false

func _is_busy(a: Actor) -> bool:
	return activity_by_id.get(a.actor_id, null) != null

# -----------------------------------------------------------------------------
# Messages (stub)
func _emit_msg(text: String) -> void:
	print(text)
