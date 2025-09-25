extends CharacterBody2D

@export var drift_velocity: Vector2 = Vector2.ZERO   # idle motion when not lit
@export var attract_speed: float = 260.0             # pull strength toward lighthouse
@export var steering: float = 0.16                   # 0..1, higher = snappier

var lighthouse: Node2D = null

func _ready() -> void:
	# IMPORTANT: the group name must match what you added on the Lighthouse node ("lighthouse")
	lighthouse = get_tree().get_first_node_in_group("lighthouse") as Node2D

func _physics_process(delta: float) -> void:
	var target_v: Vector2 = drift_velocity

	if lighthouse != null:
		# avoid static-typing warnings by calling dynamically
		if lighthouse.has_method("is_position_lit"):
			var lit: bool = lighthouse.call("is_position_lit", global_position)
			if lit:
				var dir: Vector2 = (lighthouse.global_position - global_position).normalized()
				target_v = dir * attract_speed

	velocity = velocity.lerp(target_v, steering)
	move_and_slide()

	if velocity.length() > 1.0:
		rotation = lerp_angle(rotation, velocity.angle(), 0.1)
