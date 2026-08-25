class_name GrayboxCourse
extends Node3D

## Small movement lab built entirely from paired visible meshes and collision shapes.
## Every solid is created through _add_box(), preventing walkable decoration from
## drifting away from its collision representation.

const WORLD_LAYER := 1
const PLAYER_LAYER := 2

const FLOOR_COLOR := Color(0.32, 0.36, 0.43)
const RAMP_COLOR := Color(0.48, 0.53, 0.61)
const LEDGE_COLOR := Color(0.68, 0.53, 0.28)
const RECOVERY_COLOR := Color(0.20, 0.32, 0.38)
const WALL_COLOR := Color(0.24, 0.27, 0.33)


func _ready() -> void:
	_build_course()


func _build_course() -> void:
	# Spawn pad and direct-speed runway.
	_add_box("SpawnFloor", Vector3(16.0, 0.5, 18.0), Vector3(0.0, -0.25, 3.0), Vector3.ZERO, FLOOR_COLOR)
	_add_box("Runway", Vector3(10.0, 0.5, 14.0), Vector3(0.0, -0.25, -13.0), Vector3.ZERO, FLOOR_COLOR)

	# A 15-degree climb into an upper platform. The thick boxes eliminate seams
	# that can appear with zero-thickness trimesh collision at high velocity.
	_add_box("MainRamp", Vector3(10.0, 0.6, 12.5), Vector3(0.0, 1.43, -26.0), Vector3(15.0, 0.0, 0.0), RAMP_COLOR)
	_add_box("UpperDeck", Vector3(18.0, 0.6, 18.0), Vector3(0.0, 3.05, -40.5), Vector3.ZERO, FLOOR_COLOR)
	_add_box("UpperBackWall", Vector3(18.0, 4.0, 0.6), Vector3(0.0, 5.0, -49.2), Vector3.ZERO, WALL_COLOR)
	_add_box("UpperLeftWall", Vector3(0.6, 3.0, 18.0), Vector3(-8.7, 4.5, -40.5), Vector3.ZERO, WALL_COLOR)

	# A steeper cross-slope and stepped ledges for edge/jump behaviour.
	_add_box("SideRamp", Vector3(7.0, 0.55, 10.0), Vector3(12.0, 1.2, -35.0), Vector3(12.0, 0.0, 0.0), RAMP_COLOR)
	_add_box("SideDeck", Vector3(7.0, 0.5, 9.0), Vector3(12.0, 2.45, -44.0), Vector3.ZERO, FLOOR_COLOR)
	_add_box("LedgeA", Vector3(4.0, 0.5, 4.0), Vector3(-11.0, 0.75, -18.0), Vector3.ZERO, LEDGE_COLOR)
	_add_box("LedgeB", Vector3(4.0, 0.5, 4.0), Vector3(-11.0, 1.75, -24.0), Vector3.ZERO, LEDGE_COLOR)
	_add_box("LedgeC", Vector3(4.0, 0.5, 4.0), Vector3(-11.0, 2.75, -30.0), Vector3.ZERO, LEDGE_COLOR)

	# Corridor walls make side-on collision and slide steering easy to exercise.
	_add_box("RunwayLeftWall", Vector3(0.6, 3.0, 32.0), Vector3(-5.3, 1.5, -12.0), Vector3.ZERO, WALL_COLOR)
	_add_box("RunwayRightWall", Vector3(0.6, 3.0, 17.0), Vector3(5.3, 1.5, -4.5), Vector3.ZERO, WALL_COLOR)
	_add_box("SlideImpactWall", Vector3(10.0, 3.0, 0.6), Vector3(0.0, 1.5, 11.7), Vector3.ZERO, WALL_COLOR)

	# Two broad, vertically stacked recovery floors catch missed jumps. Their
	# footprints overlap intentionally to regression-test layered collision.
	_add_box("RecoveryFloorUpper", Vector3(44.0, 0.75, 74.0), Vector3(0.0, -8.0, -19.0), Vector3.ZERO, RECOVERY_COLOR)
	_add_box("RecoveryFloorLower", Vector3(54.0, 0.75, 84.0), Vector3(0.0, -16.0, -19.0), Vector3.ZERO, RECOVERY_COLOR.darkened(0.16))
	_add_box("RecoveryNorthWall", Vector3(54.0, 4.0, 0.75), Vector3(0.0, -14.0, -60.7), Vector3.ZERO, WALL_COLOR)
	_add_box("RecoverySouthWall", Vector3(54.0, 4.0, 0.75), Vector3(0.0, -14.0, 22.7), Vector3.ZERO, WALL_COLOR)
	_add_box("RecoveryWestWall", Vector3(0.75, 4.0, 84.0), Vector3(-26.7, -14.0, -19.0), Vector3.ZERO, WALL_COLOR)
	_add_box("RecoveryEastWall", Vector3(0.75, 4.0, 84.0), Vector3(26.7, -14.0, -19.0), Vector3.ZERO, WALL_COLOR)


func _add_box(
		surface_name: String,
		size: Vector3,
		center: Vector3,
		euler_degrees: Vector3,
		color: Color
	) -> StaticBody3D:
	assert(size.x > 0.0 and size.y > 0.0 and size.z > 0.0)

	var body := StaticBody3D.new()
	body.name = surface_name
	body.position = center
	body.rotation_degrees = euler_degrees
	body.collision_layer = WORLD_LAYER
	body.collision_mask = PLAYER_LAYER
	body.set_meta("walkable_has_collision", true)
	add_child(body)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var visible_mesh := MeshInstance3D.new()
	visible_mesh.name = "VisibleMesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	visible_mesh.mesh = mesh
	visible_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	visible_mesh.material_override = material
	body.add_child(visible_mesh)

	return body
