extends Node

## Headless movement and collision regression suite.
## Run with:
##   godot --headless --path . res://tests/regression_runner.tscn
## Exit codes: 0 = pass, 1 = regression, 2 = invalid setup.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const COURSE_SCRIPT_PATH := "res://scripts/world/graybox_course.gd"
const REQUIRED_PHYSICS_TICKS_PER_SECOND := 120
const WORLD_LAYER := 1
const PLAYER_LAYER := 2
const EXIT_SUCCESS := 0
const EXIT_TEST_FAILURE := 1
const EXIT_SETUP_FAILURE := 2
const LANDING_STABILITY_TICKS := 5
const LANDING_HEIGHT_TOLERANCE := 0.06

const INPUT_ACTIONS := [
	&"move_forward",
	&"move_back",
	&"move_left",
	&"move_right",
	&"jump",
	&"crouch",
	&"slide",
]

const EXPECTED_COURSE_SURFACES := {
	"SpawnFloor": {"size": Vector3(16.0, 0.5, 18.0), "position": Vector3(0.0, -0.25, 3.0), "rotation": Vector3.ZERO},
	"Runway": {"size": Vector3(10.0, 0.5, 14.0), "position": Vector3(0.0, -0.25, -13.0), "rotation": Vector3.ZERO},
	"MainRamp": {"size": Vector3(10.0, 0.6, 11.978001), "position": Vector3(0.0, 1.386972, -25.833904), "rotation": Vector3(16.241071, 0.0, 0.0)},
	"UpperDeck": {"size": Vector3(18.0, 0.6, 18.0), "position": Vector3(0.0, 3.05, -40.5), "rotation": Vector3.ZERO},
	"UpperBackWall": {"size": Vector3(18.0, 4.0, 0.6), "position": Vector3(0.0, 5.0, -49.2), "rotation": Vector3.ZERO},
	"UpperLeftWall": {"size": Vector3(0.6, 3.0, 18.0), "position": Vector3(-8.7, 4.5, -40.5), "rotation": Vector3.ZERO},
	"SideRamp": {"size": Vector3(7.0, 0.55, 10.0), "position": Vector3(12.0, 1.391451, -34.666438), "rotation": Vector3(12.0, 0.0, 0.0)},
	"SideDeck": {"size": Vector3(7.0, 0.5, 9.0), "position": Vector3(12.0, 2.45, -44.0), "rotation": Vector3.ZERO},
	"LedgeA": {"size": Vector3(4.0, 0.5, 4.0), "position": Vector3(-11.0, 0.75, -18.0), "rotation": Vector3.ZERO},
	"LedgeB": {"size": Vector3(4.0, 0.5, 4.0), "position": Vector3(-11.0, 1.75, -24.0), "rotation": Vector3.ZERO},
	"LedgeC": {"size": Vector3(4.0, 0.5, 4.0), "position": Vector3(-11.0, 2.75, -30.0), "rotation": Vector3.ZERO},
	"RunwayLeftWall": {"size": Vector3(0.6, 3.0, 32.0), "position": Vector3(-5.3, 1.5, -12.0), "rotation": Vector3.ZERO},
	"RunwayRightWall": {"size": Vector3(0.6, 3.0, 17.0), "position": Vector3(5.3, 1.5, -4.5), "rotation": Vector3.ZERO},
	"SlideImpactWall": {"size": Vector3(10.0, 3.0, 0.6), "position": Vector3(0.0, 1.5, 11.7), "rotation": Vector3.ZERO},
	"RecoveryFloorUpper": {"size": Vector3(44.0, 0.75, 74.0), "position": Vector3(0.0, -8.0, -19.0), "rotation": Vector3.ZERO},
	"RecoveryFloorLower": {"size": Vector3(54.0, 0.75, 84.0), "position": Vector3(0.0, -16.0, -19.0), "rotation": Vector3.ZERO},
	"RecoveryNorthWall": {"size": Vector3(54.0, 4.0, 0.75), "position": Vector3(0.0, -14.0, -60.7), "rotation": Vector3.ZERO},
	"RecoverySouthWall": {"size": Vector3(54.0, 4.0, 0.75), "position": Vector3(0.0, -14.0, 22.7), "rotation": Vector3.ZERO},
	"RecoveryWestWall": {"size": Vector3(0.75, 4.0, 84.0), "position": Vector3(-26.7, -14.0, -19.0), "rotation": Vector3.ZERO},
	"RecoveryEastWall": {"size": Vector3(0.75, 4.0, 84.0), "position": Vector3(26.7, -14.0, -19.0), "rotation": Vector3.ZERO},
}


class PostPhysicsProbe:
	extends Node
	signal step_finished

	func _ready() -> void:
		process_physics_priority = 1000

	func _physics_process(_delta: float) -> void:
		step_finished.emit()


var _player_scene: PackedScene
var _post_physics_probe: PostPhysicsProbe
var _failures: Array[String] = []
var _passes := 0


func _ready() -> void:
	_post_physics_probe = PostPhysicsProbe.new()
	_post_physics_probe.name = "PostPhysicsProbe"
	add_child(_post_physics_probe)
	_run_all.call_deferred()


func _run_all() -> void:
	print("[REGRESSION] Project Ascent headless movement/collision suite")
	print("[REGRESSION] physics_ticks_per_second=%d" % Engine.physics_ticks_per_second)

	var setup_error := _validate_setup()
	if not setup_error.is_empty():
		_setup_failed(setup_error)
		return

	_record("graybox_exact_collision_contract", await _test_graybox_exact_collision_contract())
	_record("real_course_recovery_floors", await _test_real_course_recovery_floors())
	_record("grounding_on_flat_floor", await _test_grounding_on_flat_floor())
	_record("ground_movement_13_mps", await _test_ground_movement_speed())
	_record("ground_release_brakes_hard", await _test_ground_release_brakes_hard())
	_record("jump_takeoff_and_landing", await _test_jump_takeoff_and_landing())
	_record("crouch_geometry_and_speed", await _test_crouch_geometry_and_speed())
	_record("crouch_forward_never_slides", await _test_crouch_forward_never_slides())
	_record("no_forward_no_slide", await _test_no_forward_no_slide())
	_record("flat_slide_near_16_mps", await _test_flat_slide_speed())
	_record("buffered_slide_start", await _test_buffered_slide_start())
	_record("slide_forward_release_brakes", await _test_slide_forward_release_brakes())
	_record("slide_release_with_strafe_brakes", await _test_slide_release_with_strafe_brakes())
	_record("slide_preserves_fast_momentum", await _test_slide_preserves_fast_momentum())
	_record("slide_jump_retains_17_mps", await _test_slide_jump_retains_speed())
	_record("slide_coyote_retains_17_mps", await _test_slide_coyote_retains_speed())
	_record("ramp_traversal_at_speed", await _test_ramp_traversal())
	_record("real_course_main_ramp_seams", await _test_real_course_main_ramp_seams())
	_record("curb_step_up_once", await _test_curb_step_up_once())
	_record("falling_wall_slide_limits_fall", await _test_falling_wall_slide_limits_fall())
	_record("wall_slide_duration_requires_separation", await _test_wall_slide_duration_requires_separation())
	_record("low_tap_near_wall_has_no_free_kick", await _test_low_tap_near_wall_has_no_free_kick())
	_record("probe_wall_detach_has_no_free_kick", await _test_probe_wall_detach_has_no_free_kick())
	_record("crouch_detaches_wall_slide", await _test_wall_slide_detach(&"crouch"))
	_record("slide_detaches_wall_slide", await _test_wall_slide_detach(&"slide"))
	_record("buffered_wall_jump", await _test_buffered_wall_jump())
	_record("platform_edge_to_recovery", await _test_platform_edge_to_recovery())
	_record("stacked_floor_stops_first_fall", await _test_stacked_floor_stops_first_fall())
	_record("lower_recovery_floor", await _test_lower_recovery_floor())
	_record("fast_fall_does_not_tunnel", await _test_fast_fall_does_not_tunnel())

	_release_test_inputs()
	print("[REGRESSION] SUMMARY: %d passed, %d failed" % [_passes, _failures.size()])
	if _failures.is_empty():
		print("[REGRESSION] PASS")
		get_tree().quit(EXIT_SUCCESS)
	else:
		for failure in _failures:
			printerr("[REGRESSION]   - %s" % failure)
		printerr("[REGRESSION] FAIL")
		get_tree().quit(EXIT_TEST_FAILURE)


func _validate_setup() -> String:
	if Engine.physics_ticks_per_second != REQUIRED_PHYSICS_TICKS_PER_SECOND:
		return (
			"Expected %d physics ticks per second, got %d."
			% [REQUIRED_PHYSICS_TICKS_PER_SECOND, Engine.physics_ticks_per_second]
		)

	for action in INPUT_ACTIONS:
		if not InputMap.has_action(action):
			return "Required input action is missing: %s." % action

	if not ResourceLoader.exists(PLAYER_SCENE_PATH, "PackedScene"):
		return "Player scene is missing: %s" % PLAYER_SCENE_PATH
	_player_scene = load(PLAYER_SCENE_PATH) as PackedScene
	if _player_scene == null:
		return "Player scene could not be loaded: %s" % PLAYER_SCENE_PATH

	return _validate_player_scene_contract()


func _validate_player_scene_contract() -> String:
	var instance := _player_scene.instantiate()
	if not instance is CharacterBody3D:
		var actual_type := instance.get_class()
		instance.free()
		return "Player root must be CharacterBody3D, got %s." % actual_type

	var player := instance as CharacterBody3D
	if player.collision_layer != PLAYER_LAYER or (player.collision_mask & WORLD_LAYER) == 0:
		instance.free()
		return "Player must use layer 2 and scan world layer 1."

	var enabled_capsules: Array[CollisionShape3D] = []
	for child in instance.find_children("*", "CollisionShape3D", true, false):
		var collision := child as CollisionShape3D
		if collision != null and not collision.disabled and collision.shape is CapsuleShape3D:
			enabled_capsules.append(collision)
	if enabled_capsules.size() != 1:
		instance.free()
		return "Player requires exactly one enabled CapsuleShape3D collider."

	var capsule_collision := enabled_capsules[0]
	var capsule := capsule_collision.shape as CapsuleShape3D
	var capsule_bottom := capsule_collision.position.y - capsule.height * 0.5
	if absf(capsule_bottom) > 0.01:
		instance.free()
		return "Player origin must remain at the capsule foot; bottom offset is %.4f." % capsule_bottom
	if not capsule_collision.rotation.is_zero_approx() or not capsule_collision.scale.is_equal_approx(Vector3.ONE):
		instance.free()
		return "Player capsule must be unrotated and unscaled."
	if not is_equal_approx(float(player.get("move_speed")), 13.0):
		instance.free()
		return "Player move_speed must be 13 m/s."
	if not is_equal_approx(float(player.get("slide_start_speed")), 16.0):
		instance.free()
		return "Player slide_start_speed must be 16 m/s."

	instance.free()
	return ""


func _test_graybox_exact_collision_contract() -> Dictionary:
	var world := _new_case_world("GrayboxExactCollisionContract")
	var course := _instantiate_course(world)
	if course == null:
		return await _finish_case(world, _result(false, "Could not instantiate the graybox course."))
	if not course.position.is_zero_approx() \
			or not course.rotation.is_zero_approx() \
			or not course.scale.is_equal_approx(Vector3.ONE) \
			or not course.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE):
		return await _finish_case(
			world,
			_result(false, "Graybox course root must remain at an unscaled identity transform.")
		)
	await _step_physics()

	var direct_bodies: Array[StaticBody3D] = []
	for child in course.get_children():
		if child is StaticBody3D:
			direct_bodies.append(child as StaticBody3D)
	if direct_bodies.size() != EXPECTED_COURSE_SURFACES.size():
		return await _finish_case(
			world,
			_result(
				false,
				"Expected %d course solids, found %d."
				% [EXPECTED_COURSE_SURFACES.size(), direct_bodies.size()]
			)
		)

	var all_meshes := course.find_children("*", "MeshInstance3D", true, false)
	if all_meshes.size() != EXPECTED_COURSE_SURFACES.size():
		return await _finish_case(
			world,
			_result(false, "Expected one visible mesh per solid, found %d." % all_meshes.size())
		)
	for mesh_node in all_meshes:
		if not mesh_node.get_parent() is StaticBody3D:
			return await _finish_case(
				world,
				_result(false, "Free-standing visible mesh found: %s." % mesh_node.get_path())
			)

	var space_state := course.get_world_3d().direct_space_state
	for surface_name in EXPECTED_COURSE_SURFACES:
		var node := course.get_node_or_null(NodePath(String(surface_name)))
		if not node is StaticBody3D:
			return await _finish_case(
				world,
				_result(false, "Missing StaticBody3D course surface: %s." % surface_name)
			)

		var body := node as StaticBody3D
		var spec: Dictionary = EXPECTED_COURSE_SURFACES[surface_name]
		if body.collision_layer != WORLD_LAYER or body.collision_mask != PLAYER_LAYER:
			return await _finish_case(
				world,
				_result(false, "%s must use world layer 1 and player mask 2." % surface_name)
			)
		if not bool(body.get_meta("walkable_has_collision", false)):
			return await _finish_case(
				world,
				_result(false, "%s is missing its collision invariant metadata." % surface_name)
			)
		if not body.position.is_equal_approx(spec["position"]) \
				or not body.rotation_degrees.is_equal_approx(spec["rotation"]) \
				or not body.scale.is_equal_approx(Vector3.ONE) \
				or not body.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE):
			return await _finish_case(
				world,
				_result(false, "%s transform or scale differs from the course manifest." % surface_name)
			)

		var collisions := body.find_children("*", "CollisionShape3D", true, false)
		var meshes := body.find_children("*", "MeshInstance3D", true, false)
		if collisions.size() != 1 or meshes.size() != 1:
			return await _finish_case(
				world,
				_result(false, "%s must have exactly one mesh and one collision shape." % surface_name)
			)

		var collision := collisions[0] as CollisionShape3D
		var mesh_instance := meshes[0] as MeshInstance3D
		if collision == null or collision.disabled or not collision.shape is BoxShape3D:
			return await _finish_case(
				world,
				_result(false, "%s collision must be an enabled BoxShape3D." % surface_name)
			)
		if mesh_instance == null or not mesh_instance.visible or not mesh_instance.mesh is BoxMesh:
			return await _finish_case(
				world,
				_result(false, "%s visible geometry must be a non-empty BoxMesh." % surface_name)
			)
		if not collision.position.is_zero_approx() \
				or not collision.rotation.is_zero_approx() \
				or not collision.scale.is_equal_approx(Vector3.ONE) \
				or not mesh_instance.position.is_zero_approx() \
				or not mesh_instance.rotation.is_zero_approx() \
				or not mesh_instance.scale.is_equal_approx(Vector3.ONE):
			return await _finish_case(
				world,
				_result(false, "%s mesh/collision local transforms must match." % surface_name)
			)

		var box_shape := collision.shape as BoxShape3D
		var box_mesh := mesh_instance.mesh as BoxMesh
		if not box_shape.size.is_equal_approx(spec["size"]) \
				or not box_mesh.size.is_equal_approx(spec["size"]) \
				or not box_shape.size.is_equal_approx(box_mesh.size):
			return await _finish_case(
				world,
				_result(false, "%s mesh and collision sizes differ from the manifest." % surface_name)
			)

		var ray_from := body.to_global(Vector3(0.0, box_shape.size.y * 0.5 + 0.2, 0.0))
		var ray_to := body.to_global(Vector3(0.0, box_shape.size.y * 0.5 - 0.2, 0.0))
		var ray_query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, WORLD_LAYER)
		var hit := space_state.intersect_ray(ray_query)
		if hit.is_empty() or hit.get("collider") != body:
			return await _finish_case(
				world,
				_result(false, "%s is not registered as a live world collider." % surface_name)
			)

	return await _finish_case(
		world,
		_result(true, "Verified all %d exact mesh/collision pairs." % direct_bodies.size())
	)


func _test_real_course_recovery_floors() -> Dictionary:
	var world := _new_case_world("RealCourseRecoveryFloors")
	var course := _instantiate_course(world)
	if course == null:
		return await _finish_case(world, _result(false, "Could not instantiate the graybox course."))
	await _step_physics()

	var upper_player := _spawn_player(world, Vector3(20.0, -4.0, 0.0))
	var upper_landing := await _wait_for_landing(upper_player, -7.625, -7.80, 300)
	if not bool(upper_landing["passed"]):
		return await _finish_case(world, upper_landing)

	var lower_player := _spawn_player(world, Vector3(24.0, -11.0, 20.0))
	var lower_landing := await _wait_for_landing(lower_player, -15.625, -15.80, 300)
	if not bool(lower_landing["passed"]):
		return await _finish_case(world, lower_landing)

	return await _finish_case(
		world,
		_result(true, "The real upper and lower recovery floors caught both falls.")
	)


func _test_grounding_on_flat_floor() -> Dictionary:
	var world := _new_case_world("GroundingOnFlatFloor")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(20.0, 1.0, 20.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if bool(landing["passed"]) and player.get_floor_normal().dot(Vector3.UP) < 0.98:
		landing = _result(false, "Flat floor normal was %s." % player.get_floor_normal())
	if bool(landing["passed"]) and absf(player.velocity.y) > 0.1:
		landing = _result(false, "Grounded player retained %.3f m/s vertical speed." % player.velocity.y)
	return await _finish_case(world, landing)


func _test_ground_movement_speed() -> Dictionary:
	var world := _new_case_world("GroundMovementSpeed")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"move_forward")
	var speed_at_tick_18 := 0.0
	for tick_index in range(36):
		await _step_physics()
		if tick_index == 17:
			speed_at_tick_18 = _horizontal_speed(player)
	Input.action_release(&"move_forward")

	var final_speed := _horizontal_speed(player)
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var forward_dot := horizontal_velocity.normalized().dot(Vector3.FORWARD)
	var passed := (
		speed_at_tick_18 >= 12.5
		and final_speed >= 12.85
		and final_speed <= 13.15
		and forward_dot > 0.995
		and player.is_on_floor()
		and absf(player.global_position.y) <= LANDING_HEIGHT_TOLERANCE
	)
	var detail := (
		"tick18=%.3f m/s, final=%.3f m/s, direction dot=%.4f."
		% [speed_at_tick_18, final_speed, forward_dot]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_ground_release_brakes_hard() -> Dictionary:
	var world := _new_case_world("GroundReleaseBrakesHard")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"move_forward")
	for _tick_index in range(18):
		await _step_physics()
	var release_speed := _horizontal_speed(player)
	var release_position := Vector2(player.global_position.x, player.global_position.z)
	Input.action_release(&"move_forward")

	var stopped_tick := -1
	for tick_index in range(10):
		await _step_physics()
		if stopped_tick < 0 and _horizontal_speed(player) <= 0.50:
			stopped_tick = tick_index + 1

	var stop_position := Vector2(player.global_position.x, player.global_position.z)
	var stopping_distance := release_position.distance_to(stop_position)
	var final_speed := _horizontal_speed(player)
	var passed := (
		release_speed >= 12.85
		and release_speed <= 13.15
		and stopped_tick > 0
		and stopped_tick <= 8
		and stopping_distance <= 0.40
		and final_speed <= 0.10
		and player.is_on_floor()
	)
	var detail := (
		"release=%.3f m/s, stop_tick=%d, distance=%.3f m, final=%.3f m/s."
		% [release_speed, stopped_tick, stopping_distance, final_speed]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_jump_takeoff_and_landing() -> Dictionary:
	var world := _new_case_world("JumpTakeoffAndLanding")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"jump")
	await _step_physics()
	Input.action_release(&"jump")
	var takeoff_velocity := player.velocity.y
	var takeoff_height := player.global_position.y
	if player.is_on_floor() or takeoff_velocity < 6.0 or takeoff_velocity > 6.35 or takeoff_height <= 0.03:
		return await _finish_case(
			world,
			_result(false, "Invalid jump takeoff: y=%.3f, velocity=%.3f." % [takeoff_height, takeoff_velocity])
		)

	var apex := takeoff_height
	for _tick_index in range(180):
		await _step_physics()
		apex = maxf(apex, player.global_position.y)
		if player.velocity.y <= 0.0:
			break
	if apex < 0.65 or apex > 0.82:
		return await _finish_case(world, _result(false, "Jump apex was %.3f m." % apex))

	var relanding := await _wait_for_landing(player, 0.0, -0.10, 360)
	if bool(relanding["passed"]):
		relanding["detail"] = "Takeoff %.3f m/s, apex %.3f m, then relanded." % [takeoff_velocity, apex]
	return await _finish_case(world, relanding)


func _test_crouch_geometry_and_speed() -> Dictionary:
	var world := _new_case_world("CrouchGeometryAndSpeed")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"crouch")
	for _tick_index in range(14):
		await _step_physics()
	var collision := player.get_node("CollisionShape3D") as CollisionShape3D
	var head := player.get_node("Head") as Node3D
	var capsule := collision.shape as CapsuleShape3D
	if not bool(player.call("is_crouched")) \
			or absf(capsule.height - 1.20) > 0.03 \
			or absf(collision.position.y - 0.60) > 0.03 \
			or absf(head.position.y - 1.02) > 0.03:
		return await _finish_case(
			world,
			_result(
				false,
				"Crouch geometry mismatch: height=%.3f collider_y=%.3f head_y=%.3f."
				% [capsule.height, collision.position.y, head.position.y]
			)
		)

	Input.action_press(&"move_right")
	for _tick_index in range(24):
		await _step_physics()
	var crouch_speed := _horizontal_speed(player)
	var crouch_direction := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized()
	var slid_during_strafe := bool(player.call("is_sliding"))
	Input.action_release(&"move_right")
	Input.action_release(&"crouch")
	for _tick_index in range(14):
		await _step_physics()

	var passed := (
		crouch_speed >= 6.8
		and crouch_speed <= 7.15
		and crouch_direction.dot(Vector3.RIGHT) > 0.995
		and not slid_during_strafe
		and absf(capsule.height - 1.80) <= 0.03
		and absf(collision.position.y - 0.90) <= 0.03
		and absf(head.position.y - 1.62) <= 0.03
	)
	var detail := (
		"Strafe crouch %.3f m/s (dot=%.4f, sliding=%s); restored height %.3f m and eye %.3f m."
		% [
			crouch_speed,
			crouch_direction.dot(Vector3.RIGHT),
			slid_during_strafe,
			capsule.height,
			head.position.y,
		]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_no_forward_no_slide() -> Dictionary:
	var world := _new_case_world("NoForwardNoSlide")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	var incorrectly_started: Array[StringName] = []
	var low_actions: Array[StringName] = [&"crouch", &"slide"]
	for low_action in low_actions:
		player.velocity = Vector3(0.0, 0.0, -13.0)
		Input.action_press(low_action)
		await _step_physics()
		if bool(player.call("is_sliding")):
			incorrectly_started.append(low_action)
		Input.action_release(low_action)
		# One released tick is required before the same low-input edge is reused.
		await _step_physics()

	var passed := incorrectly_started.is_empty() and player.is_on_floor()
	var detail := (
		"Low actions that incorrectly started without forward: %s."
		% [incorrectly_started]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_crouch_forward_never_slides() -> Dictionary:
	var world := _new_case_world("CrouchForwardNeverSlides")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"crouch")
	Input.action_press(&"move_forward")
	var ever_slid := false
	for _tick_index in range(30):
		await _step_physics()
		ever_slid = ever_slid or bool(player.call("is_sliding"))
	var crouch_speed := _horizontal_speed(player)
	var stayed_crouched := bool(player.call("is_crouched"))
	Input.action_release(&"move_forward")
	Input.action_release(&"crouch")

	var passed := (
		not ever_slid
		and stayed_crouched
		and crouch_speed >= 6.8
		and crouch_speed <= 7.15
	)
	return await _finish_case(
		world,
		_result(
			passed,
			"C+W speed=%.3f m/s, crouched=%s, ever_slid=%s."
			% [crouch_speed, stayed_crouched, ever_slid]
		)
	)


func _test_flat_slide_speed() -> Dictionary:
	var world := _new_case_world("FlatSlideSpeed")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"move_forward")
	for _tick_index in range(18):
		await _step_physics()
	Input.action_press(&"slide")
	await _step_physics()
	var slide_speed := _horizontal_speed(player)
	var sliding := bool(player.call("is_sliding"))
	Input.action_release(&"slide")
	var remained_latched := true
	for _tick_index in range(6):
		await _step_physics()
		remained_latched = remained_latched and bool(player.call("is_sliding"))
	Input.action_release(&"move_forward")

	var passed := (
		slide_speed >= 15.80
		and slide_speed <= 16.10
		and sliding
		and remained_latched
	)
	return await _finish_case(
		world,
		_result(
			passed,
			"Legal flat slide started at %.3f m/s (started=%s, tap_latched=%s)."
			% [slide_speed, sliding, remained_latched]
		)
	)


func _test_buffered_slide_start() -> Dictionary:
	var world := _new_case_world("BufferedSlideStart")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	# Tap Shift before reaching the entry-speed gate, then keep only W held.
	Input.action_press(&"move_forward")
	Input.action_press(&"slide")
	await _step_physics()
	var incorrectly_started_on_tap := bool(player.call("is_sliding"))
	Input.action_release(&"slide")

	var trigger_tick := -1
	var trigger_speed := 0.0
	var buffer_ticks := ceili(
		float(player.get("slide_buffer_time")) * float(REQUIRED_PHYSICS_TICKS_PER_SECOND)
	) + 2
	for tick_index in range(buffer_ticks):
		await _step_physics()
		if bool(player.call("is_sliding")):
			trigger_tick = tick_index + 1
			trigger_speed = _horizontal_speed(player)
			break
	Input.action_release(&"move_forward")

	var passed := (
		not incorrectly_started_on_tap
		and trigger_tick >= 2
		and trigger_tick <= buffer_ticks
		and trigger_speed >= 15.75
		and not Input.is_action_pressed(&"slide")
	)
	var detail := (
		"early=%s, buffered trigger=%d/%d at %.3f m/s after Shift release."
		% [incorrectly_started_on_tap, trigger_tick, buffer_ticks, trigger_speed]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_slide_forward_release_brakes() -> Dictionary:
	var world := _new_case_world("SlideForwardReleaseBrakes")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"move_forward")
	for _tick_index in range(18):
		await _step_physics()
	Input.action_press(&"slide")
	await _step_physics()
	var entry_speed := _horizontal_speed(player)
	var started_sliding := bool(player.call("is_sliding"))
	var release_position := Vector2(player.global_position.x, player.global_position.z)

	Input.action_release(&"move_forward")
	await _step_physics()
	var ended_on_release := not bool(player.call("is_sliding"))
	var stopped_tick := -1
	for tick_index in range(9):
		await _step_physics()
		if stopped_tick < 0 and _horizontal_speed(player) <= 0.50:
			stopped_tick = tick_index + 2
	Input.action_release(&"slide")

	var stop_position := Vector2(player.global_position.x, player.global_position.z)
	var stopping_distance := release_position.distance_to(stop_position)
	var final_speed := _horizontal_speed(player)
	var passed := (
		started_sliding
		and entry_speed >= 15.80
		and entry_speed <= 16.10
		and ended_on_release
		and stopped_tick > 0
		and stopped_tick <= 8
		and stopping_distance <= 0.50
		and final_speed <= 0.10
	)
	var detail := (
		"entry=%.3f, ended=%s, stop_tick=%d, distance=%.3f, final=%.3f."
		% [entry_speed, ended_on_release, stopped_tick, stopping_distance, final_speed]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_slide_release_with_strafe_brakes() -> Dictionary:
	var world := _new_case_world("SlideReleaseWithStrafeBrakes")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"move_forward")
	for _tick_index in range(18):
		await _step_physics()
	Input.action_press(&"slide")
	await _step_physics()
	var entry_speed := _horizontal_speed(player)
	var release_position := Vector2(player.global_position.x, player.global_position.z)

	Input.action_release(&"move_forward")
	Input.action_press(&"move_left")
	var stopped_tick := -1
	for tick_index in range(10):
		await _step_physics()
		if _horizontal_speed(player) <= 0.50:
			stopped_tick = tick_index + 1
			Input.action_release(&"move_left")
			break
	Input.action_release(&"move_left")
	Input.action_release(&"slide")

	var stop_position := Vector2(player.global_position.x, player.global_position.z)
	var stopping_distance := release_position.distance_to(stop_position)
	var final_speed := _horizontal_speed(player)
	var passed := (
		entry_speed >= 15.80
		and entry_speed <= 16.10
		and stopped_tick > 0
		and stopped_tick <= 8
		and stopping_distance <= 0.50
		and final_speed <= 0.50
		and not bool(player.call("is_sliding"))
	)
	var detail := (
		"entry=%.3f, strafe-stop tick=%d, distance=%.3f, final=%.3f."
		% [entry_speed, stopped_tick, stopping_distance, final_speed]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_slide_preserves_fast_momentum() -> Dictionary:
	var world := _new_case_world("SlidePreservesFastMomentum")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	player.velocity = Vector3(22.0, 0.0, 0.0)
	Input.action_press(&"move_forward")
	Input.action_press(&"slide")
	await _step_physics()
	var slide_speed := _horizontal_speed(player)
	var direction_dot := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized().dot(Vector3.RIGHT)
	var sliding := bool(player.call("is_sliding"))
	Input.action_release(&"slide")
	Input.action_release(&"move_forward")

	var passed := slide_speed >= 21.80 and direction_dot > 0.99 and sliding
	return await _finish_case(
		world,
		_result(
			passed,
			"Legal 22 m/s entry retained %.3f m/s with direction dot %.4f."
			% [slide_speed, direction_dot]
		)
	)


func _test_slide_jump_retains_speed() -> Dictionary:
	var world := _new_case_world("SlideJumpRetainsSpeed")
	_create_box_collider(world, "Floor", Vector3(0.0, -0.5, 0.0), Vector3(100.0, 1.0, 100.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"move_forward")
	for _tick_index in range(18):
		await _step_physics()
	Input.action_press(&"slide")
	await _step_physics()
	var slide_started := bool(player.call("is_sliding"))
	Input.action_press(&"jump")
	await _step_physics()
	Input.action_release(&"jump")

	var jump_speed := _horizontal_speed(player)
	var vertical_speed := player.velocity.y
	var direction_dot := Vector3(player.velocity.x, 0.0, player.velocity.z).normalized().dot(Vector3.FORWARD)
	var passed := (
		slide_started
		and not bool(player.call("is_sliding"))
		and not player.is_on_floor()
		and jump_speed >= 16.95
		and jump_speed <= 17.20
		and vertical_speed >= 5.0
		and vertical_speed <= 5.4
		and direction_dot > 0.995
	)
	Input.action_release(&"slide")
	Input.action_release(&"move_forward")

	var detail := (
		"started=%s, jump horizontal=%.3f, vertical=%.3f, direction dot=%.4f."
		% [slide_started, jump_speed, vertical_speed, direction_dot]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_slide_coyote_retains_speed() -> Dictionary:
	var world := _new_case_world("SlideCoyoteRetainsSpeed")
	_create_box_collider(world, "ShortPlatform", Vector3(0.0, -0.5, 2.0), Vector3(12.0, 1.0, 6.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	player.velocity = Vector3.FORWARD * 13.0
	Input.action_press(&"move_forward")
	Input.action_press(&"slide")
	await _step_physics()
	var slide_started := bool(player.call("is_sliding"))
	Input.action_release(&"slide")

	var left_edge := false
	for _tick_index in range(48):
		await _step_physics()
		if not player.is_on_floor():
			left_edge = true
			break
	if not left_edge:
		Input.action_release(&"move_forward")
		return await _finish_case(world, _result(false, "Slide never left the short platform."))

	Input.action_press(&"jump")
	await _step_physics()
	Input.action_release(&"jump")
	Input.action_release(&"move_forward")
	var horizontal_speed := _horizontal_speed(player)
	var vertical_speed := player.velocity.y
	var passed := (
		slide_started
		and horizontal_speed >= 16.95
		and horizontal_speed <= 17.25
		and vertical_speed >= 5.0
		and vertical_speed <= 5.4
		and not player.is_on_floor()
	)
	var detail := (
		"started=%s, left_edge=%s, coyote jump horizontal=%.3f, vertical=%.3f."
		% [slide_started, left_edge, horizontal_speed, vertical_speed]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_ramp_traversal() -> Dictionary:
	var world := _new_case_world("RampTraversal")
	_create_box_collider(world, "Approach", Vector3(0.0, -0.5, 3.0), Vector3(8.0, 1.0, 6.0))
	_create_box_collider(
		world,
		"FifteenDegreeRamp",
		Vector3(0.0, 0.7455, -3.94),
		Vector3(8.0, 0.6, 8.0),
		Vector3(deg_to_rad(15.0), 0.0, 0.0)
	)
	_create_box_collider(world, "UpperDeck", Vector3(0.0, 1.5705, -10.85), Vector3(8.0, 1.0, 6.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 2.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"move_forward")
	var ramp_ground_ticks := 0
	var airborne_ticks := 0
	var crossed_surface := false
	for _tick_index in range(120):
		await _step_physics()
		if player.global_position.y < -0.12:
			crossed_surface = true
			break
		if player.global_position.y > 0.20 and player.global_position.y < 1.95:
			if player.is_on_floor():
				var floor_normal := player.get_floor_normal()
				if floor_normal.dot(Vector3.UP) >= 0.94 \
						and floor_normal.dot(Vector3.UP) <= 0.98 \
						and absf(floor_normal.z) > 0.20:
					ramp_ground_ticks += 1
			else:
				airborne_ticks += 1
	Input.action_release(&"move_forward")

	var expected_deck_height := 2.0705
	var final_speed := _horizontal_speed(player)
	var passed := (
		not crossed_surface
		and ramp_ground_ticks >= 15
		and airborne_ticks <= 4
		and player.is_on_floor()
		and player.global_position.z < -8.0
		and absf(player.global_position.y - expected_deck_height) <= 0.08
		and final_speed >= 12.7
		and final_speed <= 13.2
	)
	var detail := (
		"ramp_ticks=%d air_ticks=%d final=(y=%.3f,z=%.3f,speed=%.3f)."
		% [ramp_ground_ticks, airborne_ticks, player.global_position.y, player.global_position.z, final_speed]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_real_course_main_ramp_seams() -> Dictionary:
	var world := _new_case_world("RealCourseMainRampSeams")
	var course := _instantiate_course(world)
	if course == null:
		return await _finish_case(world, _result(false, "Could not instantiate the graybox course."))
	await _step_physics()

	var ramp_body := course.get_node_or_null("MainRamp") as StaticBody3D
	if ramp_body == null:
		return await _finish_case(world, _result(false, "The real course has no MainRamp body."))
	var ramp_collision := ramp_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if ramp_collision == null or not ramp_collision.shape is BoxShape3D:
		return await _finish_case(world, _result(false, "MainRamp has no BoxShape3D collider."))
	var ramp_box := ramp_collision.shape as BoxShape3D
	var half_size := ramp_box.size * 0.5
	var lower_edge := ramp_collision.to_global(Vector3(0.0, half_size.y, half_size.z))
	var upper_edge := ramp_collision.to_global(Vector3(0.0, half_size.y, -half_size.z))

	var player := _spawn_player(world, Vector3(0.0, 4.0, lower_edge.z + 5.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	player.velocity = Vector3.FORWARD * 13.0
	Input.action_press(&"move_forward")
	var lower_enter_tick := -1
	var lower_exit_tick := -1
	var upper_enter_tick := -1
	var upper_exit_tick := -1
	var consecutive_stall_ticks := 0
	var maximum_stall_ticks := 0
	var seam_airborne_ticks := 0
	var fell_through := false
	var previous_z := player.global_position.z
	for tick_index in range(220):
		await _step_physics()
		var current_z := player.global_position.z
		var forward_progress := previous_z - current_z
		previous_z = current_z

		if lower_enter_tick < 0 and current_z <= lower_edge.z + 0.90:
			lower_enter_tick = tick_index + 1
		if lower_exit_tick < 0 and current_z <= lower_edge.z - 0.90:
			lower_exit_tick = tick_index + 1
		if upper_enter_tick < 0 and current_z <= upper_edge.z + 0.90:
			upper_enter_tick = tick_index + 1
		if upper_exit_tick < 0 and current_z <= upper_edge.z - 0.90:
			upper_exit_tick = tick_index + 1

		var inside_seam_band := (
			absf(current_z - lower_edge.z) <= 1.10
			or absf(current_z - upper_edge.z) <= 1.10
		)
		if inside_seam_band:
			if not player.is_on_floor():
				seam_airborne_ticks += 1
			if forward_progress < 0.01:
				consecutive_stall_ticks += 1
				maximum_stall_ticks = maxi(maximum_stall_ticks, consecutive_stall_ticks)
			else:
				consecutive_stall_ticks = 0
		else:
			consecutive_stall_ticks = 0

		if player.global_position.y < -0.12:
			fell_through = true
			break
	Input.action_release(&"move_forward")

	var lower_cross_ticks := (
		lower_exit_tick - lower_enter_tick
		if lower_enter_tick > 0 and lower_exit_tick > 0
		else -1
	)
	var upper_cross_ticks := (
		upper_exit_tick - upper_enter_tick
		if upper_enter_tick > 0 and upper_exit_tick > 0
		else -1
	)
	var expected_deck_height := 3.35
	var final_speed := _horizontal_speed(player)
	var step_up_count := int(player.call("get_step_up_count"))
	var passed := (
		not fell_through
		and lower_cross_ticks >= 0
		and lower_cross_ticks <= 36
		and upper_cross_ticks >= 0
		and upper_cross_ticks <= 36
		and maximum_stall_ticks <= 6
		and seam_airborne_ticks <= 8
		and step_up_count == 0
		and player.is_on_floor()
		and absf(player.global_position.y - expected_deck_height) <= 0.10
		and player.global_position.z < upper_edge.z - 1.0
		and final_speed >= 12.4
		and final_speed <= 13.4
	)
	var detail := (
		"lower=%d ticks, upper=%d ticks, max_stall=%d, air=%d, steps=%d, final=(y=%.3f,z=%.3f,speed=%.3f)."
		% [
			lower_cross_ticks,
			upper_cross_ticks,
			maximum_stall_ticks,
			seam_airborne_ticks,
			step_up_count,
			player.global_position.y,
			player.global_position.z,
			final_speed,
		]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_curb_step_up_once() -> Dictionary:
	var world := _new_case_world("CurbStepUpOnce")
	_create_box_collider(world, "Approach", Vector3(0.0, -0.5, 3.0), Vector3(8.0, 1.0, 6.0))
	_create_box_collider(world, "RaisedDeck", Vector3(0.0, -0.30, -3.0), Vector3(8.0, 1.0, 6.0))
	var player := _spawn_player(world, Vector3(0.0, 4.0, 3.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"move_forward")
	for _tick_index in range(65):
		await _step_physics()
	Input.action_release(&"move_forward")

	var step_up_count := int(player.call("get_step_up_count"))
	var passed := (
		step_up_count == 1
		and player.is_on_floor()
		and absf(player.global_position.y - 0.20) <= 0.06
		and player.global_position.z < -1.0
		and player.global_position.z > -5.5
		and _horizontal_speed(player) >= 12.7
	)
	var detail := (
		"steps=%d, final=(y=%.3f,z=%.3f,speed=%.3f)."
		% [step_up_count, player.global_position.y, player.global_position.z, _horizontal_speed(player)]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_falling_wall_slide_limits_fall() -> Dictionary:
	var world := _new_case_world("FallingWallSlideLimitsFall")
	_create_box_collider(world, "Wall", Vector3(0.0, 6.0, -3.0), Vector3(8.0, 24.0, 0.5))
	var wall_player := _spawn_player(
		world,
		Vector3(0.0, 10.0, 0.0),
		Vector3(0.0, -12.0, -13.0)
	)
	wall_player.name = "WallPlayer"
	var free_player := _spawn_player(
		world,
		Vector3(6.0, 10.0, 0.0),
		Vector3(0.0, -12.0, -13.0)
	)
	free_player.name = "FreeFallControl"

	Input.action_press(&"move_forward")
	var entered_tick := -1
	for tick_index in range(48):
		await _step_physics()
		if bool(wall_player.call("is_wall_sliding")):
			entered_tick = tick_index + 1
			break
	if entered_tick < 0:
		Input.action_release(&"move_forward")
		return await _finish_case(
			world,
			_result(false, "Wall slide did not engage within 48 physics ticks.")
		)

	var wall_slide_ticks := 0
	for _tick_index in range(32):
		await _step_physics()
		if bool(wall_player.call("is_wall_sliding")):
			wall_slide_ticks += 1
	Input.action_release(&"move_forward")

	var wall_fall_speed := wall_player.velocity.y
	var free_fall_speed := free_player.velocity.y
	var configured_limit := float(wall_player.get("wall_slide_fall_speed"))
	var height_advantage := wall_player.global_position.y - free_player.global_position.y
	var passed := (
		wall_slide_ticks >= 28
		and not bool(free_player.call("is_wall_sliding"))
		and wall_fall_speed < -0.5
		and wall_fall_speed >= configured_limit - 0.35
		and wall_fall_speed - free_fall_speed >= 5.0
		and height_advantage >= 0.25
	)
	var detail := (
		"entered=%d, active=%d/32, wall_vy=%.3f, free_vy=%.3f, limit=%.3f, height_gain=%.3f."
		% [
			entered_tick,
			wall_slide_ticks,
			wall_fall_speed,
			free_fall_speed,
			configured_limit,
			height_advantage,
		]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_wall_slide_duration_requires_separation() -> Dictionary:
	var world := _new_case_world("WallSlideDurationRequiresSeparation")
	_create_box_collider(world, "Wall", Vector3(0.0, 6.0, -3.0), Vector3(8.0, 24.0, 0.5))
	var player := _spawn_player(
		world,
		Vector3(0.0, 10.0, 0.0),
		Vector3(0.0, -8.0, -13.0)
	)
	player.set("wall_slide_max_duration", 0.12)
	Input.action_press(&"move_forward")

	var entered := false
	for _tick_index in range(48):
		await _step_physics()
		if bool(player.call("is_wall_sliding")):
			entered = true
			break
	if not entered:
		Input.action_release(&"move_forward")
		return await _finish_case(world, _result(false, "Short wall slide never engaged."))

	var expired := false
	var physical_contact_at_expiry := false
	for _tick_index in range(30):
		await _step_physics()
		if not bool(player.call("is_wall_sliding")):
			expired = true
			physical_contact_at_expiry = player.is_on_wall()
			break

	var reentered_same_wall := false
	for _tick_index in range(24):
		await _step_physics()
		reentered_same_wall = reentered_same_wall or bool(player.call("is_wall_sliding"))
	Input.action_release(&"move_forward")

	var passed := entered and expired and physical_contact_at_expiry and not reentered_same_wall
	var detail := (
		"entered=%s, expired=%s, contact=%s, same-wall reentry=%s."
		% [entered, expired, physical_contact_at_expiry, reentered_same_wall]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_low_tap_near_wall_has_no_free_kick() -> Dictionary:
	var world := _new_case_world("LowTapNearWallHasNoFreeKick")
	_create_box_collider(world, "Wall", Vector3(0.0, 6.0, -3.0), Vector3(8.0, 24.0, 0.5))
	var player := _spawn_player(
		world,
		Vector3(0.0, 10.0, -2.20),
		Vector3(0.0, -4.0, 0.0)
	)
	var start_position := player.global_position
	Input.action_press(&"crouch")
	await _step_physics()
	Input.action_release(&"crouch")

	var horizontal_speed := _horizontal_speed(player)
	var horizontal_displacement := Vector2(
		player.global_position.x - start_position.x,
		player.global_position.z - start_position.z
	).length()
	var passed := (
		not bool(player.call("is_wall_sliding"))
		and not player.is_on_wall()
		and horizontal_speed <= 0.10
		and horizontal_displacement <= 0.01
	)
	var detail := (
		"wall_sliding=%s, physical=%s, horizontal=%.3f m/s, displacement=%.4f m."
		% [player.call("is_wall_sliding"), player.is_on_wall(), horizontal_speed, horizontal_displacement]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_probe_wall_detach_has_no_free_kick() -> Dictionary:
	var world := _new_case_world("ProbeWallDetachHasNoFreeKick")
	_create_box_collider(world, "Wall", Vector3(0.0, 6.0, -3.0), Vector3(8.0, 24.0, 0.5))
	var player := _spawn_player(
		world,
		Vector3(0.0, 10.0, -2.20),
		Vector3(0.0, -4.0, 0.0)
	)
	await _step_physics()
	var probe_state_started := bool(player.call("is_wall_sliding"))
	var physical_before_detach := player.is_on_wall()
	var wall_normal: Vector3 = player.call("get_wall_slide_normal")
	var detach_position := player.global_position

	Input.action_press(&"crouch")
	await _step_physics()
	Input.action_release(&"crouch")
	var horizontal_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var outward_speed := horizontal_velocity.dot(wall_normal)
	var outward_displacement := (player.global_position - detach_position).dot(wall_normal)
	var passed := (
		probe_state_started
		and not physical_before_detach
		and not bool(player.call("is_wall_sliding"))
		and not player.is_on_wall()
		and outward_speed <= 0.10
		and outward_displacement <= 0.01
	)
	var detail := (
		"probe_started=%s, physical_before=%s, outward_v=%.3f, displacement=%.4f."
		% [probe_state_started, physical_before_detach, outward_speed, outward_displacement]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_wall_slide_detach(low_action: StringName) -> Dictionary:
	var world := _new_case_world("WallSlideDetach_%s" % low_action)
	_create_box_collider(world, "Wall", Vector3(0.0, 6.0, -3.0), Vector3(8.0, 24.0, 0.5))
	var player := _spawn_player(
		world,
		Vector3(0.0, 10.0, 0.0),
		Vector3(0.0, -8.0, -13.0)
	)
	Input.action_press(&"move_forward")
	var entered := false
	for _tick_index in range(48):
		await _step_physics()
		if bool(player.call("is_wall_sliding")):
			entered = true
			break
	if not entered:
		Input.action_release(&"move_forward")
		return await _finish_case(
			world,
			_result(false, "Wall slide did not engage before %s detach." % low_action)
		)

	# The radial probe starts the state just before physical contact. Wait for the
	# latest move_and_slide() result so the detach assertion covers real contact.
	var made_physical_contact := player.is_on_wall()
	for _tick_index in range(18):
		if made_physical_contact:
			break
		await _step_physics()
		made_physical_contact = player.is_on_wall()
	if not made_physical_contact or not bool(player.call("is_wall_sliding")):
		Input.action_release(&"move_forward")
		return await _finish_case(
			world,
			_result(false, "No stable physical wall contact before %s detach." % low_action)
		)
	var wall_normal: Vector3 = player.call("get_wall_slide_normal")
	var contact_position := player.global_position
	Input.action_press(low_action)
	await _step_physics()

	var outward_velocity := Vector3(player.velocity.x, 0.0, player.velocity.z).dot(wall_normal)
	var outward_displacement := (player.global_position - contact_position).dot(wall_normal)
	var detached := not bool(player.call("is_wall_sliding")) and not player.is_on_wall()
	Input.action_release(low_action)
	Input.action_release(&"move_forward")

	var passed := (
		detached
		and not wall_normal.is_zero_approx()
		and wall_normal.dot(Vector3.BACK) > 0.98
		and outward_velocity >= 2.0
		and outward_displacement >= 0.01
	)
	var detail := (
		"action=%s detached=%s normal=%s outward_v=%.3f displacement=%.3f."
		% [low_action, detached, wall_normal, outward_velocity, outward_displacement]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_buffered_wall_jump() -> Dictionary:
	var world := _new_case_world("BufferedWallJump")
	_create_box_collider(world, "Wall", Vector3(0.0, 6.0, -3.0), Vector3(8.0, 24.0, 0.5))
	var player := _spawn_player(
		world,
		Vector3(0.0, 10.0, 0.0),
		Vector3(0.0, -4.0, -13.0)
	)
	Input.action_press(&"move_forward")

	var reached_buffer_point := false
	for _tick_index in range(24):
		await _step_physics()
		if player.global_position.z <= -1.25:
			reached_buffer_point = true
			break
	if not reached_buffer_point or bool(player.call("is_wall_sliding")):
		Input.action_release(&"move_forward")
		return await _finish_case(
			world,
			_result(
				false,
				"Invalid pre-buffer point z=%.3f (wall_sliding=%s)."
				% [player.global_position.z, player.call("is_wall_sliding")]
			)
		)

	Input.action_press(&"jump")
	await _step_physics()
	Input.action_release(&"jump")
	var jumped_on_press_tick := player.velocity.y > 0.0
	var trigger_tick := -1
	var trigger_position := Vector3.ZERO
	var horizontal_at_trigger := Vector3.ZERO
	var vertical_at_trigger := 0.0
	var buffer_ticks := ceili(
		float(player.get("jump_buffer_time")) * float(REQUIRED_PHYSICS_TICKS_PER_SECOND)
	) + 2
	for tick_index in range(buffer_ticks):
		await _step_physics()
		if player.velocity.y > 0.5:
			trigger_tick = tick_index + 1
			trigger_position = player.global_position
			horizontal_at_trigger = Vector3(player.velocity.x, 0.0, player.velocity.z)
			vertical_at_trigger = player.velocity.y
			break
	Input.action_release(&"move_forward")

	var expected_normal := Vector3.BACK
	var outward_speed := horizontal_at_trigger.dot(expected_normal)
	var configured_outward := float(player.get("wall_jump_outward_speed"))
	var configured_vertical := float(player.get("wall_jump_vertical_speed"))
	var passed := (
		not jumped_on_press_tick
		and trigger_tick >= 4
		and trigger_tick <= buffer_ticks
		and trigger_position.z <= -1.45
		and outward_speed >= configured_outward - 0.60
		and vertical_at_trigger >= configured_vertical - 0.25
		and not bool(player.call("is_wall_sliding"))
		and not player.is_on_floor()
	)
	var detail := (
		"early=%s, trigger=%d/%d, pos=%s, outward=%.3f/%.3f, vertical=%.3f/%.3f."
		% [
			jumped_on_press_tick,
			trigger_tick,
			buffer_ticks,
			trigger_position,
			outward_speed,
			configured_outward,
			vertical_at_trigger,
			configured_vertical,
		]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_platform_edge_to_recovery() -> Dictionary:
	var world := _new_case_world("PlatformEdgeToRecovery")
	_create_box_collider(world, "Platform", Vector3(0.0, -0.5, 0.0), Vector3(8.0, 1.0, 12.0))
	_create_box_collider(world, "Recovery", Vector3(8.0, -4.5, 0.0), Vector3(40.0, 1.0, 30.0))
	var player := _spawn_player(world, Vector3(1.0, 4.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	if not bool(landing["passed"]):
		return await _finish_case(world, landing)

	Input.action_press(&"move_right")
	var saw_airborne := false
	var reached_below_top := false
	var recovery_landed := false
	var first_airborne_x := INF
	for _tick_index in range(180):
		await _step_physics()
		if player.global_position.y < -4.15:
			break
		if not player.is_on_floor() and player.global_position.x >= 3.8:
			if not saw_airborne:
				first_airborne_x = player.global_position.x
			saw_airborne = true
		if player.global_position.y < -0.15:
			reached_below_top = true
		if saw_airborne \
				and player.is_on_floor() \
				and absf(player.global_position.y + 4.0) <= LANDING_HEIGHT_TOLERANCE:
			recovery_landed = true
			break
	Input.action_release(&"move_right")

	var passed := (
		saw_airborne
		and reached_below_top
		and recovery_landed
		and first_airborne_x >= 3.8
		and first_airborne_x <= 4.9
	)
	var detail := (
		"first_air_x=%.3f, final=(x=%.3f,y=%.3f), recovered=%s."
		% [first_airborne_x, player.global_position.x, player.global_position.y, recovery_landed]
	)
	return await _finish_case(world, _result(passed, detail))


func _test_stacked_floor_stops_first_fall() -> Dictionary:
	var world := _new_case_world("StackedFloorStopsFirstFall")
	_create_box_collider(world, "LowerRecoveryFloor", Vector3(0.0, -0.5, 0.0), Vector3(14.0, 1.0, 14.0))
	_create_box_collider(world, "UpperFloor", Vector3(0.0, 5.5, 0.0), Vector3(14.0, 1.0, 14.0))
	var player := _spawn_player(world, Vector3(0.0, 12.0, 0.0), Vector3(0.0, -20.0, 0.0))
	var landing := await _wait_for_landing(player, 6.0, 5.85, 360)
	return await _finish_case(world, landing)


func _test_lower_recovery_floor() -> Dictionary:
	var world := _new_case_world("LowerRecoveryFloor")
	_create_box_collider(world, "LowerFloor", Vector3(0.0, -0.5, 0.0), Vector3(14.0, 1.0, 14.0))
	_create_box_collider(world, "UpperFloor", Vector3(0.0, 5.5, 0.0), Vector3(14.0, 1.0, 14.0))
	var player := _spawn_player(world, Vector3(0.0, 3.0, 0.0), Vector3(0.0, -15.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 360)
	return await _finish_case(world, landing)


func _test_fast_fall_does_not_tunnel() -> Dictionary:
	var world := _new_case_world("FastFallDoesNotTunnel")
	_create_box_collider(world, "ThinFloor", Vector3(0.0, -0.15, 0.0), Vector3(20.0, 0.3, 20.0))
	var player := _spawn_player(world, Vector3(0.0, 15.0, 0.0), Vector3(0.0, -120.0, 0.0))
	var landing := await _wait_for_landing(player, 0.0, -0.10, 240)
	return await _finish_case(world, landing)


func _new_case_world(case_name: String) -> Node3D:
	_release_test_inputs()
	var world := Node3D.new()
	world.name = case_name
	add_child(world)
	return world


func _instantiate_course(parent: Node3D) -> Node3D:
	var course_script := load(COURSE_SCRIPT_PATH) as Script
	if course_script == null:
		return null
	var instance: Object = course_script.new()
	if not instance is Node3D:
		instance.free()
		return null
	var course := instance as Node3D
	parent.add_child(course)
	return course


func _create_box_collider(
		parent: Node3D,
		body_name: String,
		center: Vector3,
		size: Vector3,
		rotation_radians: Vector3 = Vector3.ZERO
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = center
	body.rotation = rotation_radians
	body.collision_layer = WORLD_LAYER
	body.collision_mask = PLAYER_LAYER

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	parent.add_child(body)
	return body


func _spawn_player(
		parent: Node3D,
		spawn_position: Vector3,
		initial_velocity: Vector3 = Vector3.ZERO
	) -> CharacterBody3D:
	var player := _player_scene.instantiate() as CharacterBody3D
	player.name = "PlayerUnderTest"
	player.position = spawn_position
	player.velocity = initial_velocity
	player.set("capture_mouse_on_ready", false)
	parent.add_child(player)
	return player


func _wait_for_landing(
		player: CharacterBody3D,
		expected_foot_y: float,
		failure_y: float,
		max_ticks: int
	) -> Dictionary:
	var stable_ticks := 0
	var minimum_y := player.global_position.y
	for tick_index in range(max_ticks):
		await _step_physics()
		if not is_instance_valid(player):
			return _result(false, "Player was freed during the test.")

		minimum_y = minf(minimum_y, player.global_position.y)
		if player.global_position.y < failure_y:
			return _result(
				false,
				"Crossed expected surface after %d ticks (y=%.3f, limit=%.3f, velocity=%s)."
				% [tick_index + 1, player.global_position.y, failure_y, player.velocity]
			)

		if player.is_on_floor():
			if absf(player.global_position.y - expected_foot_y) > LANDING_HEIGHT_TOLERANCE:
				return _result(
					false,
					"Grounded at wrong height y=%.3f; expected %.3f ± %.3f."
					% [player.global_position.y, expected_foot_y, LANDING_HEIGHT_TOLERANCE]
				)
			stable_ticks += 1
			if stable_ticks >= LANDING_STABILITY_TICKS:
				return _result(
					true,
					"Landed after %d ticks at y=%.3f (minimum y=%.3f)."
					% [tick_index + 1, player.global_position.y, minimum_y]
				)
		else:
			stable_ticks = 0

	return _result(
		false,
		"No stable landing within %d ticks (minimum y=%.3f, final y=%.3f, velocity=%s)."
		% [max_ticks, minimum_y, player.global_position.y, player.velocity]
	)


func _step_physics() -> void:
	await _post_physics_probe.step_finished


func _horizontal_speed(player: CharacterBody3D) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _release_test_inputs() -> void:
	for action in INPUT_ACTIONS:
		Input.action_release(action)


func _finish_case(world: Node3D, result: Dictionary) -> Dictionary:
	_release_test_inputs()
	await _step_physics()
	world.queue_free()
	await _step_physics()
	return result


func _result(passed: bool, detail: String) -> Dictionary:
	return {"passed": passed, "detail": detail}


func _record(case_name: String, result: Dictionary) -> void:
	var detail := String(result.get("detail", "No details supplied."))
	if bool(result.get("passed", false)):
		_passes += 1
		print("[REGRESSION] PASS %-38s %s" % [case_name, detail])
	else:
		_failures.append("%s: %s" % [case_name, detail])
		printerr("[REGRESSION] FAIL %-38s %s" % [case_name, detail])


func _setup_failed(message: String) -> void:
	printerr("[REGRESSION] SETUP FAILURE: %s" % message)
	get_tree().quit(EXIT_SETUP_FAILURE)
