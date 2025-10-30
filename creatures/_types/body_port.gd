class_name BodyPort
extends Resource
## Port: attachment site for grafting (data-only).

@export var role: StringName = &""        # e.g., &"limb",&"sensor",&"aux"
@export var anchor: StringName = &""      # e.g., &"bone",&"skin",&"socket"
@export_range(0, 8) var max_count: int = 1
