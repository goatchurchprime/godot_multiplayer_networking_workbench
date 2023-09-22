extends ColorRect

@onready var playerframelocalgdscriptfile = get_parent().scene_file_path.get_base_dir() + "/PlayerFrameLocal.gd"
@onready var playerframeremotegdscriptfile = get_parent().scene_file_path.get_base_dir() + "/PlayerFrameRemote.gd"

var LocalPlayer = null
var ServerPlayer = null

var deferred_playerconnections = [ ]
var remote_players_idstonodenames = { }

@onready var NetworkGateway = get_node("..")
@onready var PlayersNode = get_node(NetworkGateway.playersnodepath)

@onready var PlayerList = $HBoxMain/VBoxContainer/HBox_players/PlayerList

func _ready():
	if PlayersNode.get_child_count() == 1 and NetworkGateway.localplayerscene:
		PlayersNode.get_child(0).free()
	if PlayersNode.get_child_count() == 0:
		PlayersNode.add_child(load(NetworkGateway.localplayerscene).instantiate())
	assert (PlayersNode.get_child_count() == 1) 

	LocalPlayer = PlayersNode.get_child(0)
	if not LocalPlayer.has_node("PlayerFrame"):
		var playerframe = Node.new()
		playerframe.name = "PlayerFrame"
		playerframe.set_script(load(playerframelocalgdscriptfile))
		LocalPlayer.add_child(playerframe)
	else:
		assert (LocalPlayer.get_node("PlayerFrame").get_script().resource_path == playerframelocalgdscriptfile)
	LocalPlayer.get_node("PlayerFrame").PlayerConnections = self

	LocalPlayer.PAV_initavatarlocal()

	multiplayer.peer_connected.connect(network_player_connected)
	multiplayer.peer_disconnected.connect(network_player_disconnected)

	multiplayer.connected_to_server.connect(clientplayer_connected_to_server)
	multiplayer.connection_failed.connect(clientplayer_connection_failed)
	multiplayer.server_disconnected.connect(clientplayer_server_disconnected)

	LocalPlayer.get_node("PlayerFrame").networkID = 0
	LocalPlayer.set_name("R%d" % LocalPlayer.get_node("PlayerFrame").networkID) 


func connectionlog(txt):
	$HBoxMain/ConnectionLog.text += txt
	var cl = $HBoxMain/ConnectionLog.get_line_count()
	$HBoxMain/ConnectionLog.set_caret_line(cl)

func clearconnectionlog():
	$HBoxMain/ConnectionLog.text = ""

func network_player_notyetconnected():
	assert (not multiplayer.is_server())
	LocalPlayer.get_node("PlayerFrame").networkID = -1

func clientplayer_server_disconnected():
	networkplayer_server_disconnected(false)
	
func networkplayer_server_disconnected(serverisself):
	connectionlog("_server(self) disconnect\n" if serverisself else "_server disconnect\n")
	var ns = NetworkGateway.get_node("NetworkOptions").selected
	print("(networkplayer_server_disconnected ", serverisself)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("setnetworkpeer OfflineMultiplayerPeer")
	LocalPlayer.get_node("PlayerFrame").networkID = 0
	LocalPlayer.set_name("R%d" % LocalPlayer.get_node("PlayerFrame").networkID) 
	deferred_playerconnections.clear()
	for id in remote_players_idstonodenames.duplicate():
		network_player_disconnected(id)
	print("*** _server_disconnected ", LocalPlayer.get_node("PlayerFrame").networkID)
	updateplayerlist()
	if NetworkGateway.get_node("ProtocolOptions").selected == NetworkGateway.NETWORK_PROTOCOL.ENET:
		NetworkGateway.get_node("ENetMultiplayer/Servermode/StartENetmultiplayer").button_pressed = false
		NetworkGateway.get_node("ENetMultiplayer/Clientmode/StartENetmultiplayer").button_pressed = false
	if NetworkGateway.get_node("ProtocolOptions").selected == NetworkGateway.NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
		NetworkGateway.get_node("MQTTsignalling/Servermode/WebRTCmultiplayerserver/StartWebRTCmultiplayer").button_pressed = false
		NetworkGateway.get_node("MQTTsignalling/Clientmode/WebRTCmultiplayerclient/StartWebRTCmultiplayer").button_pressed = false
		NetworkGateway.get_node("NetworkOptionsMQTTWebRTC").selected = NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF
	else:
		NetworkGateway.get_node("NetworkOptions").selected = NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF
		

func clientplayer_connected_to_server():
	networkplayer_connected_to_server()
	
func force_server_disconnect():
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		var serverisself = multiplayer.is_server()
		networkplayer_server_disconnected(serverisself)

func networkplayer_connected_to_server():
	var serverisself = multiplayer.is_server()
	LocalPlayer.PAV_clientawaitingspawnpoint = (1 if not serverisself else 0)
	connectionlog("_server(self) connect\n" if serverisself else "_server connect\n")
	LocalPlayer.get_node("PlayerFrame").networkID = multiplayer.get_unique_id()
	assert (LocalPlayer.get_node("PlayerFrame").networkID >= 1)
	LocalPlayer.set_name("R%d" % LocalPlayer.get_node("PlayerFrame").networkID)
	connectionlog("_my networkid=%d\n" % LocalPlayer.get_node("PlayerFrame").networkID)
	print("my playerid=", LocalPlayer.get_node("PlayerFrame").networkID)
	for id in deferred_playerconnections:
		network_player_added(id)
	deferred_playerconnections.clear()
	updateplayerlist()

func clientplayer_connection_failed():
	connectionlog("_connection failed\n")
	NetworkGateway.setnetworkoff()
	
func updateplayerlist():
	var plp = PlayerList.get_item_text(PlayerList.selected).split(" ")[0].replace("*", "")
	PlayerList.clear()
	PlayerList.selected = 0
	for player in PlayersNode.get_children():
		PlayerList.add_item(("*" if player == LocalPlayer else "") + (player.playername() if player.has_method("playername") else player.get_name()))
		if plp == player.get_name():
			PlayerList.selected = PlayerList.get_item_count() - 1


func network_player_connected(id):
	print("NNnetwork_player_connected ", id, "  Lid ", LocalPlayer.get_node("PlayerFrame").networkID)
	if LocalPlayer.get_node("PlayerFrame").networkID == -1:
		deferred_playerconnections.push_back(id)
		connectionlog("_add playerid %d (defer)\n" % id)
	else:
		network_player_added(id)

func network_player_added(id):
	connectionlog("_add playerid %d\n" % id)
	var serverisself = multiplayer.is_server()
	assert (LocalPlayer.get_node("PlayerFrame").networkID >= 1)
	assert (not remote_players_idstonodenames.has(id))
	remote_players_idstonodenames[id] = null
	print("players_connected_list: ", remote_players_idstonodenames)
	var avatardata = LocalPlayer.PAV_avatarinitdata()
	avatardata["playernodename"] = LocalPlayer.get_name()
	avatardata["networkid"] = LocalPlayer.get_node("PlayerFrame").networkID
	if LocalPlayer.PAV_clientawaitingspawnpoint == 0:
		avatardata["framedata0"] = LocalPlayer.get_node("PlayerFrame").framedata0.duplicate()
		avatardata["framedata0"].erase(NCONSTANTS.CFI_TIMESTAMP_F0)
	if serverisself:
		avatardata["spawnframedata"] = LocalPlayer.PAV_createspawnpoint()
	print("calling spawnintoremoteplayer at ", id, " (from ", LocalPlayer.get_node("PlayerFrame").networkID, ") ", ("with spawndata" if serverisself else ""))
	rpc_id(id, "spawnintoremoteplayer", avatardata)
	

func network_player_disconnected(id):
	network_player_removed(id)
				
func network_player_removed(id):
	connectionlog("_remove playerid %d\n" % id)
	assert (remote_players_idstonodenames.has(id))
	var remoteplayernodename = remote_players_idstonodenames[id]
	remote_players_idstonodenames.erase(id)
	if remoteplayernodename != null:
		removeremoteplayer(remoteplayernodename)
	print("players_connected_list: ", remote_players_idstonodenames)
	updateplayerlist()
			

func _on_Doppelganger_toggled(button_pressed):
	var DoppelgangerPanel = get_node("../DoppelgangerPanel")
	if button_pressed:
		#DoppelgangerPanel.visible = true
		DoppelgangerPanel.seteditable(false)
		var avatardata = LocalPlayer.PAV_avatarinitdata()
		avatardata["playernodename"] = "Doppelganger"
		avatardata["networkid"] = LocalPlayer.get_node("PlayerFrame").networkID
		var fd = LocalPlayer.get_node("PlayerFrame").framedata0.duplicate()
		fd[NCONSTANTS.CFI_TIMESTAMP] = fd[NCONSTANTS.CFI_TIMESTAMP_F0]
		fd.erase(NCONSTANTS.CFI_TIMESTAMP_F0)
		var doppelnetoffset = get_node("../DoppelgangerPanel").getnetoffset()
		LocalPlayer.PAV_changethinnedframedatafordoppelganger(fd, doppelnetoffset, true)
		avatardata["framedata0"] = fd
		var doppelgangerdelay = get_node("..").getrandomdoppelgangerdelay(true)
		await get_tree().create_timer(doppelgangerdelay*0.001).timeout
		LocalPlayer.get_node("PlayerFrame").doppelgangernode = newremoteplayer(avatardata)
		LocalPlayer.get_node("PlayerFrame").NetworkGatewayForDoppelganger = get_node("..")
	else:
		DoppelgangerPanel.seteditable(true)
		LocalPlayer.get_node("PlayerFrame").doppelgangernode = null
		LocalPlayer.get_node("PlayerFrame").NetworkGatewayForDoppelganger = null
		removeremoteplayer("Doppelganger")
	updateplayerlist()


@rpc("any_peer") func spawnintoremoteplayer(avatardata):
	var senderid = avatardata["networkid"]
	var rpcsenderid = multiplayer.get_remote_sender_id()
	print("rec spawnintoremoteplayer from ", senderid)
	connectionlog("spawn playerid %d\n" % senderid)
	var remoteplayer = newremoteplayer(avatardata)
	assert (senderid == avatardata["networkid"])
	remoteplayer.get_node("PlayerFrame").set_multiplayer_authority(senderid)
	assert (remote_players_idstonodenames[senderid] == null)
	remote_players_idstonodenames[senderid] = remoteplayer.get_name()
	updateplayerlist()

@rpc("any_peer") func networkedavatarthinnedframedataPC(vd):
	var rpcsenderid = multiplayer.get_remote_sender_id()
	var remoteplayer = PlayersNode.get_node_or_null(String(vd[NCONSTANTS.CFI_PLAYER_NODENAME]))
	if remoteplayer != null:
		remoteplayer.get_node("PlayerFrame").networkedavatarthinnedframedata(vd)
	else:
		print("networkedavatarthinnedframedataPC called before spawning")
	
func newremoteplayer(avatardata):
	print(avatardata)
	print(avatardata["playernodename"])
	print("::"+avatardata["playernodename"] + ";;")
	var remoteplayer = PlayersNode.get_node_or_null(String(avatardata["playernodename"]))
	if remoteplayer == null:
		remoteplayer = load(avatardata["avatarsceneresource"]).instantiate()
		if not remoteplayer.has_node("PlayerFrame"):
			var playerframe = Node.new()
			playerframe.name = "PlayerFrame"
			playerframe.set_script(load(playerframeremotegdscriptfile))
			remoteplayer.add_child(playerframe)
		remoteplayer.set_name(avatardata["playernodename"])
		remoteplayer.get_node("PlayerFrame").networkID = avatardata["networkid"]
		remoteplayer.PAV_initavatarremote(avatardata)
		remoteplayer.visible = false
		PlayersNode.add_child(remoteplayer)
		if remoteplayer.get_node("PlayerFrame").networkID == 1:
			ServerPlayer = remoteplayer
		if "framedata0" in avatardata:
			remoteplayer.get_node("PlayerFrame").networkedavatarthinnedframedata(avatardata["framedata0"])
			remoteplayer.visible = true
		if "spawnframedata" in avatardata:
			LocalPlayer.PAV_receivespawnpoint(avatardata["spawnframedata"])
			
		print("Adding remoteplayer: ", avatardata["playernodename"])
	else:
		print("** remoteplayer already exists: ", avatardata["playernodename"])
	return remoteplayer
	
func removeremoteplayer(playernodename):
	var remoteplayer = PlayersNode.get_node_or_null(String(playernodename))
	if remoteplayer != null:
		if remoteplayer.get_node("PlayerFrame").networkID == 1:
			ServerPlayer = null
		PlayersNode.remove_child(remoteplayer)
		remoteplayer.queue_free()
		print("Removing remoteplayer: ", playernodename)
		if get_node("../TimelineVisualizer").visible:
			get_node("../TimelineVisualizer/SubViewport/TimelineDiagram").removetimelineremoteplayer(playernodename)
	else:
		print("** remoteplayer already removed: ", playernodename)
	

func _on_PlayerList_item_selected(index):
	var player = PlayersNode.get_child(index)
	$HBoxMain/VBoxContainer/HBoxLag/PlayerLagSlider.value = 0.0 if player == LocalPlayer else player.get_node("PlayerFrame").laglatency
	
func _on_PlayerLagSlider_value_changed(value):
	var player = PlayersNode.get_child(PlayerList.selected)
	if player != LocalPlayer:
		player.get_node("PlayerFrame").laglatency = value


