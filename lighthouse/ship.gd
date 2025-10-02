extends CharacterBody2D

@export var drift_speed: float = 120.0
@export var attract_speed: float = 350.0
@export var steering: float = 0.22
@export var offscreen_margin: float = 64.0

var direction: int = 1
var lighthouse: Node2D = null
var game: Node = null
var viewport_size: Vector2
var removed: bool = false

@onready var sprite: Sprite2D = $ShipSprite if has_node("ShipSprite") else null

func _ready() -> void:
	add_to_group("boat")
	lighthouse = get_tree().get_first_node_in_group("lighthouse") as Node2D
	game = get_tree().get_first_node_in_group("game")
	viewport_size = get_viewport_rect().size

func _physics_process(_delta: float) -> void:
	var target_v: Vector2 = Vector2(direction * drift_speed, 0.0)

	# attract only while lit (uses beam cone + range)
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
	rotation = 0.0  # keep upright

	_check_dock()
	_check_offscreen()

func _check_dock() -> void:
	if removed or game == null:
		return
	# No-physics dock check
	if game.has_method("is_in_dock_rect") and bool(game.call("is_in_dock_rect", global_position)):
		removed = true
		if game.has_method("on_ship_scored"):
			game.call("on_ship_scored", self)

func _check_offscreen() -> void:
	if removed:
		return
	var m: float = offscreen_margin
	if global_position.x > viewport_size.x + m or global_position.x < -m:
		removed = true
		if game and game.has_method("on_boat_missed"):
			game.call("on_boat_missed", self)
		queue_free()
