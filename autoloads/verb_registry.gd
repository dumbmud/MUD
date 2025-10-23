# res://core/verbs/verb_registry.gd
extends Node
## Autoload singleton: maps verb name → Verb instance.

var _verbs: Dictionary = {}  # Dictionary[StringName, Verb]

func register(verb_name: StringName, verb: Verb) -> void:
	_verbs[verb_name] = verb

func get_verb(verb_name: StringName) -> Verb:
	return _verbs.get(verb_name, null)

func has(verb_name: StringName) -> bool:
	return _verbs.has(verb_name)

func clear() -> void:
	_verbs.clear()
