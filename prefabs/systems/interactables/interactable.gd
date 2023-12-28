extends StaticBody3D

class_name Interactable

signal interacted(body)

@export var prompt_message = "interact"
@export var prompt_action = "interact"
@export var key_name = "F"

func get_prompt():
	return prompt_message + "\n [" + key_name + "]"


func interact():
	emit_signal("interacted", self)
