extends CharacterBody3D

@export var sensitivity: float = 0.03

var speed
@export var walk_speed = 5.0
@export var sprint_speed = 8.0
@export var crouch_speed = 2.5
@export var slide_speed = 12.0

const JUMP_VELOCITY = 6.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

#Camera
@onready var head = $Head
@onready var fps_camera = $Head/ShakeableCamera/CamHolder/FPSCamera
@onready var shakeable_camera = $Head/ShakeableCamera
@onready var cam_holder = $Head/ShakeableCamera/CamHolder

#Head Bob
@export var head_bob_frequency = 2.0
@export var head_bob_amplitude = 0.08
var head_bob_time = 0.0

#FOV
@export var base_fov = 85.0
@export var fov_change = 1.5

#Ledge Grabbing
@onready var ledge_detection_downward_ray = $Head/LedgeCheckerHolder/LedgeDetectionDownwardRay
@onready var ledge_detection_forward_ray = $Head/LedgeDetectionForwardRay
@onready var ledge_checker_holder = $Head/LedgeCheckerHolder
@onready var ledge_marker = $Head/LedgeCheckerHolder/LedgeDetectionDownwardRay/LedgeMarker

var is_holding_on_to_ledge = false
var current_ledge_position : Vector3

#ScreenShake
signal on_screen_shake(amount)

#Crouching
var is_crouching = false
@export var height_standing = 1.8
@export var height_crouching = 0.8
@onready var collision_shape_3d = $CollisionShape3D as CollisionShape3D
@onready var ceiling_check_ray = $CeilingCheckRay

# Land Shake
var has_landed : bool = false
var air_time : float = 0.0

#Sliding
var is_sliding : bool = false
var last_direction_x : float
var last_direction_z : float
@export var height_sliding : float = 0.4
var initial_slide_speed : float = 15.0
var current_slide_speed : float
var screen_shake_amount_on_slide : float = 0.05

func ledge_detect():
	var first_hit_point = ledge_detection_forward_ray.get_collision_point()
	var second_hit_point = ledge_detection_downward_ray.get_collision_point()
	
	var offset = Vector3(0,3,0)
	if ledge_detection_forward_ray.is_colliding():
		ledge_checker_holder.global_transform.origin = first_hit_point + offset
		ledge_marker.global_transform.origin = second_hit_point
		ledge_detection_downward_ray.enabled = true
		
	else :
		ledge_detection_downward_ray.enabled = false


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventMouseMotion: 
		head.rotate_y(-event.relative.x * sensitivity)
		fps_camera.rotate_x(-event.relative.y * sensitivity)
		fps_camera.rotation.x = clamp(fps_camera.rotation.x, deg_to_rad(-75), deg_to_rad(75))


func _physics_process(delta):
	if is_sliding:
		sliding(delta)
		shakeable_camera.rotation.z = lerp_angle(shakeable_camera.rotation.z, -50.0, delta * 10)
		collision_shape_3d.shape.height = lerp(collision_shape_3d.shape.height, height_sliding, 10 * delta)
	elif is_crouching:
		collision_shape_3d.shape.height = lerp(collision_shape_3d.shape.height, height_crouching, 10 * delta)
	else:
		shakeable_camera.rotation.z = lerp_angle(shakeable_camera.rotation.z, 0.0, delta * 5)
		collision_shape_3d.shape.height = lerp(collision_shape_3d.shape.height, height_standing, 10 * delta)
	ledge_detect()
	if is_holding_on_to_ledge:
		air_time = 0.0
		global_position = global_position.lerp(current_ledge_position, 15 * delta)
		ledge_marker.global_position.y += 10
		ledge_marker.get_child(0).monitoring = false
		if Input.is_action_just_pressed("jump"):
			handle_ledge_jump_up()
	
	if is_on_floor():
		if !has_landed:
			has_landed = true
			on_screen_shake.emit(air_time / 2)
			air_time = 0.0
		ledge_marker.get_child(0).monitoring = true
	
	if not is_on_floor() && !is_holding_on_to_ledge:
		air_time += delta
		if has_landed:
			has_landed = false
		if is_sliding or is_crouching:
			velocity.y -= (gravity * 2) * delta
		else:
			velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		if is_sliding:
			stand_up_from_slide()
			velocity.y = JUMP_VELOCITY * 1.25
		else:
			velocity.y = JUMP_VELOCITY

	if is_crouching:
		speed = crouch_speed
		
	elif Input.is_action_pressed("sprint"):
		speed = sprint_speed
	else:
		speed = walk_speed
		
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if !is_holding_on_to_ledge:
		if !is_sliding:
			last_direction_x = direction.x
			last_direction_z = direction.z
			handle_movement(direction, delta)
	
	if speed > walk_speed and Input.is_action_just_pressed("crouch") && velocity.length() > 5:
		slide()
	elif Input.is_action_just_pressed("crouch") && is_on_floor():
		crouch()
	if Input.is_action_just_released("crouch"):
		stand_up_from_crouch()
		stand_up_from_slide()
	
	handle_head_bob(delta)
	
	handle_fov(delta)
	
	camera_tilt(input_dir.x, input_dir.y, delta)
	
	move_and_slide()


func handle_movement(direction, delta):
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.5)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.5)


func handle_fov(delta):
	var velocity_clamped = clamp(velocity.length(), 0.5, sprint_speed * 2)
	var target_fov = base_fov + fov_change * velocity_clamped
	fps_camera.fov = lerp(fps_camera.fov, target_fov, delta * 8.0)


func handle_head_bob(delta):
	if is_sliding: return
	head_bob_time += delta * velocity.length() * float(is_on_floor())
	fps_camera.transform.origin = head_bob(head_bob_time)


func head_bob(time):
	var pos = Vector3.ZERO
	pos.y = sin(head_bob_time * head_bob_frequency) * head_bob_amplitude
	pos.x = cos(head_bob_time * head_bob_frequency / 2) * head_bob_amplitude
	return pos


#Ledge grabbing collision detection
func _on_area_3d_body_entered(body):
	if body.name != "Player": return
	if !is_on_floor():
		on_screen_shake.emit(1)
		is_holding_on_to_ledge = true
		velocity.y = 0
		velocity.x = 0
		current_ledge_position = ledge_marker.global_position
		current_ledge_position.y = current_ledge_position.y - 1


func handle_ledge_jump_up():
	on_screen_shake.emit(1)
	velocity.y += 6.5
	is_holding_on_to_ledge = false


func camera_tilt(x, z, delta):
	if fps_camera:
		shakeable_camera.rotation.z = lerp_angle(shakeable_camera.rotation.z, -x * .1, 7.5 * delta)
		shakeable_camera.rotation.x = lerp_angle(shakeable_camera.rotation.x, z * .1, 7.5 * delta)


func crouch():
	is_crouching = true
	

func stand_up_from_crouch():
	if ceiling_check_ray.is_colliding(): return
	is_crouching = false


func stand_up_from_slide():
	if ceiling_check_ray.is_colliding(): return
	is_sliding = false


func slide():
	is_sliding = true
	current_slide_speed = initial_slide_speed
	

func sliding(delta):
	if is_on_floor():
		on_screen_shake.emit(screen_shake_amount_on_slide)
		current_slide_speed -= delta * 10
		velocity.x = last_direction_x * current_slide_speed
		velocity.z = last_direction_z * current_slide_speed
	if current_slide_speed <= 0:
		stand_up_from_slide()
