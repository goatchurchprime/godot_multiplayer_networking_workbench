extends Control

signal mqttsig_connection_established(wclientid)   # (badly named: applies to websocket signalling too)
signal mqttsig_packet_received(v)

@onready var NetworkGateway = get_node("../..")
var websocketclient = null
const websocketprotocol = "webrtc-signalling"
var wclientid = 0

func _ready():
	set_process(false)
	
func _process(delta):
	websocketclient.poll()

func sendpacket_toserver(v):
	websocketclient.get_peer(1).put_packet(var_to_bytes(v))

func isconnectedtosignalserver():
	return websocketclient != null and websocketclient.get_peer(1).is_connected_to_host()

func wsc_connection_closed(was_clean_close: bool):
	print("wsc_connection_closed ", was_clean_close)
	get_parent().get_parent().setnetworkoff()
	
func wsc_connection_error():
	print("wsc_connection_error")
	get_parent().get_parent().setnetworkoff()
	
func wsc_connection_established(protocol: String):
	print("wsc_connection_established ", protocol)
	get_node("../client_id").text = "connecting"
	wclientid = -1

func wsc_server_close_request(code: int, reason: String):
	print("wsc_server_close_request ", code, " ", reason)
	get_parent().get_parent().setnetworkoff()

func wsc_data_received():
	while websocketclient.get_peer(1).get_available_packet_count() != 0:
		var p = websocketclient.get_peer(1).get_packet()
		var v = bytes_to_var(p)
		if v != null and v.has("subject"):
			if v["subject"] == "firstmessage":
				assert (wclientid == -1)
				wclientid = v["clientid"]
				get_node("../client_id").text = str(wclientid)
				emit_signal("mqttsig_connection_established", int(wclientid))
				$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = false
				if get_node("../autoconnect").button_pressed:
					$WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = true
			else:
				emit_signal("mqttsig_packet_received", v)

func startwebsocketsignalclient():
	assert (websocketclient == null)
	websocketclient = WebSocketMultiplayerPeer.new()
	websocketclient.connect("connection_closed", Callable(self, "wsc_connection_closed"))
	websocketclient.connect("connection_error", Callable(self, "wsc_connection_error"))
	websocketclient.connect("connection_established", Callable(self, "wsc_connection_established"))
	websocketclient.connect("server_close_request", Callable(self, "wsc_server_close_request"))
	websocketclient.connect("data_received", Callable(self, "wsc_data_received"))
	var portnumber = int(NetworkGateway.get_node("NetworkOptions/portnumber").text)
	var ns = NetworkGateway.get_node("NetworkOptions").selected
	var serverIPnumber = NetworkGateway.get_node("NetworkOptions").get_item_text(ns).split(" ", 1)[0]
	var wsurl = "ws://%s:%d" % [serverIPnumber, portnumber]
	print("Websocketclient connect to: ", wsurl)
	var clienterror = websocketclient.create_client(wsurl) # , PackedStringArray([websocketprotocol]), false)
	if clienterror == 0:
		set_process(true)
	else:
		print("Bad start websocket")
		get_parent().get_parent().setnetworkoff()

func stopwebsocketsignalclient():
	assert (websocketclient != null)
	set_process(false)
	websocketclient.disconnect("connection_closed", Callable(self, "wsc_connection_closed"))
	websocketclient.disconnect("connection_error", Callable(self, "wsc_connection_error"))
	websocketclient.disconnect("connection_established", Callable(self, "wsc_connection_established"))
	websocketclient.disconnect("server_close_request", Callable(self, "wsc_server_close_request"))
	websocketclient.disconnect("data_received", Callable(self, "wsc_data_received"))
	websocketclient = null
	get_node("../client_id").text = "off"
	wclientid = 0
