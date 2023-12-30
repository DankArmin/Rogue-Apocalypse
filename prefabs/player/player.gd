extends CharacterBody3D

@export var sensitivity: float = 0.03

var speed
@export var walk_speed = 5.0
@export var sprint_speed = 8.0
@export var crouch_speed = 2.5

const JUMP_VELOCITY = 6.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

#Camera
@onready var head = $Head
@onready var fps_camera = $Head/ShakeableCamera/CamHolder/FPSCamera
@onready var shakeable_camera = $Head/ShakeableCamera

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
	if is_crouching:
		collision_shape_3d.shape.height = lerp(collision_shape_3d.shape.height, height_crouching, 10 * delta)
	else:
		collision_shape_3d.shape.height = lerp(collision_shape_3d.shape.height, height_standing, 10 * delta)
	ledge_detect()
	if is_holding_on_to_ledge:
		global_position = global_position.lerp(current_ledge_position, 15 * delta)
		ledge_marker.global_position.y += 10
		ledge_marker.get_child(0).monitoring = false
		if Input.is_action_just_pressed("jump"):
			handle_ledge_jump_up()
	
	if is_on_floor():
		ledge_marker.get_child(0).monitoring = true
	
	if not is_on_floor() && !is_holding_on_to_ledge:
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
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
		handle_movement(direction, delta)
	
	if Input.is_action_just_pressed("crouch"):
		crouch()
	if Input.is_action_just_released("crouch"):
		stand_up_from_crouch()
	
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
		on_screen_shake.emit(0.5)
		is_holding_on_to_ledge = true
		velocity.y = 0
		velocity.x = 0
		current_ledge_position = ledge_marker.global_position
		current_ledge_position.y = current_ledge_position.y - 1


func handle_ledge_jump_up():
	on_screen_shake.emit(0.25)
	velocity.y += 6.5
	is_holding_on_to_ledge = false


func camera_tilt(x, z, delta):
	if fps_camera:
		shakeable_camera.rotation.z = lerp_angle(shakeable_camera.rotation.z, -x * .1, 7.5 * delta)
		shakeable_camera.rotation.x = lerp_angle(shakeable_camera.rotation.x, z * .1, 7.5 * delta)


func crouch():
	is_crouching = true
	collision_shape_3d.shape.height = height_crouching
	

func stand_up_from_crouch():
	is_crouching = false
