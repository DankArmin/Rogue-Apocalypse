extends Node3D

@export var shake_reduction_rate := 1.0

@export var noise : Noise
@export var noise_speed := 50.0

@export var max_x := 10.0
@export var max_y := 10.0
@export var max_z := 5.0

var shake := 0.0

var time := 0.0

@onready var camera := $FPSCamera as Camera3D 
@onready var initial_rotation := camera.rotation_degrees as Vector3


func _process(delta):
	time += delta
	shake = max(shake - delta * shake_reduction_rate, 0.0)
	
	camera.rotation_degrees.x = initial_rotation.x + max_x * get_shake_intensity() * get_noise_from_seed(0)
	camera.rotation_degrees.y = initial_rotation.y + max_y * get_shake_intensity() * get_noise_from_seed(1)
	camera.rotation_degrees.z = initial_rotation.z + max_z * get_shake_intensity() * get_noise_from_seed(2)

func add_trauma(shake_amount: float):
	shake = clamp(shake + shake_amount, 0.0, 1.0)


func get_shake_intensity() -> float:
	return shake * shake


func get_noise_from_seed(_seed: int):
	noise.seed = _seed
	return noise.get_noise_1d(time * noise_speed)


func _on_player_on_screen_shake(amount):
	add_trauma(amount)
