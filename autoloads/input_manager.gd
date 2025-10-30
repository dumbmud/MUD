# res://autoloads/input_manager.gd
extends Node
##
## Centralized input router. Maps InputEvent → {verb, args} for the active UI mode.
## Scheduler-agnostic. No world or SimManager access.
##
## Modes:
##   - GAMEPLAY: gameplay bindings active
##   - UI_MENU / TEXT: reserved
##
## Driver coupling:
##   - After any tap, call GameLoop.kick() to advance TB.
##   - Holds are enabled only in RT by GameLoop policy.

enum Mode { GAMEPLAY, UI_MENU, TEXT }

var _mode_stack: Array[int] = [Mode.GAMEPLAY]
var _player_controller: Variant = null   # expects push(Dictionary) and set_hold_sampler(Callable)
var _desired_gait: int = 0  # 0..3

# UI signals
signal gait_changed(gait: int)
# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

func set_player_controller(controller: Variant) -> void:
	_player_controller = controller
	_player_controller.set_hold_sampler(Callable(self, "_hold_sampler_impl"))
	GameLoop.register_player(controller)

func push_mode(m: int) -> void:
	_mode_stack.append(m)

func pop_mode() -> void:
	if _mode_stack.size() > 1:
		_mode_stack.pop_back()

func current_mode() -> int:
	return _mode_stack.back()

# ─────────────────────────────────────────────────────────────────────────────
# UI helpers
# ─────────────────────────────────────────────────────────────────────────────

func get_desired_gait() -> int:
	return _desired_gait

static func gait_name(g: int) -> String:
	match g:
		0: return "Blue"
		1: return "Green"
		2: return "Orange"
		3: return "Red"
		_: return "Blue"

# ─────────────────────────────────────────────────────────────────────────────
# Godot input hook
# ─────────────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _player_controller == null:
		return

	# Time mode toggle goes to the driver; scheduler is agnostic.
	if event.is_action_pressed("time_mode_toggle"):
		GameLoop.toggle_real_time()
		return

	# Ignore gameplay bindings unless in GAMEPLAY mode.
	if current_mode() != Mode.GAMEPLAY:
		return

	var kicked := false

	# Movement taps
	if event.is_action_pressed("move_up"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(0,-1), "gait": _desired_gait}})
		kicked = true
	elif event.is_action_pressed("move_down"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(0, 1), "gait": _desired_gait}})
		kicked = true
	elif event.is_action_pressed("move_left"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(-1, 0), "gait": _desired_gait}})
		kicked = true
	elif event.is_action_pressed("move_right"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(1, 0), "gait": _desired_gait}})
		kicked = true
	elif event.is_action_pressed("move_upleft"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(-1, -1), "gait": _desired_gait}})
		kicked = true
	elif event.is_action_pressed("move_upright"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(1, -1), "gait": _desired_gait}})
		kicked = true
	elif event.is_action_pressed("move_downleft"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(-1, 1), "gait": _desired_gait}})
		kicked = true
	elif event.is_action_pressed("move_downright"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(1, 1), "gait": _desired_gait}})
		kicked = true

	# Wait taps
	if event.is_action_pressed("wait_drain"):
		_player_controller.push({"verb": &"Wait", "args": {"ticks": 0}})
		kicked = true
	if event.is_action_pressed("wait_5"):
		_player_controller.push({"verb": &"Wait", "args": {"ticks": 5}})
		kicked = true
	
	# gait cycle
	if event.is_action_pressed("gait_cycle"):
		_desired_gait = (_desired_gait + 1) % 4
		kicked = true
		emit_signal("gait_changed", _desired_gait)

	# In TB, kick one step per tap. In RT, GameLoop ignores kicks.
	if kicked:
		GameLoop.kick()

# ─────────────────────────────────────────────────────────────────────────────
# Hold sampling
# ─────────────────────────────────────────────────────────────────────────────

func _hold_sampler_impl() -> Array[Dictionary]:
	if current_mode() != Mode.GAMEPLAY:
		return []

	var out: Array[Dictionary] = []

	# Aggregate 8-way
	var x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	var v := Vector2i(x, y)

	# Prefer diagonals if no axial input
	if v == Vector2i.ZERO:
		if Input.is_action_pressed("move_upleft"):   v = Vector2i(-1, -1)
		elif Input.is_action_pressed("move_upright"): v = Vector2i( 1, -1)
		elif Input.is_action_pressed("move_downleft"):v = Vector2i(-1,  1)
		elif Input.is_action_pressed("move_downright"):v=Vector2i( 1,  1)

	# Normalize
	if v.x != 0: v.x = sign(v.x)
	if v.y != 0: v.y = sign(v.y)

	# One Move with gait (no gait-less Move before this)
	if v != Vector2i.ZERO:
		out.append({"verb": &"Move", "args": {"dir": v, "gait": _desired_gait}})

	# Held waits
	if Input.is_action_pressed("wait_drain"):
		out.append({"verb": &"Wait", "args": {"ticks": 0}})
	if Input.is_action_pressed("wait_5"):
		out.append({"verb": &"Wait", "args": {"ticks": 5}})

	return out
