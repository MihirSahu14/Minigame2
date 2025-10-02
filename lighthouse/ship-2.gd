extends Node2D
@export var velocity: Vector2 = Vector2.ZERO

func _process(delta):
	position += velocity * delta
	
	# 超出屏幕后自动删除
	var screen_rect = get_viewport_rect()
	if position.x < -100 or position.x > screen_rect.size.x + 100:
		queue_free()
