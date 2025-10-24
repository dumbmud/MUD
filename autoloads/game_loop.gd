# res://autoloads/game_loop.gd
extends Node
##
## Driver for the pure scheduler.
## Turn-based (TB): pause-by-default. On kick(), advance real time until the tracked
## actor commits, then pause immediately (mid-tick allowed).
## Real-time (RT): advance full ticks on a cadence. The only RT differences are that
## PlayerController allows holds and assumes Wait(1) when idle.
##
## Accumulator rules:
##  - Accumulate wall time only while actually running
##    (RT always; TB only between kick and the tracked-commit pause).
##  - Cap catch-up per frame to avoid spirals.

@export var tick_sec: float = 0.1
@export var tracked_actor_id: int = 0
@export var max_catchup_per_frame: int = 8           # max tick slices processed per frame
@export var max_rounds_per_tick_slice: int = 128     # safety cap inside one tick slice

var real_time: bool = false

var _sim: SimManager = null
var _player_controller: PlayerController = null
var _accum: float = 0.0
var _tb_running: bool = false

func _ready() -> void:
	set_process(true)

# ── wiring ───────────────────────────────────────────────────────────────────

func register_sim(sim: SimManager) -> void:
	_sim = sim

func register_player(pc: PlayerController) -> void:
	_player_controller = pc
	_apply_policy()

# ── mode control ─────────────────────────────────────────────────────────────

func set_real_time(on: bool) -> void:
	real_time = on
	_accum = 0.0
	_tb_running = false
	_apply_policy()

func toggle_real_time() -> void:
	set_real_time(!real_time)

# ── TB kick ──────────────────────────────────────────────────────────────────

func kick() -> void:
	# TB only: start a run if the player has a valid command prefetched.
	if _sim == null or real_time:
		return
	if _sim.prefetch_command(tracked_actor_id):
		_accum = 0.0
		_tb_running = true

# ── frame pump ───────────────────────────────────────────────────────────────

func _process(dt: float) -> void:
	if _sim == null:
		return

	if real_time:
		# RT: advance full ticks on cadence.
		_accum += dt
		var loops := 0
		while _accum >= tick_sec and loops < max_catchup_per_frame:
			_sim.step_tick()
			_accum -= tick_sec
			loops += 1
		if loops == max_catchup_per_frame:
			_accum = 0.0
		return

	# TB: paused unless a run is active.
	if !_tb_running:
		_accum = 0.0
		return

	_accum += dt
	var slices := 0
	var stop_now := false

	while _accum >= tick_sec and slices < max_catchup_per_frame:
		# One "tick slice": run rounds until (a) tick goes quiet, or (b) the player commits.
		var rounds := 0
		while rounds < max_rounds_per_tick_slice:
			var r: Dictionary = _sim.step_round(tracked_actor_id)
			if bool(r.get("stopped_on_target", false)):
				stop_now = true
				break
			if !bool(r.get("spent", false)):
				_sim.end_tick_if_quiet()
				break
			rounds += 1
		_accum -= tick_sec
		slices += 1
		if stop_now:
			break

	if stop_now:
		_tb_running = false
		_accum = 0.0
	elif slices == max_catchup_per_frame:
		_accum = 0.0  # back-pressure

# ── policy ───────────────────────────────────────────────────────────────────

func _apply_policy() -> void:
	if _player_controller != null:
		_player_controller.allow_holds = real_time
		_player_controller.assume_wait_when_idle = real_time
