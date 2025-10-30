class_name BodyLink
extends Resource
## Undirected link between nodes with channel flow budgets 0..3.

@export var a: StringName
@export var b: StringName

@export var flow := {
	"signal": 3, "fluid": 3, "gas": 3
}
