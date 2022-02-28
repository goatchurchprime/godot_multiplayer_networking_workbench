extends ColorRect

var mousecommandvelocity = Vector2(0, 0)
var mousebuttondown = false

func _ready():
	get_node("../Players").set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	connect("mouse_exited", self, "_gui_input", [null])

func _gui_input(event):
	var mouseposition = null
	if event == null:
		pass
	elif event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				mouseposition = event.position
				mousebuttondown = true
			else:
				mousebuttondown = false
	elif event is InputEventMouseMotion and mousebuttondown:
		print(event.position, " ", OS.get_ticks_msec())
		mouseposition = event.position
	if mouseposition != null:
		mousecommandvelocity = Vector2((-1 if mouseposition.x < rect_size.x/3 else 0) + (1 if mouseposition.x > 2*rect_size.x/3 else 0), 
									   (-1 if mouseposition.y < rect_size.y/3 else 0) + (1 if mouseposition.y > 2*rect_size.y/3 else 0))
	else:
		mousecommandvelocity = Vector2(0, 0)
