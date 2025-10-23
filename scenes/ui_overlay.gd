# res://scenes/ui_overlay.gd
class_name UIOverlay
extends Control

@onready var lbl_tick: Label = $VBoxContainer/Tick
@onready var lbl_db0: Label = $VBoxContainer/debug0
@onready var lbl_db1: Label = $VBoxContainer/debug1
@onready var lbl_db2: Label = $VBoxContainer/debug2
@onready var lbl_db3: Label = $VBoxContainer/debug3

# Debug HUD for the boundary model
# ready_tick is unused under the new model; kept for interface stability
func set_debug(
	tick: int,
	pos: Vector2i,
	_ready_tick_unused: int,
	zoom: float,
	vis_w_cells: int,
	vis_h_cells: int,
	mode_label: String,
	phase: int,
	phase_per_tick: int,
	is_busy: bool,
	steps_this_tick: int
) -> void:
	lbl_tick.text = "Tick: %d   Mode: %s" % [tick, mode_label]
	lbl_db0.text = "Pos: (%d,%d)   Phase: %d   Phase/tick: %d   StepsThisTick: %d" \
		% [pos.x, pos.y, phase, phase_per_tick, steps_this_tick]
	lbl_db1.text = "Busy: %s   Zoom: %.2f   View: %dx%d cells" \
		% [str(is_busy), zoom, vis_w_cells, vis_h_cells]
	lbl_db2.text = ""
	lbl_db3.text = ""
