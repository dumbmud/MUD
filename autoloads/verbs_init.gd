# res://core/verbs/verbs_init.gd
extends Node

const MoveVerbClass = preload("res://core/verbs/move_verb.gd")
const WaitVerbClass = preload("res://core/verbs/wait_verb.gd")

func _ready() -> void:
	VerbRegistry.register(&"Move", MoveVerbClass.new())
	VerbRegistry.register(&"Wait", WaitVerbClass.new())
