extends Control

@onready var NetworkGateway = get_node("../..")
@onready var PlayerConnections = NetworkGateway.get_node("PlayerConnections")
var websocketclient = null

func _ready():
	set_process(false)
#func _process(delta):
#	websocketclient.poll()
func websocketshutdown(was_clean_close):
	set_process(false)
	websocketclient = null
	
func _on_StartWebSocketmultiplayer_toggled(button_pressed):
	if button_pressed:
		var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
		var ns = NetworkGateway.get_node("NetworkOptions").selected
		var serverIPnumber = NetworkGateway.get_node("NetworkOptions").get_item_text(ns).split(" ", 1)[0]
		var url = "ws://%s:%d" % [serverIPnumber, portnumber]
		print("Websocketclient connect to: ", url)
		var lwebsocketclient = WebSocketMultiplayerPeer.new();
		var clienterror = lwebsocketclient.create_client(url)
		if clienterror == 0:
			PlayerConnections.SetNetworkedMultiplayerPeer(lwebsocketclient)
			websocketclient = lwebsocketclient
			websocketclient.connect("server_disconnected", Callable(self, "websocketshutdown"))
			set_process(true)
		else:
			print("Bad start websocket")
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
			
	else:
		if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			PlayerConnections.force_server_disconnect()
		if websocketclient != null:
			websocketclient.close()


