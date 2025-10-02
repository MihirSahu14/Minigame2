extends Node2D
class_name Main

@export var boat_scene: PackedScene

@onready var lighthouse: Node2D = $Lighthouse
@onready var score_label: Label = $UI/Margin/VBox/Score
@onready var energy_bar: ProgressBar = $UI/Margin/VBox/Energy

# ------- Dock "rectangle" settings (script-only) -------
@export var dock_width_pct: float = 0.225      # 0..1 of screen width
@export var dock_height: float = 300.0
@export var dock_bottom_margin: float = 80.0  # how far above bottom
@export var dock_debug_color: Color = Color(1, 0, 0.5, 0.45)  # magenta overlay during dev
@export var dock_x_offset: float = -20.0

var dock_rect: Rect2
var dock_debug: ColorRect

# ------- Spawning / difficulty -------
@export var spawn_interval_base: float = 2.0
@export var spawn_interval_min: float = 0.8
@export var min_spawn_gap_y: float = 160.0
@export var boat_speed_min: float = 100.0
@export var boat_speed_max: float = 180.0
@export var speed_per_point: float = 12.0
@export var spawn_margin: float = 64.0
@export var spawn_y_top: float = 140.0
@export var spawn_y_bottom_offset: float = 260.0
@export var alternate_spawn_sides: bool = true

var spawn_side_toggle: bool = false
var viewport_size: Vector2
var score: int = 0
var missed: int = 0
var active_boats: Array[Node] = []
var spawn_cooldown: float = 0.0
var last_spawn_y: float = -9999.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("game")
	rng.randomize()
	viewport_size = get_viewport_rect().size

	# Build the dock rectangle centered on lighthouse X.
	var w: float = clamp(viewport_size.x * dock_width_pct, 120.0, viewport_size.x)
	var h: float = dock_height
	var cx: float = lighthouse.global_position.x +dock_x_offset
	var left: float = clamp(cx - w * 0.5, 0.0, viewport_size.x - w)
	var top: float = viewport_size.y - dock_bottom_margin - h
	dock_rect = Rect2(Vector2(left, top), Vector2(w, h))

	# Visual overlay to make sure you SEE the dock during testing
	dock_debug = ColorRect.new()
	dock_debug.color = dock_debug_color
	dock_debug.size = dock_rect.size
	dock_debug.position = dock_rect.position
	add_child(dock_debug)  # delete later when you’re happy

	_update_score()
	energy_bar.min_value = 0
	energy_bar.max_value = 100
	spawn_cooldown = _next_spawn_interval()

func _process(delta: float) -> void:
	# update energy UI
	if lighthouse and lighthouse.has_method("get_energy_ratio"):
		energy_bar.value = clampf(float(lighthouse.call("get_energy_ratio")) * 100.0, 0.0, 100.0)

	# spawn
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		_spawn_boat()
		spawn_cooldown = _next_spawn_interval()

# --------------- SPAWN ----------------
func _spawn_boat() -> void:
	if boat_scene == null:
		push_warning("Main: boat_scene not assigned")
		return
	
	# create the boat (don’t cast right away)
	var boat_node := boat_scene.instantiate()
	if boat_node == null:
		push_error("Boat scene failed to instantiate")
		return
	
	# assume your Ship scene root is CharacterBody2D
	var boat := boat_node as CharacterBody2D
	if boat == null:
		push_error("Boat scene root is not CharacterBody2D")
		return

	# -------- SIDE SELECTION --------
	# 50% chance spawn left (moving right), 50% spawn right (moving left)
	var spawn_left := rng.randf() < 0.5

	var side_x: float
	var direction: int
	if spawn_left:
		side_x = -spawn_margin       # just off the left edge
		direction = 1                # move right
	else:
		side_x = viewport_size.x + spawn_margin   # just off the right edge
		direction = -1                            # move left

	# -------- Y POSITION --------
	var y_min: float = spawn_y_top
	var y_max: float = viewport_size.y - spawn_y_bottom_offset
	var y: float = _pick_spawn_y(y_min, y_max)

	# -------- CONFIGURE BOAT --------
	boat.global_position = Vector2(side_x, y)
	boat.set("direction", direction)

	# speed grows with score
	var base_speed: float = rng.randf_range(boat_speed_min, boat_speed_max)
	var speed: float = base_speed + float(score) * speed_per_point
	boat.set("drift_speed", speed)

	# add to scene
	add_child(boat)
	active_boats.append(boat)

	# debug print to confirm spawns
	#print_debug("[Spawned] ", spawn_left ? "Left→Right" : "Right→Left", 
		#" pos=", boat.global_position, " speed=", speed)


func _pick_spawn_y(y_min: float, y_max: float) -> float:
	for _i in 10:
		var candidate: float = rng.randf_range(y_min, y_max)
		var ok: bool = true
		for b in active_boats:
			if abs(b.global_position.y - candidate) < min_spawn_gap_y:
				ok = false
				break
		if ok and abs(candidate - last_spawn_y) >= min_spawn_gap_y:
			last_spawn_y = candidate
			return candidate
	var y: float = rng.randf_range(y_min, y_max)
	last_spawn_y = y
	return y

func _next_spawn_interval() -> float:
	var t: float = spawn_interval_base - float(score) * 0.05
	return max(spawn_interval_min, t)

# -------- Dock rectangle helpers (no physics needed) --------
func is_in_dock_rect(pos: Vector2) -> bool:
	return dock_rect.has_point(pos)

func on_ship_scored(ship: Node) -> void:
	score += 1
	active_boats.erase(ship)
	_update_score()
	if is_instance_valid(ship):
		ship.queue_free()

func on_boat_missed(boat: Node) -> void:
	missed += 1
	active_boats.erase(boat)
	_update_score()

# --------- UI / game over ----------
func _update_score() -> void:
	score_label.text = "Score: %d   Missed: %d" % [score, missed]
