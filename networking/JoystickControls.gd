extends ColorRect

var mouseposition = Vector2(0,0)
onready var LocalPlayer = get_node("../Players").get_child(0)

func _ready():
	get_node("../Players").set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	connect("mouse_exited", self, "set_process", [false])
	set_process(false)

func _process(delta):
	var vec = Vector2((-1 if mouseposition.x < rect_size.x/3 else 0) + (1 if mouseposition.x > 2*rect_size.x/3 else 0), 
					  (-1 if mouseposition.y < rect_size.y/3 else 0) + (1 if mouseposition.y > 2*rect_size.y/3 else 0))
	LocalPlayer.processlocalavatarpositionVec(vec, delta)


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			set_process(event.pressed)
			mouseposition = event.position		
	if event is InputEventMouseMotion:
		mouseposition = event.position
		
