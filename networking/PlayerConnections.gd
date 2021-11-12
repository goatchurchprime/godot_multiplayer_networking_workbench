extends ColorRect

# command for running locally on the unix partition
# /mnt/c/Users/henry/godot/Godot_v3.2.3-stable_linux_server.64 --main-pack /mnt/c/Users/henry/godot/games/OQ_Networking_Demo/releases/OQ_Networking_Demo.pck
export var playernodepath : NodePath = "/root/Main/Players"
onready var PlayersNode = get_node(playernodepath)
var LocalPlayer = null

var deferred_playerconnections = [ ]
var remote_players_idstonodenames = { }
var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", "Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]

onready var NetworkGateway = get_node("..")
var webrtc_server_relay = false

func _ready():
	assert (PlayersNode.get_child_count() == 1) 
	LocalPlayer = PlayersNode.get_child(0)
	if not LocalPlayer.has_node("PlayerFrame"):
		var playerframe = Node.new()
		playerframe.name = "PlayerFrame"
		playerframe.set_script(load("res://networking/PlayerFrameLocal.gd"))
		LocalPlayer.add_child(playerframe)
	else:
		assert (LocalPlayer.get_node("PlayerFrame").get_script().resource_path == "res://networking/PlayerFrameLocal.gd")
	LocalPlayer.get_node("PlayerFrame").PlayerConnections = self

	randomize()
	var randomplayername = possibleusernames[randi()%len(possibleusernames)]
	LocalPlayer.rect_position.y += randi()%300
	print(LocalPlayer.modulate)
	LocalPlayer.modulate = Color.yellow
	LocalPlayer.initavatar({"labeltext":randomplayername})

	get_tree().connect("network_peer_connected", self, "network_player_connected")
	get_tree().connect("network_peer_disconnected", self, "network_player_disconnected")

	get_tree().connect("connected_to_server", self, "clientplayer_connected_to_server")
	get_tree().connect("connection_failed", self, "clientplayer_connection_failed")
	get_tree().connect("server_disconnected", self, "clientplayer_server_disconnected")

	LocalPlayer.networkID = 0
	LocalPlayer.set_name("R%d" % LocalPlayer.networkID) 


func connectionlog(txt):
	$ConnectionLog.text += txt
	var cl = $ConnectionLog.get_line_count()
	$ConnectionLog.cursor_set_line(cl)

func SetNetworkedMultiplayerPeer(peer):
	assert (peer != null)
	get_tree().set_network_peer(peer)
	if get_tree().is_network_server():
		networkplayer_connected_to_server(true)
	else:
		LocalPlayer.networkID = -1

func clientplayer_server_disconnected():
	networkplayer_server_disconnected(false)
	
	
func networkplayer_server_disconnected(serverisself):
	connectionlog("_server(self) disconnect\n" if serverisself else "_server disconnect\n")
	var ns = NetworkGateway.get_node("NetworkOptions").selected
	print("(networkplayer_server_disconnected ", serverisself)
	get_tree().set_network_peer(null)
	print("setnetworkpeer null")
	LocalPlayer.networkID = 0
	LocalPlayer.set_name("R%d" % LocalPlayer.networkID) 
	deferred_playerconnections.clear()
	for id in remote_players_idstonodenames.duplicate():
		network_player_disconnected(id)
	print("*** _server_disconnected ", LocalPlayer.networkID)
	updateplayerlist()
	if NetworkGateway.get_node("ProtocolOptions").selected == NetworkGateway.NETWORK_PROTOCOL.ENET:
		NetworkGateway.get_node("ENetMultiplayer/Servermode/StartENetmultiplayer").pressed = false
		NetworkGateway.get_node("ENetMultiplayer/Clientmode/StartENetmultiplayer").pressed = false
	if NetworkGateway.get_node("ProtocolOptions").selected == NetworkGateway.NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
		NetworkGateway.get_node("MQTTsignalling/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer").pressed = false
		NetworkGateway.get_node("MQTTsignalling/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer").pressed = false
		NetworkGateway.get_node("NetworkOptionsMQTTWebRTC").selected = NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF
	else:
		NetworkGateway.get_node("NetworkOptions").selected = NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF
		

func clientplayer_connected_to_server():
	networkplayer_connected_to_server(false)
	
func force_server_disconnect():
	if get_tree().get_network_peer() != null:
		var serverisself = get_tree().is_network_server()
		networkplayer_server_disconnected(serverisself)

func networkplayer_connected_to_server(serverisself):
	connectionlog("_server(self) connect\n" if serverisself else "_server connect\n")
	LocalPlayer.networkID = get_tree().get_network_unique_id()
	assert (LocalPlayer.networkID >= 1)
	LocalPlayer.set_name("R%d" % LocalPlayer.networkID)
	connectionlog("_my networkid=%d\n" % LocalPlayer.networkID)
	print("my playerid=", LocalPlayer.networkID)
	for id in deferred_playerconnections:
		network_player_added(id, false)
	deferred_playerconnections.clear()
	updateplayerlist()
		

func clientplayer_connection_failed():
	connectionlog("_connection failed\n")
	NetworkGateway.setnetworkoff()
	
func updateplayerlist():
	var plp = $PlayerList.get_item_text($PlayerList.selected).split(" ")[0].replace("*", "")
	$PlayerList.clear()
	$PlayerList.selected = 0
	for player in PlayersNode.get_children():
		$PlayerList.add_item(("*" if player == LocalPlayer else "") + player.get_name() + " " + player.text)
		if plp == player.get_name():
			$PlayerList.selected = $PlayerList.get_item_count() - 1

func network_player_connected(id):
	print("NNnetwork_player_connected ", id, "  Lid ", LocalPlayer.networkID)

	# tests here to work out if connections are being made before all the channels are completely ready!
	var Dpeer = get_tree().get_network_peer()
	if Dpeer is WebRTCMultiplayer:
		var DDpeer = Dpeer.get_peer(id)
		print("DDpeer ", DDpeer)
		for channel in DDpeer["channels"]:
			print("channel readystate ", channel, " ", channel.get_ready_state())
		#print(Dpeer.get_connection_state())
		
	if LocalPlayer.networkID == -1:
		deferred_playerconnections.push_back(id)
		connectionlog("_add playerid %d (defer)\n" % id)
	else:
		network_player_added(id, false)

func network_player_added(id, via_server_relay):
	connectionlog("_add playerid %d\n" % id)
	assert (LocalPlayer.networkID >= 1)
	assert (not remote_players_idstonodenames.has(id))
	remote_players_idstonodenames[id] = null
	print("players_connected_list: ", remote_players_idstonodenames)
	var avatardata = LocalPlayer.avatarinitdata()
	avatardata["framedata0"] = LocalPlayer.get_node("PlayerFrame").framedata0
	print("calling spawnintoremoteplayer at ", id, " (from ", LocalPlayer.networkID, ")", (" via serverrelay" if via_server_relay else ""))
	#yield(get_tree().create_timer(1.0), "timeout")   # allow for webrtc to complete connection
	if not via_server_relay:
		rpc_id(id, "spawnintoremoteplayer", avatardata)
	else:
		rpc_id(1, "spawnintoremoteplayer_relay", id, avatardata)
	if webrtc_server_relay:
		for fid in remote_players_idstonodenames:
			if fid != id:
				print(" sending between-link serverrelay_network_player_added ", id, " ", fid)
				rpc_id(fid, "serverrelay_network_player_added", id)				
				rpc_id(id, "serverrelay_network_player_added", fid)


func network_player_disconnected(id):
	network_player_removed(id, false)
				
func network_player_removed(id, via_server_relay):
	connectionlog("_remove playerid %d\n" % id)
	assert (remote_players_idstonodenames.has(id))
	var remoteplayernodename = remote_players_idstonodenames[id]
	remote_players_idstonodenames.erase(id)
	if remoteplayernodename != null:
		removeremoteplayer(remoteplayernodename)
	print("players_connected_list: ", remote_players_idstonodenames)
	updateplayerlist()
	if webrtc_server_relay:
		assert (not via_server_relay)
		for fid in remote_players_idstonodenames:
			rpc_id(fid, "serverrelay_network_player_disconnected", id)
			
remote func serverrelay_network_player_added(id):
	print("serverrelay_network_player_added ", id)
	assert (id != get_tree().get_network_unique_id())
	network_player_added(id, true)

remote func serverrelay_network_player_disconnected(id):
	assert (id != get_tree().get_network_unique_id())
	network_player_removed(id, true)

func _on_Doppelganger_toggled(button_pressed):
	var DoppelgangerPanel = get_node("../DoppelgangerPanel")
	if button_pressed:
		#DoppelgangerPanel.visible = true
		DoppelgangerPanel.get_node("netoffset").editable = false
		DoppelgangerPanel.get_node("netdelaymin").editable = false
		var avatardata = LocalPlayer.avatarinitdata()
		avatardata["playernodename"] = "Doppelganger"
		var fd = LocalPlayer.get_node("PlayerFrame").framedata0.duplicate()
		#LocalPlayer.changethinnedframedatafordoppelganger(fd)
		#avatardata["framedata0"] = fd
		LocalPlayer.get_node("PlayerFrame").doppelgangernode = newremoteplayer(avatardata)
		LocalPlayer.get_node("PlayerFrame").NetworkGatewayForDoppelganger = get_node("..")
	else:
		#DoppelgangerPanel.visible = false
		DoppelgangerPanel.get_node("netoffset").editable = true
		DoppelgangerPanel.get_node("netdelaymin").editable = true
		LocalPlayer.get_node("PlayerFrame").doppelgangernode = null
		LocalPlayer.get_node("PlayerFrame").NetworkGatewayForDoppelganger = null
		removeremoteplayer("Doppelganger")
	updateplayerlist()


remote func spawnintoremoteplayer_relay(rpcid, avatardata):
	assert (get_tree().is_network_server())
	assert (get_tree().get_network_unique_id() == 1)
	rpc_id(rpcid, "spawnintoremoteplayer", avatardata)

remote func spawnintoremoteplayer(avatardata):
	var senderid = avatardata["networkid"]
	var rpcsenderid = get_tree().get_rpc_sender_id()
	print("rec spawnintoremoteplayer from ", senderid, (" (server_relayed)" if senderid != rpcsenderid else ""))
	connectionlog("spawn playerid %d\n" % senderid)
	var remoteplayer = newremoteplayer(avatardata)
	assert (senderid == avatardata["networkid"])
	remoteplayer.get_node("PlayerFrame").set_network_master(senderid)
	assert (remote_players_idstonodenames[senderid] == null)
	remote_players_idstonodenames[senderid] = remoteplayer.get_name()
	updateplayerlist()

remote func networkedavatarthinnedframedataPC(vd):
	var rpcsenderid = get_tree().get_rpc_sender_id()
	var remoteplayer = PlayersNode.get_node_or_null(vd["playernodename"])
	if remoteplayer != null:
		remoteplayer.get_node("PlayerFrame").networkedavatarthinnedframedata(vd)
		get_node("../TimelineVisualizer/Viewport/TimelineDiagram").marknetworkdataat(vd)
	else:
		print("networkedavatarthinnedframedataPC called before spawning")
	if webrtc_server_relay:
		for fid in remote_players_idstonodenames:
			if fid != rpcsenderid:
				rpc_id(fid, "networkedavatarthinnedframedataPC", vd)
	
func newremoteplayer(avatardata):
	var remoteplayer = PlayersNode.get_node_or_null(avatardata["playernodename"])
	if remoteplayer == null:
		remoteplayer = load(avatardata["avatarsceneresource"]).instance()
		if not remoteplayer.has_node("PlayerFrame"):
			var playerframe = Node.new()
			playerframe.name = "PlayerFrame"
			playerframe.set_script(load("res://networking/PlayerFrameRemote.gd"))
			remoteplayer.add_child(playerframe)
		remoteplayer.initavatar(avatardata)
		PlayersNode.add_child(remoteplayer)
		if "framedata0" in avatardata:
			remoteplayer.get_node("PlayerFrame").networkedavatarthinnedframedata(avatardata["framedata0"])
		print("Adding remoteplayer: ", avatardata["playernodename"])
		get_node("../TimelineVisualizer/Viewport/TimelineDiagram").newtimelineremoteplayer(avatardata)
	else:
		print("** remoteplayer already exists: ", avatardata["playernodename"])
	return remoteplayer
	
func removeremoteplayer(playernodename):
	var remoteplayer = PlayersNode.get_node_or_null(playernodename)
	if remoteplayer != null:
		PlayersNode.remove_child(remoteplayer)
		remoteplayer.queue_free()
		print("Removing remoteplayer: ", playernodename)
		get_node("../TimelineVisualizer/Viewport/TimelineDiagram").removetimelineremoteplayer(playernodename)
	else:
		print("** remoteplayer already removed: ", playernodename)
	
