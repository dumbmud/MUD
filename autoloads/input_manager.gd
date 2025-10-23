# res://autoloads/input_manager.gd
extends Node
##
## Centralized input router. Maps InputEvent → {verb, args} for the active UI mode.
## Keeps SimManager verb-agnostic. No world or scheduler access here.
##
## Usage:
##   - Add as Autoload: Name "InputManager"
##   - Call `InputManager.set_player_controller(controller)` where `controller` has:
##       * func push(cmd: Dictionary) -> void
##       * func set_hold_sampler(c: Callable) -> void
##     The controller will receive tap commands via `push(...)`.
##     The controller will call back the sampler at boundaries to get held commands.
##
## Modes:
##   - GAMEPLAY: gameplay bindings active
##   - UI_MENU / TEXT: reserved, swallow gameplay actions
##
## This file owns only input concerns. It does not know SimManager, worlds, or verbs.

enum Mode { GAMEPLAY, UI_MENU, TEXT }

var _mode_stack: Array[int] = [Mode.GAMEPLAY]
var _player_controller: Variant = null   # Expecting push(Dictionary) and set_hold_sampler(Callable)

func _ready() -> void:
	# Provide the hold-sampler callback to the controller once it is set.
	if _player_controller != null:
		_player_controller.set_hold_sampler(Callable(self, "_hold_sampler_impl"))

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

func set_player_controller(controller: Variant) -> void:
	# `controller` duck-types CommandSource: must implement push() and set_hold_sampler().
	_player_controller = controller
	_player_controller.set_hold_sampler(Callable(self, "_hold_sampler_impl"))

func push_mode(m: int) -> void:
	_mode_stack.append(m)

func pop_mode() -> void:
	if _mode_stack.size() > 1:
		_mode_stack.pop_back()

func current_mode() -> int:
	return _mode_stack.back()

# ─────────────────────────────────────────────────────────────────────────────
# Godot input hook
# ─────────────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Ignore gameplay bindings unless in GAMEPLAY mode.
	if current_mode() != Mode.GAMEPLAY: return
	if _player_controller == null: return

	# Movement taps
	if event.is_action_pressed("move_up"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(0, -1)}})
	elif event.is_action_pressed("move_down"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(0, 1)}})
	elif event.is_action_pressed("move_left"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(-1, 0)}})
	elif event.is_action_pressed("move_right"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(1, 0)}})
	elif event.is_action_pressed("move_upleft"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(-1, -1)}})
	elif event.is_action_pressed("move_upright"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(1, -1)}})
	elif event.is_action_pressed("move_downleft"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(-1, 1)}})
	elif event.is_action_pressed("move_downright"):
		_player_controller.push({"verb": &"Move", "args": {"dir": Vector2i(1, 1)}})

	# Wait taps
	if event.is_action_pressed("wait_1"):
		_player_controller.push({"verb": &"Wait", "args": {"ticks": 1}})
	if event.is_action_pressed("wait_5"):
		_player_controller.push({"verb": &"Wait", "args": {"ticks": 5}})

# ─────────────────────────────────────────────────────────────────────────────
# Hold sampling
# ─────────────────────────────────────────────────────────────────────────────

func _hold_sampler_impl() -> Array[Dictionary]:
	# Return zero or more commands based on currently held inputs.
	# Called once per boundary by the player controller.
	if current_mode() != Mode.GAMEPLAY:
		return []

	var out: Array[Dictionary] = []

	# Aggregate 8-way movement.
	var x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var y := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	var v := Vector2i(x, y)

	# Prefer diagonals from dedicated binds if no axial input.
	if v == Vector2i.ZERO:
		if Input.is_action_pressed("move_upleft"):
			v = Vector2i(-1, -1)
		elif Input.is_action_pressed("move_upright"):
			v = Vector2i(1, -1)
		elif Input.is_action_pressed("move_downleft"):
			v = Vector2i(-1, 1)
		elif Input.is_action_pressed("move_downright"):
			v = Vector2i(1, 1)

	# Normalize to unit step.
	if v.x != 0: v.x = sign(v.x)
	if v.y != 0: v.y = sign(v.y)

	if v != Vector2i.ZERO:
		out.append({"verb": &"Move", "args": {"dir": v}})

	# Held waits (useful for RT or key-repeat UX).
	if Input.is_action_pressed("wait_1"):
		out.append({"verb": &"Wait", "args": {"ticks": 1}})
	if Input.is_action_pressed("wait_5"):
		out.append({"verb": &"Wait", "args": {"ticks": 5}})

	return out
