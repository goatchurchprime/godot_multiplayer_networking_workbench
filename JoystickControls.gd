extends ColorRect

var mousecommandvelocity = Vector2(0, 0)
var mousebuttondown = false


var Dinitializewebrtcmode = false

func _ready():
	get_node("../Players").set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	connect("mouse_exited", Callable(self, "_gui_input").bind(null))
	get_node("/root").connect("size_changed", Callable(self, "window_size_changed"))
	var NetworkGateway = get_node("../NetworkGateway")

	if Dinitializewebrtcmode:
		#var brokeraddress = "ws://broker.hivemq.com:8000"
		#var brokeraddress = "broker.hivemq.com"
		#var brokeraddress = "mqtt.dynamicdevices.co.uk"
		var brokeraddress = "mosquitto.doesliverpool.xyz"
		#NetworkGateway.initialstate(NetworkGateway.get_node("ProtocolOptions").selected, NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
		NetworkGateway.initialstatemqttwebrtc(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY, "tomato", brokeraddress)


	if OS.has_feature("Server"):
		await get_tree().create_timer(1.5).timeout
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.AS_SERVER)

	print($TextureRect.texture)
	var image1 = Image.load_from_file("res://texture1.png")
	var image2 = Image.load_from_file("res://texture2.png")
	image2.shrink_x2()
	image1.blit_rect(image2, Rect2i(100,100,150,300), Vector2i(50,50))
	$TextureRect.texture.set_image(image1)
	#var texture = ImageTexture.create_from_image(image1)
	#$TextureRect.texture = texture



func _gui_input(event):
	var mouseposition = null
	if event == null:
		pass
	elif event is InputEventScreenDrag or event is InputEventScreenTouch:
		return
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouseposition = event.position
				mousebuttondown = true
			else:
				mousebuttondown = false
	elif event is InputEventMouseMotion and mousebuttondown:
		mouseposition = event.position
		
	if mouseposition != null:
		mousecommandvelocity = Vector2((-1 if mouseposition.x < size.x/3 else 0) + (1 if mouseposition.x > 2*size.x/3 else 0), 
										(-1 if mouseposition.y < size.y/3 else 0) + (1 if mouseposition.y > 2*size.y/3 else 0))
	else:
		mousecommandvelocity = Vector2(0, 0)



func window_size_changed():
	get_node("../Players").set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	var windowsize = get_node("/root").size
	print("windowsize ", windowsize)
