extends Node2D

var localavatarvelocity = Vector2()
var batvelocity = 200
var clientawaitingspawnpoint = false
var nextframeisfirst = false

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

	global_position = get_global_mouse_position().clamp(Vector2(0,0), get_window().get_size())
	
	var vec = Vector2((-1 if Input.is_action_pressed("ui_left") else 0) + (1 if Input.is_action_pressed("ui_right") else 0), 
						(-1 if Input.is_action_pressed("ui_up") else 0) + (1 if Input.is_action_pressed("ui_down") else 0))
	localavatarvelocity = vec
#	position = Vector2(clamp(position.x + localavatarvelocity.x*batvelocity*delta, 65, 500), 
#					   clamp(position.y + localavatarvelocity.y*batvelocity*delta, 7, 339))
	return true
	
func PF_avatartoframedata():
	var fd = { NCONSTANTS.CFI_RECT_POSITION: position, 
			   NCONSTANTS.CFI_VISIBLE: visible }
	fd[NCONSTANTS.CFI_FIRE_KEY] = Input.is_key_pressed(KEY_SPACE)
	if nextframeisfirst:
		fd[NCONSTANTS.CFI_NOTHINFRAME] = 1
		nextframeisfirst = false
	return fd

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
	
