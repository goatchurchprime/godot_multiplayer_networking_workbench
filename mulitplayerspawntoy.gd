extends RigidBody2D

func mouseentered():
	get_node("../..").mouseenter(self)
	
func mouseexited():
	get_node("../..").mouseexit(self)
