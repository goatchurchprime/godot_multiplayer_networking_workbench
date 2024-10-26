extends Control


## PlayerConnections 
##
## This object receives and manages all networked multiplayer connections and 
## disconnections


# We should implement this to log what passes through
# https://docs.godotengine.org/en/stable/classes/class_multiplayerapiextension.html

@onready var NetworkGateway = find_parent("NetworkGateway")

const PlayerFrameLocalScenePath = "res://addons/player-networking/PlayerFrameLocal.tscn"
const PlayerFrameRemoteScenePath = "res://addons/player-networking/PlayerFrameRemote.tscn"

var LocalPlayer = null
var LocalPlayerFrame = null
var ServerPlayer = null

var deferred_playerconnections = null
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
	if PlayerList.selected == -1:
		PlayerList.selected = 0

	if PlayersNode.get_child_count() == 1 and NetworkGateway.localplayerscene:
		PlayersNode.get_child(0).free()
	if PlayersNode.get_child_count() == 0:
		PlayersNode.add_child(load(NetworkGateway.localplayerscene).instantiate())
	assert (PlayersNode.get_child_count() == 1) 

	LocalPlayer = PlayersNode.get_child(0)
	if not LocalPlayer.has_node("PlayerFrame"):
		LocalPlayer.add_child(load(PlayerFrameLocalScenePath).instantiate())
	LocalPlayerFrame = LocalPlayer.get_node("PlayerFrame")
	assert (LocalPlayerFrame.scene_file_path == PlayerFrameLocalScenePath)

	LocalPlayerFrame.PlayerConnections = self
	LocalPlayer.PF_initlocalplayer()
	LocalPlayerFrame.setlocalframenetworkidandname(0)

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
	LocalPlayerFrame.setlocalframenetworkidandname(multiplayer.get_unique_id())
	assert (LocalPlayerFrame.networkID >= 1)

	connectionlog("_my networkid=%d\n" % LocalPlayerFrame.networkID)
	print("my playerid=", LocalPlayerFrame.networkID)
	LocalPlayerFrame.bawaitingspawnpoint = not serverisself
	NetworkGateway.Dconnectedplayerscount += 1  
	assert (NetworkGateway.Dconnectedplayerscount == 1)

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
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for id in remote_players_idstonodenames.duplicate():
		_peer_disconnected(id)
	LocalPlayerFrame.setlocalframenetworkidandname(0)
	NetworkGateway.Dconnectedplayerscount -= 1
	assert (NetworkGateway.Dconnectedplayerscount == 0)
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
	if multiplayer.is_server():
		rpc_id(id, "RPCspawndatafromserver", LocalPlayer.spawnpointfornewplayer())
	assert (LocalPlayerFrame.networkID >= 1)
	assert (not remote_players_idstonodenames.has(id))
	remote_players_idstonodenames[id] = null
	print("players_connected_list: ", remote_players_idstonodenames)
	var avatardata = LocalPlayer.PF_datafornewconnectedplayer()
	avatardata["playernodename"] = LocalPlayer.get_name()
	avatardata["networkid"] = LocalPlayerFrame.networkID
	print("calling spawnintoremoteplayer at ", id, " (from ", LocalPlayerFrame.networkID, ") ")
	rpc_id(id, "RPCspawnintoremoteplayer", avatardata)



func _peer_disconnected(id):
	if NetworkGateway.Dconnectedplayerscount == 0 and multiplayer.get_unique_id() == 1:
		print("_peer_disconnected already called by _server_disconnected")
		return
	connectionlog("_remove playerid %d\n" % id)
	print("_peer_disconnected localid=", multiplayer.get_unique_id(), " playerid=", id, " cplayserscount=", NetworkGateway.Dconnectedplayerscount)
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
			var doppelnetoffset = DoppelgangerPanel.getnetoffset()
			var doppelgangerdelay = NetworkGateway.getrandomdoppelgangerdelay(true)
			await get_tree().create_timer(doppelgangerdelay*0.001).timeout
			LocalPlayerFrame.doppelgangernode = newremoteplayer(avatardata)
			LocalPlayer.get_node("PlayerFrame").bnextframerecordalltracks = true
			LocalPlayerFrame.NetworkGatewayForDoppelganger = NetworkGateway
		else:
			var avatardata = rlogrecfile.get_var()
			avatardata["playernodename"] = "Logrecreplay"
			avatardata["networkid"] = LocalPlayer.get_node("PlayerFrame").networkID
			avatardata["labeltext"] = avatardata["playername"]
			LocalPlayerFrame.doppelgangernode = newremoteplayer(avatardata)
			var df = LocalPlayerFrame.doppelgangernode.get_node("PlayerFrame")
			df.doppelgangerrecfile = rlogrecfile
			df.doppelgangernextrec = df.doppelgangerrecfile.get_var()
			df.doppelgangerrectimeoffset = avatardata.t - Time.get_ticks_msec()*0.001
			df.NetworkGatewayForDoppelgangerReplay = NetworkGateway

	else:
		DoppelgangerPanel.seteditable(true)
		var df = LocalPlayerFrame.doppelgangernode.get_node("PlayerFrame")
		if df.doppelgangerrecfile != null:
			df.doppelgangerrecfile.close()
			df.doppelgangerrecfile = null
			df.doppelgangernextrec = null
			df.NetworkGatewayForDoppelgangerReplay = null

			#var a = pf.doppelgangernode.get_node("PlayerAnimation").get_animation("playeral/playanim1")
			#ResourceSaver.save(a, "user://saveanimation.res")


		removeremoteplayer(LocalPlayerFrame.doppelgangernode.get_name())
		LocalPlayerFrame.doppelgangernode = null
		LocalPlayerFrame.NetworkGatewayForDoppelganger = null

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
		# this doesn't seem the right place
	LocalPlayerFrame.bnextframerecordalltracks = true
	updateplayerlist()

@rpc("any_peer", "call_remote", "reliable", 0)
func RPCspawndatafromserver(sfd):
	var rpcsenderid = multiplayer.get_remote_sender_id()
	assert (rpcsenderid == 1)
	LocalPlayer.spawnpointreceivedfromserver(sfd)
	LocalPlayerFrame.bawaitingspawnpoint = false
	LocalPlayerFrame.bnextframerecordalltracks = true

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
			remoteplayer.add_child(load(PlayerFrameRemoteScenePath).instantiate())
		assert (remoteplayer.get_node("PlayerFrame").scene_file_path == PlayerFrameRemoteScenePath)
		remoteplayer.set_name(avatardata["playernodename"])
		remoteplayer.get_node("PlayerFrame").networkID = avatardata["networkid"]
		remoteplayer.PF_startupdatafromconnectedplayer(avatardata)
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
