# res://autoloads/verb_registry.gd
extends Node
##
## Autoload singleton: name → Verb instance.
## Pure registry; no knowledge of scheduler, actors, or worlds.

var _verbs: Dictionary = {}  # Dictionary[StringName, Verb]

func register(verb_name: StringName, verb: Verb) -> void:
	# Overwrites existing entry by design.
	_verbs[verb_name] = verb

func unregister(verb_name: StringName) -> void:
	_verbs.erase(verb_name)

func get_verb(verb_name: StringName) -> Verb:
	return _verbs.get(verb_name, null)

func has(verb_name: StringName) -> bool:
	return _verbs.has(verb_name)

func clear() -> void:
	_verbs.clear()

func all_names() -> Array[StringName]:
	return _verbs.keys()
