extends Control


var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", "Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]
func PF_initlocalplayer():
	randomize()
	$Label.text = possibleusernames[randi()%len(possibleusernames)]

func spawninfofornewplayer():
	return { NCONSTANTS.CFI_ANIMTRACKS+0: position - Vector2(0,20*get_parent().get_child_count()) }

func spawninforeceivedfromserver(sfd):
	position = sfd[NCONSTANTS.CFI_ANIMTRACKS+0]
	
func PF_datafornewconnectedplayer(bfordoppelganger):
	var avatardata = { "avatarsceneresource":scene_file_path, 
					   "labeltext":$Label.text
					 }
	avatardata["snapshottracks"] = get_node("PlayerFrame").snapshotallanimatedtracks()
	if not bfordoppelganger:
		avatardata["Dplayernodename"] = get_name()
		avatardata["Dnetworkid"] = get_node("PlayerFrame").networkID
	return avatardata


# The receiver of the the above function after the scene 
# specified by avatarsceneresource has been instanced
func PF_startupdatafromconnectedplayer(avatardata):
	$Label.text = avatardata["labeltext"]
	visible = false

func PF_processlocalavatarposition(delta):
	pass
	
func PF_setspeakingvolume(v):
	$SpeakingBar.scale.x = v

func playername():
	return $Label.text 

static func PF_changethinnedframedatafordoppelganger(fd, doppelnetoffset, isframe0):
	fd[NCONSTANTS.CFI_TIMESTAMP] += doppelnetoffset
	fd[NCONSTANTS.CFI_TIMESTAMPPREV] += doppelnetoffset
	if fd.has(NCONSTANTS.CFI_ANIMTRACKS+0):
		fd[NCONSTANTS.CFI_ANIMTRACKS+0].y = 339 - fd[NCONSTANTS.CFI_ANIMTRACKS+0].y
	
