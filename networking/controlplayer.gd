extends Node2D

var localavatardisplacement = Vector3(0,0,-0.1)*0
func processlocalavatarposition(delta):
	var vec = Vector2((-1 if Input.is_action_pressed("ui_left") else 0) + (1 if Input.is_action_pressed("ui_right") else 0), 
					  (-1 if Input.is_action_pressed("ui_up") else 0) + (1 if Input.is_action_pressed("ui_down") else 0))
	processlocalavatarpositionVec(vec, delta)
	
func processlocalavatarpositionVec(vec, delta):
	position = Vector2(clamp(position.x + vec.x*200*delta, 65, 500), 
					   clamp(position.y + vec.y*200*delta, 7, 339))
		
func avatartoframedata():
	var fd = { NCONSTANTS.CFI_RECT_POSITION: position }
	fd[NCONSTANTS.CFI_FIRE_KEY] = Input.is_key_pressed(KEY_SPACE)
	return fd

func framedatatoavatar(fd):
	position = fd[NCONSTANTS.CFI_RECT_POSITION]

func initavatar(avatardata, firstlocalinit):
	if firstlocalinit:
		position.y += randi()%300
		modulate = Color.yellow
	$ColorRect/Label.text = avatardata["labeltext"]

func avatarinitdata():
	var avatardata = { "avatarsceneresource":filename, 
					   "labeltext":$ColorRect/Label.text
					 }
	return avatardata
	
func playername():
	return $ColorRect/Label.text 

static func changethinnedframedatafordoppelganger(fd, doppelnetoffset):
	fd[NCONSTANTS.CFI_TIMESTAMP] += doppelnetoffset
	fd[NCONSTANTS.CFI_TIMESTAMPPREV] += doppelnetoffset
	if fd.has(NCONSTANTS.CFI_RECT_POSITION):
		#fd[NCONSTANTS.CFI_RECT_POSITION].x = 500 - fd[NCONSTANTS.CFI_RECT_POSITION].x
		fd[NCONSTANTS.CFI_RECT_POSITION].y = 339 - fd[NCONSTANTS.CFI_RECT_POSITION].y
