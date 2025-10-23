# res://creatures/_types/body_part.gd
extends Resource
class_name BodyPart

@export var name: StringName
@export var parent: StringName = &""
@export var coverage: int = 1
@export var volume: int = 1
@export var vital: bool = false

# Zoning
@export var slot: StringName              # &"core" | &"limb"
@export var core_role: StringName = &""   # head/torso for core
@export var limb_class: StringName = &""  # arm/leg
@export var group_id: StringName = &""    # e.g. "arm.L","leg.R"
@export var has_artery: bool = false
@export var label_hint: String = ""

# Effectors + sensors
@export var effector_kind: StringName = &""   # &"grasper"|&"stepper"|&"chewer"|&""
@export var effector_score: float = 0.0       # 0..1
@export var sensor_kind: StringName = &""     # &"vision"|&""
@export var sensor_score: float = 0.0         # 0..1
