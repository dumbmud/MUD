# res://scenes/sim_manager.gd
extends Node2D
class_name SimManager

signal redraw(player_pos: Vector2i, resolver: Callable)
signal hud(tick:int, pos:Vector2i, mode_label:String, phase:int, phase_per_tick:int, is_busy:bool, steps:int)

@onready var world: WorldAPI = $WorldTest

enum GameMode { TURN_BASED, REAL_TIME }
@export var mode: GameMode = GameMode.TURN_BASED

const TICK_SEC := 0.1
const PHASE_MAX := 1_000_000
var tick_accum := 0.0
var tick_count := 0
var ticks_running := false

var actors: Array[Actor] = []
var next_actor_id := 1
var npc_dir_by_id: Dictionary = {}                 # id -> Vector2i

# Command = {verb:StringName, args:Dictionary}
var tap_queue: Array[Dictionary] = []              # player-only taps
var activity_by_id: Dictionary[int, Activity] = {} # id -> Activity or null
var resume_table: Dictionary = {}                  # key->Activity (verbs opt-in)

var rng := RandomNumberGenerator.new()
@export var rng_seed: int = 123456789

var _last_blocked_hold_emit_tick := -1

func _ready() -> void:
	rng.seed = rng_seed

	# Player
	var p := ActorFactory.spawn(0, Vector2i.ZERO, &"human", true)
	actors.append(p)
	GridOccupancy.claim(p.actor_id, p.grid_pos)
	activity_by_id[p.actor_id] = null

	# NPCs
	_add_npc(&"goblin", Vector2i(-15, -8), Vector2i(1, 0))
	_add_npc(&"goblin", Vector2i(-18, 0),  Vector2i(1, 0))

	_redraw()

func _add_npc(species_id: StringName, start: Vector2i, dir: Vector2i) -> void:
	var a: Actor = ActorFactory.spawn(next_actor_id, start, species_id, false)
	next_actor_id += 1
	actors.append(a)
	GridOccupancy.claim(a.actor_id, a.grid_pos)
	npc_dir_by_id[a.actor_id] = dir
	activity_by_id[a.actor_id] = null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("time_mode_toggle"):
		mode = GameMode.REAL_TIME if mode == GameMode.TURN_BASED else GameMode.TURN_BASED
		ticks_running = true if mode == GameMode.REAL_TIME else _should_keep_running_TB()

	# Movement taps
	if event.is_action_pressed("move_up"):         tap_queue.append(_cmd_move(Vector2i(0,-1)))
	elif event.is_action_pressed("move_down"):     tap_queue.append(_cmd_move(Vector2i(0,1)))
	elif event.is_action_pressed("move_left"):     tap_queue.append(_cmd_move(Vector2i(-1,0)))
	elif event.is_action_pressed("move_right"):    tap_queue.append(_cmd_move(Vector2i(1,0)))
	elif event.is_action_pressed("move_upleft"):   tap_queue.append(_cmd_move(Vector2i(-1,-1)))
	elif event.is_action_pressed("move_upright"):  tap_queue.append(_cmd_move(Vector2i(1,-1)))
	elif event.is_action_pressed("move_downleft"): tap_queue.append(_cmd_move(Vector2i(-1,1)))
	elif event.is_action_pressed("move_downright"):tap_queue.append(_cmd_move(Vector2i(1,1)))

	# Wait taps
	if event.is_action_pressed("wait_1"): tap_queue.append(_cmd_wait(1))
	if event.is_action_pressed("wait_5"): tap_queue.append(_cmd_wait(5))

	# TB autostart only if next tap is valid after draining invalid taps
	if mode == GameMode.TURN_BASED and !_is_busy(_player()):
		_drain_invalid_player_taps()
		if tap_queue.size() > 0 and _can_start_cmd(_player(), tap_queue[0]):
			ticks_running = true

func _process(dt: float) -> void:
	if mode == GameMode.REAL_TIME or (mode == GameMode.TURN_BASED and ticks_running):
		tick_accum += dt
		while tick_accum >= TICK_SEC:
			_tick()
			tick_accum -= TICK_SEC

func _tick() -> void:
	tick_count += 1

	for a in actors:
		a.phase = min(a.phase + a.phase_per_tick, PHASE_MAX)

	var player_steps_this_tick := 0

	actors.sort_custom(func(x, y): return x.actor_id < y.actor_id)

	var round_idx := 0
	const MAX_ROUNDS_PER_TICK := 32
	while round_idx < MAX_ROUNDS_PER_TICK:
		var commits := 0
		for a in actors:
			var act: Activity = activity_by_id.get(a.actor_id, null)
			if act == null:
				var cmd_v: Variant = _acquire_command(a)
				if cmd_v != null:
					var cmd_d: Dictionary = cmd_v
					var verb_name: StringName = cmd_d["verb"]
					var args: Dictionary = cmd_d["args"]
					var verb := VerbRegistry.get_verb(verb_name)
					if verb != null:
						var key: Variant = verb.resumable_key(a, args, self)
						if key != null and resume_table.has(key):
							act = resume_table[key]
						else:
							var need := verb.phase_cost(a, args, self)
							act = Activity.from(verb_name, args, need, key)
							if verb_name == &"Wait": a.phase = 0
						activity_by_id[a.actor_id] = act

			act = activity_by_id.get(a.actor_id, null)
			if act != null and a.phase >= act.remaining:
				a.phase -= act.remaining
				var verb2 := VerbRegistry.get_verb(act.verb)
				var ok := verb2 != null and verb2.apply(a, act.args, self)
				if act.resume_key != null: resume_table.erase(act.resume_key)
				activity_by_id[a.actor_id] = null
				commits += 1
				if a.is_player and act.verb == &"Move" and ok:
					player_steps_this_tick += 1
		if commits == 0: break
		round_idx += 1

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

	if mode == GameMode.TURN_BASED:
		ticks_running = _should_keep_running_TB()
		if !ticks_running: tick_accum = 0.0

func _drain_invalid_player_taps() -> void:
	var pl := _player()
	while tap_queue.size() > 0:
		var cmd: Dictionary = tap_queue[0]
		if _can_start_cmd(pl, cmd): return
		tap_queue.pop_front()
		MessageBus.send("blocked: %s" % [str(cmd)], &"info", tick_count, pl.actor_id)

func _acquire_command(a: Actor) -> Variant:
	if a.is_player:
		while tap_queue.size() > 0:
			var cmd_d: Dictionary = tap_queue.pop_front()
			if _can_start_cmd(a, cmd_d): return cmd_d
			MessageBus.send("blocked: %s" % [str(cmd_d)], &"info", tick_count, a.actor_id)
		for cmd in _held_actions_now():
			var hc: Dictionary = cmd
			if _can_start_cmd(a, hc): return hc
			if _last_blocked_hold_emit_tick != tick_count:
				_last_blocked_hold_emit_tick = tick_count
				MessageBus.send("blocked: %s" % [str(hc)], &"info", tick_count, a.actor_id)
		if mode == GameMode.REAL_TIME:
			return _cmd_wait(1)
		return null
	else:
		var dir: Vector2i = npc_dir_by_id.get(a.actor_id, Vector2i.ZERO)
		if dir != Vector2i.ZERO:
			var mv: Dictionary = _cmd_move(dir)
			if _can_start_cmd(a, mv): return mv
			npc_dir_by_id[a.actor_id] = -dir
		if mode == GameMode.REAL_TIME:
			return _cmd_wait(1)
		return null

func _can_start_cmd(a: Actor, cmd: Dictionary) -> bool:
	var verb_name: StringName = cmd.get("verb", &"")
	var args: Dictionary = cmd.get("args", {})
	var verb := VerbRegistry.get_verb(verb_name)
	return verb != null and verb.can_start(a, args, self)

func _cmd_move(dir: Vector2i) -> Dictionary:
	return {"verb": &"Move", "args": {"dir": dir}}

func _cmd_wait(n: int) -> Dictionary:
	return {"verb": &"Wait", "args": {"ticks": n}}

func _held_actions_now() -> Array[Dictionary]:
	var cmds: Array[Dictionary] = []
	var x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	var v := Vector2i(x, y)
	if v == Vector2i.ZERO:
		if Input.is_action_pressed("move_upleft"):   v = Vector2i(-1, -1)
		elif Input.is_action_pressed("move_upright"): v = Vector2i(1, -1)
		elif Input.is_action_pressed("move_downleft"):v = Vector2i(-1, 1)
		elif Input.is_action_pressed("move_downright"):v = Vector2i(1, 1)
	if v.x != 0: v.x = sign(v.x)
	if v.y != 0: v.y = sign(v.y)
	if v != Vector2i.ZERO: cmds.append(_cmd_move(v))
	if Input.is_action_pressed("wait_1"): cmds.append(_cmd_wait(1))
	if Input.is_action_pressed("wait_5"): cmds.append(_cmd_wait(5))
	return cmds

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

func _should_keep_running_TB() -> bool:
	var pl := _player()
	if _is_busy(pl): return true
	_drain_invalid_player_taps()
	if tap_queue.size() > 0 and _can_start_cmd(pl, tap_queue[0]): return true
	for cmd in _held_actions_now():
		if _can_start_cmd(pl, cmd): return true
	return false

func _is_busy(a: Actor) -> bool:
	return activity_by_id.get(a.actor_id, null) != null
