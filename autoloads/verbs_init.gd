# res://autoloads/verbs_init.gd
extends Node
##
## Autoload: registers built-in verbs at startup.

const MoveVerbClass = preload("res://core/verbs/move_verb.gd")
const WaitVerbClass = preload("res://core/verbs/wait_verb.gd")

func _ready() -> void:
	# Fresh start
	VerbRegistry.clear()
	# Register core verbs
	VerbRegistry.register(&"Move", MoveVerbClass.new())
	VerbRegistry.register(&"Wait", WaitVerbClass.new())
