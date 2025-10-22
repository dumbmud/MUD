class_name UIOverlay
extends Control

@onready var lbl_tick: Label = $VBoxContainer/Tick
@onready var lbl_db0: Label = $VBoxContainer/debug0
@onready var lbl_db1: Label = $VBoxContainer/debug1
@onready var lbl_db2: Label = $VBoxContainer/debug2
@onready var lbl_db3: Label = $VBoxContainer/debug3

# New: ready_tick, mode label, energy_TU, speed, busy, steps_this_tick
func set_debug(
	tick: int,
	pos: Vector2i,
	ready_tick: int,
	zoom: float,
	vis_w: int,
	vis_h: int,
	mode_label: String,
	energy_TU: int,
	speed_TU_per_tick: int,
	is_busy: bool,
	steps_this_tick: int
) -> void:
	var cols := int(vis_w / zoom)
	var rows := int(vis_h / zoom)
	lbl_tick.text = "Tick: %d   Mode: %s" % [tick, mode_label]
	lbl_db0.text = "Pos: (%d,%d)   EnergyTU: %d   SpeedTU/tick: %d   StepsThisTick: %d" \
		% [pos.x, pos.y, energy_TU, speed_TU_per_tick, steps_this_tick]
	lbl_db1.text = "ReadyTick: %d   Busy: %s   Zoom: %.2f   View: %dx%d cells" \
		% [ready_tick, str(is_busy), zoom, cols, rows]
	
