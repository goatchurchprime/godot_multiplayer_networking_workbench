extends Area2D

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

func spawninfofornewplayer():
	var pos = position
	pos.y -= 20
	while true:
		for player in get_parent().get_children():
			if player != self:
				if abs(player.position.y - pos.y) < 10 and abs(player.position.x - pos.x) < 500:
					pos.y = player.position.y - 20
					continue
		break
	var ipostrack = 0
	return { NCONSTANTS.CFI_ANIMTRACKS+ipostrack: pos }

func spawninforeceivedfromserver(sfd):
	print("** spawninforeceivedfromserver", sfd)
	position = sfd[NCONSTANTS.CFI_ANIMTRACKS+0]
	
# Data about ourself that is sent to the other players on connection
func PF_datafornewconnectedplayer():
	var avatardata = { "avatarsceneresource":scene_file_path, 
						"labeltext":$Label.text
					 }
	return avatardata

# The receiver of the the above function after the scene 
# specified by avatarsceneresource has been instanced
func PF_startupdatafromconnectedplayer(avatardata):
	$Label.text = avatardata["labeltext"]
	visible = false

func PF_processlocalavatarposition(delta):
	if get_window().has_focus():
		var quickoptions = get_node("../../../../QuickOptions")
		if quickoptions.subviewpointcontainerhasmouse:
			global_position = get_global_mouse_position().clamp(minmouseposition, maxmouseposition)
	
func PF_setspeakingvolume(v):
	$SpeakingBar.scale.x = v

func playername():
	return $Label.text 

static func PF_changethinnedframedatafordoppelganger(fd, doppelnetoffset, isframe0):
	fd[NCONSTANTS.CFI_TIMESTAMP] += doppelnetoffset
	fd[NCONSTANTS.CFI_TIMESTAMPPREV] += doppelnetoffset
	if fd.has(NCONSTANTS.CFI_ANIMTRACKS+0):
		fd[NCONSTANTS.CFI_ANIMTRACKS+0].y = 339 - fd[NCONSTANTS.CFI_ANIMTRACKS+0].y
