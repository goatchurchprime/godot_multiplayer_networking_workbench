extends Panel




export var remoteservers = [ "192.168.43.1", "192.168.8.111" ]

var websocketobjecttopoll = null


enum NETWORK_OPTIONS { NETWORK_OFF = 0
					   AS_SERVER = 1,
					   LOCAL_NETWORK = 2,
					   FIXED_URL = 3,
					 }
enum NETWORK_PROTOCOL { ENET = 0, 
						WEBSOCKET = 1,
						WEBRTC_WEBSOCKETSIGNAL = 2
						WEBRTC_MQTTSIGNAL = 3
					  }



const errordecodes = { ERR_ALREADY_IN_USE:"ERR_ALREADY_IN_USE", 
					   ERR_CANT_CREATE:"ERR_CANT_CREATE"
					 }

# command for running locally on the unix partition
# /mnt/c/Users/henry/godot/Godot_v3.2.3-stable_linux_server.64 --main-pack /mnt/c/Users/henry/godot/games/OQ_Networking_Demo/releases/OQ_Networking_Demo.pck
export var playernodepath = "/root/Main/Players"
onready var PlayersNode = get_node(playernodepath)
var LocalPlayer = null

var deferred_playerconnections = [ ]
var remote_players_idstonodenames = { }
var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John"]

func _ready():
	assert (PlayersNode.get_child_count() == 1)  # Must have a 
	LocalPlayer = PlayersNode.get_child(0)
	if not LocalPlayer.has_node("PlayerFrame"):
		var playerframe = Node.new()
		playerframe.name = "PlayerFrame"
		playerframe.set_script(load("res://networking/LocalPlayerFrame.gd"))
		LocalPlayer.add_child(playerframe)

	randomize()
	var randomusername = LocalPlayer.initavatar({"labeltext":possibleusernames[randi()%len(possibleusernames)]})
	for rs in remoteservers:
		$NetworkOptions.add_item(rs)

	get_tree().connect("network_peer_connected", 	self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")

	get_tree().connect("connected_to_server", 		self, "_connected_to_server")
	get_tree().connect("connection_failed", 		self, "_connection_failed")
	get_tree().connect("server_disconnected", 		self, "_server_disconnected")

	yield(get_tree().create_timer(1.5), "timeout")
	if OS.has_feature("Server"):
		$NetworkOptions.select(NETWORK_OPTIONS.AS_SERVER)
	if OS.has_feature("HTML5"):
		$NetworkOptions.get_item(NETWORK_OPTIONS.LOCAL_NETWORK).disabled = true
		
	_server_disconnected()
	_on_OptionButton_item_selected($NetworkOptions.selected)

func _input(event):
	if event is InputEventKey and event.pressed:
		var bsel = -1
		if (event.scancode == KEY_0):	bsel = 0
		elif (event.scancode == KEY_1):	bsel = 1
		elif (event.scancode == KEY_2):	bsel = 2
		elif (event.scancode == KEY_3):	bsel = 3
		elif (event.scancode == KEY_4):	bsel = 4

		if bsel != -1 and $NetworkOptions.selected != bsel:
			$NetworkOptions.select(bsel)
			_on_OptionButton_item_selected(bsel)
		elif (event.scancode == KEY_G):
			$Doppelganger.pressed = not $Doppelganger.pressed

func updatestatusrec(ptxt):
	$ColorRect/StatusRec.text = "%sNetworkID: %d\nRemotes: %s" % [ptxt, LocalPlayer.networkID, PoolStringArray(remote_players_idstonodenames.values()).join(", ")]

func _server_disconnected():
	if websocketobjecttopoll != null:
		if LocalPlayer.networkID == 1:
			websocketobjecttopoll.stop()
		else:
			websocketobjecttopoll.close()
		websocketobjecttopoll = null
	if $ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_WEBSOCKETSIGNAL:
		if LocalPlayer.networkID == 1:
			$SignallingWebsocket.stopwebsocketserver()
		else:
			$SignallingWebsocket.closeconnection()
	
	var ns = $NetworkOptions.selected
	get_tree().set_network_peer(null)
	LocalPlayer.networkID = 0
	LocalPlayer.set_name("R%d" % LocalPlayer.networkID) 
	deferred_playerconnections.clear()
	for id in remote_players_idstonodenames.duplicate():
		_player_disconnected(id)
	print("*** _server_disconnected ", LocalPlayer.networkID)
	$ColorRect.color = Color.red if (ns >= NETWORK_OPTIONS.LOCAL_NETWORK) else Color.black
	updatestatusrec("")
	updateplayerlist()

func _connected_to_server():
	LocalPlayer.networkID = get_tree().get_network_unique_id()
	assert (LocalPlayer.networkID >= 1)
	LocalPlayer.set_name("R%d" % LocalPlayer.networkID)
	print("_connected_to_server myid=", LocalPlayer.networkID)
	for id in deferred_playerconnections:
		_player_connected(id)
	deferred_playerconnections.clear()
	$ColorRect.color = Color.green
	updatestatusrec("")
	updateplayerlist()

func setnetworkoff():
	$NetworkOptions.select(NETWORK_OPTIONS.NETWORK_OFF)
	
func _connection_failed():
	$NetworkOptions.select(NETWORK_OPTIONS.NETWORK_OFF)
	updatestatusrec("Connection failed\n")
	return
	
	print("_connection_failed ", LocalPlayer.networkID)
	assert (LocalPlayer.networkID == -1)
	get_tree().set_network_peer(null)	
	LocalPlayer.networkID = 0
	deferred_playerconnections.clear()
	$ColorRect.color = Color.red
	websocketobjecttopoll = null

func updateplayerlist():
	var plp = $PlayerList.get_item_text($PlayerList.selected).split(" ")[0].replace("*", "")
	$PlayerList.clear()
	$PlayerList.selected = 0
	for player in PlayersNode.get_children():
		$PlayerList.add_item(("*" if player == LocalPlayer else "") + player.get_name() + " " + player.text)
		if plp == player.get_name():
			$PlayerList.selected = $PlayerList.get_item_count() - 1

func _player_connected(id):
	if LocalPlayer.networkID == -1:
		deferred_playerconnections.push_back(id)
		print("_player_connected remote=", id, "  **deferred")
		return
	print("_player_connected remote=", id)
	assert (LocalPlayer.networkID >= 1)
	assert (not remote_players_idstonodenames.has(id))
	remote_players_idstonodenames[id] = null
	print("players_connected_list: ", remote_players_idstonodenames)
	var avatardata = LocalPlayer.avatarinitdata()
	avatardata["framedata0"] = LocalPlayer.get_node("PlayerFrame").framedata0
	if $SignallingWebsocket.Dpeer != null:
		print("Dpeer.get_connection_state ", $SignallingWebsocket.Dpeer.get_connection_state(), " tree: ", get_tree().network_peer.get_connection_status())
	print("calling spawnintoremoteplayer at ", id)
	rpc_id(id, "spawnintoremoteplayer", avatardata)
	updatestatusrec("")

	
func _player_disconnected(id):
	print("_player_disconnected remote=", id)
	assert (remote_players_idstonodenames.has(id))
	var remoteplayernodename = remote_players_idstonodenames[id]
	remote_players_idstonodenames.erase(id)
	if remoteplayernodename != null:
		removeremoteplayer(remoteplayernodename)
	print("players_connected_list: ", remote_players_idstonodenames)
	updatestatusrec("")
	updateplayerlist()

remote func spawnintoremoteplayer(avatardata):
	var senderid = get_tree().get_rpc_sender_id()
	print("rec spawnintoremoteplayer from ", senderid)
	var remoteplayer = newremoteplayer(avatardata)
	assert (senderid == avatardata["networkid"])
	remoteplayer.get_node("PlayerFrame").set_network_master(senderid)
	assert (remote_players_idstonodenames[senderid] == null)
	remote_players_idstonodenames[senderid] = remoteplayer.get_name()
	updateplayerlist()
	
var Dudpcount = 0
func _process(delta):
	if websocketobjecttopoll != null:
		websocketobjecttopoll.poll()


				
func _data_channel_received(channel: Object):
	print("_data_channel_received ", channel)

func udpreceivedipnumber(receivedIPnumber):

	var ns = $NetworkOptions.selected
	for nsi in range(NETWORK_OPTIONS.FIXED_URL, $NetworkOptions.get_item_count()):
		if receivedIPnumber == $NetworkOptions.get_item_text(nsi):
			ns = nsi
			break
	if ns == NETWORK_OPTIONS.LOCAL_NETWORK:
		$NetworkOptions.add_item(receivedIPnumber)
		ns = $NetworkOptions.get_item_count() - 1
	$NetworkOptions.select(ns)
	_on_OptionButton_item_selected(ns)


func _on_OptionButton_item_selected(ns):
	var selectasoff = (ns == NETWORK_OPTIONS.NETWORK_OFF)
	var selectasserver = (ns == NETWORK_OPTIONS.AS_SERVER)
	var selectasclient = (ns >= NETWORK_OPTIONS.LOCAL_NETWORK)
	$NetworkRole/ServermodeMQTTsignal.visible = ($ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	if $ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
		$NetworkRole/ServermodeMQTTsignal.visible = selectasserver
		$NetworkRole/ClientmodeMQTTsignal.visible = selectasclient
		if $NetworkRole/SetupMQTTsignal/autoconnect.pressed or $NetworkRole/ServermodeMQTTsignal/StartServer.pressed:
			$NetworkRole/ServermodeMQTTsignal/StartServer.pressed = selectasserver
		if $NetworkRole/SetupMQTTsignal/autoconnect.pressed or $NetworkRole/ClientmodeMQTTsignal/StartClient.pressed:
			$NetworkRole/ClientmodeMQTTsignal/StartClient.pressed = selectasclient
	$ProtocolOptions.disabled = not selectasoff



func D_on_OptionButton_item_selected(ns):
	print(" _on_OptionButton_item_selected ", ns)
	if $ProtocolOptions.selected != NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
		if ns == NETWORK_OPTIONS.LOCAL_NETWORK:
			$SignallingUDP.start_udp_localIP_discovery_signals(false)
		else:
			$SignallingUDP.stop_udp_localIP_discovery_signals()

	if LocalPlayer.networkID != 0:
		if get_tree().get_network_peer() != null:
			print("closing connection ", LocalPlayer.networkID, get_tree().get_network_peer())
		_server_disconnected()

	assert (LocalPlayer.networkID == 0)

	if ns == NETWORK_OPTIONS.AS_SERVER:
		var networkedmultiplayerserver = null
		var servererror = 0
		if $ProtocolOptions.selected == NETWORK_PROTOCOL.WEBSOCKET:
			print("creating Websocket server on port: ", int($NetworkOptions/portnumber.text))
			networkedmultiplayerserver = WebSocketServer.new()
			servererror = networkedmultiplayerserver.listen(int($NetworkOptions/portnumber.text), PoolStringArray(), true)
			if servererror == 0:
				websocketobjecttopoll = networkedmultiplayerserver
		elif $ProtocolOptions.selected == NETWORK_PROTOCOL.ENET:
			print("creating ENet server on port: ", int($NetworkOptions/portnumber.text))
			networkedmultiplayerserver = NetworkedMultiplayerENet.new()
			servererror = networkedmultiplayerserver.create_server(int($NetworkOptions/portnumber.text))

		elif $ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_WEBSOCKETSIGNAL:
			networkedmultiplayerserver = WebRTCMultiplayer.new()
			servererror = networkedmultiplayerserver.initialize(1, true)
			$SignallingWebsocket.startwebsocketserver(int($NetworkOptions/portnumber.text))

		elif $ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
			networkedmultiplayerserver = WebRTCMultiplayer.new()
			servererror = networkedmultiplayerserver.initialize(1, true)
			$SignallingMQTT.serverstate_startmqttsignalling($NetworkOptions/roomname.text)

		if (not OS.has_feature("Server")) and (not OS.has_feature("HTML5")) \
				and $ProtocolOptions.selected != NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
			$SignallingUDP.start_udp_localIP_discovery_signals(true)

		if servererror == OK:
			get_tree().set_network_peer(networkedmultiplayerserver)
			_connected_to_server()
			print("networkedmultiplayerserver.is_network_server ", get_tree().is_network_server(), " tree: ", get_tree().network_peer.get_connection_status())
			if (not OS.has_feature("Server")) and (not OS.has_feature("HTML5")) and $ProtocolOptions.selected != NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL:
				$SignallingUDP.start_udp_localIP_discovery_signals(true)

		else:
			print("networkedmultiplayer createserver Error: ", errordecodes.get(servererror, servererror))
			print("*** is there a server running on this port already? ", int($NetworkOptions/portnumber.text))
			$ColorRect.color = Color.red
			$NetworkOptions.select(NETWORK_OPTIONS.NETWORK_OFF)

	if $ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL and ns > NETWORK_OPTIONS.AS_SERVER:
		$SignallingMQTT.clientstate_connecttomqttsignal($NetworkOptions/roomname.text)
		$ColorRect.color = Color.yellow
		LocalPlayer.networkID = -1
		
	elif ns >= NETWORK_OPTIONS.FIXED_URL and LocalPlayer.networkID == 0:
		var serverIPnumber = $NetworkOptions.get_item_text(ns).split(" ", 1)[0]
		var networkedmultiplayerclient = null
		var clienterror = 0
		if $ProtocolOptions.selected == NETWORK_PROTOCOL.WEBSOCKET:
			var url = "ws://%s:%d" % [serverIPnumber, int($NetworkOptions/portnumber.text)]
			print("Websocketclient connect to: ", url)
			networkedmultiplayerclient = WebSocketClient.new();
			clienterror = networkedmultiplayerclient.connect_to_url(url, PoolStringArray(), true)
		elif $ProtocolOptions.selected == NETWORK_PROTOCOL.ENET:
			print("networkedmultiplayerenet createclient ", serverIPnumber, ":", int($NetworkOptions/portnumber.text))
			networkedmultiplayerclient = NetworkedMultiplayerENet.new()
			clienterror = networkedmultiplayerclient.create_client(serverIPnumber, int($NetworkOptions/portnumber.text), 0, 0)
		elif $ProtocolOptions.selected == NETWORK_PROTOCOL.WEBRTC_WEBSOCKETSIGNAL:
			var wsurl = "ws://%s:%d" % [serverIPnumber, int($NetworkOptions/portnumber.text)]
			print("networkedmultiplayerwebrtc createwebsocket signal ", wsurl)
			$SignallingWebsocket.connectwebsocket(wsurl)

		if clienterror == 0:
			get_tree().set_network_peer(networkedmultiplayerclient)
			print("networkedmultiplayerclient.is_network_server ", get_tree().is_network_server())
			$ColorRect.color = Color.yellow
			LocalPlayer.networkID = -1
		else:
			print("networkedmultiplayer createclient Error: ", errordecodes.get(clienterror, clienterror))
			print("*** is there a server running on this port already? ", int($NetworkOptions/portnumber.text))
			$ColorRect.color = Color.red
			$NetworkOptions.select(NETWORK_OPTIONS.NETWORK_OFF)
		
	$ProtocolOptions.disabled = ($NetworkOptions.selected != NETWORK_OPTIONS.NETWORK_OFF)
	
func _on_Doppelganger_toggled(button_pressed):
	if button_pressed:
		$DoppelgangerPanel.visible = true
		var avatardata = LocalPlayer.avatarinitdata()
		avatardata["playernodename"] = "Doppelganger"
		var fd = LocalPlayer.get_node("PlayerFrame").framedata0.duplicate()
		LocalPlayer.changethinnedframedatafordoppelganger(fd)
		avatardata["framedata0"] = fd
		LocalPlayer.get_node("PlayerFrame").doppelgangernode = newremoteplayer(avatardata)
	else:
		$DoppelgangerPanel.visible = false
		LocalPlayer.get_node("PlayerFrame").doppelgangernode = null
		removeremoteplayer("Doppelganger")
	updateplayerlist()

func newremoteplayer(avatardata):
	var remoteplayer = PlayersNode.get_node_or_null(avatardata["playernodename"])
	if remoteplayer == null:
		remoteplayer = load(avatardata["avatarsceneresource"]).instance()
		if not remoteplayer.has_node("PlayerFrame"):
			var playerframe = Node.new()
			playerframe.name = "PlayerFrame"
			playerframe.set_script(load("res://networking/RemotePlayerFrame.gd"))
			remoteplayer.add_child(playerframe)
		remoteplayer.initavatar(avatardata)
		PlayersNode.add_child(remoteplayer)
		if "framedata0" in avatardata:
			remoteplayer.get_node("PlayerFrame").networkedavatarthinnedframedata(avatardata["framedata0"])
		print("Adding remoteplayer: ", avatardata["playernodename"])
	else:
		print("** remoteplayer already exists: ", avatardata["playernodename"])
	return remoteplayer
	
func removeremoteplayer(playernodename):
	var remoteplayer = PlayersNode.get_node_or_null(playernodename)
	if remoteplayer != null:
		PlayersNode.remove_child(remoteplayer)
		remoteplayer.queue_free()
		print("Removing remoteplayer: ", playernodename)
	else:
		print("** remoteplayer already removed: ", playernodename)
	


func _on_ProtocolOptions_item_selected(np):
	$NetworkOptions/portnumber.visible = (np != NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)
	$NetworkOptions/roomname.visible = (np == NETWORK_PROTOCOL.WEBRTC_MQTTSIGNAL)


