extends Control

onready var NetworkGateway = get_node("../..")
var websocketserver = null
const websocketprotocol = "webrtc-signalling"
var clientsconnected = [ ]

func _process(delta):
	websocketserver.poll()

signal mqttsig_client_connected(id)
signal mqttsig_client_disconnected(id)
signal mqttsig_packet_received(id, v)

func _ready():
	set_process(false)

func sendpacket_toclient(id, v):
	websocketserver.get_peer(id).put_packet(var2bytes(v))
	
func wss_data_received(id: int):
	while websocketserver.get_peer(id).get_available_packet_count() != 0:
		var p = websocketserver.get_peer(id).get_packet()
		var v = bytes2var(p)
		if v != null and v.has("subject"):
			emit_signal("mqttsig_packet_received", id, v)

func on_broker_disconnect():
	$StartServer.pressed = false
	
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
	assert (websocketserver == null)
	websocketserver = WebSocketServer.new()
	var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
	websocketserver.connect("client_close_request", self, "wss_client_close_request")
	websocketserver.connect("client_connected", self, "wss_client_connected")
	websocketserver.connect("client_disconnected", self, "wss_client_disconnected")
	websocketserver.connect("data_received", self, "wss_data_received")
	var servererror = websocketserver.listen(portnumber, PoolStringArray([websocketprotocol]), false)
	if servererror == 0:
		set_process(true)
		get_node("../client_id").text = "server"
		$ClientsList.set_item_text(0, str(1))
		$WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = false
		if get_node("../autoconnect").pressed:
			$WebRTCmultiplayerserver/StartWebRTCmultiplayer.pressed = true

	else:
		print("websocket server error ", servererror)
		stopwebsocketsignalserver()

func stopwebsocketsignalserver():
	assert (websocketserver != null)
	set_process(false)
	websocketserver.disconnect("client_close_request", self, "wss_client_close_request")
	websocketserver.disconnect("client_connected", self, "wss_client_connected")
	websocketserver.disconnect("client_disconnected", self, "wss_client_disconnected")
	websocketserver.disconnect("data_received", self, "wss_data_received")
	get_node("../client_id").text = ""
	websocketserver = null
	
	for id in clientsconnected:
		emit_signal("mqttsig_client_disconnected", id)
	$ClientsList.clear()
	$ClientsList.add_item("none", 0)
	$WebRTCmultiplayerserver/StartWebRTCmultiplayer.pressed = false

