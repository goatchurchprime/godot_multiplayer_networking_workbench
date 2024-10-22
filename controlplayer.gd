extends Area2D

var batvelocity = 200
var clientawaitingspawnpoint = false
var nextframeisfirst = false

var minmouseposition = Vector2(300 - 1800/2, 400 - 1500/2)
var maxmouseposition = Vector2(300 + 1800/2, 400 + 1500/2)

# The PF_functions are called by the PlayerConnections object and the 
# PlayerFrame node which is a child of this player node and handles 
# the rpc calls between the players in the network

# This same class is used for the local player and the remote players, 
# so the send and receive data functions can be seen here in pairs


# Startup initialization of ourself (before a connection has been made)
var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", "Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]
func PF_initlocalplayer():
	randomize()
	position.y += randi()%300
	modulate = Color.YELLOW
	$Label.text = possibleusernames[randi()%len(possibleusernames)]

# Called on connection to server so we can get ready
func PF_connectedtoserver():
	if not multiplayer.is_server():
		clientawaitingspawnpoint = true
		print("  sdff  spawnpointreceivedfromserver ", clientawaitingspawnpoint)

func spawnpointfornewplayer():
	var sfd = { NCONSTANTS.CFI_RECT_POSITION: position }
	sfd[NCONSTANTS.CFI_RECT_POSITION].y -= 20
	while true:
		for player in get_parent().get_children():
			if player != self:
				if abs(player.position.y - sfd[NCONSTANTS.CFI_RECT_POSITION].y) < 10 and abs(player.position.x - sfd[NCONSTANTS.CFI_RECT_POSITION].x) < 500:
					sfd[NCONSTANTS.CFI_RECT_POSITION].y = player.position.y - 20
					continue
		break
	return sfd

func spawnpointreceivedfromserver(sfd):
	print("** spawnpointreceivedfromserver", sfd)
	PF_framedatatoavatar(sfd)
	get_node("PlayerFrame").bnextframerecordalltracks = true
	clientawaitingspawnpoint = false
	print("  gggsdff  spawnpointreceivedfromserver ", clientawaitingspawnpoint)
	nextframeisfirst = true
	
# Data about ourself that is sent to the other players on connection
func PF_datafornewconnectedplayer():
	var avatardata = { "avatarsceneresource":scene_file_path, 
						"labeltext":$Label.text
					 }

	# if we are the server then we should send them a spawn point
	if multiplayer.is_server():
		avatardata["spawnframedata"] = spawnpointfornewplayer()

	# if we are already spawned then we should send our position
	if not clientawaitingspawnpoint:
		avatardata["framedata0"] = get_node("PlayerFrame").framedata0.duplicate()
		avatardata["framedata0"].erase(NCONSTANTS.CFI_TIMESTAMP_F0)
		get_node("PlayerFrame").bnextframerecordalltracks = true
		
	return avatardata

# The receiver of the the above function after the scene 
# specified by avatarsceneresource has been instanced
func PF_startupdatafromconnectedplayer(avatardata, localplayer):
	$Label.text = avatardata["labeltext"]
	if "framedata0" in avatardata:
		get_node("PlayerFrame").networkedavatarthinnedframedata(avatardata["framedata0"])
	else:
		visible = false
	if "spawnframedata" in avatardata:
		localplayer.spawnpointreceivedfromserver(avatardata["spawnframedata"])


# Function called 
func PF_processlocalavatarposition(delta):
	if clientawaitingspawnpoint:
		return false

	if get_window().has_focus():
		var quickoptions = get_node("../../../../QuickOptions")
		if quickoptions.subviewpointcontainerhasmouse:
			global_position = get_global_mouse_position().clamp(minmouseposition, maxmouseposition)
	return true
	
func PF_avatartoframedata():
	
	var fd = { NCONSTANTS.CFI_RECT_POSITION: position, 
			   NCONSTANTS.CFI_VISIBLE: visible }
	fd[NCONSTANTS.CFI_FIRE_KEY] = Input.is_key_pressed(KEY_SPACE)
	if nextframeisfirst:
		fd[NCONSTANTS.CFI_NOTHINFRAME] = 1
		nextframeisfirst = false
	return fd

# Defunct
func PF_framedatatoavatar(fd):
	if fd.has(NCONSTANTS.CFI_RECT_POSITION):
		position = fd[NCONSTANTS.CFI_RECT_POSITION]
	if fd.has(NCONSTANTS.CFI_VISIBLE):
		visible = fd[NCONSTANTS.CFI_VISIBLE]
	if fd.has(NCONSTANTS.CFI_SPEAKING):
		$SpeakingIcon.visible = fd[NCONSTANTS.CFI_SPEAKING]

func playername():
	return $Label.text 

static func PF_changethinnedframedatafordoppelganger(fd, doppelnetoffset, isframe0):
	fd[NCONSTANTS.CFI_TIMESTAMP] += doppelnetoffset
	fd[NCONSTANTS.CFI_TIMESTAMPPREV] += doppelnetoffset
	if fd.has(NCONSTANTS.CFI_RECT_POSITION):
		#fd[NCONSTANTS.CFI_RECT_POSITION].x = 500 - fd[NCONSTANTS.CFI_RECT_POSITION].x
		fd[NCONSTANTS.CFI_RECT_POSITION].y = 339 - fd[NCONSTANTS.CFI_RECT_POSITION].y
	
