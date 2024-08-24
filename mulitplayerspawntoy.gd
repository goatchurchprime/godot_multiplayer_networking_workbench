extends RigidBody2D

func mouseentered():
	get_node("../..").mouseenter(self)
	
func mouseexited():
	get_node("../..").mouseexit(self)


func _on_body_entered(body):
	print(" _on_body_entered ", body)
