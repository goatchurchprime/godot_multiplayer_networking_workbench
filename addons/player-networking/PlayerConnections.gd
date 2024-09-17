extends Control


## PlayerConnections 
##
## This object receives and manages all networked multiplayer connections and 
## disconnections


# We should implement this to log what passes through
# https://docs.godotengine.org/en/stable/classes/class_multiplayerapiextension.html

@onready var NetworkGateway = find_parent("NetworkGateway")
@onready var playerframelocalgdscriptfile = NetworkGateway.scene_file_path.get_base_dir() + "/PlayerFrameLocal.gd"
@onready var playerframeremotegdscriptfile = NetworkGateway.scene_file_path.get_base_dir() + "/PlayerFrameRemote.gd"

var LocalPlayer = null    # Points into Players for my current self
var ServerPlayer = null   # Should be myself if I am a server

# Temporary list of _peer_connected signals received (out of order) before the 
# _connected_to_server signal.  Can only happen on a client
var deferred_playerconnections = null

# Mapping required by the _peer_disconnected function to know which 
# player node to remove
var remote_players_idstonodenames = { }

@onready var PlayersNode = NetworkGateway.get_node_or_null(NetworkGateway.playersnodepath)
@onready var PlayerList = $VBox/HBox/PlayerList

var multiplayersignalsconnected = false
func connect_multiplayersignals():
	if not multiplayersignalsconnected:
		# Signals received on behalf of any other player in the network 
		# including the server.  These are are sent by a new player to 
		# all other players and by all other players to the new player
		multiplayer.peer_connected.connect(_peer_connected)
		multiplayer.peer_disconnected.connect(_peer_disconnected)

		# signals generated only in the client.  These functions are 
		# mamnually called at the startup of the server code code simplicity
		multiplayer.connected_to_server.connect(_connected_to_server)
		multiplayer.connection_failed.connect(_connection_failed)
		multiplayer.server_disconnected.connect(_server_disconnected)
		multiplayersignalsconnected = true

func _ready():
	assert (PlayerList.item_count == 1)
	if PlayerList.selected == -1:  PlayerList.selected = 0


	# Overwrite the localplayer node if the local player scene is defined
	if PlayersNode.get_child_count() == 1 and NetworkGateway.localplayerscene:
		PlayersNode.get_child(0).free()
	if PlayersNode.get_child_count() == 0:
		var g = load(NetworkGateway.localplayerscene)
		PlayersNode.add_child(load(NetworkGateway.localplayerscene).instantiate())
	assert (PlayersNode.get_child_count() == 1) 

	# Insert a player frame below the local player if necessary
	LocalPlayer = PlayersNode.get_child(0)
	if not LocalPlayer.has_node("PlayerFrame"):
		var playerframe = Node.new()
		playerframe.name = "PlayerFrame"
		playerframe.set_script(load(playerframelocalgdscriptfile))
		LocalPlayer.add_child(playerframe)
	else:
		print(LocalPlayer.get_node("PlayerFrame").get_script().resource_path)
		assert (LocalPlayer.get_node("PlayerFrame").get_script().resource_path == playerframelocalgdscriptfile)
	LocalPlayer.get_node("PlayerFrame").PlayerConnections = self

	LocalPlayer.PF_initlocalplayer()

	LocalPlayer.get_node("PlayerFrame").networkID = 0
	LocalPlayer.set_name("R%d" % LocalPlayer.get_node("PlayerFrame").networkID) 


var prevtxt = ""
func clearconnectionlog():
	$VBox/ConnectionLog.text = ""
	prevtxt = ""

func connectionlog(txt):
	if not txt.ends_with("\n"):
		if txt == prevtxt:
			$VBox/ConnectionLog.text += "."
		else:
			if prevtxt != "":
				$VBox/ConnectionLog.text += "\n"
			$VBox/ConnectionLog.text += txt
			prevtxt = txt
	else:
		$VBox/ConnectionLog.text += txt
		prevtxt = ""
	var cl = $VBox/ConnectionLog.get_line_count()
	$VBox/ConnectionLog.set_caret_line(cl)

func _connected_to_server():
	var serverisself = multiplayer.is_server()
	connectionlog("_server(self) connect\n" if serverisself else "_server connect\n")
	if LocalPlayer:
		LocalPlayer.get_node("PlayerFrame").networkID = multiplayer.get_unique_id()
		assert (LocalPlayer.get_node("PlayerFrame").networkID >= 1)
		LocalPlayer.set_name("R%d" % LocalPlayer.get_node("PlayerFrame").networkID)
		connectionlog("_my networkid=%d\n" % LocalPlayer.get_node("PlayerFrame").networkID)
		print("my playerid=", LocalPlayer.get_node("PlayerFrame").networkID)
		LocalPlayer.PF_connectedtoserver()
	NetworkGateway.Dconnectedplayerscount += 1  
	assert (NetworkGateway.Dconnectedplayerscount == 1)

	# act on the prematurely received _peer_connected signals
	if deferred_playerconnections != null:
		var ldeferred_playerconnections = deferred_playerconnections
		deferred_playerconnections = null
		for id in ldeferred_playerconnections:
			_peer_connected(id)

	updateplayerlist()
	if NetworkGateway.ProtocolOptions.selected == NetworkGateway.NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
		NetworkGateway.MQTTsignalling.StatusWebRTC.text = "connected"

func _connection_failed():
	connectionlog("_connection failed\n")
	if NetworkGateway.ProtocolOptions.selected == NetworkGateway.NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
		NetworkGateway.MQTTsignalling.StatusWebRTC.text = "failed"
	NetworkGateway.setnetworkoff()

func _server_disconnected():
	deferred_playerconnections = null
	if (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		NetworkGateway.Dconnectedplayerscount -= 1
		assert (NetworkGateway.Dconnectedplayerscount == 0)
		return
	connectionlog("_server(self) disconnect\n")
	var ns = NetworkGateway.NetworkOptions.selected
	print("(networkplayer_server_disconnected ")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("setnetworkpeer OfflineMultiplayerPeer")
	LocalPlayer.get_node("PlayerFrame").networkID = 0
	LocalPlayer.set_name("R%d" % LocalPlayer.get_node("PlayerFrame").networkID) 
	for id in remote_players_idstonodenames.duplicate():
		_peer_disconnected(id)
	prints("svedisconnected ", NetworkGateway.Dconnectedplayerscount, multiplayer.get_unique_id())
	NetworkGateway.Dconnectedplayerscount -= 1
	assert (NetworkGateway.Dconnectedplayerscount == 0)
	print("*** _server_disconnected ", LocalPlayer.get_node("PlayerFrame").networkID)
	updateplayerlist()
	if NetworkGateway.ProtocolOptions.selected == NetworkGateway.NETWORK_PROTOCOL.ENET:
		NetworkGateway.ENetMultiplayer.get_node("HBox/Servermode/StartENetmultiplayer").set_pressed_no_signal(false)
		NetworkGateway.ENetMultiplayer.get_node("HBox/Clientmode/StartENetmultiplayer").set_pressed_no_signal(false)
	if NetworkGateway.ProtocolOptions.selected == NetworkGateway.NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
		NetworkGateway.selectandtrigger_networkoption(NetworkGateway.NETWORK_OPTIONS_MQTT_WEBRTC.NETWORK_OFF)
	else:
		NetworkGateway.NetworkOptions.selected = NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF
		
func updateplayerlist():
	var plp = PlayerList.get_item_text(PlayerList.selected).split(" ")[0].replace("*", "").replace("&", "")
	PlayerList.clear()
	PlayerList.selected = 0
	for player in PlayersNode.get_children():
		PlayerList.add_item(("*" if player == LocalPlayer else "") + ("&" if player == ServerPlayer else "") + (player.playername() if player.has_method("playername") else player.get_name()))
		if plp == player.get_name():
			PlayerList.selected = PlayerList.get_item_count() - 1

func _peer_connected(id):
	if deferred_playerconnections != null:
		deferred_playerconnections.push_back(id)
		connectionlog("_add playerid %d (defer)\n" % id)
		return
	assert (NetworkGateway.Dconnectedplayerscount >= 1)
	NetworkGateway.Dconnectedplayerscount += 1
	connectionlog("_add playerid %d\n" % id)
	var serverisself = multiplayer.is_server()
	assert (LocalPlayer.get_node("PlayerFrame").networkID >= 1)
	assert (not remote_players_idstonodenames.has(id))
	remote_players_idstonodenames[id] = null
	print("players_connected_list: ", remote_players_idstonodenames)
	var avatardata = LocalPlayer.PF_datafornewconnectedplayer()
	avatardata["playernodename"] = LocalPlayer.get_name()
	avatardata["networkid"] = LocalPlayer.get_node("PlayerFrame").networkID
	print("calling spawnintoremoteplayer at ", id, " (from ", LocalPlayer.get_node("PlayerFrame").networkID, ") ", ("with spawndata" if serverisself else ""))
	rpc_id(id, "RPCspawnintoremoteplayer", avatardata)

func _peer_disconnected(id):
	connectionlog("_remove playerid %d\n" % id)
	prints("hhhh ", NetworkGateway.Dconnectedplayerscount, id, multiplayer.get_unique_id())
	NetworkGateway.Dconnectedplayerscount -= 1
	assert (NetworkGateway.Dconnectedplayerscount >= 1)
	assert (remote_players_idstonodenames.has(id))
	var remoteplayernodename = remote_players_idstonodenames[id]
	remote_players_idstonodenames.erase(id)
	if remoteplayernodename != null:
		removeremoteplayer(remoteplayernodename)
	print("players_connected_list: ", remote_players_idstonodenames)
	updateplayerlist()
			

func _on_Doppelganger_toggled(button_pressed):
	var pf = LocalPlayer.get_node("PlayerFrame")
	var DoppelgangerPanel = get_node("../DoppelgangerPanel")
	if button_pressed:
		#DoppelgangerPanel.visible = true
		var rlogrecfile = null
		print(DoppelgangerPanel.get_node("hbox/VBox_enable/chooselogrec").selected)
		if DoppelgangerPanel.get_node("hbox/VBox_enable/chooselogrec").selected == 1:
			rlogrecfile = FileAccess.open("user://logrec.dat", FileAccess.READ)
		DoppelgangerPanel.seteditable(false)
		if rlogrecfile == null:
			var avatardata = LocalPlayer.PF_datafornewconnectedplayer()
			avatardata["playernodename"] = "Doppelganger"
			avatardata.erase("spawnframedata")
			avatardata["networkid"] = LocalPlayer.get_node("PlayerFrame").networkID
			var fd = LocalPlayer.get_node("PlayerFrame").framedata0.duplicate()
			fd[NCONSTANTS.CFI_TIMESTAMP] = fd[NCONSTANTS.CFI_TIMESTAMP_F0]
			fd.erase(NCONSTANTS.CFI_TIMESTAMP_F0)
			var doppelnetoffset = DoppelgangerPanel.getnetoffset()
			LocalPlayer.PF_changethinnedframedatafordoppelganger(fd, doppelnetoffset, true)
			avatardata["framedata0"] = fd
			var doppelgangerdelay = NetworkGateway.getrandomdoppelgangerdelay(true)
			await get_tree().create_timer(doppelgangerdelay*0.001).timeout
			pf.doppelgangernode = newremoteplayer(avatardata)
			pf.NetworkGatewayForDoppelganger = NetworkGateway
		else:
			var avatardata = rlogrecfile.get_var()
			avatardata["playernodename"] = "Logrecreplay"
			avatardata["networkid"] = LocalPlayer.get_node("PlayerFrame").networkID
			avatardata["labeltext"] = avatardata["playername"]
			pf.doppelgangernode = newremoteplayer(avatardata)
			var df = pf.doppelgangernode.get_node("PlayerFrame")
			df.doppelgangerrecfile = rlogrecfile
			df.doppelgangernextrec = df.doppelgangerrecfile.get_var()
			df.doppelgangerrectimeoffset = avatardata.t - Time.get_ticks_msec()*0.001
			df.NetworkGatewayForDoppelgangerReplay = NetworkGateway

	else:
		DoppelgangerPanel.seteditable(true)
		var df = pf.doppelgangernode.get_node("PlayerFrame")
		if df.doppelgangerrecfile != null:
			df.doppelgangerrecfile.close()
			df.doppelgangerrecfile = null
			df.doppelgangernextrec = null
			df.NetworkGatewayForDoppelgangerReplay = null
		removeremoteplayer(pf.doppelgangernode.get_name())
		pf.doppelgangernode = null
		pf.NetworkGatewayForDoppelganger = null

	updateplayerlist()

@rpc("any_peer", "call_remote", "reliable", 0)
func RPCspawnintoremoteplayer(avatardata):
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

@rpc("any_peer", "call_remote", "reliable", 0)
func RPCnetworkedavatarthinnedframedataPC(vd):
	var rpcsenderid = multiplayer.get_remote_sender_id()
	var remoteplayer = PlayersNode.get_node_or_null(String(vd[NCONSTANTS.CFI_PLAYER_NODENAME]))
	if remoteplayer != null:
		remoteplayer.get_node("PlayerFrame").networkedavatarthinnedframedata(vd)
	else:
		print("networkedavatarthinnedframedataPC called before spawning")

@rpc("any_peer", "call_remote", "unreliable", 0) 
func RPCincomingaudiopacket(packet):
	var rpcsenderid = multiplayer.get_remote_sender_id()
	var remoteplayernodename = remote_players_idstonodenames[rpcsenderid]
	var remoteplayer = PlayersNode.get_node_or_null(String(remoteplayernodename))
	if remoteplayer != null:
		remoteplayer.get_node("PlayerFrame").incomingaudiopacket(packet)
	
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
		remoteplayer.PF_startupdatafromconnectedplayer(avatardata, LocalPlayer)
		PlayersNode.add_child(remoteplayer)
		if remoteplayer.get_node("PlayerFrame").networkID == 1:
			ServerPlayer = remoteplayer
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
	else:
		print("** remoteplayer already removed: ", playernodename)
	

func _on_PlayerList_item_selected(index):
	var player = PlayersNode.get_child(index)
	$VBox/HBox/PlayerLagSlider.value = 0.0 if player == LocalPlayer else player.get_node("PlayerFrame").laglatency
	
func _on_PlayerLagSlider_value_changed(value):
	var player = PlayersNode.get_child(PlayerList.selected)
	if player != LocalPlayer:
		player.get_node("PlayerFrame").laglatency = value


var playerbeingrecorded = null
func _on_log_rec_toggled(toggled_on):
	if toggled_on:
		assert (playerbeingrecorded == null and PlayerList.selected >= 0)
		playerbeingrecorded = PlayersNode.get_child(PlayerList.selected)
		var logrecfile = FileAccess.open("user://logrec.dat", FileAccess.WRITE)
		print("logging to: ", logrecfile.get_path_absolute())
		
		#var avatardata = playerbeingrecorded.PF_datafornewconnectedplayer()
		var pf = playerbeingrecorded.get_node("PlayerFrame")
		var avatardata = { "avatarsceneresource":playerbeingrecorded.scene_file_path }
		if pf.get("framedata0"):
			avatardata["framedata0"] = pf.framedata0.duplicate()
		else:
			avatardata["framedata0"] = pf.completedframe0.duplicate()
		avatardata["playername"] = playerbeingrecorded.playername()
		avatardata["t"] = Time.get_ticks_msec()*0.001
		logrecfile.store_var(avatardata)
		playerbeingrecorded.get_node("PlayerFrame").logrecfile = logrecfile
	else:
		if playerbeingrecorded != null:
			var pf = playerbeingrecorded.get_node("PlayerFrame")
			assert (pf.logrecfile != null)
			pf.logrecfile.store_var({ "t":Time.get_ticks_msec()*0.001, "END":true })
			pf.logrecfile.close()
			pf.logrecfile = null
			playerbeingrecorded = null
