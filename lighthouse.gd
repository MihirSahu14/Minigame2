extends Node2D

# --- Beam / sweep ---
@export var base_points_up: bool = true
@export var light_range: float = 2300.0
@export var light_half_angle: float = deg_to_rad(17.5)

# Manual sweep (edit in Inspector)
@export var auto_fit_on_ready: bool = false
@export var sweep_min_deg: float = -90.0
@export var sweep_max_deg: float = 90.0
@export var sweep_cycles_per_sec: float = 0.25
@export var sweep_slow_mult: float = 0.35   # slower while holding

# Energy & cooldown
@export var energy_max: float = 100.0
@export var energy_drain_per_sec: float = 30.0
@export var energy_recharge_per_sec: float = 20.0
@export var cooldown_on_empty: float = 1.5

@onready var beam_pivot: Node2D = $BeamPivot
@onready var beam_visual: Polygon2D = $BeamPivot/BeamVisual

var t: float = 0.0
var energy: float = 0.0
var effect_active: bool = false

enum UseState { IDLE, COOLDOWN }
var state: UseState = UseState.IDLE
var cd_timer: float = 0.0

func _ready() -> void:
	if base_points_up:
		beam_pivot.rotation = -PI / 2.0
	energy = energy_max
	if auto_fit_on_ready:
		fit_sweep_to_corners()
	_apply_visuals()

func _process(delta: float) -> void:
	# sweep
	var rate: float = sweep_cycles_per_sec * (sweep_slow_mult if effect_active else 1.0)
	t += delta * rate
	var tri: float = abs(fmod(t, 1.0) * 2.0 - 1.0)               # 0..1..0 triangle
	var offset: float = lerp(deg_to_rad(sweep_min_deg), deg_to_rad(sweep_max_deg), tri)
	var base: float = (-PI / 2.0) if base_points_up else 0.0
	beam_pivot.rotation = base + offset

	# input + energy/cooldown
	var want_on: bool = Input.is_action_pressed("tap")

	match state:
		UseState.IDLE:
			effect_active = want_on and (energy > 0.0)
			if effect_active:
				energy -= energy_drain_per_sec * delta
				if energy <= 0.0:
					energy = 0.0
					_enter_cooldown()
			else:
				energy += energy_recharge_per_sec * delta
				energy = clamp(energy, 0.0, energy_max)
		UseState.COOLDOWN:
			effect_active = false
			cd_timer -= delta
			energy += energy_recharge_per_sec * delta
			energy = clamp(energy, 0.0, energy_max)
			if cd_timer <= 0.0 and energy > 0.0 and not want_on:
				state = UseState.IDLE

	_apply_visuals()

func _enter_cooldown() -> void:
	state = UseState.COOLDOWN
	cd_timer = cooldown_on_empty
	effect_active = false

# --- API for ships/UI ---
func get_beam_rotation() -> float:
	return beam_pivot.global_rotation

func get_beam_origin() -> Vector2:
	return beam_pivot.global_position

func get_range() -> float:
	return light_range

func get_half_angle() -> float:
	return light_half_angle

func is_position_lit(world_pos: Vector2) -> bool:
	if not effect_active:
		return false
	var origin: Vector2 = get_beam_origin()
	var to_pos: Vector2 = world_pos - origin
	if to_pos.length() > light_range:
		return false
	var ang_diff: float = abs(wrapf(to_pos.angle() - get_beam_rotation(), -PI, PI))
	return ang_diff <= light_half_angle

func get_energy_ratio() -> float:
	return energy / max(1.0, energy_max)

# Optional: auto-fit sweep to top corners
func fit_sweep_to_corners() -> void:
	var sz: Vector2 = get_viewport_rect().size
	var origin: Vector2 = get_beam_origin()
	var base: float = (-PI / 2.0) if base_points_up else 0.0
	var a_left: float  = (Vector2(0.0, 0.0) - origin).angle()
	var a_right: float = (Vector2(sz.x, 0.0) - origin).angle()
	var o_left: float  = wrapf(a_left  - base, -PI, PI)
	var o_right: float = wrapf(a_right - base, -PI, PI)
	if o_left > o_right:
		var tmp: float = o_left; o_left = o_right; o_right = tmp
	sweep_min_deg = rad_to_deg(o_left)  - 2.0
	sweep_max_deg = rad_to_deg(o_right) + 2.0

func _apply_visuals() -> void:
	var a: float = (
		0.20 if state == UseState.COOLDOWN
		else (0.85 if effect_active else (0.45 if energy > 0.0 else 0.20))
	)
	if beam_visual:
		var c: Color = beam_visual.color
		c.a = a
		beam_visual.color = c
