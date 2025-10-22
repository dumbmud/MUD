extends Resource
class_name BodyPart

@export var name: StringName
@export var parent: StringName = &""
@export var coverage: int = 1      # target weight
@export var volume: int = 1        # for damage scaling
@export var vital: bool = false
