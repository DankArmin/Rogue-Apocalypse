extends CharacterBody3D

@export var sensitivity: float = 0.03

const SPEED = 5.0
const JUMP_VELOCITY = 6.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head = $Head
@onready var fps_camera = $Head/FPSCamera


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event):
	if event is InputEventMouseMotion: 
		head.rotate_y(-event.relative.x * sensitivity)
		fps_camera.rotate_x(-event.relative.y * sensitivity)
		fps_camera.rotation.x = clamp(fps_camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()
