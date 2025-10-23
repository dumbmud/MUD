# res://core/verbs/verb.gd
extends RefCounted
class_name Verb

func can_start(_a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	return false

func phase_cost(_a: Actor, _args: Dictionary, _sim: SimManager) -> int:
	return 0

func apply(_a: Actor, _args: Dictionary, _sim: SimManager) -> bool:
	return false

func resumable_key(_a: Actor, _args: Dictionary, _sim: SimManager) -> Variant:
	return null
