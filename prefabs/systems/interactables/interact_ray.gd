extends RayCast3D

@onready var prompt = $Prompt


var picked_up_object : RigidBody3D
var pull_force = 4
@onready var grab_position = $GrabPosition

func _ready():
	add_exception(owner)
	

func _physics_process(delta):
	prompt.text = ""
	
	if is_colliding():
		var detected = get_collider()
		
		if detected is Interactable:
			prompt.text = detected.get_prompt()
			
			if Input.is_action_just_pressed(detected.prompt_action):
				detected.interact()
		
		elif detected is RigidBody3D:
			if Input.is_action_just_pressed("grab"):
				picked_up_object = detected
		
		if Input.is_action_just_released("grab"):
			picked_up_object = null
	if picked_up_object != null:
		var a = picked_up_object.global_transform.origin
		var b = grab_position.global_transform.origin
		picked_up_object.linear_velocity = (b-a) * pull_force
