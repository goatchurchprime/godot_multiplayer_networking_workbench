extends Control

var clientawaitingspawnpoint = false

var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", "Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]
func PF_initlocalplayer():
	randomize()
	$Label.text = possibleusernames[randi()%len(possibleusernames)]

# Called on connection to server so we can get ready
func PF_connectedtoserver():
	clientawaitingspawnpoint = not multiplayer.is_server()

func spawnpointfornewplayer():
	return { NCONSTANTS.CFI_ANIMTRACKS+0: position - Vector2(0,20*get_parent().get_child_count()) }

func spawnpointreceivedfromserver(sfd):
	position = sfd[NCONSTANTS.CFI_ANIMTRACKS+0]
	get_node("PlayerFrame").bnextframerecordalltracks = true
	clientawaitingspawnpoint = false
	
# Data about ourself that is sent to the other players on connection
func PF_datafornewconnectedplayer():
	var avatardata = { "avatarsceneresource":scene_file_path, 
					   "labeltext":$Label.text
					 }

	# if we are the server then we should send them a spawn point
	if multiplayer.is_server():
		avatardata["spawnframedata"] = spawnpointfornewplayer()

	return avatardata

# The receiver of the the above function after the scene 
# specified by avatarsceneresource has been instanced
func PF_startupdatafromconnectedplayer(avatardata, localplayer):
	$Label.text = avatardata["labeltext"]
	visible = false
	if "spawnframedata" in avatardata:
		localplayer.spawnpointreceivedfromserver(avatardata["spawnframedata"])

func PF_processlocalavatarposition(delta):
	if clientawaitingspawnpoint:
		return false
	return true

func PF_setspeakingvolume(v):
	$SpeakingBar.scale.x = v

func playername():
	return $Label.text 

static func PF_changethinnedframedatafordoppelganger(fd, doppelnetoffset, isframe0):
	fd[NCONSTANTS.CFI_TIMESTAMP] += doppelnetoffset
	fd[NCONSTANTS.CFI_TIMESTAMPPREV] += doppelnetoffset
	if fd.has(NCONSTANTS.CFI_ANIMTRACKS+0):
		fd[NCONSTANTS.CFI_ANIMTRACKS+0].y = 339 - fd[NCONSTANTS.CFI_ANIMTRACKS+0].y
	
