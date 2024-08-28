extends Control

signal mqttsig_connection_established(wclientid)   # (badly named: applies to websocket signalling too)
signal mqttsig_packet_received(v)
signal mqttsig_connection_closed()

@onready var NetworkGateway = get_node("../../../../../..")
var websocketclient = null
const websocketprotocol = "webrtc-signalling"
var wclientid = 0

func _ready():
	set_process(false)
	
func sendpacket_toserver(v):
	websocketclient.put_packet(var_to_bytes(v))

func isconnectedtosignalserver():
	return websocketclient != null and websocketclient.get_ready_state() == WebSocketPeer.STATE_OPEN
		
func wsc_connection_closed(was_clean_close: bool):
	print("wsc_connection_closed ", was_clean_close)
	NetworkGateway.setnetworkoff()
	
func wsc_connection_error():
	print("wsc_connection_error")
	NetworkGateway.setnetworkoff()
	
func stopwebsocketsignalclient():
	assert (websocketclient != null)
	websocketclient.close()


func wsc_data_received():
	while websocketclient.get_available_packet_count() != 0:
		var p = websocketclient.get_packet()
		var v = bytes_to_var(p)
		print("websocket data received ", len(p))
		if v != null and v.has("subject"):
			if v["subject"] == "firstmessage":
				assert (wclientid == -1)
				wclientid = v["clientid"]
				get_node("../HBox/client_id").text = str(wclientid)
				emit_signal("mqttsig_connection_established", int(wclientid))
				$WebRTCmultiplayerclient/StartWebRTCmultiplayer.disabled = false
				if get_node("../HBox/autoconnect").button_pressed:
					$WebRTCmultiplayerclient/StartWebRTCmultiplayer.button_pressed = true
			else:
				emit_signal("mqttsig_packet_received", v)



func _process(delta):
	websocketclient.poll()
	var state = websocketclient.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		wsc_data_received()
	elif state == WebSocketPeer.STATE_CONNECTING:
		pass
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = websocketclient.get_close_code()
		var reason = websocketclient.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.
		websocketclient = null
		NetworkGateway.setnetworkoff()
		get_node("../HBox/client_id").text = "off"
		wclientid = 0
		emit_signal("mqttsig_connection_closed")


func startwebsocketsignalclient():
	assert (websocketclient == null)
	websocketclient = WebSocketPeer.new()
	var portnumber = int(NetworkGateway.NetworkOptions_portnumber.text)
	var ns = NetworkGateway.NetworkOptions.selected
	var serverIPnumber = NetworkGateway.NetworkOptions.get_item_text(ns).split(" ", 1)[0]
	var wsurl = "ws://%s:%d" % [serverIPnumber, portnumber]
	print("Websocketclient connect to: ", wsurl)
	var clienterror = websocketclient.connect_to_url(wsurl)
	if clienterror == OK:
		set_process(true)
		get_node("../HBox/client_id").text = "connecting"
		wclientid = -1

	else:
		print("Bad start websocket")
		NetworkGateway.setnetworkoff()
