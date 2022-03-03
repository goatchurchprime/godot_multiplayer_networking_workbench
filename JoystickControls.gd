extends ColorRect

var mousecommandvelocity = Vector2(0, 0)
var mousebuttondown = false



func _ready():
	get_node("../Players").set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	connect("mouse_exited", self, "_gui_input", [null])
	get_node("/root").connect("size_changed", self, "window_size_changed")
	var NetworkGateway = get_node("../NetworkGateway")
	#NetworkGateway.initialstate(NetworkGateway.get_node("ProtocolOptions").selected, NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
	NetworkGateway.initialstatemqttwebrtc(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_SERVER, "tomato", "")
	if OS.has_feature("Server"):
		yield(get_tree().create_timer(1.5), "timeout")
		NetworkGateway.get_node("NetworkOptions").select(NetworkGateway.NETWORK_OPTIONS.AS_SERVER)

func _gui_input(event):
	var mouseposition = null
	if event == null:
		pass
	elif event is InputEventScreenDrag or event is InputEventScreenTouch:
		return
	elif event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				mouseposition = event.position
				mousebuttondown = true
			else:
				mousebuttondown = false
	elif event is InputEventMouseMotion and mousebuttondown:
		mouseposition = event.position
		
	if mouseposition != null:
		mousecommandvelocity = Vector2((-1 if mouseposition.x < rect_size.x/3 else 0) + (1 if mouseposition.x > 2*rect_size.x/3 else 0), 
									   (-1 if mouseposition.y < rect_size.y/3 else 0) + (1 if mouseposition.y > 2*rect_size.y/3 else 0))
	else:
		mousecommandvelocity = Vector2(0, 0)



func window_size_changed():
	get_node("../Players").set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	var windowsize = get_node("/root").size
	print("windowsize ", windowsize)
