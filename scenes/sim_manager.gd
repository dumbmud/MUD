# res://scenes/sim_manager.gd
extends Node2D
class_name SimManager
##
## Pure scheduler: ticks, phase regen/cap, activity creation, commit loop, and signals.
## Ignorant of verb semantics and input specifics. Controllers supply commands.
##
## External collaborations:
##   - World node (must implement WorldAPI)
##   - Autoloads:
##       * VerbRegistry: verb lookup
##       * GridOccupancy: id ↔ pos claims
##       * MessageBus: user-facing messages (used by controllers, not here)
##       * InputManager: routes InputEvent → PlayerController taps/holds
##
## Controllers:
##   - One CommandSource per actor in `controller_by_id`.
##   - At boundaries, SimManager asks the source for a command via `dequeue(a, self)`.
##   - TB autostart: SimManager prefetches a pending command non-destructively for the player
##     by calling `dequeue` *and caching* the result until the next boundary.

signal redraw(player_pos: Vector2i, resolver: Callable)
signal hud(tick:int, pos:Vector2i, mode_label:String, phase:int, phase_per_tick:int, is_busy:bool, steps:int)

@onready var world: WorldAPI = $WorldTest

# Controllers
const PlayerControllerClass = preload("res://controllers/player_controller.gd")
const AIPatrolControllerClass = preload("res://controllers/ai_patrol_controller.gd")

# Game modes
enum GameMode { TURN_BASED, REAL_TIME }
@export var mode: GameMode = GameMode.TURN_BASED

# Time + phase
const TICK_SEC := 0.1
const PHASE_MAX := 1_000_000
var tick_accum := 0.0
var tick_count := 0
var ticks_running := false

# Actors and control
var actors: Array[Actor] = []
var next_actor_id := 1
var controller_by_id: Dictionary = {}                  # id -> CommandSource
var activity_by_id: Dictionary[int, Activity] = {}     # id -> Activity or null
var resume_table: Dictionary = {}                      # key -> Activity (verbs opt-in)
var pending_cmd_by_id: Dictionary[int, Dictionary] = {}# id -> {verb,args} prefetched

# RNG
var rng := RandomNumberGenerator.new()
@export var rng_seed: int = 123456789

func _ready() -> void:
	rng.seed = rng_seed

	# Player
	var p := ActorFactory.spawn(0, Vector2i.ZERO, &"human", true)
	actors.append(p)
	GridOccupancy.claim(p.actor_id, p.grid_pos)
	activity_by_id[p.actor_id] = null

	# Attach player controller and hand it to InputManager
	var pc = PlayerControllerClass.new()
	controller_by_id[p.actor_id] = pc
	InputManager.set_player_controller(pc)  # Autoload at res://autoloads/input_manager.gd

	# NPCs (simple patrol controllers)
	_add_npc(&"goblin", Vector2i(-15, -8), Vector2i(1, 0))
	_add_npc(&"goblin", Vector2i(-18, 0),  Vector2i(1, 0))

	_redraw()

func _add_npc(species_id: StringName, start: Vector2i, dir: Vector2i) -> void:
	var a: Actor = ActorFactory.spawn(next_actor_id, start, species_id, false)
	next_actor_id += 1
	actors.append(a)
	GridOccupancy.claim(a.actor_id, a.grid_pos)
	activity_by_id[a.actor_id] = null
	var ai = AIPatrolControllerClass.new()
	ai.set_initial_dir(dir)
	controller_by_id[a.actor_id] = ai

func _input(event: InputEvent) -> void:
	# Time mode toggle stays here since it affects the scheduler itself.
	if event.is_action_pressed("time_mode_toggle"):
		mode = GameMode.REAL_TIME if mode == GameMode.TURN_BASED else GameMode.TURN_BASED
		# In RT, always run. In TB, autostart will kick in via prefetch below.
		ticks_running = true if mode == GameMode.REAL_TIME else _should_keep_running_TB()

func _process(dt: float) -> void:
	# TB autostart: if stopped and a valid command is available, prefetch it and run.
	if mode == GameMode.TURN_BASED and !ticks_running and !_is_busy(_player()):
		if _prefetch_player_if_available():
			ticks_running = true

	if mode == GameMode.REAL_TIME or (mode == GameMode.TURN_BASED and ticks_running):
		tick_accum += dt
		while tick_accum >= TICK_SEC:
			_tick()
			tick_accum -= TICK_SEC

func _tick() -> void:
	tick_count += 1

	# Phase regen with cap
	for a in actors:
		a.phase = min(a.phase + a.phase_per_tick, PHASE_MAX)

	var player_steps_this_tick := 0

	# Stable order: player first, then ascending IDs
	actors.sort_custom(func(x, y): return x.actor_id < y.actor_id)

	# Multi-commit rounds inside one tick
	var round_idx := 0
	const MAX_ROUNDS_PER_TICK := 32
	while round_idx < MAX_ROUNDS_PER_TICK:
		var commits := 0

		for a in actors:
			# Acquire or continue an activity
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
						activity_by_id[a.actor_id] = act

			# Commit if enough phase
			act = activity_by_id.get(a.actor_id, null)
			if act != null and a.phase >= act.remaining:
				a.phase -= act.remaining
				var verb2 := VerbRegistry.get_verb(act.verb)
				var ok := verb2 != null and verb2.apply(a, act.args, self)
				if act.resume_key != null:
					resume_table.erase(act.resume_key)
				activity_by_id[a.actor_id] = null
				commits += 1

				# Debug counter for steps (optional; remove to be verb-agnostic)
				if a.is_player and act.verb == &"Move" and ok:
					player_steps_this_tick += 1

		if commits == 0:
			break
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

	# TB run/stop policy
	if mode == GameMode.TURN_BASED:
		ticks_running = _should_keep_running_TB()
		if !ticks_running:
			tick_accum = 0.0

# ── command acquisition ───────────────────────────────────────────────────────

func _acquire_command(a: Actor) -> Variant:
	# Use prefetched command first if present (TB autostart path).
	if pending_cmd_by_id.has(a.actor_id):
		var cmd := pending_cmd_by_id[a.actor_id]
		pending_cmd_by_id.erase(a.actor_id)
		return cmd

	# Otherwise, ask the actor’s controller.
	var src = controller_by_id.get(a.actor_id, null)
	return src.dequeue(a, self) if src != null else null

func _prefetch_player_if_available() -> bool:
	# Try to obtain one valid command for the player without advancing time.
	# We *consume* the controller’s dequeue and stash it for the next boundary.
	# This keeps SimManager ignorant of verbs and inputs and still lets TB autostart.
	var pl := _player()
	if controller_by_id.has(pl.actor_id) and !pending_cmd_by_id.has(pl.actor_id):
		var src: CommandSource = controller_by_id[pl.actor_id]
		var cmd : Variant = src.dequeue(pl, self)
		if cmd != null:
			pending_cmd_by_id[pl.actor_id] = cmd
			return true
	return false

# ── drawing / UI ─────────────────────────────────────────────────────────────

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

# ── run policy helpers ───────────────────────────────────────────────────────

func _should_keep_running_TB() -> bool:
	var pl := _player()
	if _is_busy(pl): return true
	# If we already have a prefetched command, keep running.
	if pending_cmd_by_id.has(pl.actor_id): return true
	# Otherwise try to prefetch now.
	return _prefetch_player_if_available()

func _is_busy(a: Actor) -> bool:
	return activity_by_id.get(a.actor_id, null) != null
