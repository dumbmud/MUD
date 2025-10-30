extends RefCounted
class_name Tuning

const REF_MASS_KG := 70.0

# Base travel speed
const HUMAN_WALK_MPS := 1.40

# Effort modes
const MODE_BLUE := 0
const MODE_GREEN := 1
const MODE_ORANGE := 2
const MODE_RED := 3

# Speed multipliers per mode (apply mobility & mass after)
const MODE_SPEED_MULT := {MODE_BLUE:1.0, MODE_GREEN:2.0, MODE_ORANGE:5.0, MODE_RED:6.0}

# Global stamina rates (per second)
const BASE_STAMINA_DRAIN_PER_SEC := 1.0
const BASE_STAMINA_REGEN_PER_SEC := 0.8   # constant regen, independent of mode

# Drain multipliers per mode (set time-to-empty targets)
const MODE_DRAIN_MULT := {
	MODE_BLUE:   0.20,    # net +0.60/s while traveling at baseline (0.8 - 0.2)
	MODE_GREEN:  0.80,    # break-even at baseline; hours if cardio*thermo > 1
	MODE_ORANGE: 4.133,   # 4.133 - 0.8 = 3.333 → 100/3.333 ≈ 30 s
	MODE_RED:   17.467    # 17.467 - 0.8 = 16.667 → 100/16.667 ≈ 6 s
}

# Optional start burst floors
const MODE_MIN_BURST := {MODE_BLUE:0.0, MODE_GREEN:0.0, MODE_ORANGE:2.0, MODE_RED:5.0}

const MOBILITY_GAIN_ABOVE_1 := 0.6
const MASS_SPEED_EXP := -0.1666667

static func thermo_regen_factor(thermo: Dictionary) -> float:
	var shed := float(thermo.get("shedding", 0.7))
	return clamp(0.5 + 0.5 * shed, 0.25, 1.25)
