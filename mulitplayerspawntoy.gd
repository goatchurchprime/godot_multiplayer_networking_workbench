extends RigidBody2D


var relmouse = null
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			relmouse = get_global_mouse_position() - global_position
		else:
			relmouse = null
	if relmouse != null and event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - relmouse

		
