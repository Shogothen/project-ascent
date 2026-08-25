class_name FirstPersonPlayer
extends CharacterBody3D

## A compact first-person movement controller for the movement alpha.
##
## The body origin stays at the player's feet. This makes spawning and resizing
## the capsule predictable and avoids moving the body itself while crouching.

const INPUT_MOVE_FORWARD: StringName = &"move_forward"
const INPUT_MOVE_BACKWARD: StringName = &"move_back"
const INPUT_MOVE_LEFT: StringName = &"move_left"
const INPUT_MOVE_RIGHT: StringName = &"move_right"
const INPUT_JUMP: StringName = &"jump"
const INPUT_CROUCH: StringName = &"crouch"
const INPUT_SLIDE: StringName = &"slide"
const INPUT_RELEASE_MOUSE: StringName = &"release_mouse"
const CLEARANCE_SKIN := 0.01

@export_category("Ground Movement")
@export_range(0.0, 30.0, 0.1) var move_speed: float = 13.0
@export_range(0.0, 300.0, 1.0) var ground_acceleration: float = 100.0
@export_range(0.0, 300.0, 1.0) var ground_turn_acceleration: float = 180.0
@export_range(0.0, 300.0, 1.0) var ground_deceleration: float = 140.0
@export_range(0.0, 100.0, 0.5) var air_acceleration: float = 20.0
@export_range(0.0, 20.0, 0.1) var jump_velocity: float = 6.5
@export_range(0.0, 3.0, 0.05) var gravity_multiplier: float = 1.0
@export_range(0.0, 0.5, 0.01) var coyote_time: float = 0.10
@export_range(0.0, 0.5, 0.01) var jump_buffer_time: float = 0.12

@export_category("Crouch")
@export_range(0.5, 2.5, 0.01) var standing_height: float = 1.80
@export_range(0.5, 2.5, 0.01) var crouching_height: float = 1.20
@export_range(0.1, 1.0, 0.01) var capsule_radius: float = 0.42
@export_range(0.1, 2.5, 0.01) var standing_eye_height: float = 1.62
@export_range(0.1, 2.5, 0.01) var crouching_eye_height: float = 1.02
@export_range(0.1, 20.0, 0.1) var stance_change_speed: float = 6.0
@export_range(0.0, 20.0, 0.1) var crouching_move_speed: float = 7.0

@export_category("Slide")
@export_range(0.0, 40.0, 0.1) var slide_start_speed: float = 16.0
@export_range(0.0, 30.0, 0.1) var slide_end_speed: float = 7.0
@export_range(0.0, 30.0, 0.1) var slide_friction: float = 5.5
@export_range(0.0, 5.0, 0.05) var slide_steering: float = 1.75
@export_range(0.0, 5.0, 0.05) var slide_slope_gravity_multiplier: float = 1.25

@export_category("Look")
@export_range(0.0001, 0.02, 0.0001) var mouse_sensitivity: float = 0.0020
@export_range(1.0, 89.9, 0.1) var maximum_look_angle: float = 89.0
@export var capture_mouse_on_ready: bool = true

@onready var _capsule_collider: CollisionShape3D = $CollisionShape3D
@onready var _head: Node3D = $Head

var _capsule_shape: CapsuleShape3D
var _gravity: float = 9.8
var _pitch: float = 0.0
var _current_height: float = standing_height
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _is_sliding: bool = false


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

	var source_shape: CapsuleShape3D = _capsule_collider.shape as CapsuleShape3D
	if source_shape == null:
		push_error("FirstPersonPlayer requires a CapsuleShape3D on CollisionShape3D.")
		set_physics_process(false)
		return

	# Each player owns its shape because crouching changes it at runtime.
	_capsule_shape = source_shape.duplicate() as CapsuleShape3D
	_capsule_collider.shape = _capsule_shape
	_validate_dimensions()
	_current_height = standing_height
	_apply_stance_geometry()
	_pitch = _head.rotation.x

	if capture_mouse_on_ready and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(INPUT_RELEASE_MOUSE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mouse_motion.relative.x * mouse_sensitivity)
		_pitch = clampf(
			_pitch - mouse_motion.relative.y * mouse_sensitivity,
			-deg_to_rad(maximum_look_angle),
			deg_to_rad(maximum_look_angle)
		)
		_head.rotation.x = _pitch
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var grounded: bool = is_on_floor()
	_update_jump_timers(delta, grounded)

	var input_vector: Vector2 = Input.get_vector(
		INPUT_MOVE_LEFT,
		INPUT_MOVE_RIGHT,
		INPUT_MOVE_FORWARD,
		INPUT_MOVE_BACKWARD
	)
	var wish_direction: Vector3 = _world_wish_direction(input_vector)

	_update_slide_state(grounded, wish_direction)
	_update_stance(delta)
	var jumped: bool = _try_jump()

	if _is_sliding:
		_move_slide(delta, grounded, wish_direction)
	elif grounded and not jumped:
		_move_ground(delta, wish_direction)
	else:
		_move_air(delta, wish_direction)

	if grounded and not jumped:
		# Floor snap and move_and_slide() handle the ramp component. Keeping a
		# neutral vertical velocity prevents accumulated gravity on floors.
		velocity.y = 0.0
	elif not jumped:
		velocity.y -= _gravity * gravity_multiplier * delta

	move_and_slide()


func is_sliding() -> bool:
	return _is_sliding


func is_crouched() -> bool:
	return _current_height < standing_height - 0.01


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _validate_dimensions() -> void:
	var minimum_capsule_height: float = capsule_radius * 2.0
	standing_height = maxf(standing_height, minimum_capsule_height)
	crouching_height = clampf(crouching_height, minimum_capsule_height, standing_height)
	standing_eye_height = clampf(standing_eye_height, capsule_radius, standing_height)
	crouching_eye_height = clampf(crouching_eye_height, capsule_radius, crouching_height)


func _world_wish_direction(input_vector: Vector2) -> Vector3:
	if input_vector.is_zero_approx():
		return Vector3.ZERO

	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction: Vector3 = global_transform.basis * local_direction
	world_direction.y = 0.0
	return world_direction.normalized()


func _update_jump_timers(delta: float, grounded: bool) -> void:
	if grounded:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

	if Input.is_action_just_pressed(INPUT_JUMP):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)


func _try_jump() -> bool:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return false

	velocity.y = jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_is_sliding = false
	return true


func _update_slide_state(grounded: bool, wish_direction: Vector3) -> void:
	if not _is_sliding and grounded and Input.is_action_just_pressed(INPUT_SLIDE):
		_begin_slide(wish_direction)

	if not _is_sliding:
		return

	var slide_is_held: bool = Input.is_action_pressed(INPUT_SLIDE)
	if not grounded or not slide_is_held or get_horizontal_speed() <= slide_end_speed:
		_is_sliding = false


func _begin_slide(wish_direction: Vector3) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = horizontal_velocity.length()
	var slide_direction: Vector3

	if current_speed > 0.01:
		slide_direction = horizontal_velocity / current_speed
	elif not wish_direction.is_zero_approx():
		slide_direction = wish_direction
	else:
		slide_direction = -global_transform.basis.z.normalized()

	# Starting a slide supplies the flat-ground launch speed, but never clamps
	# faster incoming momentum (for example after a steep downhill section).
	var initial_speed: float = maxf(current_speed, slide_start_speed)
	velocity.x = slide_direction.x * initial_speed
	velocity.z = slide_direction.z * initial_speed
	_is_sliding = true


func _move_ground(delta: float, wish_direction: Vector3) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var target_speed: float = crouching_move_speed if is_crouched() else move_speed

	if wish_direction.is_zero_approx():
		horizontal_velocity = horizontal_velocity.move_toward(
			Vector3.ZERO,
			ground_deceleration * delta
		)
	else:
		var target_velocity: Vector3 = wish_direction * target_speed
		var acceleration: float = ground_acceleration
		if (
			not horizontal_velocity.is_zero_approx()
			and horizontal_velocity.normalized().dot(wish_direction) < 0.0
		):
			acceleration = ground_turn_acceleration
		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			acceleration * delta
		)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _move_air(delta: float, wish_direction: Vector3) -> void:
	if wish_direction.is_zero_approx():
		return

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var speed_along_wish: float = horizontal_velocity.dot(wish_direction)
	var speed_available: float = move_speed - speed_along_wish
	if speed_available <= 0.0:
		return

	# Projection-based acceleration permits steering without silently clamping
	# horizontal momentum that is already above the regular running speed.
	var acceleration_step: float = minf(air_acceleration * delta, speed_available)
	horizontal_velocity += wish_direction * acceleration_step
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _move_slide(delta: float, grounded: bool, wish_direction: Vector3) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = horizontal_velocity.length()

	if current_speed > 0.01 and not wish_direction.is_zero_approx():
		var steer_weight: float = minf(slide_steering * delta, 1.0)
		var steered_direction: Vector3 = horizontal_velocity.normalized().lerp(
			wish_direction,
			steer_weight
		).normalized()
		horizontal_velocity = steered_direction * current_speed

	if grounded:
		var downhill: Vector3 = Vector3.DOWN.slide(get_floor_normal())
		var downhill_horizontal := Vector3(downhill.x, 0.0, downhill.z)
		horizontal_velocity += (
			downhill_horizontal
			* _gravity
			* slide_slope_gravity_multiplier
			* delta
		)

	horizontal_velocity = horizontal_velocity.move_toward(
		Vector3.ZERO,
		slide_friction * delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _update_stance(delta: float) -> void:
	var wants_low_stance: bool = (
		_is_sliding
		or Input.is_action_pressed(INPUT_CROUCH)
		or Input.is_action_pressed(INPUT_SLIDE)
	)
	var target_height: float = crouching_height

	if not wants_low_stance and _can_stand():
		target_height = standing_height

	_current_height = move_toward(_current_height, target_height, stance_change_speed * delta)
	_apply_stance_geometry()


func _apply_stance_geometry() -> void:
	if _capsule_shape == null:
		return

	_capsule_shape.radius = capsule_radius
	_capsule_shape.height = _current_height
	_capsule_collider.position.y = _current_height * 0.5

	var stance_range: float = standing_height - crouching_height
	var stance_weight: float = 1.0
	if stance_range > 0.001:
		stance_weight = (_current_height - crouching_height) / stance_range
	_head.position.y = lerpf(crouching_eye_height, standing_eye_height, stance_weight)


func _can_stand() -> bool:
	if _current_height >= standing_height - 0.01:
		return true

	if standing_height - crouching_height <= 0.01 or get_world_3d() == null:
		return true

	# Probe the complete standing capsule. A small skin keeps the supporting
	# floor and already-touching walls from becoming false ceiling hits while
	# still matching the capsule's rounded shoulders and crown.
	var clearance_shape := CapsuleShape3D.new()
	clearance_shape.radius = maxf(0.01, capsule_radius - CLEARANCE_SKIN)
	clearance_shape.height = maxf(
		clearance_shape.radius * 2.0,
		standing_height - CLEARANCE_SKIN * 2.0
	)

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = clearance_shape
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = 0.001
	var excluded_bodies: Array[RID] = [get_rid()]
	query.exclude = excluded_bodies

	query.transform = Transform3D(
		global_transform.basis,
		to_global(Vector3(0.0, standing_height * 0.5, 0.0))
	)
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
