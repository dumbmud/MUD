# res://autoloads/message_bus.gd
# Add as Autoload: Name "MessageBus"
extends Node

signal message(text: String, kind: StringName, tick: int, actor_id: int)

var _last_tick_by_key: Dictionary = {} # Dictionary[StringName, int]

func send(text: String, kind: StringName = &"info", tick: int = 0, actor_id: int = -1) -> void:
	emit_signal("message", text, kind, tick, actor_id)

func send_once_per_tick(key: StringName, text: String, kind: StringName, tick: int, actor_id: int = -1) -> void:
	var last := int(_last_tick_by_key.get(key, -999999))
	if last == tick: return
	_last_tick_by_key[key] = tick
	send(text, kind, tick, actor_id)

func clear_rate_limits() -> void:
	_last_tick_by_key.clear()
