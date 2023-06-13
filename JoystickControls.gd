extends ColorRect

var mousecommandvelocity = Vector2(0, 0)
var mousebuttondown = false


var Dinitializewebrtcmode = false

func _ready():
	get_node("../Players").set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	connect("mouse_exited", self, "_gui_input", [null])
	get_node("/root").connect("size_changed", self, "window_size_changed")
	var NetworkGateway = get_node("../NetworkGateway")

	if Dinitializewebrtcmode:
		#var brokeraddress = "ws://broker.hivemq.com:8000"
		#var brokeraddress = "broker.hivemq.com"
		#var brokeraddress = "mqtt.dynamicdevices.co.uk"
		var brokeraddress = "mosquitto.doesliverpool.xyz"
		#NetworkGateway.initialstate(NetworkGateway.get_node("ProtocolOptions").selected, NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
		NetworkGateway.initialstatemqttwebrtc(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.AS_NECESSARY, "tomato", brokeraddress)


	if OS.has_feature("Server"):
		yield(get_tree().create_timer(1.5), "timeout")
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.AS_SERVER)
	$HelloWorld.connect("item_selected", self, "callhelloworld")
	
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




func copytouserfilesystem(f):
	var dir = Directory.new()
	if not dir.dir_exists("user://executingfeatures"):
		dir.make_dir("user://executingfeatures")
	var fname = f.rsplit("/")[-1]
	var dest = "user://executingfeatures/"+fname
	if true or not dir.file_exists(dest):
		print("Copying out our py file ", fname)
		var e = dir.copy(f, dest)
		if e != 0:
			print("copytousrfilesystem ERROR ", e)
	return ProjectSettings.globalize_path(dest)


func callhelloworld(index):
	print("callhelloworld", index)
	$HelloWorld.select(0)
	var f = File.new()
	var sehw = "res://executables/hello_i86" if index == 1 else "res://executables/hello_arm"
	print("Does ", sehw, " exist? ")
	if f.file_exists(sehw):
		f.open(sehw, File.READ)
		var ehw = f.get_path_absolute()
		print("Yes.  The absolute path is: ", ehw, " length is: ", f.get_len())
		f.close()
		var dir = Directory.new()
		var dest = "user://exefile"
		var e = dir.copy(sehw, dest)
		if e != 0:
			print("copytousrfilesystem ERROR ", e)
		ehw = ProjectSettings.globalize_path(dest)
		print("copied to user directory ", ehw)
		var output = [ ]
		var res2 = OS.execute("chmod", PoolStringArray(["755", ehw]), true, output, false, true)
		print("chmod change ", res2)
#		var res = OS.execute(ehw, PoolStringArray([]), true, output, false, true)
#		var res = OS.execute("python", ["/home/julian/repositories/godot_multiplayer_networking_workbench/executables/hello.py"], true, output, false, true)
#		var res = OS.execute("bash", ["/home/julian/repositories/godot_multiplayer_networking_workbench/executables/hello.sh"], true, output, false, true)
#		var res = OS.execute("/home/julian/repositories/godot_multiplayer_networking_workbench/executables/hello_i86", [], true, output, false, true)
		print(ProjectSettings.globalize_path("user://"))  # this has /files
		var ss = "/data/data/org.godotengine.multiplayernetworkingworkbench/"
		var res = OS.execute("ls", PoolStringArray(["-l", ss]), true, output, false, true)
		print("returned ", res, " output: ", output)

		$HelloWorld/TextEdit.text = "\n".join(PoolStringArray(output))
	else:
		print("the file is not here!")

func window_size_changed():
	get_node("../Players").set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	var windowsize = get_node("/root").size
	print("windowsize ", windowsize)
