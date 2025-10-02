extends Node2D
class_name Main

@export var boat_scene: PackedScene

@onready var lighthouse: Node2D = $Lighthouse
@onready var score_label: Label = $UI/Margin/VBox/Score
@onready var ui_root: Control = $UI/Margin   # root UI node

# ------- Dock "rectangle" settings (script-only) -------
@export var dock_width_pct: float = 0.23
@export var dock_height: float = 300.0
@export var dock_bottom_margin: float = 80.0
@export var dock_debug_color: Color = Color(1.0, 0.0, 0.502, 0.0)
@export var dock_x_offset: float = -20.0

var dock_rect: Rect2
var dock_debug: ColorRect

# ------- Spawning / difficulty -------
@export var spawn_interval_base: float = 3.0
@export var spawn_interval_min: float = 1.5
@export var min_spawn_gap_y: float = 160.0
@export var boat_speed_min: float = 100.0
@export var boat_speed_max: float = 180.0
@export var speed_per_point: float = 12.0
@export var spawn_margin: float = 64.0
@export var spawn_y_top: float = 140.0
@export var spawn_y_bottom_offset: float = 260.0

var viewport_size: Vector2
var score: int = 0
var missed: int = 0
var active_boats: Array[Node] = []
var spawn_cooldown: float = 0.0
var last_spawn_y: float = -9999.0
var rng := RandomNumberGenerator.new()

# ------- Cosmetic assets (set in Inspector) -------
@export var explosion_frames: Array[Texture2D] = []     # 3-frame explosion
@export var energy_frames: Array[Texture2D] = []        # 10 energy meter frames
var energy_tex: TextureRect

# ------- Game over -------
@export var misses_to_game_over: int = 3
var game_over: bool = false

func _ready() -> void:
	add_to_group("game")
	rng.randomize()
	viewport_size = get_viewport_rect().size

	# Build dock rectangle
	var w: float = clamp(viewport_size.x * dock_width_pct, 120.0, viewport_size.x)
	var h: float = dock_height
	var cx: float = lighthouse.global_position.x + dock_x_offset
	var left: float = clamp(cx - w * 0.5, 0.0, viewport_size.x - w)
	var top: float = viewport_size.y - dock_bottom_margin - h
	dock_rect = Rect2(Vector2(left, top), Vector2(w, h))

	# Visible overlay for debug
	dock_debug = ColorRect.new()
	dock_debug.color = dock_debug_color
	dock_debug.size = dock_rect.size
	dock_debug.position = dock_rect.position
	dock_debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dock_debug)

	# --- Energy image meter (bottom-left anchored)
	energy_tex = TextureRect.new()
	energy_tex.name = "EnergyImage"
	energy_tex.texture = energy_frames.back() if energy_frames.size() > 0 else null
	energy_tex.stretch_mode = TextureRect.STRETCH_SCALE
	energy_tex.size = Vector2(200, 30)  # width x height
	energy_tex.position = Vector2(1300, 800)  
	add_child(energy_tex)
	
	_update_score()
	spawn_cooldown = _next_spawn_interval()

func _process(delta: float) -> void:
	# Update energy UI
	if lighthouse and lighthouse.has_method("get_energy_ratio") and energy_tex:
		var ratio: float = clampf(float(lighthouse.call("get_energy_ratio")), 0.0, 1.0)
		if energy_frames.size() > 0:
			var last := energy_frames.size() - 1
			var idx := int(round(ratio * last))
			energy_tex.texture = energy_frames[idx]

	if game_over:
		return

	# Spawn loop
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		_spawn_boat()
		spawn_cooldown = _next_spawn_interval()

# ------------------- SPAWN -------------------
func _spawn_boat() -> void:
	if boat_scene == null:
		push_warning("Main: boat_scene not assigned")
		return
	var boat := boat_scene.instantiate() as CharacterBody2D
	if boat == null: return

	# Random side
	var go_right: bool = rng.randi() % 2 == 0
	var start_x: float = -spawn_margin if go_right else (viewport_size.x + spawn_margin)
	var direction: int = 1 if go_right else -1

	# Spread vertically
	var y_min: float = spawn_y_top
	var y_max: float = viewport_size.y - spawn_y_bottom_offset
	var y: float = _pick_spawn_y(y_min, y_max)

	boat.global_position = Vector2(start_x, y)
	boat.set("direction", direction)
	var base_speed: float = rng.randf_range(boat_speed_min, boat_speed_max)
	var speed: float = base_speed + float(score) * speed_per_point
	boat.set("drift_speed", speed)

	add_child(boat)
	active_boats.append(boat)

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

# -------- Dock helpers --------
func is_in_dock_rect(pos: Vector2) -> bool:
	return dock_rect.has_point(pos)

# -------- Scoring & miss --------
func on_ship_scored(ship: Node) -> void:
	if game_over: return
	score += 1
	active_boats.erase(ship)
	_update_score()
	_spawn_explosion(ship.global_position)
	_shake_camera(0.15, 10.0)
	if is_instance_valid(ship):
		ship.queue_free()

func on_boat_missed(boat: Node) -> void:
	if game_over: return
	missed += 1
	active_boats.erase(boat)
	_update_score()
	if missed >= misses_to_game_over:
		_game_over()

func _update_score() -> void:
	score_label.text = "Score: %d   Missed: %d" % [score, missed]

# --------- Effects ---------
func _spawn_explosion(pos: Vector2) -> void:
	if explosion_frames.size() == 0: return
	var s := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("boom")
	frames.set_animation_loop("boom", false)
	for t in explosion_frames:
		frames.add_frame("boom", t)
	s.sprite_frames = frames
	s.animation = "boom"
	s.scale = Vector2(4.0, 4.0)
	s.z_index = 50
	s.global_position = pos
	add_child(s)
	s.animation_finished.connect(func(): s.queue_free())
	s.play()

func _shake_camera(duration: float, pixels: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null: return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var orig := cam.offset
	var steps := 8
	for i in steps:
		var offs := Vector2(
			rng.randf_range(-pixels, pixels),
			rng.randf_range(-pixels, pixels)
		)
		tw.tween_property(cam, "offset", orig + offs, duration / float(steps))
	tw.tween_property(cam, "offset", orig, 0.05)

# --------- Game over ---------
func _game_over() -> void:
	game_over = true
	spawn_cooldown = 99999.0
	for b in active_boats:
		if is_instance_valid(b):
			b.queue_free()
	active_boats.clear()
	score_label.text = "Game Over!  Score: %d   Missed: %d   (Space to restart)" % [score, missed]
	set_process_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and not event.echo and event.pressed and event.keycode == KEY_SPACE:
		get_tree().reload_current_scene()
