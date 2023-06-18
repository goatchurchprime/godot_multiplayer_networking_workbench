extends Control

@onready var NetworkGateway = get_node("../..")
@onready var PlayerConnections = NetworkGateway.get_node("PlayerConnections")
var websocketserver = null

func _ready():
	set_process(false)
func _process(delta):
	websocketserver.poll()
	
func _on_StartWebSocketmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
		var lwebsocketserver = WebSocketMultiplayerPeer.new()
		var servererror = lwebsocketserver.create_server(portnumber)
		if servererror == 0:
			PlayerConnections.SetNetworkedMultiplayerPeer(lwebsocketserver)
			websocketserver = lwebsocketserver
			set_process(true)

		else:
			PlayerConnections.connectionlog("Server error: %d\n" % servererror)
			print("networkedmultiplayer createserver Error: ", servererror)
			print("*** is there a server running on this port already? ", portnumber)
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

	else:
		if get_tree().get_multiplayer().multiplayer_peer != null:
			PlayerConnections.force_server_disconnect()
		if websocketserver != null:
			websocketserver.stop()
			websocketserver = null
			set_process(false)
		


