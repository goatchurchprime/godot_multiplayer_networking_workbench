extends Control

@onready var NetworkGateway = get_node("../..")
var websocketserver = null
const websocketprotocol = "webrtc-signalling"
var clientsconnected = [ ]

# This could all be done by re-implementing the 
# Websocket player lists and networking, but a 
# second shadow time with a local multiplayer_peer for just these nodes.
# Wacky, eh?

signal mqttsig_client_connected(id)
signal mqttsig_client_disconnected(id)
signal mqttsig_packet_received(id, v)

func _ready():
	set_process(false)

func sendpacket_toclient(id, v):
	websocketserver.get_peer(id).put_packet(var_to_bytes(v))
	
func wss_data_received(id: int):
	while websocketserver.get_peer(id).get_available_packet_count() != 0:
		var p = websocketserver.get_peer(id).get_packet()
		var v = bytes_to_var(p)
		if v != null and v.has("subject"):
			emit_signal("mqttsig_packet_received", id, v)

func on_broker_disconnect():
	$StartServer.button_pressed = false
	
func wss_client_connected(id: int, protocol: String):
	emit_signal("mqttsig_client_connected", id)
	assert (clientsconnected.find(id) == -1)
	clientsconnected.push_back(id)
	$ClientsList.add_item(str(id), id)
	$ClientsList.selected = $ClientsList.get_item_count()-1
	sendpacket_toclient(id, {"subject":"firstmessage", "clientid":id})
	
func wss_client_disconnected(id: int, was_clean_close: bool):
	emit_signal("mqttsig_client_disconnected", id)
	var cidx = clientsconnected.find(id)
	assert (cidx != -1)
	clientsconnected.remove(cidx)
	var idx = $ClientsList.get_item_index(id)
	print($ClientsList.selected)
	if $ClientsList.selected == idx:
		$ClientsList.selected = 0
	$ClientsList.remove_item(idx)
	

func startwebsocketsignalserver():
		var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
		var multiplayerpeer = WebSocketMultiplayerPeer.new()
		var E = multiplayerpeer.create_server(portnumber)
		if E != OK:
			$StartWebSocketmultiplayer.button_pressed = false
			print("Failed code: [", error_string(E))
			print("networkedmultiplayer createserver Error: ", E)
			print("*** is there a server running on this port already? ", portnumber)
			NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)

		get_tree().set_multiplayer(multiplayerpeer, NodePath("."))
		print("multiplayer_peer ", multiplayer.multiplayer_peer)
		assert (multiplayer.server_relay)
		assert (multiplayer.get_unique_id() == 1)
		assert (get_tree().multiplayer_poll)
		#PlayerConnections.networkplayer_connected_to_server()

func Dstartwebsocketsignalserver():
	assert (websocketserver == null)
	
	
	
	websocketserver = WebSocketMultiplayerPeer.new()
	var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
	websocketserver.connect("client_close_request", Callable(self, "wss_client_close_request"))
	websocketserver.connect("client_connected", Callable(self, "wss_client_connected"))
	websocketserver.connect("client_disconnected", Callable(self, "wss_client_disconnected"))
	websocketserver.connect("data_received", Callable(self, "wss_data_received"))
	var servererror = websocketserver.create_server(portnumber) # , PackedStringArray([websocketprotocol]), false)
	if servererror == 0:
		set_process(true)
		get_node("../client_id").text = "server"
		$ClientsList.set_item_text(0, str(1))
		$WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = false
		if get_node("../autoconnect").button_pressed:
			$WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = true

	else:
		print("websocket server error ", servererror)
		stopwebsocketsignalserver()

func stopwebsocketsignalserver():
	assert (websocketserver != null)
	set_process(false)
	websocketserver.disconnect("client_close_request", Callable(self, "wss_client_close_request"))
	websocketserver.disconnect("client_connected", Callable(self, "wss_client_connected"))
	websocketserver.disconnect("client_disconnected", Callable(self, "wss_client_disconnected"))
	websocketserver.disconnect("data_received", Callable(self, "wss_data_received"))
	get_node("../client_id").text = ""
	websocketserver = null
	
	for id in clientsconnected:
		emit_signal("mqttsig_client_disconnected", id)
	$ClientsList.clear()
	$ClientsList.add_item("none", 0)
	$WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = false

	
