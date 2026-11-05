class_name ChJuice extends Node

# A juice beat on its parent: scale and rotation are springs, so a caller kicks and the node moves
# without the caller touching transforms. attach() keeps it to one "Juice" child per target.

# A pop is slightly wider than tall: scale.y follows scale.x at this fraction of its travel.
const SQUASH := 0.6

var scale_spring := ChSpring.new(1.0)
var rotation_spring := ChSpring.new(0.0)


func _init() -> void:
	name = "Juice"


func _process(delta: float) -> void:
	advance(delta)


func kick(scale_impulse: float, rotation_impulse: float) -> void:
	scale_spring.velocity += scale_impulse
	rotation_spring.velocity += rotation_impulse


func advance(delta: float) -> void:
	scale_spring.step(delta)
	rotation_spring.step(delta)
	var target := get_parent()
	if target == null:
		return
	var value := scale_spring.value
	# Plain Vector2.ONE * value would lose the squash on y, so the vector is built directly.
	var squash := Vector2(value, 1.0 + (value - 1.0) * SQUASH)
	# A Control scales around pivot_offset, which defaults to its top-left; centre it first.
	if target is Control:
		var control := target as Control
		control.pivot_offset = control.size * 0.5
		control.scale = squash
		control.rotation = rotation_spring.value
	elif target is Node2D:
		var node := target as Node2D
		node.scale = squash
		node.rotation = rotation_spring.value


static func of(target: Node) -> ChJuice:
	return target.get_node_or_null("Juice") as ChJuice


static func attach(target: CanvasItem) -> ChJuice:
	var existing := of(target)
	if existing != null:
		return existing
	var juice := ChJuice.new()
	target.add_child(juice)
	return juice
