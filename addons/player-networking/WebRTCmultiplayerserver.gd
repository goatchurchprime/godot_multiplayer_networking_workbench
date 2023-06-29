extends Control

@onready var serversignalling = get_parent()
@onready var PlayerConnections = get_node("../../../PlayerConnections")

var networkedmultiplayerserver = null
var Dpeer = null

func _process(delta):
	if Dpeer:
		Dpeer.poll()

func server_ice_candidate_created(mid_name, index_name, sdp_name, id):
	serversignalling.sendpacket_toclient(id, {"subject":"ice_candidate", "mid_name":mid_name, "index_name":index_name, "sdp_name":sdp_name})

func server_session_description_created(type, data, id):
	print("we got server_session_description_created ", type)
	assert (type == "offer")
	var peer = get_tree().get_multiplayer().multiplayer_peer.get_peer(id)
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
		#get_tree().get_multiplayer().multiplayer_peer = networkedmultiplayerserver
		$statuslabel.text = "create offer"
		Dpeer = peer
		
	elif v["subject"] == "answer":
		print("Check equal multiplayer ", get_tree().get_multiplayer(), " vs ", multiplayer)
		assert (get_tree().get_multiplayer().multiplayer_peer.is_class("WebRTCMultiplayerPeer"))
		var peer = get_tree().get_multiplayer().multiplayer_peer.get_peer(id)
		peer["connection"].set_remote_description("answer", v["data"])
		$statuslabel.text = "answer"

	elif v["subject"] == "ice_candidate":
		var peer = get_tree().get_multiplayer().multiplayer_peer.get_peer(id)
		peer["connection"].add_ice_candidate(v["mid_name"], v["index_name"], v["sdp_name"])
		$statuslabel.text = "ice_candidate"


	
func _on_StartWebRTCmultiplayer_toggled(button_pressed):
	if button_pressed:
		networkedmultiplayerserver = WebRTCMultiplayerPeer.new()
		#var servererror = networkedmultiplayerserver.initialize(1, true)
		#assert (servererror == 0)
		PlayerConnections.webrtc_server_relay = true
		networkedmultiplayerserver.create_server()
		PlayerConnections.SetNetworkedMultiplayerPeer(networkedmultiplayerserver)
		
		#assert (get_tree().get_multiplayer().get_unique_id() == 1)
		serversignalling.connect("mqttsig_client_connected", Callable(self, "server_client_connected")) 
		serversignalling.connect("mqttsig_client_disconnected", Callable(self, "server_client_disconnected")) 
		serversignalling.connect("mqttsig_packet_received", Callable(self, "server_packet_received")) 
			
	else:
		serversignalling.disconnect("mqttsig_client_connected", Callable(self, "server_client_connected")) 
		serversignalling.disconnect("mqttsig_client_disconnected", Callable(self, "server_client_disconnected")) 
		serversignalling.disconnect("mqttsig_packet_received", Callable(self, "server_packet_received")) 
		PlayerConnections.webrtc_server_relay = false
		if not (get_tree().get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer):
			PlayerConnections.force_server_disconnect()


