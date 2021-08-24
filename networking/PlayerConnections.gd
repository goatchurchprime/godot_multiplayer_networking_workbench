extends ColorRect

# command for running locally on the unix partition
# /mnt/c/Users/henry/godot/Godot_v3.2.3-stable_linux_server.64 --main-pack /mnt/c/Users/henry/godot/games/OQ_Networking_Demo/releases/OQ_Networking_Demo.pck
export var playernodepath : NodePath = "/root/Main/Players"
onready var PlayersNode = get_node(playernodepath)
var LocalPlayer = null

var deferred_playerconnections = [ ]
var remote_players_idstonodenames = { }
var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John"]

onready var NetworkGateway = get_node("..")

func _ready():
	assert (PlayersNode.get_child_count() == 1) 
	LocalPlayer = PlayersNode.get_child(0)
	if not LocalPlayer.has_node("PlayerFrame"):
		var playerframe = Node.new()
		playerframe.name = "PlayerFrame"
		playerframe.set_script(load("res://networking/LocalPlayerFrame.gd"))
		LocalPlayer.add_child(playerframe)

	randomize()
	var randomusername = LocalPlayer.initavatar({"labeltext":possibleusernames[randi()%len(possibleusernames)]})

	get_tree().connect("network_peer_connected", 	self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")

	get_tree().connect("connected_to_server", 		self, "_connected_to_server")
	get_tree().connect("connection_failed", 		self, "_connection_failed")
	get_tree().connect("server_disconnected", 		self, "_server_disconnected")

	_server_disconnected()

func updatestatusrec(ptxt):
	$ColorRect/StatusRec.text = "%sNetworkID: %d\nRemotes: %s" % [ptxt, LocalPlayer.networkID, PoolStringArray(remote_players_idstonodenames.values()).join(", ")]

func SetNetworkedMultiplayerPeer(peer):
	if peer != null:
		get_tree().set_network_peer(peer)
		if get_tree().is_network_server():
			_connected_to_server()
		else:
			$ColorRect.color = Color.yellow
			LocalPlayer.networkID = -1
	else:
		get_tree().set_network_peer(null)

func _server_disconnected():	
	var ns = NetworkGateway.get_node("NetworkOptions").selected
	get_tree().set_network_peer(null)
	LocalPlayer.networkID = 0
	LocalPlayer.set_name("R%d" % LocalPlayer.networkID) 
	deferred_playerconnections.clear()
	for id in remote_players_idstonodenames.duplicate():
		_player_disconnected(id)
	print("*** _server_disconnected ", LocalPlayer.networkID)
	var selectasclient = (ns >= NetworkGateway.NETWORK_OPTIONS.LOCAL_NETWORK)	
	$ColorRect.color = Color.red if selectasclient else Color.black
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


func _connection_failed():
	NetworkGateway.get_node("NetworkOptions").select(NetworkGateway.NETWORK_OPTIONS.NETWORK_OFF)
	updatestatusrec("Connection failed\n")

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
	
