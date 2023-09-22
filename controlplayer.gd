extends Node2D

var localavatarvelocity = Vector2()
var batvelocity = 200
var PAV_clientawaitingspawnpoint = 0  # 1 awaiting, -1 next frame is first

func PAV_processlocalavatarposition(delta):
	var vec = Vector2((-1 if Input.is_action_pressed("ui_left") else 0) + (1 if Input.is_action_pressed("ui_right") else 0), 
						(-1 if Input.is_action_pressed("ui_up") else 0) + (1 if Input.is_action_pressed("ui_down") else 0))
	var mousecommandvelocity = get_node("/root/Main/JoystickControls").mousecommandvelocity
	processlocalavatarpositionVec(vec + mousecommandvelocity, delta)
	
func processlocalavatarpositionVec(vec, delta):
	localavatarvelocity = vec
	position = Vector2(clamp(position.x + vec.x*batvelocity*delta, 65, 500), 
						clamp(position.y + vec.y*batvelocity*delta, 7, 339))
		
func PAV_avatartoframedata():
	var fd = { NCONSTANTS.CFI_RECT_POSITION: position, 
				NCONSTANTS.CFI_VISIBLE: visible }
	fd[NCONSTANTS.CFI_FIRE_KEY] = Input.is_key_pressed(KEY_SPACE)
	return fd

func PAV_framedatatoavatar(fd):
	if fd.has(NCONSTANTS.CFI_RECT_POSITION):
		position = fd[NCONSTANTS.CFI_RECT_POSITION]
	if fd.has(NCONSTANTS.CFI_VISIBLE):
		visible = fd[NCONSTANTS.CFI_VISIBLE]

var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", "Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]
func PAV_initavatarlocal():
	randomize()
	position.y += randi()%300
	modulate = Color.YELLOW
	$ColorRect/Label.text = possibleusernames[randi()%len(possibleusernames)]

func PAV_initavatarremote(avatardata):
	$ColorRect/Label.text = avatardata["labeltext"]

func PAV_avatarinitdata():
	var avatardata = { "avatarsceneresource":scene_file_path, 
						"labeltext":$ColorRect/Label.text
						}
	return avatardata
	
func playername():
	return $ColorRect/Label.text 

static func PAV_changethinnedframedatafordoppelganger(fd, doppelnetoffset, isframe0):
	fd[NCONSTANTS.CFI_TIMESTAMP] += doppelnetoffset
	fd[NCONSTANTS.CFI_TIMESTAMPPREV] += doppelnetoffset
	if fd.has(NCONSTANTS.CFI_RECT_POSITION):
		#fd[NCONSTANTS.CFI_RECT_POSITION].x = 500 - fd[NCONSTANTS.CFI_RECT_POSITION].x
		fd[NCONSTANTS.CFI_RECT_POSITION].y = 339 - fd[NCONSTANTS.CFI_RECT_POSITION].y

func PAV_createspawnpoint():
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
	
func PAV_receivespawnpoint(sfd):
	PAV_framedatatoavatar(sfd)
	PAV_clientawaitingspawnpoint = -1
