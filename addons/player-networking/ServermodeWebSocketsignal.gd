extends Control

@onready var NetworkGateway = get_node("../..")
var websocketserver = null
const websocketprotocol = "webrtc-signalling"

var websocketclientsconnected = { }
var websocketclientsconnecting = [ ]

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
	websocketclientsconnected[id].put_packet(var_to_bytes(v))
	print("put packet ", len(var_to_bytes(v)), " to ", websocketclientsconnected[id])
	
func on_broker_disconnect():
	$StartServer.button_pressed = false
	
func wss_client_disconnected(id: int):
	emit_signal("mqttsig_client_disconnected", id)
	var idx = $ClientsList.get_item_index(id)
	print($ClientsList.selected)
	if $ClientsList.selected == idx:
		$ClientsList.selected = 0
	$ClientsList.remove_item(idx)

func wss_client_poll(id):
	var websocketclient = websocketclientsconnected[id]
	websocketclient.poll()
	var state = websocketclient.get_ready_state()
	
	if state == WebSocketPeer.STATE_CONNECTING:
		pass
	elif state == WebSocketPeer.STATE_OPEN:
		if id in websocketclientsconnecting:
			sendpacket_toclient(id, {"subject":"firstmessage", "clientid":id})
			websocketclientsconnecting.erase(id)
		while websocketclient.get_available_packet_count():
			var p = websocketclient.get_packet()
			print("rrecievedpacketg ", len(p))
			var v = bytes_to_var(p)
			if v != null and v.has("subject"):
				emit_signal("mqttsig_packet_received", id, v)
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = websocketclient.get_close_code()
		var reason = websocketclient.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
	return state

var tcpserver = null
func _process(delta):
	var streampeertcp = tcpserver.take_connection()
	if streampeertcp != null:
		websocketserver = WebSocketPeer.new()
		var E = websocketserver.accept_stream(streampeertcp)
		print("taken websocket connection ")
		if E == OK:
			var id = 2 + (randi()%0x7ffffff8)
			websocketclientsconnected[id] = websocketserver
			$ClientsList.add_item(str(id), id)
			$ClientsList.selected = $ClientsList.get_item_count()-1
			websocketclientsconnecting.append(id)

		else:
			print("websocketserver.accept_stream error ", E)
		
	var wssidstoclose = [ ]
	for id in websocketclientsconnected.keys():
		if wss_client_poll(id) == WebSocketPeer.STATE_CLOSED:
			wssidstoclose.append(id)
	for id in wssidstoclose:
		wss_client_disconnected(id)
		websocketclientsconnected.erase(id)

func startwebsocketsignalserver():
	var portnumber = int(NetworkGateway.NetworkOptions_portnumber.text)
	tcpserver = TCPServer.new()
	var E = tcpserver.listen(portnumber, "*")
	if E == OK:
		set_process(true)
		get_node("../client_id").text = "server"
		$ClientsList.clear()
		$ClientsList.add_item("1", 1)
		$ClientsList.selected = 0
		websocketclientsconnected.clear()
		websocketclientsconnecting.clear()
		$WebRTCmultiplayerserver/StartWebRTCmultiplayer.disabled = false
		if get_node("../autoconnect").button_pressed:
			$WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = true

	else:
		print("Failed code: [", error_string(E))
		print("*** is there a server running on this port already? ", portnumber)
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)


func stopwebsocketsignalserver():
	assert (websocketserver != null)
	set_process(false)
	get_node("../client_id").text = ""
	websocketserver = null
	
	for id in websocketclientsconnected.keys():
		emit_signal("mqttsig_client_disconnected", id)
	$ClientsList.clear()
	$WebRTCmultiplayerserver/StartWebRTCmultiplayer.button_pressed = false

	
