extends Control

var clientawaitingspawnpoint = false
var nextframeisfirst = false

var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", "Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]
func PF_initlocalplayer():
	randomize()
	$Label.text = possibleusernames[randi()%len(possibleusernames)]

# Called on connection to server so we can get ready
func PF_connectedtoserver():
	clientawaitingspawnpoint = not multiplayer.is_server()

func spawnpointfornewplayer():
	return { NCONSTANTS.CFI_RECT_POSITION: position - Vector2(0,20*get_parent().get_child_count()) }

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
	return true

func PF_framedatatoavatar(fd):
	if fd.has(NCONSTANTS.CFI_RECT_POSITION):
		position = fd[NCONSTANTS.CFI_RECT_POSITION]
	if fd.has(NCONSTANTS.CFI_VISIBLE):
		visible = fd[NCONSTANTS.CFI_VISIBLE]
	if fd.has(NCONSTANTS.CFI_SPEAKING):
		$SpeakingIcon.visible = fd[NCONSTANTS.CFI_SPEAKING]

func playername():
	return $Label.text 

func setplayername(lname):
	$Label.text = lname

static func PF_changethinnedframedatafordoppelganger(fd, doppelnetoffset, isframe0):
	fd[NCONSTANTS.CFI_TIMESTAMP] += doppelnetoffset
	fd[NCONSTANTS.CFI_TIMESTAMPPREV] += doppelnetoffset
	if fd.has(NCONSTANTS.CFI_ANIMTRACKS+0):
		fd[NCONSTANTS.CFI_ANIMTRACKS+0].y = 339 - fd[NCONSTANTS.CFI_ANIMTRACKS+0].y
	
