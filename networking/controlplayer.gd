extends Label

var networkID = 0   # 0:unconnected, 1:server, -1:connecting, >1:connected to client

var localavatardisplacement = Vector3(0,0,-0.1)*0
func processlocalavatarposition(delta):
	var vec = Vector2((-1 if Input.is_action_pressed("ui_left") else 0) + (1 if Input.is_action_pressed("ui_right") else 0), 
					  (-1 if Input.is_action_pressed("ui_up") else 0) + (1 if Input.is_action_pressed("ui_down") else 0))
	processlocalavatarpositionVec(vec, delta)
	
func processlocalavatarpositionVec(vec, delta):
	rect_position = Vector2(clamp(rect_position.x + vec.x*200*delta, 0, 500), 
							clamp(rect_position.y + vec.y*200*delta, 0, 300))
		
func avatartoframedata():
	var fd = { "rect_position":	rect_position }
	return fd

func framedatatoavatar(fd):
	rect_position = fd["rect_position"]

func initavatar(avatardata):
	if avatardata.has("playernodename"):
		set_name(avatardata["playernodename"])
	if avatardata.has("networkid"):
		networkID = avatardata["networkid"]
	text = avatardata["labeltext"]

func avatarinitdata():
	var avatardata = { "playernodename":get_name(),
					   "avatarsceneresource":filename, 
					   "networkid":networkID, 
					   "labeltext":text
					 }
	return avatardata
	
static func changethinnedframedatafordoppelganger(fd):
	if fd.has("rect_position"):
		fd["rect_position"].x = 500 - fd["rect_position"].x
