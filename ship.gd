extends CharacterBody2D

@export var drift_speed: float = 120.0
@export var attract_speed: float = 500.0
@export var steering: float = 0.22
@export var offscreen_margin: float = 64.0
@export var debug: bool = false

@export var variants: Array[Texture2D] = []

var direction: int = 1
var lighthouse: Node2D = null
var game: Node = null
var removed: bool = false
var has_been_on_screen: bool = false
var rng := RandomNumberGenerator.new()

@onready var sprite: Sprite2D = $ShipSprite if has_node("ShipSprite") else null
@onready var notifier: VisibleOnScreenNotifier2D = $ScreenNotifier

func _ready() -> void:
	add_to_group("boat")
	rng.randomize()
	lighthouse = get_tree().get_first_node_in_group("lighthouse") as Node2D
	game = get_tree().get_first_node_in_group("game")

	if sprite and variants.size() > 0:
		sprite.texture = variants[rng.randi() % variants.size()]

	# --- Flip the sprite if going right ---
	# direction is set in Main.gd before spawning
	if sprite:
		if direction == 1:
			sprite.flip_h = true   # moving right, flip horizontally
		else:
			sprite.flip_h = false  # moving left, normal

	if debug:
		print("Boat ready at ", global_position, " dir=", direction, " speed=", drift_speed)

func _physics_process(_delta: float) -> void:
	if notifier.is_on_screen():
		if not has_been_on_screen:
			has_been_on_screen = true
			if debug: print("Boat entered screen:", global_position)
	else:
		if has_been_on_screen and not removed:
			if debug: print("Boat exited screen:", global_position)
			_do_missed()
			return

	# Movement
	var target_v: Vector2 = Vector2(direction * drift_speed, 0.0)

	if lighthouse and lighthouse.has_method("is_position_lit"):
		var lit: bool = bool(lighthouse.call("is_position_lit", global_position))
		if lit:
			var origin: Vector2 = lighthouse.call("get_beam_origin") as Vector2
			var dir_vec: Vector2 = (origin - global_position).normalized()
			target_v = dir_vec * attract_speed
		if sprite:
			sprite.modulate = Color(0.85, 1.0, 0.85, 1.0) if lit else Color(1, 1, 1, 1)

	velocity = velocity.lerp(target_v, steering)
	move_and_slide()
	rotation = 0.0

	_check_dock()

func _check_dock() -> void:
	if removed or game == null:
		return
	if game.has_method("is_in_dock_rect") and bool(game.call("is_in_dock_rect", global_position)):
		removed = true
		if game.has_method("on_ship_scored"):
			game.call("on_ship_scored", self)

func _do_missed() -> void:
	if removed: return
	removed = true
	if game and game.has_method("on_boat_missed"):
		game.call("on_boat_missed", self)
	queue_free()
