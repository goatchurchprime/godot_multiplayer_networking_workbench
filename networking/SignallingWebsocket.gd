extends Node

onready var websocketserver = WebSocketServer.new()
onready var websocketclient = WebSocketClient.new()
const websocketprotocol = "webrtc-signalling"

func _ready():
	return 
	websocketserver.connect("client_close_request", self, "wss_client_close_request")
	websocketserver.connect("client_connected", self, "wss_client_connected")
	websocketserver.connect("client_disconnected", self, "wss_client_disconnected")
	websocketserver.connect("data_received", self, "wss_data_received")
	
	websocketclient.connect("mqttsig_connection_closed", self, "wsc_connection_closed")
	websocketclient.connect("connection_error", self, "wsc_connection_error")
	websocketclient.connect("mqttsig_connection_established", self, "wsc_connection_established")

	websocketclient.connect("server_close_request", self, "wsc_server_close_request")
	websocketclient.connect("data_received", self, "wsc_data_received")
	set_process(false)


func wss_session_description_created(type, data, id):
	print("wss_session_description_created ", id, " ", type)
	var dpeer = get_tree().network_peer.get_peer(id)
	dpeer["connection"].set_local_description(type, data)
	websocketserver.get_peer(id).put_packet(var2bytes(["session_description_created", id, type, data]))

func wsc_session_description_created(type, data):
	print("wsc_session_description_created ", type)
	var dpeer = get_tree().network_peer.get_peer(1)
	dpeer["connection"].set_local_description(type, data)
	websocketclient.get_peer(1).put_packet(var2bytes(["session_description_created", 1, type, data]))

func wss_client_close_request(id: int, code: int, reason: String):
	print("wss_client_close_request ", id, " ", code, " ", reason)
	
func wss_ice_candidate_created(mid_name, index_name, sdp_name, id):
	print("wss_ice_candidate_created ", id, " ", mid_name)
	websocketserver.get_peer(id).put_packet(var2bytes(["ice_candidate_created", mid_name, index_name, sdp_name]))

func wsc_ice_candidate_created(mid_name, index_name, sdp_name):
	print("wsc_ice_candidate_created ", mid_name)
	websocketclient.get_peer(1).put_packet(var2bytes(["ice_candidate_created", mid_name, index_name, sdp_name]))

var Dpeer = null
func wss_client_connected(id: int, protocol: String):
	var peer = WebRTCPeerConnection.new()
	Dpeer = peer
	peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
	peer.connect("session_description_created", self, "wss_session_description_created", [id])
	peer.connect("ice_candidate_created", self, "wss_ice_candidate_created", [id])
	peer.connect("data_channel_received", self, "wss_data_channel_received", [id])
	get_tree().network_peer.add_peer(peer, id)
	var webrtcpeererror = peer.create_offer()
	print("peer create offer ", peer, "Error:", webrtcpeererror)

func wss_client_disconnected(id: int, was_clean_close: bool):
	print("wss_client_disconnected ", id, " ", was_clean_close)

func wss_data_received(id: int):
	while websocketserver.get_peer(id).get_available_packet_count() != 0:
		var p = websocketserver.get_peer(id).get_packet()
		var d = bytes2var(p)
		if d[0] == "session_description_created":
			print("rec ", d[0], " ", d[1], " ", id)
			if d[2] == "answer":
				var dpeer = get_tree().network_peer.get_peer(id)
				dpeer["connection"].set_remote_description(d[2], d[3])
		elif d[0] == "ice_candidate_created":
			print("rec ", d[0], " ", d[1], " ", id)
			var dpeer = get_tree().network_peer.get_peer(id)
			dpeer["connection"].add_ice_candidate(d[1], d[2], d[3])
		else:
			print("UNKNOWN wsc_data_received ", d)

func wsc_connection_closed(was_clean_close: bool):
	print("wsc_connection_closed ", was_clean_close)
	set_process(false)
	get_parent().setnetworkoff()
	
func wsc_connection_error():
	print("wsc_connection_error")
	set_process(false)
	get_parent().setnetworkoff()
	
func wsc_connection_established(protocol: String):
	print("wsc_connection_established ", protocol)
func wsc_server_close_request(code: int, reason: String):
	print("wsc_server_close_request ", code, " ", reason)

func wsc_data_channel_received(channel: Object):
	print("wsc_data_channel_received ", channel)

func wss_data_channel_received(channel: Object, id):
	print("wss_data_channel_received ", id, " ", channel)

func wsc_data_received():
	while websocketclient.get_peer(1).get_available_packet_count() != 0:
		var p = websocketclient.get_peer(1).get_packet()
		var d = bytes2var(p)
		if d[0] == "session_description_created":
			if d[2] == "offer":
				print("rec ", d[0], " ", d[2], " ", d[1])
				var peer = WebRTCPeerConnection.new()
				Dpeer = peer
				peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
				peer.connect("session_description_created", self, "wsc_session_description_created")
				peer.connect("ice_candidate_created", self, "wsc_ice_candidate_created")
				peer.connect("data_channel_received", self, "wsc_data_channel_received")
				peer.set_remote_description(d[2], d[3])

				var networkedmultiplayerclient = WebRTCMultiplayer.new()
				networkedmultiplayerclient.initialize(d[1], true)
				networkedmultiplayerclient.add_peer(peer, 1)
				get_tree().set_network_peer(networkedmultiplayerclient)
				print("networkedmultiplayerclient.is_network_server ", get_tree().is_network_server())
		elif d[0] == "ice_candidate_created":
			print("rec ", d[0], " ", d[2], " ", d[1])
			var dpeer = get_tree().network_peer.get_peer(1)
			dpeer["connection"].add_ice_candidate(d[1], d[2], d[3])
		else:
			print("UNKNOWN wsc_data_received ", d)
			
func _process(delta):
	websocketserver.poll()
	websocketclient.poll()
		
func startwebsocketserver(port):
	var servererror = websocketserver.listen(port, PoolStringArray([websocketprotocol]), false)
	if servererror == 0:
		set_process(true)
	else:
		print("websocket server error ", servererror)

func stopwebsocketserver():
	websocketserver.stop()
	websocketserver = null
	set_process(false)
		
func connectwebsocket(wsurl):
	var clienterror = websocketclient.connect_to_url(wsurl, PoolStringArray([websocketprotocol]), false)
	if clienterror == 0:
		set_process(true)
	else:
		print("websocket client error ", clienterror)

func closeconnection():
	websocketclient.disconnect_from_host(1000, "closeconnection")

