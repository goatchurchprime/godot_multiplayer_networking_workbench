extends Control

@onready var serversignalling = get_parent()
@onready var PlayerConnections = get_node("../../../PlayerConnections")

var networkedmultiplayerserver = null

func server_ice_candidate_created(mid_name, index_name, sdp_name, id):
	serversignalling.sendpacket_toclient(id, {"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func server_session_description_created(type, data, id):
	print("we got server_session_description_created ", type)
	assert (type == "offer")
	var peer = multiplayer.multiplayer_peer.get_peer(id)
	peer["connection"].set_local_description(type, data)
	serversignalling.sendpacket_toclient(id, {"subject":"offer", "data":data})
	$statuslabel.text = "offer"
		
func server_client_connected(id):
	print("server client connected ", id)

func server_client_disconnected(id):
	print("server client_disconnected ", id)

func Ddata_channel_created(channel):
	print("DDDdata_channel_created ", channel)

func server_packet_received(id, v):
	#print("server packet_received ", id, v["subject"])
	if v["subject"] == "request_offer":
		var peer = WebRTCPeerConnection.new()
		peer.initialize({"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ] })
		#peer.connect("session_description_created", Callable(self, "server_session_description_created").bind(id))
		peer.session_description_created.connect(self.server_session_description_created.bind(id))

		peer.connect("ice_candidate_created", Callable(self, "server_ice_candidate_created").bind(id))
		print("serverpacket peer.get_connection_state() ", peer.get_connection_state())
		peer.connect("data_channel_received", Callable(self, "Ddata_channel_created"))
		networkedmultiplayerserver.add_peer(peer, id)
		var webrtcpeererror = peer.create_offer()
		print("peer create offer ", peer, "id ", id, " Error:", webrtcpeererror, " connstate")
		#multiplayer.multiplayer_peer = networkedmultiplayerserver
		$statuslabel.text = "create offer"

		
	elif v["subject"] == "answer":
		print("Check equal multiplayer ", multiplayer, " vs ", multiplayer)
		assert (multiplayer.multiplayer_peer.is_class("WebRTCMultiplayerPeer"))
		var peer = multiplayer.multiplayer_peer.get_peer(id)
		peer["connection"].set_remote_description("answer", v["data"])
		$statuslabel.text = "answer"

	elif v["subject"] == "ice_candidate":
		var peer = multiplayer.multiplayer_peer.get_peer(id)
		peer["connection"].add_ice_candidate(v["mid_name"], v["index_name"], v["sdp_name"])
		$statuslabel.text = "ice_candidate"


	
func _on_StartWebRTCmultiplayer_toggled(button_pressed):
	if button_pressed:
		networkedmultiplayerserver = WebRTCMultiplayerPeer.new()
		var E = networkedmultiplayerserver.create_server()
		if E != OK:
			$StartWebRTCmultiplayer.button_pressed = false
			print("Failed ", error_string(E))
		assert(networkedmultiplayerserver.is_server_relay_supported())
		PlayerConnections.SetNetworkedMultiplayerPeer(networkedmultiplayerserver)
		assert(multiplayer.server_relay)
		assert (multiplayer.get_unique_id() == 1)

		serversignalling.mqttsig_client_connected.connect(server_client_connected) 
		serversignalling.mqttsig_client_disconnected.connect(server_client_disconnected) 
		serversignalling.mqttsig_packet_received.connect(server_packet_received) 
			
	else:
		serversignalling.mqttsig_client_connected.disconnect(server_client_connected) 
		serversignalling.mqttsig_client_disconnected.disconnect(server_client_disconnected) 
		serversignalling.mqttsig_packet_received.disconnect(server_packet_received) 
		if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
			PlayerConnections.force_server_disconnect()


