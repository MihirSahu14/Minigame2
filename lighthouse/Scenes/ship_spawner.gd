extends Node2D

@export var ship_scene: PackedScene   # 预制体
@export var spawn_interval: float = 2.0  # 每隔多久生成一艘船
@export var ship_speed: float = 100.0    # 船只移动速度

func _ready():
	var timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_on_spawn_ship)

func _on_spawn_ship():
	var ship = ship_scene.instantiate()
	add_child(ship)

	var screen_size = get_viewport_rect().size
	var from_left = randi() % 2 == 0

	var top_margin := 40.0
	var bottom_margin := 40.0
	var max_y = screen_size.y * (2.0/3.0) - bottom_margin
	var min_y = top_margin
	var y_pos = randf_range(min_y, max_y)

	if from_left:
		ship.position = Vector2(-50, y_pos)
		ship.velocity = Vector2(ship_speed, 0)
	else:
		ship.position = Vector2(screen_size.x + 50, y_pos)
		ship.velocity = Vector2(-ship_speed, 0)
