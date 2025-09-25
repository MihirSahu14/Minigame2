extends Node2D

# --- Tunable values (shown in Inspector) ---
@export var base_points_up: bool = true                 # our triangle points RIGHT; rotate UP by default
@export var light_range: float = 600.0                  # how far the beam reaches
@export var light_half_angle: float = deg_to_rad(18.0)  # ~36° full cone

@export var sweep_min_deg: float = -60.0    # sweep left bound (deg)
@export var sweep_max_deg: float =  60.0    # sweep right bound (deg)
@export var sweep_cycles_per_sec: float = 0.25
@export var start_sweeping: bool = true

# --- Internals ---
@onready var beam_pivot: Node2D = $BeamPivot

var sweeping: bool = false
var t: float = 0.0   # time accumulator for sweep

func _ready() -> void:
	# Our polygon points RIGHT; this makes its base orientation UP
	if base_points_up:
		beam_pivot.rotation = -PI / 2.0
	sweeping = start_sweeping

func _process(delta: float) -> void:
	# One-button toggle
	if Input.is_action_just_pressed("tap"):
		sweeping = !sweeping

	if sweeping:
		t += delta * sweep_cycles_per_sec
		# Triangle wave 0..1..0..1 using fractional part via fmod
		var tri: float = abs(fmod(t, 1.0) * 2.0 - 1.0)
		var offset: float = lerp(deg_to_rad(sweep_min_deg), deg_to_rad(sweep_max_deg), tri)
		var base: float = (-PI / 2.0) if base_points_up else 0.0
		beam_pivot.rotation = base + offset

# --- API for ships ---
func get_beam_rotation() -> float:
	return beam_pivot.global_rotation

func get_range() -> float:
	return light_range

func get_half_angle() -> float:
	return light_half_angle

func is_position_lit(world_pos: Vector2) -> bool:
	var to_pos: Vector2 = world_pos - global_position
	if to_pos.length() > light_range:
		return false
	var ang_diff: float = abs(wrapf(to_pos.angle() - get_beam_rotation(), -PI, PI))
	return ang_diff <= light_half_angle
