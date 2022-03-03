extends Node2D

var localavatarvelocity = Vector2()
var batvelocity = 200

func processlocalavatarposition(delta):
	var vec = Vector2((-1 if Input.is_action_pressed("ui_left") else 0) + (1 if Input.is_action_pressed("ui_right") else 0), 
					  (-1 if Input.is_action_pressed("ui_up") else 0) + (1 if Input.is_action_pressed("ui_down") else 0))
	var mousecommandvelocity = get_node("/root/Main/JoystickControls").mousecommandvelocity
	processlocalavatarpositionVec(vec + mousecommandvelocity, delta)
	
func processlocalavatarpositionVec(vec, delta):
	localavatarvelocity = vec
	position = Vector2(clamp(position.x + vec.x*batvelocity*delta, 65, 500), 
					   clamp(position.y + vec.y*batvelocity*delta, 7, 339))
		
func avatartoframedata():
	var fd = { NCONSTANTS.CFI_RECT_POSITION: position }
	fd[NCONSTANTS.CFI_FIRE_KEY] = Input.is_key_pressed(KEY_SPACE)
	return fd

func framedatatoavatar(fd):
	position = fd[NCONSTANTS.CFI_RECT_POSITION]

var possibleusernames = ["Alice", "Beth", "Cath", "Dan", "Earl", "Fred", "George", "Harry", "Ivan", "John", "Kevin", "Larry", "Martin", "Oliver", "Peter", "Quentin", "Robert", "Samuel", "Thomas", "Ulrik", "Victor", "Wayne", "Xavier", "Youngs", "Zephir"]
func initavatarlocal():
	randomize()
	position.y += randi()%300
	modulate = Color.yellow
	$ColorRect/Label.text = possibleusernames[randi()%len(possibleusernames)]

func initavatarremote(avatardata):
	$ColorRect/Label.text = avatardata["labeltext"]

func avatarinitdata():
	var avatardata = { "avatarsceneresource":filename, 
					   "labeltext":$ColorRect/Label.text
					 }
	return avatardata
	
func playername():
	return $ColorRect/Label.text 

static func changethinnedframedatafordoppelganger(fd, doppelnetoffset, isframe0):
	fd[NCONSTANTS.CFI_TIMESTAMP] += doppelnetoffset
	fd[NCONSTANTS.CFI_TIMESTAMPPREV] += doppelnetoffset
	if fd.has(NCONSTANTS.CFI_RECT_POSITION):
		#fd[NCONSTANTS.CFI_RECT_POSITION].x = 500 - fd[NCONSTANTS.CFI_RECT_POSITION].x
		fd[NCONSTANTS.CFI_RECT_POSITION].y = 339 - fd[NCONSTANTS.CFI_RECT_POSITION].y
