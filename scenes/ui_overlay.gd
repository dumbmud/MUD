# res://scenes/ui_overlay.gd
class_name UIOverlay
extends Control
##
## Minimal HUD for the pure scheduler.
## Displays tick/mode, position and phase, view size, and actor count.

@onready var lbl_tick: Label = $VBoxContainer/Tick
@onready var lbl_db0: Label = $VBoxContainer/debug0
@onready var lbl_db1: Label = $VBoxContainer/debug1
@onready var lbl_db2: Label = $VBoxContainer/debug2
@onready var lbl_db3: Label = $VBoxContainer/debug3

func set_debug(
	tick: int,
	pos: Vector2i,
	zoom: float,
	vis_w: int,
	vis_h: int,
	mode_label: String,
	phase: int,
	per_tick: int,
	in_tick: bool,
	actor_count: int
) -> void:
	lbl_tick.text = "Tick: %d   Mode: %s" % [tick, mode_label]
	lbl_db0.text = "Pos: (%d,%d)   Phase: %d / %d" % [pos.x, pos.y, phase, per_tick]
	lbl_db1.text = "Zoom: %.2f   View: %dx%d cells" % [zoom, vis_w, vis_h]
	lbl_db2.text = "Actors: %d   InTick: %s" % [actor_count, str(in_tick)]
	lbl_db3.text = ""
