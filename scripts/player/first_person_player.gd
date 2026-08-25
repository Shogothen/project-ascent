class_name FirstPersonPlayer
extends CharacterBody3D

## VHOLUME-inspired first-person movement prototype.
##
## The body origin stays at the player's feet. Ground, slide and wall movement
## are deliberately separate states so that momentum rules remain predictable.

const INPUT_MOVE_FORWARD: StringName = &"move_forward"
const INPUT_MOVE_BACKWARD: StringName = &"move_back"
const INPUT_MOVE_LEFT: StringName = &"move_left"
const INPUT_MOVE_RIGHT: StringName = &"move_right"
const INPUT_JUMP: StringName = &"jump"
const INPUT_CROUCH: StringName = &"crouch"
const INPUT_SLIDE: StringName = &"slide"
const INPUT_RELEASE_MOUSE: StringName = &"release_mouse"
const CLEARANCE_SKIN: float = 0.01

@export_category("Ground Movement")
@export_range(0.0, 30.0, 0.1) var move_speed: float = 13.0
@export_range(0.0, 500.0, 1.0) var ground_acceleration: float = 240.0
@export_range(0.0, 500.0, 1.0) var ground_turn_acceleration: float = 360.0
@export_range(0.0, 500.0, 1.0) var ground_deceleration: float = 300.0
@export_range(0.0, 20.0, 0.1) var high_speed_ground_drag: float = 1.5
@export_range(0.0, 30.0, 0.1) var high_speed_ground_steering: float = 7.0
@export_range(0.0, 100.0, 0.5) var air_acceleration: float = 20.0
@export_range(0.0, 20.0, 0.1) var jump_velocity: float = 6.2
@export_range(0.0, 30.0, 0.1) var run_jump_speed: float = 14.0
@export_range(0.0, 3.0, 0.05) var gravity_multiplier: float = 1.15
@export_range(0.0, 0.5, 0.01) var coyote_time: float = 0.10
@export_range(0.0, 0.5, 0.01) var jump_buffer_time: float = 0.12
@export_range(0.0, 0.5, 0.01) var maximum_step_height: float = 0.28

@export_category("Crouch")
@export_range(0.5, 2.5, 0.01) var standing_height: float = 1.80
@export_range(0.5, 2.5, 0.01) var crouching_height: float = 1.20
@export_range(0.1, 1.0, 0.01) var capsule_radius: float = 0.42
@export_range(0.1, 2.5, 0.01) var standing_eye_height: float = 1.62
@export_range(0.1, 2.5, 0.01) var crouching_eye_height: float = 1.02
@export_range(0.1, 20.0, 0.1) var stance_change_speed: float = 8.0
@export_range(0.0, 20.0, 0.1) var crouching_move_speed: float = 7.0

@export_category("Slide")
@export_range(0.0, 30.0, 0.1) var slide_min_entry_speed: float = 7.0
@export_range(0.0, 1.0, 0.05) var slide_forward_gate: float = 0.55
@export_range(0.0, 40.0, 0.1) var slide_start_speed: float = 16.0
@export_range(0.0, 40.0, 0.1) var slide_jump_speed: float = 17.0
@export_range(0.0, 10.0, 0.1) var slide_jump_vertical_speed: float = 5.2
@export_range(0.0, 10.0, 0.1) var slide_jump_chain_gain: float = 1.0
@export_range(0.0, 50.0, 0.1) var movement_chain_speed_cap: float = 27.0
@export_range(0.0, 1.0, 0.01) var slide_boost_duration: float = 0.16
@export_range(0.0, 300.0, 1.0) var slide_drive: float = 80.0
@export_range(0.0, 50.0, 0.1) var slide_friction: float = 18.0
@export_range(0.0, 20.0, 0.1) var slide_overspeed_drag: float = 1.5
@export_range(0.0, 500.0, 1.0) var slide_no_forward_brake: float = 300.0
@export_range(0.0, 30.0, 0.1) var slide_end_speed: float = 7.0
@export_range(0.0, 10.0, 0.05) var slide_steering: float = 2.6
@export_range(0.0, 5.0, 0.05) var slide_slope_gravity_multiplier: float = 1.25
@export_range(0.0, 0.5, 0.01) var slide_buffer_time: float = 0.12
@export_range(0.0, 0.5, 0.01) var slide_coyote_time: float = 0.08

@export_category("Wall Slide")
@export_range(-20.0, -0.1, 0.1) var wall_slide_fall_speed: float = -3.5
@export_range(0.0, 200.0, 1.0) var wall_slide_catch_acceleration: float = 55.0
@export_range(0.0, 10.0, 0.1) var wall_adhesion_speed: float = 2.0
@export_range(0.0, 5.0, 0.05) var wall_air_steering: float = 1.5
@export_range(0.0, 3.0, 0.05) var wall_slide_max_duration: float = 1.30
@export_range(0.0, 0.5, 0.01) var wall_lost_grace_time: float = 0.07
@export_range(0.0, 0.5, 0.01) var wall_regrab_lock_time: float = 0.16
@export_range(0.0, 20.0, 0.1) var wall_jump_outward_speed: float = 8.5
@export_range(0.0, 20.0, 0.1) var wall_jump_vertical_speed: float = 6.8
@export_range(0.0, 1.0, 0.01) var wall_jump_tangent_retention: float = 0.95
@export_range(0.0, 10.0, 0.1) var wall_detach_speed: float = 2.5
@export_range(0.0, 0.5, 0.01) var wall_probe_reach: float = 0.18

@export_category("Look and Feedback")
@export_range(0.0001, 0.02, 0.0001) var mouse_sensitivity: float = 0.0020
@export_range(1.0, 89.9, 0.1) var maximum_look_angle: float = 89.0
@export_range(60.0, 130.0, 0.5) var base_fov: float = 104.0
@export_range(60.0, 140.0, 0.5) var speed_fov: float = 112.0
@export_range(0.0, 30.0, 0.5) var camera_response: float = 10.0
@export_range(0.0, 10.0, 0.1) var strafe_tilt_degrees: float = 1.5
@export_range(0.0, 15.0, 0.1) var wall_tilt_degrees: float = 4.0
@export var capture_mouse_on_ready: bool = true

@onready var _capsule_collider: CollisionShape3D = $CollisionShape3D
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D

var _capsule_shape: CapsuleShape3D
var _gravity: float = 9.8
var _pitch: float = 0.0
var _current_height: float = standing_height
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _slide_buffer_timer: float = 0.0
var _slide_coyote_timer: float = 0.0
var _slide_elapsed: float = 0.0
var _slide_rearm_ready: bool = true
var _is_sliding: bool = false
var _is_slide_braking: bool = false
var _is_wall_sliding: bool = false
var _wall_normal: Vector3 = Vector3.ZERO
var _blocked_wall_normal: Vector3 = Vector3.ZERO
var _wall_requires_separation: bool = false
var _wall_lost_timer: float = 0.0
var _wall_regrab_timer: float = 0.0
var _wall_slide_elapsed: float = 0.0
var _last_input_vector: Vector2 = Vector2.ZERO
var _step_up_count: int = 0


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

	var source_shape: CapsuleShape3D = _capsule_collider.shape as CapsuleShape3D
	if source_shape == null:
		push_error("FirstPersonPlayer requires a CapsuleShape3D on CollisionShape3D.")
		set_physics_process(false)
		return

	_capsule_shape = source_shape.duplicate() as CapsuleShape3D
	_capsule_collider.shape = _capsule_shape
	_validate_dimensions()
	_current_height = standing_height
	_apply_stance_geometry()
	_pitch = _head.rotation.x
	_camera.fov = base_fov

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
	var grounded_before: bool = is_on_floor()
	var low_pressed: bool = _is_low_action_pressed()
	var low_just_pressed: bool = _is_low_action_just_pressed()
	var slide_pressed: bool = Input.is_action_pressed(INPUT_SLIDE)
	var slide_just_pressed: bool = Input.is_action_just_pressed(INPUT_SLIDE)
	if not slide_pressed:
		_slide_rearm_ready = true

	_last_input_vector = Input.get_vector(
		INPUT_MOVE_LEFT,
		INPUT_MOVE_RIGHT,
		INPUT_MOVE_FORWARD,
		INPUT_MOVE_BACKWARD
	)
	var wish_direction: Vector3 = _world_wish_direction(_last_input_vector)
	var forward_strength: float = maxf(0.0, -_last_input_vector.y)

	_update_timers(delta, grounded_before, slide_just_pressed)
	var nearby_wall_normal: Vector3 = _find_nearby_wall_normal()
	_update_wall_slide_state(
		delta,
		grounded_before,
		low_just_pressed,
		nearby_wall_normal
	)
	_update_ground_slide_state(
		grounded_before,
		wish_direction,
		forward_strength,
		slide_pressed
	)
	_update_stance(delta, low_pressed)

	var jumped: bool = _try_jump(grounded_before, wish_direction)
	if _is_sliding:
		_move_ground_slide(delta, grounded_before, wish_direction)
	elif _is_wall_sliding:
		_move_wall_slide(delta, wish_direction)
	elif _is_slide_braking and grounded_before and not jumped:
		_move_slide_brake(delta)
	elif grounded_before and not jumped:
		_move_ground(delta, wish_direction)
	else:
		_move_air(delta, wish_direction)

	if grounded_before and not jumped:
		velocity.y = 0.0
	elif _is_wall_sliding and not jumped:
		velocity.y = move_toward(
			velocity.y,
			wall_slide_fall_speed,
			wall_slide_catch_acceleration * delta
		)
	elif not jumped:
		velocity.y -= _gravity * gravity_multiplier * delta

	_prepare_step_up(delta, grounded_before, wish_direction)
	move_and_slide()
	_update_camera_feedback(delta)


func is_sliding() -> bool:
	return _is_sliding


func is_wall_sliding() -> bool:
	return _is_wall_sliding


func get_wall_slide_normal() -> Vector3:
	return _wall_normal


func is_crouched() -> bool:
	return _current_height < standing_height - 0.01


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func get_step_up_count() -> int:
	return _step_up_count


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


func _is_low_action_pressed() -> bool:
	return Input.is_action_pressed(INPUT_CROUCH) or Input.is_action_pressed(INPUT_SLIDE)


func _is_low_action_just_pressed() -> bool:
	return (
		Input.is_action_just_pressed(INPUT_CROUCH)
		or Input.is_action_just_pressed(INPUT_SLIDE)
	)


func _update_timers(delta: float, grounded: bool, slide_just_pressed: bool) -> void:
	if grounded:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

	if Input.is_action_just_pressed(INPUT_JUMP):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)

	if slide_just_pressed:
		_slide_buffer_timer = slide_buffer_time
	else:
		_slide_buffer_timer = maxf(0.0, _slide_buffer_timer - delta)

	_wall_regrab_timer = maxf(0.0, _wall_regrab_timer - delta)
	_slide_coyote_timer = maxf(0.0, _slide_coyote_timer - delta)


func _try_jump(grounded: bool, wish_direction: Vector3) -> bool:
	if _jump_buffer_timer <= 0.0:
		return false

	if _is_wall_sliding:
		_apply_wall_jump()
		return true

	if not grounded and _coyote_timer <= 0.0:
		return false

	if _is_sliding or _slide_coyote_timer > 0.0:
		_apply_slide_jump(wish_direction)
	else:
		_apply_ground_jump(wish_direction)

	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_slide_coyote_timer = 0.0
	_is_sliding = false
	_is_slide_braking = false
	return true


func _apply_ground_jump(wish_direction: Vector3) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = horizontal_velocity.length()
	if not wish_direction.is_zero_approx():
		var launch_speed: float = maxf(current_speed, run_jump_speed)
		horizontal_velocity = wish_direction * launch_speed
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	velocity.y = jump_velocity


func _apply_slide_jump(wish_direction: Vector3) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = horizontal_velocity.length()
	var launch_direction: Vector3 = horizontal_velocity.normalized()
	if launch_direction.is_zero_approx():
		launch_direction = wish_direction
	if launch_direction.is_zero_approx():
		launch_direction = -global_transform.basis.z.normalized()

	var launch_speed: float = current_speed
	if current_speed <= movement_chain_speed_cap:
		launch_speed = minf(
			movement_chain_speed_cap,
			maxf(slide_jump_speed, current_speed + slide_jump_chain_gain)
		)
	horizontal_velocity = launch_direction * launch_speed
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	velocity.y = slide_jump_vertical_speed


func _apply_wall_jump() -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var tangent_velocity: Vector3 = horizontal_velocity.slide(_wall_normal)
	var launch_velocity: Vector3 = (
		tangent_velocity * wall_jump_tangent_retention
		+ _wall_normal * wall_jump_outward_speed
	)
	velocity.x = launch_velocity.x
	velocity.z = launch_velocity.z
	velocity.y = wall_jump_vertical_speed
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_is_wall_sliding = false
	_wall_lost_timer = 0.0
	_wall_regrab_timer = wall_regrab_lock_time
	_blocked_wall_normal = _wall_normal
	_wall_requires_separation = false
	_is_slide_braking = false


func _update_ground_slide_state(
		grounded: bool,
		wish_direction: Vector3,
		forward_strength: float,
		slide_pressed: bool
	) -> void:
	if _is_slide_braking and (
		not grounded
		or forward_strength >= slide_forward_gate
		or get_horizontal_speed() <= 0.5
	):
		_is_slide_braking = false

	if _is_sliding:
		if not grounded:
			_slide_coyote_timer = slide_coyote_time
			_is_sliding = false
		elif forward_strength < slide_forward_gate:
			_is_sliding = false
			_is_slide_braking = true
		elif _slide_elapsed >= slide_boost_duration and get_horizontal_speed() <= slide_end_speed:
			_is_sliding = false
		return

	if (
		grounded
		and not _is_wall_sliding
		and _slide_rearm_ready
		and (_slide_buffer_timer > 0.0 or slide_pressed)
		and forward_strength >= slide_forward_gate
		and get_horizontal_speed() >= slide_min_entry_speed
	):
		_begin_slide(wish_direction)


func _begin_slide(wish_direction: Vector3) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = horizontal_velocity.length()
	var slide_direction: Vector3 = horizontal_velocity.normalized()
	if current_speed <= slide_start_speed + 0.5 and not wish_direction.is_zero_approx():
		slide_direction = wish_direction
	if slide_direction.is_zero_approx():
		slide_direction = -global_transform.basis.z.normalized()

	var initial_speed: float = maxf(current_speed, slide_start_speed)
	velocity.x = slide_direction.x * initial_speed
	velocity.z = slide_direction.z * initial_speed
	_is_sliding = true
	_is_slide_braking = false
	_slide_elapsed = 0.0
	_slide_coyote_timer = 0.0
	_slide_buffer_timer = 0.0
	_slide_rearm_ready = false


func _move_ground(delta: float, wish_direction: Vector3) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var target_speed: float = crouching_move_speed if is_crouched() else move_speed
	var current_speed: float = horizontal_velocity.length()

	if wish_direction.is_zero_approx():
		horizontal_velocity = horizontal_velocity.move_toward(
			Vector3.ZERO,
			ground_deceleration * delta
		)
	elif current_speed > target_speed + 0.05:
		var steer_weight: float = minf(high_speed_ground_steering * delta, 1.0)
		var steered_direction: Vector3 = horizontal_velocity.normalized().lerp(
			wish_direction,
			steer_weight
		).normalized()
		var retained_speed: float = maxf(
			target_speed,
			current_speed - high_speed_ground_drag * delta
		)
		horizontal_velocity = steered_direction * retained_speed
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

	var acceleration_step: float = minf(air_acceleration * delta, speed_available)
	horizontal_velocity += wish_direction * acceleration_step
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _move_ground_slide(delta: float, grounded: bool, wish_direction: Vector3) -> void:
	_slide_elapsed += delta
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

	current_speed = horizontal_velocity.length()
	if _slide_elapsed <= slide_boost_duration and current_speed < slide_start_speed:
		horizontal_velocity = horizontal_velocity.normalized() * minf(
			slide_start_speed,
			current_speed + slide_drive * delta
		)
	elif current_speed > slide_start_speed:
		horizontal_velocity = horizontal_velocity.move_toward(
			Vector3.ZERO,
			slide_overspeed_drag * delta
		)
	elif _slide_elapsed > slide_boost_duration:
		horizontal_velocity = horizontal_velocity.move_toward(
			Vector3.ZERO,
			slide_friction * delta
		)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _move_slide_brake(delta: float) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		Vector3.ZERO,
		slide_no_forward_brake * delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _update_wall_slide_state(
		delta: float,
		grounded: bool,
		low_just_pressed: bool,
		nearby_wall_normal: Vector3
	) -> void:
	if grounded:
		_is_wall_sliding = false
		_wall_lost_timer = 0.0
		_wall_slide_elapsed = 0.0
		_blocked_wall_normal = Vector3.ZERO
		_wall_requires_separation = false
		return

	if _is_wall_sliding:
		if low_just_pressed:
			_detach_from_wall()
			return

		_wall_slide_elapsed += delta
		if not nearby_wall_normal.is_zero_approx():
			_wall_normal = nearby_wall_normal
			_wall_lost_timer = wall_lost_grace_time
		else:
			_wall_lost_timer = maxf(0.0, _wall_lost_timer - delta)

		if velocity.y > 0.2 or _wall_lost_timer <= 0.0:
			_is_wall_sliding = false
		elif _wall_slide_elapsed >= wall_slide_max_duration:
			_is_wall_sliding = false
			_blocked_wall_normal = _wall_normal
			_wall_requires_separation = true
			_wall_regrab_timer = wall_regrab_lock_time
		return

	var wall_candidate_is_blocked: bool = _is_wall_candidate_blocked(nearby_wall_normal)
	if (
		not low_just_pressed
		and velocity.y <= -0.5
		and not nearby_wall_normal.is_zero_approx()
		and not wall_candidate_is_blocked
		and _can_attach_to_wall(nearby_wall_normal)
	):
		_is_wall_sliding = true
		_wall_normal = nearby_wall_normal
		_wall_lost_timer = wall_lost_grace_time
		_wall_slide_elapsed = 0.0
		_is_sliding = false


func _detach_from_wall() -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if is_on_wall():
		horizontal_velocity = (
			horizontal_velocity.slide(_wall_normal)
			+ _wall_normal * wall_detach_speed
		)
	else:
		# Radial probes can prime a wall-slide just before contact. Cancelling that
		# preview must not become a free air kick.
		horizontal_velocity = horizontal_velocity.slide(_wall_normal)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	_is_wall_sliding = false
	_wall_lost_timer = 0.0
	_wall_regrab_timer = wall_regrab_lock_time
	_blocked_wall_normal = _wall_normal
	_wall_requires_separation = false


func _is_wall_candidate_blocked(candidate_normal: Vector3) -> bool:
	if _blocked_wall_normal.is_zero_approx():
		return false

	if candidate_normal.is_zero_approx():
		if _wall_requires_separation or _wall_regrab_timer <= 0.0:
			_blocked_wall_normal = Vector3.ZERO
			_wall_requires_separation = false
		return false

	var is_same_wall: bool = candidate_normal.dot(_blocked_wall_normal) > 0.50
	if _wall_requires_separation:
		if not is_same_wall:
			_wall_requires_separation = false
			if _wall_regrab_timer <= 0.0:
				_blocked_wall_normal = Vector3.ZERO
			return false
		return true

	if _wall_regrab_timer <= 0.0:
		_blocked_wall_normal = Vector3.ZERO
		return false
	return is_same_wall


func _can_attach_to_wall(candidate_normal: Vector3) -> bool:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	return horizontal_velocity.dot(candidate_normal) <= 0.50


func _move_wall_slide(delta: float, wish_direction: Vector3) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var wall_tangent_velocity: Vector3 = horizontal_velocity.slide(_wall_normal)
	if not wish_direction.is_zero_approx():
		var tangent_wish: Vector3 = wish_direction.slide(_wall_normal)
		tangent_wish.y = 0.0
		if not tangent_wish.is_zero_approx():
			var current_tangent_speed: float = wall_tangent_velocity.length()
			var steer_weight: float = minf(wall_air_steering * delta, 1.0)
			var tangent_direction: Vector3 = wall_tangent_velocity.normalized().lerp(
				tangent_wish.normalized(),
				steer_weight
			).normalized()
			wall_tangent_velocity = tangent_direction * current_tangent_speed

	horizontal_velocity = wall_tangent_velocity - _wall_normal * wall_adhesion_speed
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _find_nearby_wall_normal() -> Vector3:
	if is_on_wall():
		var contact_normal: Vector3 = get_wall_normal()
		if _is_usable_wall_normal(contact_normal):
			return contact_normal.normalized()

	if get_world_3d() == null:
		return Vector3.ZERO

	var probe_origin: Vector3 = global_position + Vector3.UP * minf(0.85, _current_height * 0.55)
	var probe_distance: float = capsule_radius + wall_probe_reach
	var best_normal: Vector3 = Vector3.ZERO
	var best_distance: float = INF
	var excluded_bodies: Array[RID] = [get_rid()]

	for probe_index in range(8):
		var angle: float = TAU * float(probe_index) / 8.0
		var probe_direction := Vector3(cos(angle), 0.0, sin(angle))
		var ray_query := PhysicsRayQueryParameters3D.create(
			probe_origin,
			probe_origin + probe_direction * probe_distance,
			collision_mask
		)
		ray_query.exclude = excluded_bodies
		ray_query.collide_with_areas = false
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
		if hit.is_empty():
			continue
		var candidate_normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if not _is_usable_wall_normal(candidate_normal):
			continue
		var hit_position: Vector3 = hit.get("position", probe_origin)
		var hit_distance: float = probe_origin.distance_to(hit_position)
		if hit_distance < best_distance:
			best_distance = hit_distance
			best_normal = candidate_normal.normalized()

	return best_normal


func _is_valid_wall_normal(candidate_normal: Vector3) -> bool:
	return (
		not candidate_normal.is_zero_approx()
		and absf(candidate_normal.normalized().dot(Vector3.UP)) <= 0.20
	)


func _is_usable_wall_normal(candidate_normal: Vector3) -> bool:
	if not _is_valid_wall_normal(candidate_normal):
		return false
	return (
		not _is_wall_sliding
		or _wall_normal.is_zero_approx()
		or candidate_normal.normalized().dot(_wall_normal) >= 0.65
	)


func _prepare_step_up(delta: float, was_grounded: bool, wish_direction: Vector3) -> void:
	if (
		not was_grounded
		or wish_direction.is_zero_approx()
		or maximum_step_height <= 0.0
		or absf(velocity.y) > 0.1
	):
		return

	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if horizontal_motion.length_squared() < 0.000001:
		return
	var blocking_collision := KinematicCollision3D.new()
	if not test_move(
		global_transform,
		horizontal_motion,
		blocking_collision,
		safe_margin
	):
		return
	var blocking_normal: Vector3 = blocking_collision.get_normal()
	if blocking_normal.dot(up_direction) >= cos(floor_max_angle):
		return

	var upward_motion := Vector3.UP * maximum_step_height
	if test_move(global_transform, upward_motion, null, safe_margin):
		return
	var raised_transform := Transform3D(
		global_transform.basis,
		global_transform.origin + upward_motion
	)
	if test_move(raised_transform, horizontal_motion, null, safe_margin):
		return

	var landing_transform := Transform3D(
		global_transform.basis,
		raised_transform.origin + horizontal_motion
	)
	var landing_collision := KinematicCollision3D.new()
	var downward_motion: Vector3 = Vector3.DOWN * (maximum_step_height + floor_snap_length)
	if not test_move(
		landing_transform,
		downward_motion,
		landing_collision,
		safe_margin
	):
		return
	if landing_collision.get_normal().dot(up_direction) < cos(floor_max_angle):
		return

	var resolved_step_height: float = clampf(
		maximum_step_height + landing_collision.get_travel().y,
		0.0,
		maximum_step_height
	)
	if resolved_step_height <= safe_margin:
		return
	var resolved_step_transform := Transform3D(
		global_transform.basis,
		global_transform.origin + Vector3.UP * resolved_step_height
	)
	if test_move(resolved_step_transform, horizontal_motion, null, safe_margin):
		return
	global_position.y += resolved_step_height
	_step_up_count += 1


func _update_stance(delta: float, low_pressed: bool) -> void:
	var wants_low_stance: bool = _is_sliding or _is_slide_braking or low_pressed
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


func _update_camera_feedback(delta: float) -> void:
	var speed_weight: float = clampf(
		inverse_lerp(move_speed, movement_chain_speed_cap, get_horizontal_speed()),
		0.0,
		1.0
	)
	var target_fov: float = lerpf(base_fov, speed_fov, speed_weight)
	var response_weight: float = 1.0 - exp(-camera_response * delta)
	_camera.fov = lerpf(_camera.fov, target_fov, response_weight)

	var target_roll: float = deg_to_rad(-_last_input_vector.x * strafe_tilt_degrees)
	if _is_wall_sliding:
		var local_wall_normal: Vector3 = global_transform.basis.inverse() * _wall_normal
		target_roll += deg_to_rad(local_wall_normal.x * wall_tilt_degrees)
	_camera.rotation.z = lerp_angle(_camera.rotation.z, target_roll, response_weight)
