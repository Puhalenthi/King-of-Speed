extends Area2D

@export var speed: float = 1400.0
@export var direction: int = 1  # 1 for forward, -1 for backward

var is_grappled = false
var line: Line2D = null

var fixPoint 

func _ready():
	# Create the line and add it as a child of this node
	line = Line2D.new()
	line.default_color = Color.WHITE
	line.width = 2.0
	add_child(line)

func _process(delta):
	if not is_grappled:
		var velocity = Vector2.RIGHT.rotated(rotation) * direction * speed
		position += velocity * delta
	else:
		fix_at_point()
		

	# Update the line to draw between this node and its parent
	if get_parent() and line:
		line.clear_points()
		line.add_point(to_local(get_parent().global_position))  # Start at parent
		line.add_point(Vector2.ZERO)  # End at this node's position (self)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("grapplearea"):
		is_grappled = true
		fixPoint = global_position

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") and not is_grappled:
		is_grappled = true
		fixPoint = global_position

func fix_at_point():
	global_position = fixPoint
