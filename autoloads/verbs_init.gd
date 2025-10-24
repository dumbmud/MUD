# res://autoloads/verbs_init.gd
extends Node
##
## Autoload: registers built-in verbs at startup.
## Scheduler is pure; this only populates the registry.

const MoveVerbClass = preload("res://core/verbs/move_verb.gd")
const WaitVerbClass = preload("res://core/verbs/wait_verb.gd")

func _ready() -> void:
	VerbRegistry.clear()
	VerbRegistry.register(&"Move", MoveVerbClass.new())   # costs: 500/707 baseline
	VerbRegistry.register(&"Wait", WaitVerbClass.new())   # Wait(0)=drain; Wait(n)=n ticks
